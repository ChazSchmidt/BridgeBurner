pragma solidity ^0.4.25;
import "./Streams.sol";

contract DateMaker is Streams {  // creates Dates (shared streams) and corresponds them to the streams[]
    uint256 dateNonce;  // used for dateID and corresponding streamID/might be replaced by streamNonce
    address burnAddress = 0xbad0000000000000000000000000000000000000;
    Date[] datebook;
  
    function createDate(
        address _invited, 
        address _tokenAddress,
        uint256 _startBlock,
        uint256 _stopBlock,
        uint256 _payment
    ) 
      public {
          
          uint256 deposit = _stopBlock.sub(_startBlock).mul(_payment); // TODO: change start and stop times to match 'desired meeting time'
          IERC20 tokenContract = IERC20(_tokenAddress);
          uint256 allowance = tokenContract.allowance(_sender, address(this));
          require(
              allowance >= deposit,
              "contract not allowed to transfer enough tokens"
              );
          
          
          
          datebook[dateNonce]=Date(msg.sender, _invited, _tokenAddress, _startBlock, _stopBlock, _payment);
          emit LogCreateInvite(dateNonce, _invited, _tokenAddress, _startBlock, _stopBlock, _payment);
          dateNonce = dateNonce.add(1);
          tokenContract.transferFrom(_sender, address(this), deposit);
          datebook[dateNonce].setShareofBalance(msg.sender,deposit);
      }
      
    function acceptInvite(uint256 _dateID) public {
        datebook[_dateID].getStreamTerms();  // get stream terms and create stream
    }
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
      uint256 _payment) { // passes all terms to later create stream
      
      host = _sender;
      invited = _invited;
      tokenAddress = _tokenAddress;
      startBlock = _startBlock;
      stopBlock = _stopBlock;
      payment = _payment;
      interval = 1;
    }
    
    function getStreamTerms() returns  
        address _tokenAddress,
        uint256 _startBlock,
        uint256 _stopBlock,
        uint256 _payment,
        uint256 _interval // should pass all terms to later create stream
    {
        return 
    }
    
    function getInvited() public returns (address _invited) {
        return invited;
    }
    
    function getShareofBalance(address _address) public returns (uint256 _share){
        return depositedShare[_address];
    }
    
    function setShareofBalance(address _address, uint256 _share) {
        depositedShare[_address]=_share;
    }
}
