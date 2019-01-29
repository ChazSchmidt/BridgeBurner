pragma solidity ^0.4.25;
import "./Streams.sol";

contract DateMaker is Streams {  // creates Dates (shared streams) and corresponds them to the streams[]
    uint256 dateNonce;  // used for dateId and corresponding streamID/might be replaced by streamNonce
    address burnAddress = 0xbAd0000000000000000000000000000000000000;
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
          
          
          
          datebook[dateNonce]=Date({
		host : msg.sender, 
		invited : _invited, 
		tokenAddress : _tokenAddress, 
		startBlock :_startBlock, 
		stopBlock : _stopBlock, 
		payment : _payment});
          emit LogCreateInvite(dateNonce, msg.sender, _invited, _tokenAddress, _startBlock, _stopBlock, _payment, 1);
          
          tokenContract.transferFrom(msg.sender, address(this), deposit);
          datebook[dateNonce].setShareofBalance(msg.sender,deposit);
          dateNonce = dateNonce.add(1);
          
      }
      
    function getCurrentStreamNonce() returns (uint256) {
        return streamNonce;
    }

    function acceptInvite(uint256 _dateId, uint256 _deposit) public {
        address host = datebook[_dateId].getHost();
        require(datebook[_dateId].getInvited() == msg.sender && _deposit >= datebook[_dateId].getDepositedShare(host));
        IERC20 tokenContract = IERC20(datebook[_dateId].getTokenAddress());
        uint256 allowance = tokenContract.allowance(msg.sender, address(this));
        require(
              allowance >= _deposit,
              "contract not allowed to transfer enough tokens"
              );
        // apply Checks-Effects-Interactions
        tokenContract.transferFrom(msg.sender, address(this), _deposit);

        datebook[_dateId].setPayment(datebook[_dateId].getPayment().add(_deposit));
        datebook[_dateId].adjustRedeemableValue(datebook[_dateId].getRedeemableValue().add(_deposit));
        datebook[_dateId].setShareofBalance(msg.sender, _deposit);
        
        
        dateIdTOstreamId[_dateId] = getCurrentStreamNonce();
        create(address(this), burnAddress, datebook[_dateId].getStreamTerms());  // get stream terms and create stream
    }
    
    function checkIn(uint256 _dateId) public {
        require (msg.sender == datebook[_dateId].getHost() || msg.sender == datebook[_dateId].getInvited());
        datebook[_dateId].setCheckInBool(msg.sender);
        if (datebook[_dateId].getCheckInBool(datebook[_dateId].getHost()) && datebook[_dateId].getCheckInBool(datebook[_dateId].getInvited())) {
            redeem(dateIdTOstreamId[_dateId]); // TODO: find a way to record the value of the remaining(/received) tokens 
        }
    }
    
    function reclaimDeposit(uint256 _dateId) public {
        require (msg.sender == datebook[_dateId].getHost() || msg.sender == datebook[_dateId].getInvited());
        require (datebook[_dateId].getCheckedInBool(datebook[_dateId].getHost()) && datebook[_dateId].CheckedInBool(datebook[_dateId].getInvited()));
        IERC20 tokenContract = IERC20(datebook[_dateId].getTokenAddress());
        address host = datebook[_dateId].getHost();
        address invited = datebook[_dateId].getInvited();
        uint256 hostShareRatio = datebook[_dateId].getDepositedShare(host).div(datebook[_dateId].getPayment());
        uint256 hostShare = datebook[_dateId].getRedeemableValue().mul(hostShareRatio);
        uint256 invitedShare = datebook[_dateId].getRedeemableValue().sub(hostShare);
        tokenContract.transferFrom(address(this), host, hostShare);
        tokenContract.transferFrom(address(this), invited, invitedShare);
    }
    
    function checkDateOwner(uint256 _dateId) public returns (address) {
        return datebook[_dateId].host;
    }
    
    function checkRequiredDeposit(uint256 _dateId) public returns (uint256) {
        return datebook[_dateId].getDepositedShare(datebook[_dateId].getHost());
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

    function getCheckInBool(address _address) returns (bool) {
        if (_address == host) {
            return hostCheckedIn;
        } else if (_address == invited) {
            return invitedCheckedIn;
        }
    }
    
    function adjustRedeemableValue(uint256 _newValue) {
        redeemableValue = _newValue;
    } 
    
    function getHost() returns (address) {
        return host;
    } 

    function getInvited() returns (address) {
        return invited;
    }
	
    function getDepositedShare(address _share) returns (uint256) {
        return depositedShare[_share];
    } 
    function getTokenAddress() returns (address) {
        return tokenAddress;
    }
    function getPayment() returns (uint256) {
        return payment;
    }
    function getRedeemableValue() returns (uint256) {
        return redeemableValue;
    }
}
