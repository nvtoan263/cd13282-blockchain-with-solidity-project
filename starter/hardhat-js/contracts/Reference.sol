// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CryptoCollateralizedLoan {

    struct LoanInfo {
        address borrower;
        uint256 borrowedAmount;
        uint256 collateralAmount;
        uint256 requestedAt;
        bool paid;
    }

    ERC20 public collateralToken;
    uint256 public interestRate;
    uint256 public minCollateralizationRatio;

    mapping(address => LoanInfo) public loans;

    event LoanGranted(
        address indexed borrower,
        uint256 borrowedAmount,
        uint256 collateralAmount
    );

    event LoanRepaid(address indexed borrower, uint256 repaidAmount);

    constructor(
        ERC20 _collateralToken,
        uint256 _interestRate,
        uint256 _minCollateralizationRatio
    ) {
        collateralToken = _collateralToken;
        interestRate = _interestRate;
        minCollateralizationRatio = _minCollateralizationRatio;
    }

    function requestLoan(
        uint256 _borrowedAmount,
        uint256 _collateralAmount
    ) public {
        LoanInfo storage initialLoanInfo = loans[msg.sender];
        require(
            initialLoanInfo.collateralAmount == 0 ||
            (initialLoanInfo.collateralAmount > 0 && initialLoanInfo.paid == true),
            "Active loan"
        );

        uint256 extraAmountToLiquidate = (_borrowedAmount * minCollateralizationRatio) / 100;
        require(
            _collateralAmount >= (_borrowedAmount + extraAmountToLiquidate),
            "Insufficient collateral"
        );

        collateralToken.transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );

        LoanInfo memory loanInfo = LoanInfo({
            borrower: msg.sender,
            borrowedAmount: _borrowedAmount,
            collateralAmount: _collateralAmount,
            requestedAt: block.timestamp,
            paid: false
        });

        _sendEthersTo(msg.sender, loanInfo.borrowedAmount);
        loans[msg.sender] = loanInfo;
        emit LoanGranted(msg.sender, _borrowedAmount, _collateralAmount);
    }

    function repayLoan() public payable {
        LoanInfo storage loanInfo = loans[msg.sender];
        require(loanInfo.borrowedAmount > 0, "No active loan");

        uint256 collateralizationRatio = _calculateCollateralizationRatio(loanInfo);
        require(
            collateralizationRatio < minCollateralizationRatio,
            "Collateralization ratio above minimum"
        );

        uint256 outstandingAmount = _calculateOutstandingAmount(loanInfo);
        require(msg.value >= outstandingAmount, "Insufficient funds");

        collateralToken.transfer(msg.sender, loanInfo.collateralAmount);
        loanInfo.paid = true;
        emit LoanRepaid(msg.sender, loanInfo.borrowedAmount);
    }

    function _sendEthersTo(
        address _receiver,
        uint256 _amount
    ) private returns (bool) {
        (bool sent, ) = payable(_receiver).call{value: _amount}("");
        require(sent, "Ether transfer failed");
        return sent;
    }

    function _calculateOutstandingAmount(
        LoanInfo storage loanInfo
    ) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - loanInfo.requestedAt;
        uint256 interestAccrued = (loanInfo.borrowedAmount * interestRate * timeElapsed) / (100 * 365 days);
        return loanInfo.borrowedAmount + interestAccrued;
    }

    function _calculateCollateralizationRatio(
        LoanInfo storage loanInfo
    ) private view returns (uint256) {
        uint256 outstandingAmount = _calculateOutstandingAmount(loanInfo);
        uint256 diff = outstandingAmount - loanInfo.borrowedAmount;
        return (diff * 100) / loanInfo.borrowedAmount;
    }

    receive() external payable {}
}
