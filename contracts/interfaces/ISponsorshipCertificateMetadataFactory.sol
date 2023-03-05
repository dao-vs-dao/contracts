//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "../CertificateData.sol";

interface ISponsorshipCertificateMetadataFactory {
  /**
   * Creates the metadata for the specified certificate.
   */
  function createCertificateMetadata(
    uint256 _certificateId,
    CertificateData calldata _certificateData
  ) external pure returns (string memory);
}
