// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILTV} from "./interfaces/ILTV.sol";
import {IMorpho, IMorphoFlashLoanCallback} from "./interfaces/IMorpho.sol";
import {IWstEth} from "./interfaces/IWstEth.sol";
import {IWeth} from "./interfaces/IWeth.sol";
import {ICurvePool} from "./interfaces/ICurvePool.sol";

IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
IERC20 constant STETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
IERC20 constant WSTETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
ICurvePool constant CURVE_POOL = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);

contract Deleverager is Ownable, IMorphoFlashLoanCallback {
    using SafeERC20 for IERC20;

    ILTV public immutable ltv;

    constructor(address _ltv, address initialOwner) Ownable(initialOwner) {
        ltv = ILTV(_ltv);
    }

    function execute() external onlyOwner {
        bytes memory getterData = ltv.lendingConnectorGetterData();
        (, address debtToken) = abi.decode(getterData, (address, address));
        uint256 grossBorrow = IERC20(debtToken).balanceOf(address(ltv));
        MORPHO.flashLoan(address(WETH), grossBorrow, abi.encode(grossBorrow));
    }

    function onMorphoFlashLoan(uint256 flashLoanAmount, bytes calldata data) external override {
        require(msg.sender == address(MORPHO), "Deleverager: unauthorized callback");

        uint256 borrowAmount = abi.decode(data, (uint256));

        uint16 feeDividend = ltv.maxDeleverageFeeDividend();
        uint16 feeDivider = ltv.maxDeleverageFeeDivider();

        WETH.forceApprove(address(ltv), borrowAmount);
        ltv.deleverageAndWithdraw(borrowAmount, feeDividend, feeDivider);

        _exchangeWstEthToWeth(WSTETH.balanceOf(address(this)));

        WETH.forceApprove(address(MORPHO), flashLoanAmount);

        uint256 wethBalance = WETH.balanceOf(address(this));
        if (wethBalance > flashLoanAmount) {
            _exchangeWethToWstEth(wethBalance - flashLoanAmount);
            WSTETH.safeTransfer(address(ltv), WSTETH.balanceOf(address(this)));
        }
    }

    function _exchangeWstEthToWeth(uint256 wstEthAmount) internal {
        if (wstEthAmount == 0) return;
        uint256 stEthAmount = IWstEth(address(WSTETH)).unwrap(wstEthAmount);
        STETH.forceApprove(address(CURVE_POOL), stEthAmount);
        CURVE_POOL.exchange(1, 0, stEthAmount, 0);
        IWeth(address(WETH)).deposit{value: address(this).balance}();
    }

    function _exchangeWethToWstEth(uint256 wethAmount) internal {
        if (wethAmount == 0) return;
        IWeth(address(WETH)).withdraw(wethAmount);
        uint256 stEthReceived = CURVE_POOL.exchange{value: wethAmount}(0, 1, wethAmount, 0);
        STETH.forceApprove(address(WSTETH), stEthReceived);
        IWstEth(address(WSTETH)).wrap(stEthReceived);
    }

    function execute(address target, bytes calldata data) external onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Deleverager: call failed");
        return result;
    }

    receive() external payable {}
}
