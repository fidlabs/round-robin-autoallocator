// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {UtilsHandlers} from "filecoin-solidity/utils/UtilsHandlers.sol";
import {DataCapAPI} from "filecoin-solidity/DataCapAPI.sol";
import {BigInts} from "filecoin-solidity/utils/BigInts.sol";
import {FilAddresses} from "filecoin-solidity/utils/FilAddresses.sol";

import {Errors} from "./lib/Errors.sol";
import {AllocationRequestCbor, AllocationRequestData, ProviderAllocationPayload} from "./lib/AllocationRequestCbor.sol";
import {AllocationResponseCbor} from "./lib/AllocationResponseCbor.sol";
import {Storage} from "./Storage.sol";
import {AllocatorManager} from "./AllocatorManager.sol";
import {StorageEntityManager} from "./StorageEntityManager.sol";
import {StorageEntityPicker} from "./StorageEntityPicker.sol";

struct AllocationRequest {
    bytes dataCID;
    uint64 size;
}

struct AllocationResponse {
    uint64 provider;
    uint64[] allocationIds;
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
    StorageEntityPicker
{
    using AllocationRequestCbor for AllocationRequestData[];
    using AllocationRequestCbor for AllocationRequest[];
    using AllocationResponseCbor for DataCapTypes.TransferReturn;

    uint32 constant _FRC46_TOKEN_TYPE = 2233613279;
    address private constant _DATACAP_ADDRESS =
        address(0xfF00000000000000000000000000000000000007);

    event AllocationCreated(
        address indexed client,
        uint64 indexed provider,
        uint256 allocationSize,
        uint64[] allocationIds,
        uint256 collateral
    );

    // TODO: remove me b4 prod
    event DebugBytes(address indexed client, bytes data);
    event DebugUint(address indexed client, uint256 data);

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function initialize(address initialOwner) public initializer {
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __Pausable_init();

        Storage.AppConfig memory appConfig;
        appConfig.minReplicas = 1;
        appConfig.maxReplicas = 3;
        appConfig.collateralPerCID = 1 * 10 ** 18;
        appConfig.minRequiredStorageProviders = 3;

        Storage.setAppConfig(appConfig);
    }

    function renounceOwnership() public view override onlyOwner {
        revert Errors.OwnershipCannotBeRenounced();
    }

    function allocate(
        uint replicaSize,
        AllocationRequest[] calldata allocReq
    ) public payable returns (AllocationResponse[] memory allocationResponses) {
        if (allocReq.length == 0) {
            revert Errors.InvalidAllocationRequest();
        }
        Storage.AppConfig memory appConfig = Storage.getAppConfig();
        if (
            replicaSize < appConfig.minReplicas ||
            replicaSize > appConfig.maxReplicas
        ) {
            revert Errors.InvalidReplicaSize();
        }
        if (
            allocReq.length * replicaSize <
            appConfig.minRequiredStorageProviders
        ) {
            revert Errors.NotEnoughAllocationData();
        }

        uint64[] memory providers = _pickStorageProviders(
            appConfig.minRequiredStorageProviders
        );
  
        int64 termMin = 518400;
        int64 termMax = 5256000;
        int64 expiration = 114363;
        ProviderAllocationPayload[] memory providerPayloads = allocReq
            .encodeAllocationDataPerProvider(
                providers,
                replicaSize,
                termMin,
                termMax,
                expiration
            );

        uint packageId = Storage.s().packageCount++;
        Storage.s().clientAllocationPackages[msg.sender].push(packageId);

        Storage.AllocationPackage storage package = Storage
            .s()
            .allocationPackages[packageId];
        package.client = msg.sender;
        package.storageProviders = providers;

        allocationResponses = new AllocationResponse[](providerPayloads.length);

        // send data cap separately for each provider so we can track allocation IDs per SP
        for (uint i = 0; i < providerPayloads.length; i++) {
            uint amount = uint256(providerPayloads[i].totalSize) * 10 ** 18;
        DataCapTypes.TransferParams memory params = DataCapTypes
            .TransferParams({
                to: FilAddresses.fromActorID(6),
                amount: BigInts.fromUint256(amount),
                    operator_data: providerPayloads[i].payload
            });
        (
            int256 exit_code,
            DataCapTypes.TransferReturn memory result
        ) = DataCapAPI.transfer(params);

            uint64[] memory allocationIds = result.decodeAllocationResponse();
            package.spAllocationIds[
                providerPayloads[i].provider
            ] = allocationIds;

            allocationResponses[i] = AllocationResponse({
                provider: providerPayloads[i].provider,
                allocationIds: allocationIds
            });

            if (allocationIds.length != providerPayloads[i].count) {
            revert Errors.AllocationFailed();
        }

            emit AllocationCreated(
                msg.sender,
                providerPayloads[i].provider,
                amount,
                allocationIds,
                0
            );

        if (exit_code != 0) {
            revert Errors.DataCapTransferFailed();
        }
        }
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
    // solhint-disable func-name-mixedcase
    function handle_filecoin_method(
        uint64 method,
        uint64 inputCodec,
        bytes calldata params
    ) external view returns (uint32 exitCode, uint64 codec, bytes memory data) {
        if (msg.sender != _DATACAP_ADDRESS)
            revert Errors.InvalidCaller(msg.sender, _DATACAP_ADDRESS);
        CommonTypes.UniversalReceiverParams
            memory receiverParams = UtilsHandlers.handleFilecoinMethod(
                method,
                inputCodec,
                params
            );
        if (receiverParams.type_ != _FRC46_TOKEN_TYPE)
            revert Errors.UnsupportedType();
        (uint256 tokenReceivedLength, uint256 byteIdx) = CBORDecoder
            .readFixedArray(receiverParams.payload, 0);
        if (tokenReceivedLength != 6) revert Errors.InvalidTokenReceived();
        uint64 from;
        (from, byteIdx) = CBORDecoder.readUInt64(
            receiverParams.payload,
            byteIdx
        ); // payload == FRC46TokenReceived
        if (from != CommonTypes.FilActorId.unwrap(DataCapTypes.ActorID))
            revert Errors.UnsupportedToken();
        exitCode = 0;
        codec = 0;
        data = "";
    }
}
