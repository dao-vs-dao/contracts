//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "../interfaces/ISponsorshipCertificate.sol";

contract TestSponsorshipCertificate is ISponsorshipCertificate {
  /**
   * Mint a new sponsorship certificate.
   */
  function emitCertificate(address, address, uint256, uint256) external pure override {}
}
