// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CollateralizedLoan is ReentrancyGuard {
    // State variables
    struct Loan {
        address payable borrower;
        address payable lender;
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 dueDate;
        bool funded;
        bool repaid;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;

    // Events
    event LoanRequested(uint256 loanId, address indexed borrower, uint256 collateralAmount, uint256 loanAmount, uint256 interestRate, uint256 duration);
    event LoanFunded(uint256 loanId, address indexed lender);
    event LoanRepaid(uint256 loanId, address indexed borrower, uint256 amountRepaid);
    event CollateralClaimed(uint256 loanId, address indexed lender, address indexed borrower, uint256 collateralAmount);

    // Modifiers
    modifier loanExists(uint256 loanId) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");
        _;
    }

    modifier notFunded(uint256 loanId) {
        require(!loans[loanId].funded, "Loan already funded");
        _;
    }

    // Functions

    // Borrower deposits collateral and requests a loan
    function depositCollateralAndRequestLoan(uint256 loanAmount, uint256 interestRate, uint256 duration) external payable nonReentrant {
        require(msg.value > 0, "Collateral amount must be greater than 0");
        require(loanAmount > 0, "Loan amount must be greater than 0");

        loanCounter++;
        loans[loanCounter] = Loan({
            borrower: payable(msg.sender),
            lender: payable(address(0)),
            collateralAmount: msg.value,
            loanAmount: loanAmount,
            interestRate: interestRate,
            duration: duration,
            dueDate: 0,
            funded: false,
            repaid: false
        });

        emit LoanRequested(loanCounter, msg.sender, msg.value, loanAmount, interestRate, duration);
    }

    // Lender funds the loan
    function fundLoan(uint256 loanId) external payable nonReentrant loanExists(loanId) notFunded(loanId) {
        Loan storage loan = loans[loanId];
        require(msg.value == loan.loanAmount, "Incorrect loan amount");

        loan.lender = payable(msg.sender);
        loan.dueDate = block.timestamp + loan.duration;
        loan.funded = true;

        loan.borrower.transfer(loan.loanAmount);

        emit LoanFunded(loanId, msg.sender);
    }

    // Borrower repays the loan
    function repayLoan(uint256 loanId) external payable nonReentrant loanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Only the borrower can repay the loan");
        require(loan.funded, "Loan is not funded");
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp <= loan.dueDate, "Loan is overdue");

        uint256 repaymentAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate / 100);
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        loan.lender.transfer(repaymentAmount);
        loan.repaid = true;

        loan.borrower.transfer(loan.collateralAmount);

        emit LoanRepaid(loanId, msg.sender, msg.value);
    }

    // Lender claims the collateral on default
    function claimCollateral(uint256 loanId) external nonReentrant loanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(loan.lender == msg.sender, "Only the lender can claim the collateral");
        require(loan.funded, "Loan is not funded");
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp > loan.dueDate, "Loan is not overdue yet");

        loan.lender.transfer(loan.collateralAmount);

        emit CollateralClaimed(loanId, loan.lender, loan.borrower, loan.collateralAmount);
    }
}
