//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

struct CertificateData {
  address receiver;
  uint256 amount;
  uint256 redeemed;
  uint256 shares;
  bool closed;
}
