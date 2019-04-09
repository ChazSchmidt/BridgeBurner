pragma solidity ^0.4.25;

import "./openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";


/// @title BridgeBurner - A modified version of Paul Berg's ERC Money Streaming Implementation
/// @author Chaz Schmidt <schmidt.864@osu.edu> and Paul Berg - <hello@paulrberg.com>

//TODO check in time period

contract BridgeBurner {
  using SafeMath for uint256;

  /*
   * Types
   */
   // start and stop of burn time
  struct Timeframe {
    uint256 start;
    uint256 stop;
  }
  // burn rate
  struct Rate {
    uint256 payment;  // amount to burn
    uint256 interval; // every x blocks
  }

  struct Date {
    address host; // TODO mapping participants for more than 2 addresses/participants
    address guest;
    address recipient;
    uint256 hostShare;
    uint256 guestShare;
    //mapping(address => uint256) depositedShare;
    //uint256 totalDeposit;
    //mapping(address => bool) checkedIn;
    bool hostCheckedIn;
    bool guestCheckedIn;
    address tokenAddress;
    uint256 balance;
    Timeframe timeframe;
    Rate rate;
  }

  /*
   * Storage
   */
  mapping(uint256 => Date) private dates;
  uint256 private dateNonce;
  address burnAddress = 0xbAd0000000000000000000000000000000000000;

  /*
   * Events
   */
   // TODO not modified yet

  event LogInviteCreate(
    uint256 indexed _dateId,
    address indexed _host,
    address indexed _guest,
    uint256 deposit,
    address _tokenAddress,
    uint256 _startBlock,
    uint256 _stopBlock,
    uint256 _payment,
    uint256 _interval
  );

  event LogInviteAccepted(
    uint256 indexed _dateId,
    address indexed _host,
    address indexed _guest
  );

  event LogInviteCancel(
    uint256 indexed _dateId,
    address indexed _host,
  );

  event LogRedeem(
    uint256 indexed _dateId,
    address indexed _host,
    address indexed _guest,
    uint256 _burnedFunds,
    uint256 _hostShare,
    uint256 _guestShare
  );

  /*
   * Modifiers
   */
   // TODO might not be necessary. could change this for my own purposes
  modifier onlyGuest(uint256 _dateId) {
    require(
      dates[_dateId].guest == msg.sender,
      "only the date recipient is allowed to perform this action"
    );
    _;
  }

  modifier onlyHostOrGuest(uint256 _dateId) {
    require(
      msg.sender == dates[_dateId].host ||
      msg.sender == dates[_dateId].guest,
      "only the sender or the recipient of the date can perform this action"
    );
    _;
  }

  modifier dateExists(uint256 _dateId) {
    require(
      dates[_dateId].host != address(0x0),
      "date doesn't exist"
    );
    _;
  }

  /*
   * Functions
   */
  constructor() public {
    dateNonce = 1;
  }
  // total available balance of existing date
  function balanceOf(uint256 _dateId)
    public
    view
    dateExists(_dateId)
    returns (uint256 balance)
  {
    Date memory date = dates[_dateId];
    uint256 delta = deltaOf(_dateId);
    uint256 burnedFunds = delta.div(date.rate.interval).mul(date.rate.payment);
    return date.balance.sub(burnedFunds);
  }

  // total share of available balance of existing date
  function balanceShareOf(uint256 _dateId, address _addr)
    public
    view
    dateExists(_dateId)
    returns (uint256 shareOfBalance)
  {
    Date memory date = dates[_dateId];
    uint256 share;
    if(_addr == date.host) {
    share = date.hostShare;
  } else {
    share = date.guestShare;
  }
    if (deltaOf(_dateId) > 0) {
      share = balanceOf(_dateId).div(2);
    }
    return share;
  }


  function getDate(uint256 _dateId)
    public
    view
    dateExists(_dateId)
    returns (
      address host,
      address guest,
      address recipient,
      uint256 hostShare,
      uint256 guestShare,
      bool hostCheckedIn,
      bool guestCheckedIn,
      address tokenAddress,
      uint256 initialBalance
  )
  {
    Date memory date = dates[_dateId];
    return (
      date.host,
      date.guest,
      date.recipient,
      date.hostShare,
      date.guestShare,
      date.hostCheckedIn,
      date.guestCheckedIn,
      date.tokenAddress,
      date.balance
    );
  }

  function getDate2(uint256 _dateId)
    public
    view
    dateExists(_dateId)
    returns (
      uint256 startBlock,
      uint256 stopBlock,
      uint256 payment,
      uint256 interval
  )
  {
    Date memory date = dates[_dateId];
    return (
      date.timeframe.start,
      date.timeframe.stop,
      date.rate.payment,
      date.rate.interval
    );
  }

  function create(
    address _guest,
    address _tokenAddress,
    uint256 _startBlock,
    uint256 _stopBlock,
    uint256 _payment,
    uint256 _interval
  )
    public
  {
    verifyTerms(
      _tokenAddress,
      _startBlock,
      _stopBlock,
      _interval
    );

    // both tokens and ether can be streamed
    uint256 deposit = _stopBlock.sub(_startBlock).div(_interval).mul(_payment);
    IERC20 tokenContract = IERC20(_tokenAddress);
    uint256 allowance = tokenContract.allowance(msg.sender, address(this));
    require(
      allowance >= deposit,
      "contract not allowed to transfer enough tokens"
    );

    // create and log the stream if the deposit is okay
    dates[dateNonce] = Date({
      host : msg.sender,
      guest : _guest,
      recipient : burnAddress,
      hostShare : deposit,
      guestShare : 0,
      hostCheckedIn : false,
      guestCheckedIn : false,
      tokenAddress : _tokenAddress,
      balance : deposit,
      timeframe : Timeframe(_startBlock, _stopBlock),
      rate : Rate(_payment, _interval)
    });
    emit LogInviteCreate(
      dateNonce,
      msg.sender,
      _guest,
      deposit,
      _tokenAddress,
      _startBlock,
      _stopBlock,
      _payment,
      _interval
    );
    dateNonce = dateNonce.add(1);

    // apply Checks-Effects-Interactions
    tokenContract.transferFrom(msg.sender, address(this), deposit);
  }

  function acceptInvite(uint256 _dateId)
  public
  onlyGuest(_dateId)
  {
    Date memory date = dates[_dateId];
    IERC20 tokenContract = IERC20(date.tokenAddress);
    uint256 allowance = tokenContract.allowance(msg.sender, address(this));
    require(
      allowance >= date.hostShare,
      "contract not allowed to transfer enough tokens to match host's deposit"
    );
    tokenContract.transferFrom(msg.sender, address(this), date.hostShare);
    emit LogInviteAccepted(
        _dateId,
        date.host,
        date.guest
      );
    date.guestShare = date.hostShare;
    dates[_dateId] = date;
  }

  function checkIn(
    uint256 _dateId
  )
    public
    dateExists(_dateId)
    onlyHostOrGuest(_dateId)
  {

    Date memory date = dates[_dateId];
    require(block.number>date.timeframe.start, "Cannot check in before the date has started");
    if (msg.sender == date.host) {
      date.hostCheckedIn = true;
    } else {
      date.guestCheckedIn = true;
  }
   dates[_dateId] = date;
   if (date.hostCheckedIn && date.guestCheckedIn) {
     redeem(_dateId);}
  }


  function checkedInStatus(
    uint256 _dateId, address _addr
  )
    public
    view
    dateExists(_dateId)
    onlyHostOrGuest(_dateId)
    returns (bool status)
  {
    Date memory date = dates[_dateId];
    if (msg.sender == date.host) {
      return date.hostCheckedIn;
    } else {
      return date.guestCheckedIn;
  }
  }

  function cancelDate(uint256 _dateId)
   public
   dateExists(_dateId)
    {
    Date memory date = dates[_dateId];
    require(msg.sender == date.host, "Only host can cancel the date without checking in.");
    if(date.guestShare == 0) {
       redeem(_dateId);}
    emit LogInviteCancel(
         _dateId,
         date.host
       );
  }

function getDateNonce() public view returns (uint256 currentDateNonce) {
  return dateNonce;
}




  /*  //////////////////////////////////////////////////////////////
   * Private
   */ //////////////////////////////////////////////////////////////
   // time passed since start of Date
  function deltaOf(uint256 _dateId)
    private
    view
    returns (uint256 delta)
  {
    Date memory date = dates[_dateId];
    uint256 startBlock = date.timeframe.start;

    // before the streaming period finished
    if (block.number < startBlock)
      return 0;

    // after the streaming period finished
    uint256 latestBlock = block.number;
    if (latestBlock > date.timeframe.stop)
      latestBlock = date.timeframe.stop;
    return latestBlock.sub(startBlock);
  }

  function verifyTerms(
    address _tokenAddress,
    uint256 _startBlock,
    uint256 _stopBlock,
    uint256 _interval
  )
    private
    view
    returns (bool valid)
  {
    require(
      _tokenAddress != address(0x0),
      "token contract address needs to be provided"
    );
    require(
      _startBlock >= block.number,
      "the start block needs to be higher than the current block number"
    );
    require(
      _stopBlock > _startBlock,
      "the stop block needs to be higher than the start block"
    );
    uint256 delta = _stopBlock - _startBlock;
    require(
      delta >= _interval,
      "the block difference needs to be higher than the payment interval"
    );
    require(
      delta.mod(_interval) == 0,
      "the block difference needs to be a multiple of the payment interval"
    );
    return true;
  }
}

function redeem(uint256 _dateId)
  private
{
  Date memory date = dates[_dateId];
  uint256 participantShare = balanceOf(_dateId).div(2);
  uint256 delta = deltaOf(_dateId);
  uint256 burnedFunds = delta.div(date.rate.interval).mul(date.rate.payment);
  emit LogRedeem(
    _dateId,
    date.host,
    date.guest,
    burnedFunds,
    participantShare,
    participantShare
  );
  delete dates[_dateId];

  // reverts when the token address is not an ERC20 contract
  IERC20 tokenContract = IERC20(date.tokenAddress);
  // saving gas by checking beforehand
  if (burnedFunds > 0) {
    tokenContract.transfer(date.recipient, burnedFunds);}
  if (participantShare > 0) {
    tokenContract.transfer(date.host, participantShare);
    tokenContract.transfer(date.guest, participantShare);
}
}
