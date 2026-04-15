// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Deleverager, WETH, WSTETH, STETH} from "../src/Deleverager.sol";
import {ILTV} from "../src/interfaces/ILTV.sol";

address constant LTV_VAULT = 0xa260b049ddD6567E739139404C7554435c456d9E;
address constant AWSTETH_ADDR = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
address constant VAR_DEBT_WETH = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE;

interface ILTVTest is ILTV {
    function owner() external view returns (address);
    function governor() external view returns (address);
    function updateEmergencyDeleverager(address newEmergencyDeleverager) external;
    function setSoftLiquidationLtv(uint16 dividend, uint16 divider) external;
    function isVaultDeleveraged() external view returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function maxRedeemCollateral(address owner) external view returns (uint256);
    function redeemCollateral(uint256 shares, address receiver, address owner) external returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract DeleveragerTest is Test {
    ILTVTest internal ltv;
    Deleverager internal deleverager;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        ltv = ILTVTest(LTV_VAULT);
        deleverager = new Deleverager(address(ltv));

        vm.prank(ltv.governor());
        ltv.setSoftLiquidationLtv(1, 1);

        vm.prank(ltv.owner());
        ltv.updateEmergencyDeleverager(address(deleverager));
    }

    function test_execute_onlyOwner() public {
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.expectRevert();
        deleverager.execute(address(WETH), "");
    }

    function test_execute_transferWETH() public {
        address recipient = makeAddr("recipient");
        deal(address(WETH), address(deleverager), 1 ether);

        deleverager.execute(address(WETH), abi.encodeCall(IERC20.transfer, (recipient, 1 ether)));

        assertEq(WETH.balanceOf(recipient), 1 ether);
        assertEq(WETH.balanceOf(address(deleverager)), 0);
    }

    function test_deleverageAndWithdraw() public {
        assertGt(IERC20(AWSTETH_ADDR).balanceOf(LTV_VAULT), 0, "pre: vault should have aWSTETH (supplied collateral)");
        assertGt(
            IERC20(VAR_DEBT_WETH).balanceOf(LTV_VAULT),
            0,
            "pre: vault should have variable-debt WETH (outstanding borrow)"
        );
        assertFalse(ltv.isVaultDeleveraged(), "pre: vault should not be deleveraged yet");

        deleverager.execute();

        assertEq(IERC20(AWSTETH_ADDR).balanceOf(LTV_VAULT), 0, "post: aWSTETH balance must be zero");
        assertEq(IERC20(VAR_DEBT_WETH).balanceOf(LTV_VAULT), 0, "post: variable-debt WETH must be zero");
        assertGt(WSTETH.balanceOf(LTV_VAULT), 0, "post: vault must hold WSTETH directly");
        assertTrue(ltv.isVaultDeleveraged(), "post: vault must be deleveraged");

        assertEq(WETH.balanceOf(address(deleverager)), 0, "deleverager: no WETH");
        assertEq(WSTETH.balanceOf(address(deleverager)), 0, "deleverager: no WSTETH");
        assertEq(STETH.balanceOf(address(deleverager)), 0, "deleverager: no stETH");
        assertEq(address(deleverager).balance, 0, "deleverager: no ETH");

        assertEq(WETH.balanceOf(address(ltv)), 0, "ltv: no WETH");
        assertEq(STETH.balanceOf(address(ltv)), 0, "ltv: no stETH");
        assertEq(address(ltv).balance, 0, "ltv: no ETH");

        address user = makeAddr("randomUser");
        uint256 userShares = 1 ether;
        deal(address(ltv), user, userShares, false);

        uint256 redeemable = ltv.maxRedeemCollateral(user);
        assertGt(redeemable, 0, "user: should have redeemable collateral shares");

        uint256 wstEthBefore = WSTETH.balanceOf(user);
        uint256 vaultWstEthBefore = WSTETH.balanceOf(address(ltv));

        vm.prank(user);
        uint256 collateralReceived = ltv.redeemCollateral(redeemable, user, user);

        assertEq(WSTETH.balanceOf(address(ltv)), vaultWstEthBefore - collateralReceived);
        assertGt(collateralReceived, 0, "user: redeemCollateral must return > 0 WSTETH");
        assertEq(
            WSTETH.balanceOf(user),
            wstEthBefore + collateralReceived,
            "user: WSTETH balance must increase after withdrawal"
        );
        assertGt(ltv.convertToAssets(10 ** 18), 10 ** 18);
    }
}
