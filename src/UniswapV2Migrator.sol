// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";

import "aloe-blend/interfaces/IAloeBlend.sol";
import "aloe-blend/interfaces/IFactory.sol";

interface IUniswapHelper {
    function TOKEN0() external view returns (IERC20);

    function TOKEN1() external view returns (IERC20);
}

contract UniswapV2Migrator {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable uniswapFactory;
    IFactory public immutable blendFactory;

    constructor(IUniswapV2Factory _uniswapFactory, IFactory _blendFactory) {
        uniswapFactory = _uniswapFactory;
        blendFactory = _blendFactory;
    }

    function migrate(
        IAloeBlend vault,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256, uint256) {
        require(blendFactory.didCreateVault(vault), "Fake vault");

        // Derive Uniswap V2 pair address
        IERC20 token0 = IUniswapHelper(address(vault)).TOKEN0();
        IERC20 token1 = IUniswapHelper(address(vault)).TOKEN1();
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapFactory.getPair(address(token0), address(token1)));

        // Check caller's Uniswap V2 LP balance
        uint256 balance = pair.balanceOf(msg.sender);
        require(balance != 0, "Migration unnecessary");

        // If caller passes signatures, use them to permit token transfer
        if (r != 0) {
            pair.permit(msg.sender, address(this), balance, deadline, v, r, s);
        }

        // Send caller's Uniswap V2 LP tokens to the pair itself, then burn them
        pair.transferFrom(msg.sender, address(pair), balance);
        (uint256 amount0Max, uint256 amount1Max) = pair.burn(address(this));

        // Approve Blend to use the tokens which just came in
        _approve(token0, address(vault), amount0Max);
        _approve(token1, address(vault), amount1Max);

        // Deposit to vault
        (uint256 shares, uint256 amount0, uint256 amount1) = vault.deposit(amount0Max, amount1Max, 0, 0);
        amount0 = amount0Max - amount0;
        amount1 = amount1Max - amount1;

        // Send shares and any extra funds back to caller
        IERC20(address(vault)).transfer(msg.sender, shares);
        if (amount0 != 0) token0.safeTransfer(msg.sender, amount0);
        if (amount1 != 0) token1.safeTransfer(msg.sender, amount1);

        return (amount0Max, amount1Max);
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
