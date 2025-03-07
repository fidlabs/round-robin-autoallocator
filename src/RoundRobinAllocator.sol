// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RoundRobinAllocator is
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable
{
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function initialize(address initialOwner) public initializer {
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __Pausable_init();
    }
}
