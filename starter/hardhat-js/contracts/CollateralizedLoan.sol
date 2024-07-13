// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Collateralized Loan Contract
contract CollateralizedLoan {
    // Define the structure of a loan
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

    // Create a mapping to manage the loans
    mapping(uint => Loan) public loans;
    uint public nextLoanId;
    uint public loanCounter;

    // Hint: Define events for loan requested, funded, repaid, and collateral claimed
    // event for load requested
    event LoanRequested(uint256 loadId, address indexed borrower, uint256 collateralAmount, uint256 loanAmount, uint256 interestRate, uint256 duration);
    // event for funded
    event LoanFunded(uint loanId, address indexed lender, address indexed borrower, uint256 amountFunded);
    // event for repaid
    event LoanRepaid(uint loanId, address indexed borrower, address indexed lender,uint256 amountRepaid);
    // event for collateral claimed
    event CollateralClaimed(uint256 loanId, address indexed lender, address indexed borrower, uint256 amountCollateralClaimed);

    // Custom Modifiers
    modifier loanExists(uint256 loanId) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");
    }
    modifier notFunded(uint256 loandId) {
        require(!loans[loandId].funded, "Loan not funded");
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(uint256 _interestRate, uint256 _duration) external payable {
        // Hint: Check if the collateral is more than 0
        require(msg.value > 0, "Collateral amount must be greater than 0");
        // Hint: Calculate the loan amount based on the collateralized amount
        uint256 eligibleLoanAmount = msg.value * 10;

        // Hint: Increment nextLoanId and create a new loan in the loans mapping
        loanCounter++;
        loans[loanCounter] = Loan({
            borrower: payable(msg.sender),
            lender: payable(address(0)),
            collateralAmount: msg.value,
            loanAmount: eligibleLoanAmount,
            interestRate: _interestRate,
            duration: _duration,
            dueDate: 0,
            funded: false,
            repaid: false
        });
        // Hint: Emit an event for loan request
        emit LoanRequested(loanCounter, msg.sender, msg.value, eligibleLoanAmount, _interestRate, _duration);
    }

    // Function to fund a loan
    function fundLoan(uint _loanId) external payable loanExists(_loanId) notFunded(_loanId) {
        Loan storage loan = loans[_loanId];
        require(!loan.funded, "Loan already funded");
        require(msg.value == loan.loanAmount, "Incorrect loanAmount");

        loan.lender = payable(msg.sender);
        loan.dueDate = block.timestamp + loan.duration;
        loan.funded = true;

        loan.borrower.transfer(loan.loanAmount);

        emit LoanFunded(_loanId, loan.lender, loan.borrower, loan.loanAmount);
    }

    // Function to repay a loan
    function repayLoan(uint _loanId) external payable loanExists(_loanId) {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender,"Only borrower can repay");
        require(loan.funded, "Only repay if loan is funded");
        require(!loan.repaid, "Only repay if loand is not repaid");
        require(block.timestamp <= loan.dueDate, "Loan is overdue");

        uint256 repaymentAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate / 100);
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        loan.lender.transfer(repaymentAmount);
        loan.repaid = true;
        loan.borrower.transfer(loan.collateralAmount);

        emit LoanRepaid(_loanId, loan.borrower, loan.lender, repaymentAmount);

    }

    // Function to claim collateral on default
    function claimCollateral(uint256 loanId) external loanExists(_loanId) {
        Loan storage loan = loans[loanId];
        require(loan.lender == msg.sender, "Only the lender can claim the collateral");
        require(loan.funded, "Loan is not funded");
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp > loan.dueDate, "Loan is not overdue yet");
        
        loan.lender.transfer(loan.collateralAmount);
        
        emit CollateralClaimed(loanId, loan.lender, loan.borrower, loan.collateralAmount);
    }
}