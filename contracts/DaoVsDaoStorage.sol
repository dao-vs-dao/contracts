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
}
