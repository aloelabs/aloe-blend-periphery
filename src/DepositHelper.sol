// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "solmate/tokens/ERC20.sol";

import "aloe-blend/interfaces/IAloeBlend.sol";
import "aloe-blend/interfaces/IFactory.sol";

interface IUniswapHelper {
    function TOKEN0() external view returns (IERC20);

    function TOKEN1() external view returns (IERC20);
}

contract DepositHelper {
    using SafeERC20 for IERC20;

    IFactory public immutable factory;

    constructor(IFactory _factory) {
        factory = _factory;
    }

    function deposit(
        IAloeBlend vault,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256[2] calldata deadlines,
        uint8[2] calldata v,
        bytes32[2] calldata r,
        bytes32[2] calldata s
    ) external {
        require(factory.didCreateVault(vault), "Fake vault");
        IERC20 token0 = IUniswapHelper(address(vault)).TOKEN0();
        IERC20 token1 = IUniswapHelper(address(vault)).TOKEN1();

        // If caller passes signatures, use them to permit token transfer
        if (r[0] != 0) {
            ERC20(address(token0)).permit(msg.sender, address(this), amount0Max, deadlines[0], v[0], r[0], s[0]);
        }
        if (r[1] != 0) {
            ERC20(address(token1)).permit(msg.sender, address(this), amount1Max, deadlines[1], v[1], r[1], s[1]);
        }

        // Pull in tokens from caller
        token0.safeTransferFrom(msg.sender, address(this), amount0Max);
        token1.safeTransferFrom(msg.sender, address(this), amount1Max);

        // Approve vault to use the tokens which were just pulled in
        _approve(token0, address(vault), amount0Max);
        _approve(token1, address(vault), amount1Max);

        // Deposit to vault
        (uint256 shares, uint256 amount0, uint256 amount1) = vault.deposit(
            amount0Max,
            amount1Max,
            amount0Min,
            amount1Min
        );
        amount0 = amount0Max - amount0;
        amount1 = amount1Max - amount1;

        // Send shares and any extra funds back to caller
        IERC20(address(vault)).transfer(msg.sender, shares);
        if (amount0 != 0) token0.safeTransfer(msg.sender, amount0);
        if (amount1 != 0) token1.safeTransfer(msg.sender, amount1);
    }

    function _approve(
        IERC20 token,
        address spender,
        uint256 amount
    ) private {
        // 200 gas to read uint256
        if (token.allowance(address(this), spender) < amount) {
            // 20000 gas to write uint256 if changing from zero to non-zero
            // 5000  gas to write uint256 if changing from non-zero to non-zero
            token.approve(spender, type(uint256).max);
        }
    }
}
