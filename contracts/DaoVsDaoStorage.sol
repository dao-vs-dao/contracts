//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

struct Coordinates {
  uint64 realm;
  uint64 row;
  uint64 column;
}

abstract contract DaoVsDaoStorageV1 {
  /* ========== GAME FIELD ========== */

  /** A matrix containing the game map */
  address[][][] public lands;
  /** The user coordinates */
  mapping(address => Coordinates) public userCoord;
  /** The number of players on the board */
  uint256 public nrPlayers;

  /* ========== REWARDS ========== */

  /** The timestamp the user last claimed their tokens.
  This variable is also used to define whether an address belongs to a player or not */
  mapping(address => uint256) public latestClaim;

  /* ========== SLASHING ========== */

  /** The percentage of tokens removed from the user when slashed */
  uint256 public slashingPercentage;
  /** The percentage of slashed tokens sent to the team */
  uint256 public slashingTax;

  /* ========== SPONSORSHIPS ========== */

  /** The contract emitting sponsorship certificates */
  address public sponsorshipCertificateEmitter;
  /** The amount given to the user as sponsorship */
  mapping(address => uint256) public sponsorships;
  /** The amount of shares for a single user's sponsorship */
  mapping(address => uint256) public sponsorshipShares;

  /* ========== PARTICIPATION COSTS ========== */

  /** The minimum amount of chain coins needed to participate to the game */
  uint256 public participationFee;
  /** The percentage of the fee that will be forwarded to the player that referred this user */
  uint256 public percentageForReferrer;

  /* ========== COOL-DOWNS ========== */

  /** How often players can attack */
  uint256 public constant attackCoolDownTime = 12 hours;
  /** A map containing the timestamps signaling when the players will be able to attack again */
  mapping(address => uint256) public attackCoolDowns;

  /** How long a player won't be able to be attacked after being swapped */
  uint256 public constant recoveryCoolDownTime = 24 hours;
  /** A map containing the timestamps signaling when the players will be able to be attacked again */
  mapping(address => uint256) public recoveryCoolDowns;
}
