// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/UniswapV2Migrator.sol";

contract UniswapV2MigratorTest is Test {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    IUniswapV2Pair constant pair = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    IAloeBlend constant vault = IAloeBlend(0x33cB657E7fd57F1f2d5f392FB78D5FA80806d1B4);
    address constant whale = 0x06981EfbE070996654482F4F20786e0CEf0f8740;

    UniswapV2Migrator migrator;

    function setUp() public {
        migrator = new UniswapV2Migrator(
            IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f),
            IFactory(0x000000000008b34b9C428ddC00f54d49105dA313)
        );
    }

    function testMigrateUsingApprove() public {
        vm.startPrank(whale);

        pair.approve(address(migrator), pair.balanceOf(whale));
        (uint256 amount0, uint256 amount1) = migrator.migrate(vault, 0, 0, 0, 0);

        assertEq(amount0, 299999999999);
        assertEq(amount1, 156761448537020693329);
        assertEq(IERC20(address(vault)).balanceOf(whale), 369311498940);
    }

    function testMigrateUsingPermit() public {
        uint256 privateKey = 0xBEEF;
        address testAccount = vm.addr(privateKey);

        uint256 balance = pair.balanceOf(whale);
        vm.prank(whale);
        pair.transfer(testAccount, balance);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    pair.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, testAccount, address(migrator), balance, 0, block.timestamp))
                )
            )
        );

        vm.prank(testAccount);
        (uint256 amount0, uint256 amount1) = migrator.migrate(vault, block.timestamp, v, r, s);

        assertEq(amount0, 299999999999);
        assertEq(amount1, 156761448537020693329);
        assertEq(IERC20(address(vault)).balanceOf(testAccount), 369311498940);
    }
}
