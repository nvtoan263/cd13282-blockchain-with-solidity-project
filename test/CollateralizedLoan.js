// Importing necessary modules and functions from Hardhat and Chai for testing
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Describing a test suite for the CollateralizedLoan contract
describe("CollateralizedLoan", function () {

  beforeEach(async function() {
    [owner, borrower, lender] = await ethers.getSigners();
    CollateralizedLoan = await ethers.getContractFactory("CollateralizedLoan");
    collateralizedLoan = await CollateralizedLoan.deploy();
    await collateralizedLoan.deployed();
  });

  // Test suite for the loan request functionality
  describe("Loan Request", function () {
    it("should allow a borrower to deposit collateral and request a loan", async function () {
      const collateralAmount = ethers.utils.parseEther("1.0");
      const loanAmount = ethers.utils.parseEther("0.5");
      const interestRate = 10; // 10%
      const duration = 86400; // 1 day
  
      await expect(
        collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, { value: collateralAmount })
      )
      .to.emit(collateralizedLoan, "LoanRequested")
      .withArgs(1, borrower.address, collateralAmount, loanAmount, interestRate, duration);
  
      const loan = await collateralizedLoan.loans(1);
      expect(loan.borrower).to.equal(borrower.address);
      expect(loan.collateralAmount).to.equal(collateralAmount);
      expect(loan.loanAmount).to.equal(loanAmount);
      expect(loan.interestRate).to.equal(interestRate);
      expect(loan.duration).to.equal(duration);
      expect(loan.funded).to.be.false;
      expect(loan.repaid).to.be.false;
    });
  });

  // Test suite for funding a loan
  describe("Funding a Loan", function () {
    it("should allow a lender to fund a loan", async function () {
      const collateralAmount = ethers.utils.parseEther("1.0");
      const loanAmount = ethers.utils.parseEther("0.5");
      const interestRate = 10; // 10%
      const duration = 86400; // 1 day
  
      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, { value: collateralAmount });
  
      await expect(
        collateralizedLoan.connect(lender).fundLoan(1, { value: loanAmount })
      )
      .to.emit(collateralizedLoan, "LoanFunded")
      .withArgs(1, lender.address);
  
      const loan = await collateralizedLoan.loans(1);
      expect(loan.lender).to.equal(lender.address);
      expect(loan.funded).to.be.true;
    });
  });

  // Test suite for repaying a loan
  describe("Repaying a Loan", function () {
    it("should allow a borrower to repay a loan", async function () {
      const collateralAmount = ethers.utils.parseEther("1.0");
      const loanAmount = ethers.utils.parseEther("0.5");
      const interestRate = 10; // 10%
      const duration = 86400; // 1 day
  
      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, { value: collateralAmount });
      await collateralizedLoan.connect(lender).fundLoan(1, { value: loanAmount });
  
      const repaymentAmount = ethers.utils.parseEther("0.55"); // 0.5 + 10% interest
  
      await expect(
        collateralizedLoan.connect(borrower).repayLoan(1, { value: repaymentAmount })
      )
      .to.emit(collateralizedLoan, "LoanRepaid")
      .withArgs(1, borrower.address, repaymentAmount);
  
      const loan = await collateralizedLoan.loans(1);
      expect(loan.repaid).to.be.true;
    });
  });

  // Test suite for claiming collateral
  describe("Claiming Collateral", function () {
    it("should allow a lender to claim collateral if the loan is not repaid on time", async function () {
      const collateralAmount = ethers.utils.parseEther("1.0");
      const loanAmount = ethers.utils.parseEther("0.5");
      const interestRate = 10; // 10%
      const duration = 1; // 1 second for testing
  
      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, { value: collateralAmount });
      await collateralizedLoan.connect(lender).fundLoan(1, { value: loanAmount });
  
      // Increase time to after the loan due date
      await ethers.provider.send("evm_increaseTime", [2]);
      await ethers.provider.send("evm_mine");
  
      await expect(
        collateralizedLoan.connect(lender).claimCollateral(1)
      )
      .to.emit(collateralizedLoan, "CollateralClaimed")
      .withArgs(1, lender.address, borrower.address, collateralAmount);
      const loan = await collateralizedLoan.loans(1);
      expect(loan.repaid).to.be.false;
    });
  });
});
