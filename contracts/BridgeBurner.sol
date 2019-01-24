pragma solidity ^0.4.25;
import "./Streams.sol";

contract DateMaker is Streams {  // creates Dates (shared streams) and corresponds them to the streams[]
    uint256 dateNonce;  // used for dateId and corresponding streamID/might be replaced by streamNonce
    address burnAddress = 0xbad0000000000000000000000000000000000000;
    Date[] datebook;
    mapping (uint256=>uint256) dateIdTOstreamId;
    
    /*
   * Events
   */
  event LogCreateInvite(
    uint256 indexed _dateId,
    address indexed _host,
    address indexed _invited,
    address _tokenAddress,
    uint256 _startBlock,
    uint256 _stopBlock,
    uint256 _payment,
    uint256 _interval
  );
  
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
          uint256 allowance = tokenContract.allowance(msg.sender, address(this));
          require(
              allowance >= deposit,
              "contract not allowed to transfer enough tokens"
              );
          
          
          
          datebook[dateNonce]=Date(msg.sender, _invited, _tokenAddress, _startBlock, _stopBlock, _payment);
          emit LogCreateInvite(dateNonce, msg.sender, _invited, _tokenAddress, _startBlock, _stopBlock, _payment, datebook[dateNonce].interval);
          
          tokenContract.transferFrom(_sender, address(this), deposit);
          datebook[dateNonce].setShareofBalance(msg.sender,deposit);
          dateNonce = dateNonce.add(1);
          
      }
      
    function acceptInvite(uint256 _dateId, uint256 _deposit) public {
        require(datebook[_dateId].invited == msg.sender && _deposit >= datebook[_dateId].depositedShare[[datebook[_dateId].host]]);
        IERC20 tokenContract = IERC20(_tokenAddress);
        uint256 allowance = tokenContract.allowance(msg.sender, address(this));
        require(
              allowance >= deposit,
              "contract not allowed to transfer enough tokens"
              );
        // apply Checks-Effects-Interactions
        tokenContract.transferFrom(msg.sender, address(this), _deposit);

        datebook[_dateId].setPayment(datebook[_dateId].payment.add(_deposit));
        datebook[_dateId].adjustRedeemableValue(datebook[_dateId].redeemableValue.add(_deposit));
        datebook[_dateId].setShareofBalance(msg.sender, _deposit);
        
        
        dateIdTOstreamId[_dateId] = streamNonce;
        create(address(this), burnAddress, datebook[_dateId].getStreamTerms());  // get stream terms and create stream
    }
    
    function checkIn(_dateId) public {
        require (msg.sender == datebook[_dateId].host || msg.sender == datebook[_dateId].invited);
        datebook[_dateId].setCheckInBool(msg.sender);
        if (datebook[_dateId].hostCheckedIn && datebook[_dateId].invitedCheckedIn) {
            redeem(dateIdTOstreamId[_dateId]); // TODO: find a way to record the value of the remaining(/received) tokens 
        }
    }
    
    function reclaimDeposit(_dateId) public {
        require (msg.sender == datebook[_dateId].host || msg.sender == datebook[_dateId].invited);
        require (datebook[_dateId].hostCheckedIn && datebook[_dateId].invitedCheckedIn);
        IERC20 tokenContract = IERC20(datebook[_dateId].tokenAddress);
        uint256 hostShareRatio = datebook[_dateId].depositedShare[datebook[_dateId].host].div(datebook[_dateId].payment);
        uint256 hostShare = datebook[_dateId].redeemableValue.mul(hostShareRatio);
        uint256 invitedShare = datebook[_dateId].redeemableValue.sub(hostShare);
        tokenContract.transferFrom(address(this), datebook[_dateId].host, hostShare);
        tokenContract.transferFrom(address(this), datebook[_dateId].invited, invitedShare);
    }
    
    function checkDateOwner(_dateId) public returns (address) {
        return datebook[_dateId].host;
    }
    
    function checkRequiredDeposit(_dateId) public returns (uint256) {
        return datebook[_dateId].depositedShare[datebook[_dateId].host];
    }
}

contract Date {
    address host;
    address invited;
    mapping(address => uint256) depositedShare;
    
    // check in variables
    bool hostCheckedIn;
    bool invitedCheckedIn;
    uint256 redeemableValue;
    
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
      hostCheckedIn = false;
      invitedCheckedIn = false;
      redeemableValue = _payment;
    }
    
    function getStreamTerms() returns  
        (address _tokenAddress,
        uint256 _startBlock,
        uint256 _stopBlock,
        uint256 _payment,
        uint256 _interval) // should pass all terms to later create stream
    {
        return (tokenAddress, startBlock, stopBlock, payment, interval); 
    }
    
    function setShareofBalance(address _address, uint256 _share) {
        depositedShare[_address]=_share;
    }
    
    function setPayment(uint256 _newPayment) {
        payment = _newPayment;
    }
    
    function setCheckInBool(address _address) {
        if (_address == host) {
            hostCheckedIn = true;
        } else if (_address == invited) {
            invitedCheckedIn = true;
        }
    }
    
    function adjustRedeemableValue(uint256 _newValue) {
        redeemableValue = _newValue;
    } 
}
