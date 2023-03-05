//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./CertificateData.sol";

abstract contract SponsorshipCertificateStorageV1 {
  /** A counter to keep track of the next certificate id */
  CountersUpgradeable.Counter internal _tokenIds;

  /** The contract managing the sponsorships creations and redemptions */
  address public sponsorshipManager;

  /** The contract creating the metadata for each certificate */
  address public sponsorshipCertificateMetadataFactory;

  /** The data relative to each certificate */
  mapping(uint256 => CertificateData) public certificateData;
}
