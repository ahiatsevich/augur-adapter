pragma solidity 0.4.24;

pragma experimental ABIEncoderV2;

import "./bzx/OracleInterface.sol";
import "./AugurAdapter.sol";

contract AugurOracle is OracleInterface, AugurAdapter {   

    function didTakeOrder(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanOrderAux memory loanOrderAux,
        BZxObjects.LoanPosition memory loanPosition,
        address taker,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didTradePosition(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didPayInterest(
        BZxObjects.LoanOrder memory loanOrder,
        address lender,
        uint amountOwed,
        bool convert,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didDepositCollateral(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didWithdrawCollateral(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didChangeCollateral(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didWithdrawProfit(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint profitAmount,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didCloseLoan(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        address loanCloser,
        bool isLiquidation,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didChangeTraderOwnership(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        address oldTrader,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didChangeLenderOwnership(
        BZxObjects.LoanOrder memory loanOrder,
        address oldLender,
        address newLender,
        uint gasUsed)
        public
        returns (bool) {

    }

    function didIncreaseLoanableAmount(
        BZxObjects.LoanOrder memory loanOrder,
        address lender,
        uint loanTokenAmountAdded,
        uint totalNewFillableAmount,
        uint gasUsed)
        public
        returns (bool) {

    }

    function doManualTrade(
        address sourceTokenAddress,
        address destTokenAddress,
        uint sourceTokenAmount)
        public
        returns (uint) {

    }

    function doTrade(
        address sourceTokenAddress,
        address destTokenAddress,
        uint sourceTokenAmount)
        public
        returns (uint) {

    }

    function verifyAndLiquidate(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition)
        public
        returns (uint) {

    }

    function processCollateral(
        BZxObjects.LoanOrder memory loanOrder,
        BZxObjects.LoanPosition memory loanPosition,
        uint loanTokenAmountNeeded,
        bool isLiquidation)
        public
        returns (uint loanTokenAmountCovered, uint collateralTokenAmountUsed) {

    }

    function shouldLiquidate(
        bytes32 loanOrderHash,
        address trader,
        address loanTokenAddress,
        address positionTokenAddress,
        address collateralTokenAddress,
        uint loanTokenAmount,
        uint positionTokenAmount,
        uint collateralTokenAmount,
        uint maintenanceMarginAmount)
        public
        view
        returns (bool) {

    }

    function getTradeData(
        address sourceTokenAddress,
        address destTokenAddress,
        uint sourceTokenAmount)
        public
        view
        returns (uint sourceToDestRate, uint destTokenAmount) {

    }

    function getProfitOrLoss(
        address positionTokenAddress,
        address loanTokenAddress,
        uint positionTokenAmount,
        uint loanTokenAmount)
        public
        view
        returns (bool isProfit, uint profitOrLoss) {

    }

    function getCurrentMarginAmount(
        address loanTokenAddress,
        address positionTokenAddress,
        address collateralTokenAddress,
        uint loanTokenAmount,
        uint positionTokenAmount,
        uint collateralTokenAmount)
        public
        view
        returns (uint) {

    }

    function isTradeSupported(
        address sourceTokenAddress,
        address destTokenAddress,
        uint sourceTokenAmount)
        public
        view
        returns (bool) {

    }
}