//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

interface ISponsorshipCertificate {
  /**
   * Mint a new sponsorship certificate.
   * @param _sponsor The user sponsoring the _receiver.
   * @param _receiver The user receiving the sponsorship funds.
   * @param _amount The amount that is being given to the user.
   * @param _shares The amount of shares that represent this sponsorship.
   */
  function emitCertificate(
    address _sponsor,
    address _receiver,
    uint256 _amount,
    uint256 _shares
  ) external;
}
