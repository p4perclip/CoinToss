pragma solidity 0.5.12;

import "./Ownable.sol";
import "./Destroyable.sol"
import "./provableAPI.sol"
import "./SafeMath.sol"

// import "../SignedSafeMath.sol"

// Import SafeMath library from github (this import only works on Remix).
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/math/SafeMath.sol";
// import "github.com/oraclize/ethereum-api/provableAPI.sol";
contract CoinToss is Ownable, usingProvable, Destroyable {

  using SafeMath for uint256;


  uint256 internal balance;

  modifier betFunding(uint minAmount){
    require(msg.value >= minAmount,"Not enough ETH sent!");
        _;
    }

  modifier contractFunding(uint minAmount){
    require(msg.value >= minAmount,"Not enough ETH sent!");
        _;
    }

  struct State {
    address payable uAddress;
    uint256 uBalance;
    bool inGame;
    bool uPlayedPreviously;
    bytes32 lastQueryId;
  }
  struct Play {
    bytes32 id;
    address player;
    uint256 value;
    uint256 qPrice;
    uint256 result;
  }

//   address[] public playersHistory;

  uint256 internal constant MAX_INT_FROM_BYTE = 256;
  uint256 internal constant NUM_RANDOM_BYTES_REQUESTED = 1;

  mapping(address => State) public stateInfo;
  mapping(bytes32 => Play) public playInfo;
  mapping(address => uint256) public playersHistory;


  event PlayPlaced(address indexed player, bytes32 indexed queryId, uint256 value, uint256 balBefore);
  event GeneratedNumber(uint256 result, bool value);
  event LogNewProvableQuery(string description, bytes32 _queryId);
  event DepositDone(uint256 amount, address fromAcc);
  event PlayerDepositDone(uint256 amount, address fromAcc, uint256 newBal);
  event Withdrawn(uint256 amount, address toAcc);
  event ContractBalWithdrawn(uint256 amount, address toAcc);

  constructor() public {
     setPlayersHistory(msg.sender);
     provable_setProof(proofType_Ledger);
     }

  function addPlayerFunds() public payable betFunding (0.1 ether) {
    require ((msg.value > 0) && (msg.value < balance), "Amount too High or too Low");
    State memory newState;
    newState.uAddress = msg.sender;
    newState.uBalance = stateInfo[msg.sender].uBalance;
    newState.inGame = stateInfo[msg.sender].inGame;
    newState.uPlayedPreviously = stateInfo[msg.sender].uPlayedPreviously;
    newState.lastQueryId = stateInfo[msg.sender].lastQueryId;

    stateInfo[msg.sender] = newState;

    stateInfo[msg.sender].uBalance += msg.value;

    emit PlayerDepositDone(msg.value, msg.sender, stateInfo[msg.sender].uBalance);
  }
  function bet(uint256 value) public payable {
      require(stateInfo[msg.sender].uBalance > msg.value, "You got not enough money");
    //require(value >= 0.1, "Bet amount is too high");
    uint256 queryPrice = getqPrice();
    // require(playerS[msg.sender].uBalance > msg.value + queryPrice, "Not enough liquidity");

    if (stateInfo[msg.sender].uPlayedPreviously == false) {
        stateInfo[msg.sender].uPlayedPreviously = true;
        stateInfo[msg.sender].inGame = false;
    }
    // require(stateInfo[msg.sender].inGame == false, "Wait for function to process");
    stateInfo[msg.sender].inGame = true;
    oracleRandom(msg.sender, value, queryPrice);

  }
   function oracleRandom(address state, uint256 value, uint256 qPrice) payable public {

     uint256 QUERY_EXECUTION_DELAY = 0;
     uint256 GAS_FOR_CALLBACK = 200000;
    //  uint8 randomResult = testRandom();
        bytes32 _queryId = provable_newRandomDSQuery(
            QUERY_EXECUTION_DELAY,
            NUM_RANDOM_BYTES_REQUESTED,
            GAS_FOR_CALLBACK
     );

    Play memory newPlay;
    newPlay.id = _queryId;
    newPlay.player = state;
    newPlay.value = value;
    newPlay.qPrice = qPrice;
    newPlay.result;
    playInfo[_queryId] = newPlay;


    emit PlayPlaced(state, newPlay.id, newPlay.value, stateInfo[newPlay.player].uBalance);
    emit LogNewProvableQuery("Provable query was sent, standing by for the answer...", _queryId);
   }
  function __callback(bytes32 _queryId,string memory _result,bytes memory _proof) public {
    require(msg.sender == provable_cbAddress());
    address state = playInfo[_queryId].player;
    stateInfo[state].lastQueryId = _queryId;

    if (provable_randomDS_proofVerify__returnCode(
                _queryId,
                _result,
                _proof
            ) != 0
        ) {
        } else {

    uint8 result = uint8(uint256(keccak256(abi.encodePacked(_result))) % 2);
    playInfo[_queryId].result = result;
    bool tossStatus = processResult(stateInfo[msg.sender].uAddress, playInfo[_queryId].value, result, _queryId);
    delete playInfo[_queryId];
    // processResult(stateInfo[msg.sender].uAddress, playInfo[_queryId].value, result, _queryId);

    emit GeneratedNumber(result,tossStatus);
     }
    stateInfo[msg.sender].inGame = false;
    }
  function processResult(address payable player, uint256 value, uint8 result, bytes32 _queryId) payable public returns(bool) {
    bool tossStatus;

      if (playInfo[_queryId].result % 2  == 1){
        stateInfo[msg.sender].uBalance = stateInfo[msg.sender].uBalance.sub(value);
        value = value.sub(playInfo[_queryId].qPrice);
        player.transfer(msg.value.mul(2));
        playersHistory[player] = playersHistory[player].add(uint256(value));
        tossStatus = true;
      } else {
        stateInfo[msg.sender].uBalance = stateInfo[msg.sender].uBalance.add(value);
        value = value.sub(playInfo[_queryId].qPrice);
        playersHistory[player] = playersHistory[player].sub(uint256(value));
        tossStatus = false;
      }
    return tossStatus;
  }
  function setPlayersHistory (address _sender) private {
    playersHistory.push(_sender);
  }
  function getqPrice() internal returns (uint256 price){
    price = provable_getPrice("price");
  }
  function reset() public onlyOwner returns (bool){
    stateInfo[msg.sender].inGame = false;
  }
  function getBalance() public view returns (uint256){
    return address(this).balance;
  }
  function getUserBalance() public view returns (uint256){
    return (stateInfo[msg.sender].uBalance);
  }
  function withdrawUserBalance() public returns (uint256){
    require (stateInfo[msg.sender].inGame == false);
    uint u = stateInfo[msg.sender].uBalance;
    stateInfo[msg.sender].uBalance = 0;
    msg.sender.transfer(u);
  }
  function fund() public payable onlyOwner contractFunding (0.5 ether){
    balance += msg.value;
    emit DepositDone(msg.value, owner);
  }
  function withdrawAll() public onlyOwner returns (uint256){
    uint toTransfer = balance;
    balance = 0;
    msg.sender.transfer(toTransfer);
    return toTransfer;
  }
//   function testRandom() private returns (bytes32){
//     bytes32 queryId = bytes32(keccak256(abi.encodePacked(msg.sender)));
//     __callback(queryId, "1", bytes("test"));
//     emit LogNewProvableQuery("Provable query was sent, standing by for the answer...", queryId);
//     return queryId;
//   }
//   function testRandom() private view returns (uint8) {
// 		uint256 firstRes = uint256(keccak256(abi.encodePacked()));
// 		uint8 result = uint8(firstRes.mod(251));
// 		return result;
//     }
}
