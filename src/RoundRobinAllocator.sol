// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {VerifRegTypes} from "filecoin-solidity/types/VerifRegTypes.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {UtilsHandlers} from "filecoin-solidity/utils/UtilsHandlers.sol";
import {DataCapAPI} from "filecoin-solidity/DataCapAPI.sol";
import {VerifRegAPI} from "filecoin-solidity/VerifRegAPI.sol";
import {BigInts} from "filecoin-solidity/utils/BigInts.sol";
import {FilAddresses} from "filecoin-solidity/utils/FilAddresses.sol";

import {ErrorLib} from "./lib/Errors.sol";
import {Events} from "./lib/Events.sol";
import {
    AllocationRequestCbor, AllocationRequestData, ProviderAllocationPayload
} from "./lib/AllocationRequestCbor.sol";
import {AllocationResponseCbor} from "./lib/AllocationResponseCbor.sol";
import {Storage} from "./Storage.sol";
import {AllocatorManager} from "./AllocatorManager.sol";
import {OwnerManager} from "./OwnerManager.sol";
import {StorageEntityManager} from "./StorageEntityManager.sol";
import {StorageEntityPicker} from "./StorageEntityPicker.sol";

struct AllocationRequest {
    bytes dataCID;
    uint64 size;
}

struct AllocationPackageReturn {
    address client;
    bool claimed;
    uint64[] storageProviders;
    uint64[][] spAllocationIds;
    uint256 collateral;
}

/**
 * @title RoundRobinAllocator
 * @notice storage allocation contract
 * @dev This contract allows clients to allocate DataCap.
 * DataCap is allocated to storage providers choosen in a round-robin fashion on the Filecoin network.
 *
 * Terminology:
 * Allocation: DataCap allocated by a client to a specific piece of data and storage provider
 * Claim: a provider's assertion they are storing all or part of an allocation
 * Term: period of time for which a DataCap allocation or claim is valid or active.
 */
