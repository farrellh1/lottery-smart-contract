// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Lottery {
  address payable public manager;
  address payable[] public players;

  constructor() {
    manager = payable(msg.sender);
  }

  receive() payable external {
    require(msg.value == 0.01 ether, "Must be 0.01ETH to enter the lottery.");
    require(payable(msg.sender) == manager, "Manager can't enter the lottery.");

    players.push(payable((msg.sender)));
  }

  function getPlayers() public managerOnly view returns(address payable[] memory) {
    return players;
  }

  function randomaizer() internal view returns(uint) {
    return uint(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, players)));
  }

  function pickWinner() public managerOnly {
    require(players.length >= 3, "Must be at least 3 players.");

    uint index = randomaizer() % players.length;
    address payable winnner = players[index];

    // Transfer 10% smart contract's balance to manager's address
    manager.transfer(address(this).balance / 10);

    // Transfer smart contract's balance to winner's address
    winnner.transfer(address(this).balance);

    players = new address payable[](0);
  }

  modifier managerOnly() {
    require(msg.sender == manager, "Can only be called by manager.");
    _;
  }
}