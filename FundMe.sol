// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//1、创建一个收款函数

//2、记录投资人并且查看

//3、在锁定期内，达到目标值，生厂商可以提款

//4、在锁定期内，没有达到目标值，投资人在锁定期以后退款

contract FundMe is ReentrancyGuard, Pausable
{
    mapping(address => uint256) public fundersAmountList;

    uint256 constant MINIMUM_VALUE = 1 * 10 ** 18; //1 USD

    uint256 constant TARGET = 2 * 10 ** 18;

    AggregatorV3Interface internal dataFeed;

    address public owner;

    event Funded(address indexed funder, uint256 amount);

    event FundWithdrawned(address indexed funder, uint256 amount);

    uint256 deploymentTimestamp;

    uint256  LOCK_TIME;

    address HHToken;

    bool public getFundSuccess = false;

    constructor(uint256 _locktime)
    {
        //Sepolia testnet
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        owner = msg.sender;
        deploymentTimestamp = block.timestamp;
        LOCK_TIME = _locktime;
    }
    
    function fund() external payable 
    {
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE,"Send more ETH");
        require(block.timestamp < deploymentTimestamp + LOCK_TIME,"LOCK TIME IS OVER");
        fundersAmountList[msg.sender] += msg.value;

        emit Funded(msg.sender, msg.value);
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function convertEthToUsd(uint256 ethAmount) internal view returns (uint256)
    {
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice / (10 ** 8);
        /*precision is 10**8  x / eth = 10 ** 18 */
    }

    function fundsWithdrawn() external onlyOwner nonReentrant whenNotPaused WindowsClosed
    {
        //Check
        require(convertEthToUsd(address(this).balance) >= TARGET,"TARGET is not reached");
        require(getFundSuccess == false,"Funds have already been withdrawn");

        //Effects
        fundersAmountList[msg.sender] = 0;
        getFundSuccess = true;
        uint256 amount = address(this).balance;

        //Interactions
        bool success;
        (success, ) = payable (msg.sender).call{value: address(this).balance}("");
        require(success,"transfer tx failed");

        emit FundWithdrawned(msg.sender, amount);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function transferOwnership(address newOwner) public onlyOwner
    {
        owner = newOwner;
    }

    function refund() external WindowsClosed nonReentrant
    {
        require(convertEthToUsd(address(this).balance) < TARGET,"TARGET is reached");
        require(fundersAmountList[msg.sender] != 0,"you have not fund");
        bool success;
        (success, ) = payable (msg.sender).call{value: fundersAmountList[msg.sender]}("");
        require(success,"transfer tx failed");
        fundersAmountList[msg.sender] = 0;

    }

    function setHHToken(address _HHToken) public onlyOwner
    {
        HHToken = _HHToken;
    }


    function setFunderAmountAfterMint(address addr, uint256 amout) external
    {
        require(msg.sender == HHToken,"the wrong function caller");
        fundersAmountList[addr] -= amout;
    }

    modifier WindowsClosed()
    {
        require(block.timestamp >= deploymentTimestamp + LOCK_TIME,"LOCK TIME IS NOT OVER");
        _;
    }

    modifier onlyOwner()
    {
        require(owner == msg.sender,"this function can only be called by owner");
        _;
    }


    
}