//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

interface ISponsorshipRedeemer {
  /**
   * Ends a sponsorship and returns the funds to the sponsor.
   * @param _sponsor The owner of the sponsorship certificate.
   * @param _receiver The user that received the sponsorship.
   * @param _shares The amount of shares to be redeemed.
   */
  function redeemSponsorshipShares(
    address _sponsor,
    address _receiver,
    uint256 _shares
  ) external returns (uint256);
}
