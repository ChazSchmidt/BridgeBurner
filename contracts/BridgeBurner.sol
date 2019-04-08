pragma solidity ^0.4.25;

import "./openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./IERC1620.sol";


/// @title BridgeBurner - A modified version of Paul Berg's ERC Money Streaming Implementation
/// @author Chaz Schmidt <schmidt.864@osu.edu> and Paul Berg - <hello@paulrberg.com>


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
  mapping(uint256 => mapping(address => bool)) private updates;
  address burnAddress = 0xbAd0000000000000000000000000000000000000;

  /*
   * Events
   */
   // TODO not modified yet

  event LogCreate(
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

  event LogWithdraw(
    uint256 indexed _dateId,
    address indexed _recipient,
    uint256 _funds
  );

  event LogRedeem(
    uint256 indexed _dateId,
    address indexed _host,
    address indexed _guest,
    uint256 _burnedFunds,
    uint256 _hostShare,
    uint256 _guestShare
  );

  event LogConfirmUpdate(
    uint256 indexed _dateId,
    address indexed confirmer,
    address _newTokenAddress,
    uint256 _newStopBlock,
    uint256 _newPayment,
    uint256 _newInterval
  );

  event LogRevokeUpdate(
    uint256 indexed _dateId,
    address indexed revoker,
    address _newTokenAddress,
    uint256 _newStopBlock,
    uint256 _newPayment,
    uint256 _newInterval
  );

  event LogExecuteUpdate(
    uint256 indexed _newDateId,
    address indexed _sender,
    address indexed _recipient,
    address _newTokenAddress,
    uint256 _newStopBlock,
    uint256 _newPayment,
    uint256 _newInterval
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

  modifier updateConfirmed(uint256 _dateId, address _addr) {
    require(
      updates[_dateId][_addr] == true,
      "msg.sender has not previously confirmed the update"
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
      share = balanceOf(_dateId).mul(share.div(date.hostShare.add(date.guestShare)));
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
      uint256 balance
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

// TODO
  function getUpdate(uint256 _dateId, address _addr)
    public
    view
    dateExists(_dateId)
    returns (bool active)
  {
    return updates[_dateId][_addr];
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
    emit LogCreate(
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
  }

function getDateNonce() public view returns (uint256 currentDateNonce) {
  return dateNonce;
}

  function redeem(uint256 _dateId)
    public
    dateExists(_dateId)
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
    updates[_dateId][date.host] = false;
    updates[_dateId][date.guest] = false;

    // reverts when the token address is not an ERC20 contract
    IERC20 tokenContract = IERC20(date.tokenAddress);
    // saving gas by checking beforehand
    if (burnedFunds > 0) {
      tokenContract.transfer(date.recipient, burnedFunds);
      tokenContract.transfer(date.host, participantShare);
      tokenContract.transfer(date.guest, participantShare);
  }
}

// // TODO
//   function confirmUpdate(
//     uint256 _dateId,
//     address _tokenAddress,
//     uint256 _startBlock,
//     uint256 _stopBlock,
//     uint256 _payment,
//     uint256 _interval
//   )
//     public
//     dateExists(_dateId)
//     onlyHostOrGuest(_dateId)
//   {
//     onlyNewTerms(
//       _dateId,
//       _tokenAddress,
//       _stopBlock,
//       _payment,
//       _interval
//     );
//     verifyTerms(
//       _tokenAddress,
//       block.number,
//       _stopBlock,
//       _interval
//     );
//
//     emit LogConfirmUpdate(
//       _dateId,
//       msg.sender,
//       _tokenAddress,
//       _stopBlock,
//       _payment,
//       _interval
//     );
//     updates[_dateId][msg.sender] = true;
//
//     executeUpdate(
//       _dateId,
//       _tokenAddress,
//       _startBlock,
//       _stopBlock,
//       _payment,
//       _interval
//     );
//   }
//
// // TODO
//   function revokeUpdate(
//     uint256 _dateId,
//     address _tokenAddress,
//     uint256 _stopBlock,
//     uint256 _payment,
//     uint256 _interval
//   )
//     public
//     updateConfirmed(_dateId, msg.sender)
//   {
//     emit LogRevokeUpdate(
//       _dateId,
//       msg.sender,
//       _tokenAddress,
//       _stopBlock,
//       _payment,
//       _interval
//     );
//     updates[_dateId][msg.sender] = false;
//   }

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

// TODO
  function onlyNewTerms(
    uint256 _dateId,
    address _tokenAddress,
    uint256 _stopBlock,
    uint256 _payment,
    uint256 _interval
  )
    private
    view
    returns (bool valid)
  {
    require(
    // Disable solium check because of
    // https://github.com/duaraghav8/Solium/issues/175
    // solium-disable-next-line operator-whitespace
      dates[_dateId].tokenAddress != _tokenAddress ||
      dates[_dateId].timeframe.stop != _stopBlock ||
      dates[_dateId].rate.payment != _payment ||
      dates[_dateId].rate.interval != _interval,
      "date has these terms already"
    );
    return true;
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

// TODO
    // solium-disable-next-line function-order
  // function executeUpdate(
  //   uint256 _dateId,
  //   address _tokenAddress,
  //   uint256 _startBlock,
  //   uint256 _stopBlock,
  //   uint256 _payment,
  //   uint256 _interval
  // )
  //   private
  //   dateExists(_dateId)
  // {
  //   Date memory date = dates[_dateId];
  //   require(block.number < date.timeframe.start, "The date has already started. Proceed to check in.");
  //   if (updates[_dateId][date.host] == false)
  //     return;
  //   if (updates[_dateId][date.guest] == false)
  //     return;
  //
  //   // adjust stop block
  //   uint256 remainder = _stopBlock.sub(block.number).mod(_interval);
  //   uint256 adjustedStopBlock = _stopBlock.sub(remainder);
  //   emit LogExecuteUpdate(
  //     _dateId,
  //     date.host,
  //     date.guest,
  //     _tokenAddress,
  //     adjustedStopBlock,
  //     _payment,
  //     _interval
  //   );
  //   updates[_dateId][date.host] = false;
  //   updates[_dateId][date.guest] = false;
  //
  //   redeem(
  //     _dateId
  //   );
  //   create(
  //     date.host,
  //     date.guest,
  //     _tokenAddress,
  //     block.number,
  //     adjustedStopBlock,
  //     _payment,
  //     _interval
  //   );
  // }
}