contract RoundRobinAllocator is
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    AllocatorManager,
    StorageEntityManager,
    StorageEntityPicker,
    OwnerManager
{
    using AllocationRequestCbor for AllocationRequestData[];
    using AllocationRequestCbor for AllocationRequest[];
    using AllocationResponseCbor for DataCapTypes.TransferReturn;

    uint32 constant _FRC46_TOKEN_TYPE = 2233613279;
    address private constant _DATACAP_ADDRESS = address(0xfF00000000000000000000000000000000000007);
    uint256 public constant MIN_REQ_SP = 2;
    uint256 public constant MIN_COLLATERAL_PER_CID = 1;

    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address initialOwner, uint256 collateralPerCID, uint256 minRequiredStorageProviders)
        public
        initializer
    {
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __Pausable_init();

        uint256 maxReplicas = 3;

        if (collateralPerCID < MIN_COLLATERAL_PER_CID) {
            revert ErrorLib.InvalidCollateralPerCID();
        }
        if (minRequiredStorageProviders < MIN_REQ_SP) {
            revert ErrorLib.InvalidMinRequiredStorageProviders();
        }
        if (minRequiredStorageProviders < maxReplicas) {
            revert ErrorLib.InvalidMinRequiredStorageProviders();
        }

        Storage.AppConfig memory appConfig = Storage.AppConfig({
            minReplicas: 1,
            maxReplicas: maxReplicas,
            collateralPerCID: collateralPerCID,
            minRequiredStorageProviders: minRequiredStorageProviders
        });

        Storage.setAppConfig(appConfig);
    }

    function renounceOwnership() public view override onlyOwner {
        revert ErrorLib.OwnershipCannotBeRenounced();
    }

    function getAppConfig() external view returns (Storage.AppConfig memory appConfig) {
        appConfig = Storage.getAppConfig();
    }

    function allocate(uint256 replicaSize, AllocationRequest[] calldata allocReq)
        external
        payable
        whenNotPaused
        onlyEOA
        returns (uint256)
    {
        return _allocate(replicaSize, allocReq);
    }

    function _allocate(uint256 replicaSize, AllocationRequest[] calldata allocReq) internal returns (uint256) {
        if (allocReq.length == 0) {
            revert ErrorLib.InvalidAllocationRequest();
        }
        Storage.AppConfig memory appConfig = Storage.getAppConfig();
        if (replicaSize < appConfig.minReplicas || replicaSize > appConfig.maxReplicas) {
            revert ErrorLib.InvalidReplicaSize();
        }
        if (allocReq.length * replicaSize < appConfig.minRequiredStorageProviders) {
            revert ErrorLib.NotEnoughAllocationData();
        }
        uint256 requiredCollateral = appConfig.collateralPerCID * allocReq.length * replicaSize;
        if (msg.value < requiredCollateral) {
            revert ErrorLib.InsufficientCollateral(requiredCollateral);
        }

        uint64[] memory providers = _pickStorageProviders(appConfig.minRequiredStorageProviders);

        int64 termMin = 518400;
        int64 termMax = 5256000;
        int64 expiration = 114363;
        ProviderAllocationPayload[] memory providerPayloads =
            allocReq.encodeAllocationDataPerProvider(providers, replicaSize, termMin, termMax, expiration);

        uint256 packageId = Storage.s().packageCount++;
        Storage.s().clientAllocationPackages[msg.sender].push(packageId);

        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        // send data cap separately for each provider so we can track allocation IDs per SP
        for (uint256 i = 0; i < providerPayloads.length; i++) {
            uint256 amount = uint256(providerPayloads[i].totalSize) * 10 ** 18;
            DataCapTypes.TransferParams memory params = DataCapTypes.TransferParams({
                to: FilAddresses.fromActorID(6),
                amount: BigInts.fromUint256(amount),
                operator_data: providerPayloads[i].payload
            });
            (int256 exit_code, DataCapTypes.TransferReturn memory result) = DataCapAPI.transfer(params);

            uint64[] memory allocationIds = result.decodeAllocationResponse();
            package.spAllocationIds[providerPayloads[i].provider] = allocationIds;

            if (allocationIds.length != providerPayloads[i].count) {
                revert ErrorLib.AllocationFailed();
            }

            emit Events.AllocationCreated(msg.sender, providerPayloads[i].provider, packageId, amount, allocationIds);

            if (exit_code != 0) {
                revert ErrorLib.DataCapTransferFailed();
            }
        }

        package.client = msg.sender;
        package.storageProviders = providers;
        package.collateral = msg.value;

        emit Events.CollateralLocked(msg.sender, packageId, msg.value);

        return packageId;
    }

    function claim(uint256 packageId) public whenNotPaused {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0) || package.storageProviders.length == 0) {
            revert ErrorLib.InvalidClaim();
        }
        if (package.claimed) {
            revert ErrorLib.CollateralAlreadyClaimed();
        }
        package.claimed = true;

        for (uint256 sp = 0; sp < package.storageProviders.length; sp++) {
            uint64 provider = package.storageProviders[sp];
            uint64[] memory allocationIds = package.spAllocationIds[provider];

            VerifRegTypes.GetClaimsParams memory params = VerifRegTypes.GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(provider),
                claim_ids: _allocationIdsToClaimIds(allocationIds)
            });

            (int256 exit_code, VerifRegTypes.GetClaimsReturn memory result) = VerifRegAPI.getClaims(params);

            if (exit_code != 0) {
                revert ErrorLib.GetClaimsFailed();
            }

            // https://github.com/filecoin-project/builtin-actors/blob/5aad41bfa29d8eab78f91eb5c82a03466c6062d2/actors/verifreg/src/lib.rs#L505-L506
            if (result.batch_info.success_count != allocationIds.length) {
                revert ErrorLib.IncompleteProviderClaims(provider);
            }

            emit Events.AllocationClaimed(package.client, packageId, provider, allocationIds);
        }

        emit Events.CollateralReleased(msg.sender, package.client, packageId, package.collateral);

        payable(package.client).transfer(package.collateral);
    }

    function _allocationIdsToClaimIds(uint64[] memory allocationIds)
        internal
        pure
        returns (CommonTypes.FilActorId[] memory claimIds)
    {
        claimIds = new CommonTypes.FilActorId[](allocationIds.length);
        for (uint256 i = 0; i < allocationIds.length; i++) {
            claimIds[i] = CommonTypes.FilActorId.wrap(allocationIds[i]);
        }
    }

    function getAllocationPackage(uint256 packageId) external view returns (AllocationPackageReturn memory ret) {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0)) {
            revert ErrorLib.InvalidPackageId();
        }

        ret.client = package.client;
        ret.storageProviders = package.storageProviders;
        ret.spAllocationIds = new uint64[][](package.storageProviders.length);
        for (uint256 sp = 0; sp < package.storageProviders.length; sp++) {
            uint64 provider = package.storageProviders[sp];
            ret.spAllocationIds[sp] = package.spAllocationIds[provider];
        }
        ret.claimed = package.claimed;
        ret.collateral = package.collateral;
    }

    /**
     * @notice The handle_filecoin_method function is a universal entry point for calls
     * coming from built-in Filecoin actors. Datacap is an FRC-46 Token. Receiving FRC46
     * tokens requires implementing a Receiver Hook:
     * https://github.com/filecoin-project/FIPs/blob/master/FRCs/frc-0046.md#receiver-hook.
     * We use handle_filecoin_method to handle the receiver hook and make sure that the token
     * sent to our contract is freshly minted Datacap and reject all other calls and transfers.
     * @param method Method number
     * @param inputCodec Codec of the payload
     * @param params Params of the call
     * @dev Reverts if caller is not a datacap contract
     * @dev Reverts if trying to send a unsupported token type
     * @dev Reverts if trying to receive invalid token
     * @dev Reverts if trying to send a unsupported token
     */
    // slither-disable-next-line naming-convention
    function handle_filecoin_method(uint64 method, uint64 inputCodec, bytes calldata params)
        external
        view
        returns (uint32 exitCode, uint64 codec, bytes memory data)
    {
        if (msg.sender != _DATACAP_ADDRESS) {
            revert ErrorLib.InvalidCaller(msg.sender, _DATACAP_ADDRESS);
        }
        CommonTypes.UniversalReceiverParams memory receiverParams =
            UtilsHandlers.handleFilecoinMethod(method, inputCodec, params);
        if (receiverParams.type_ != _FRC46_TOKEN_TYPE) {
            revert ErrorLib.UnsupportedType();
        }
        (uint256 tokenReceivedLength, uint256 byteIdx) = CBORDecoder.readFixedArray(receiverParams.payload, 0);
        if (tokenReceivedLength != 6) revert ErrorLib.InvalidTokenReceived();
        uint64 from;
        (from, byteIdx) = CBORDecoder.readUInt64(receiverParams.payload, byteIdx); // payload == FRC46TokenReceived
        if (from != CommonTypes.FilActorId.unwrap(DataCapTypes.ActorID)) {
            revert ErrorLib.UnsupportedToken();
        }
        exitCode = 0;
        codec = 0;
        data = "";
    }
}
