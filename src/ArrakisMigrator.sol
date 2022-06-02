// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "aloe-blend/interfaces/IAloeBlend.sol";
import "aloe-blend/interfaces/IFactory.sol";

interface IUniswapHelper {
    function TOKEN0() external view returns (IERC20);
    function TOKEN1() external view returns (IERC20);
}

interface IArrakisVaultV1 {
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
    function pool() external view returns (IUniswapV3Pool);
    function burn(uint256 amount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
}

contract ArrakisMigrator {
    using SafeERC20 for IERC20;

    IFactory public immutable blendFactory;

    constructor(IFactory _blendFactory) {
        blendFactory = _blendFactory;
    }

    function migrate(
        IArrakisVaultV1 arrakisVault,
        IAloeBlend blendVault
    ) external returns (uint256, uint256) {
        require(blendFactory.didCreateVault(blendVault), "Fake vault");
        IERC20 token0 = arrakisVault.token0();
        IERC20 token1 = arrakisVault.token1();
        require(
            token0 == IUniswapHelper(address(blendVault)).TOKEN0() &&
            token1 == IUniswapHelper(address(blendVault)).TOKEN1(),
            "Token mismatch"
        );

        // Check caller's Arrakis LP balance
        uint256 balance = IERC20(address(arrakisVault)).balanceOf(msg.sender);
        require(balance != 0, "Migration unnecessary");

        // Pull caller's tokens into this contract, then burn them
        IERC20(address(arrakisVault)).transferFrom(msg.sender, address(this), balance);
        (uint256 amount0Max, uint256 amount1Max, ) = arrakisVault.burn(balance, address(this));

        // Approve Blend to use the tokens which just came in
        _approve(token0, address(blendVault), amount0Max);
        _approve(token1, address(blendVault), amount1Max);

        // Deposit to vault
        (uint256 shares, uint256 amount0, uint256 amount1) = blendVault.deposit(amount0Max, amount1Max, 0, 0);
        amount0 = amount0Max - amount0;
        amount1 = amount1Max - amount1;

        // Send shares and any extra funds back to caller
        IERC20(address(blendVault)).transfer(msg.sender, shares);
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
