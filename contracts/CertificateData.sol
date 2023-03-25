//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

/**
 * Data structure used storing info about certificates.
 */
struct CertificateData {
  address receiver;
  uint256 amount;
  uint256 redeemed;
  uint256 shares;
  bool closed;
}

/**
 * Data structure used by the methods that retrieve
 * information to display on the dapp.
 */
struct CertificateView {
  uint256 id;
  address owner;
  address receiver;
  uint256 amount;
  uint256 redeemed;
  uint256 shares;
  bool closed;
}
