// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC-20 distributed by StakingVault as yield. Supply is minted to the owner, who
/// funds the vault's rewards pool via StakingVault.fundRewards (a pull-based transferFrom),
/// keeping minting and reward accounting fully decoupled.
contract RewardToken is ERC20, Ownable {
    constructor(address initialOwner, uint256 initialSupply)
        ERC20("Supra Reward Token", "sRWD")
        Ownable(initialOwner)
    {
        _mint(initialOwner, initialSupply);
    }

    /// @notice Mints additional reward supply, e.g. to top up the rewards pool later.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
