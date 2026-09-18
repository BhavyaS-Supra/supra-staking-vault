// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Mintable test ERC-20 used as the asset staked into StakingVault. Not part of the
/// vault protocol itself - a convenience token for devnets/testnets where no "real" asset exists.
contract StakeToken is ERC20, Ownable {
    constructor(address initialOwner, uint256 initialSupply)
        ERC20("Supra Stake Token", "sSTK")
        Ownable(initialOwner)
    {
        _mint(initialOwner, initialSupply);
    }

    /// @notice Mints additional test tokens. Owner-only so devnet faucets can be gated.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
