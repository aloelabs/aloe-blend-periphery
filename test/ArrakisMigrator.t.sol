// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/ArrakisMigrator.sol";

contract ArrakisMigratorTest is Test {
    IArrakisVaultV1 constant arrakisVault = IArrakisVaultV1(0xa6c49FD13E50a30C65E6C8480aADA132011D0613);
    IAloeBlend constant blendVault = IAloeBlend(0x33cB657E7fd57F1f2d5f392FB78D5FA80806d1B4);
    address constant whale = 0x07499c08287A6cD6514cace69100916C67631dC7;

    ArrakisMigrator migrator;

    function setUp() public {
        migrator = new ArrakisMigrator(IFactory(0x000000000008b34b9C428ddC00f54d49105dA313));
    }

    function testMigrate() public {
        vm.startPrank(whale);

        IERC20(address(arrakisVault)).approve(address(migrator), IERC20(address(arrakisVault)).balanceOf(whale));
        (uint256 amount0, uint256 amount1) = migrator.migrate(arrakisVault, blendVault);

        assertEq(amount0, 576775357);
        assertEq(amount1, 226524086998152847616);
        assertEq(IERC20(address(blendVault)).balanceOf(whale), 710032572);
    }
}
