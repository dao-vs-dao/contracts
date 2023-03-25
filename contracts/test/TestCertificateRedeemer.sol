//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "../interfaces/ISponsorshipRedeemer.sol";

contract TestCertificateRedeemer is ISponsorshipRedeemer {
  /** Ends a sponsorship and returns the funds to the sponsor */
  function redeemSponsorshipShares(
    address,
    address,
    uint256
  ) external pure override returns (uint256) {
    return 1000;
  }

  /**
   * Calculate how much some shares are now worth.
   */
  function worthOfSponsorshipShares(address, uint256) external pure override returns (uint256) {
    return 1000;
  }
}
