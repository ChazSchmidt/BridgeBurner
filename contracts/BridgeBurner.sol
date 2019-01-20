pragma solidity ^0.4.25;
import "./Streams.sol";

contract DateMaker is Streams {  // creates Dates (shared streams) and corresponds them to the streams[]
    uint256 IDcounter;  // used for dateID and corresponding streamID/might be replaced by streamNonce
    address burnAddress = 0x0000000000000000000000000000000000000000;
    Date[] datebook;
    
    
  
    function createDate(
        address _invited, 
        address _tokenAddress,
        uint256 _startBlock,
        uint256 _stopBlock,
        uint256 _payment,
        uint256 _interval
    ) 
      payable 
      public {}
}

contract Date {
    address host;
    address invited;
    mapping(address => uint256) depositedShare;
    
    //create function parameters
//    address _sender,
//    address _recipient,
    address tokenAddress;
    uint256 startBlock;
    uint256 stopBlock;
    uint256 payment;
    uint256 interval;
    
    
    constructor(
      address _sender,
      address _invited, 
      address _tokenAddress,
      uint256 _startBlock,
      uint256 _stopBlock,
      uint256 _payment,
      uint256 _interval) { // passes all terms to later create stream
      
      host = _sender;
      invited = _invited;
      tokenAddress = _tokenAddress;
      startBlock = _startBlock;
      stopBlock = _stopBlock;
      payment = _payment;
      interval = _interval;
    }
    
    function getStreamTerms( 
        address _tokenAddress,
        uint256 _startBlock,
        uint256 _stopBlock,
        uint256 _payment,
        uint256 _interval
      ) public// should pass all terms to later create stream
    {}
    
    function getInvited() public returns (address _invited) {
        return invited;
    }
    
    function getShareofBalance(address _address) public {
        return depositedShare[_address];
    } 
}