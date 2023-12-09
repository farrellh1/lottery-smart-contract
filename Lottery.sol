// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./VRFv2Consumer.sol"; // need to deploy the VRFv2Consumer

contract Lottery {
  address payable public manager;
  address payable[] public players;

  VRFv2Consumer internal consumerContract;
  uint roundId;
  mapping(uint => address) public roundToWinnner;

  enum LOTTERY_STATE {
    OPEN, // people can enter
    CLOSE, // lottery is closed
    CALCULATING_WINNER // waiting for VRF response
  }

  LOTTERY_STATE public lottery_state;

  constructor() {
    manager = payable(msg.sender);
    lottery_state = LOTTERY_STATE.OPEN;
    consumerContract = VRFv2Consumer(
      0x31DF0Cb06BE3Cd65E7d48E4A2B95cfa55D86ce8C
    );
  }

  modifier managerOnly() {
    require(msg.sender == manager, "Can only be called by manager.");
    _;
  }

  receive() external payable {
    require(
      payable(msg.sender) != manager,
      "Manager can't enter the lottery"
    );
    require(
      msg.value == 0.011 ether,
      "Must be 0.011ETH to enter the lottery."
    ); // 0.001 for the manager, will be paid when winner is picked

    // add player to players array
    players.push(payable((msg.sender)));
  }

  function getPlayers()
    public
    view
    managerOnly
    returns (address payable[] memory)
  {
    return players;
  }

  function requestVRF() public managerOnly {
    // send request to Chainlink VRF
    consumerContract.requestRandomWords();
    lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
  }

  function checkVRFResponse()
    internal
    view
    returns (bool fullfilled, uint[] memory randomNumbers)
  {
    uint requestId = consumerContract.lastRequestId();

    (fullfilled, randomNumbers) = consumerContract.getRequestStatus(
        requestId
    );
  }

  function pickWinner() public managerOnly {
    require(
      lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
      "Lottery is not calculating winner state."
    );

    (bool fullfilled, uint[] memory randomNumbers) = checkVRFResponse();
    require(fullfilled, "Random numbers request has not been fullfiled.");

    require(players.length >= 3, "Must be at least 3 players");
    uint index = randomNumbers[0] % players.length;
    address payable winner = players[index];

    // Transfer manager fee
    (bool sentManager, ) = manager.call{
      value: 0.001 ether * players.length
    }("");
    require(sentManager, "Failed to send manager fee.");

    // Transfer smart contract's balance to winner's address
    (bool sentWinner, ) = winner.call{value: address(this).balance}("");
    require(sentWinner, "Failed to send winner's prize.");

    roundId++;
    roundToWinnner[roundId] = winner;

    players = new address payable[](0);

    lottery_state = LOTTERY_STATE.OPEN;
  }

  function closeLottery() public managerOnly {
    require(players.length == 0, "Player have entered.");

    lottery_state = LOTTERY_STATE.CLOSE;
  }
}
