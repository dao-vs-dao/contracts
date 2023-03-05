//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./CertificateData.sol";
import "./interfaces/IERC4906.sol";
import "./interfaces/ISponsorshipCertificate.sol";
import "./interfaces/ISponsorshipRedeemer.sol";
import "./SponsorshipCertificateStorage.sol";
import "./interfaces/ISponsorshipCertificateMetadataFactory.sol";

contract SponsorshipCertificate is
  IERC4906,
  ISponsorshipCertificate,
  OwnableUpgradeable,
  UUPSUpgradeable,
  ERC721EnumerableUpgradeable,
  SponsorshipCertificateStorageV1
{
  using CountersUpgradeable for CountersUpgradeable.Counter;

  /* ========== EVENTS ========== */

  /* ========== CONSTRUCTOR & INITIALIZER ========== */

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external virtual initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
    __ERC721_init_unchained("DVD - Sponsorship Certificate", "DVD-SPCERT");
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /* ========== VIEWS ========== */

  /**
   * @dev Returns an URI for a given token ID
   */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    require(_exists(_tokenId));
    return
      ISponsorshipCertificateMetadataFactory(sponsorshipCertificateMetadataFactory)
        .createCertificateMetadata(_tokenId, certificateData[_tokenId]);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return
      interfaceId == bytes4(0x49064906) || // IERC4906
      super.supportsInterface(interfaceId);
  }

  /* ========== SETTERS ========== */

  /* ========== MUTATIVE FUNCTIONS ========== */

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
  ) external override {
    ISponsorshipRedeemer redeemer = ISponsorshipRedeemer(sponsorshipManager);
    require(msg.sender == address(redeemer));

    // mint the certificate
    _tokenIds.increment();
    uint256 certificateId = _tokenIds.current();
    _safeMint(_sponsor, certificateId);

    // store the certificate data
    certificateData[certificateId] = CertificateData(_receiver, _amount, 0, _shares, false);
  }

  function redeemCertificate(uint256 certificateId) external {
    require(ownerOf(certificateId) == msg.sender, "Not the owner");

    // redeem the certificate for the owner
    CertificateData memory data = certificateData[certificateId];
    uint256 redeemedAmount = ISponsorshipRedeemer(sponsorshipManager).redeemSponsorshipShares(
      msg.sender,
      data.receiver,
      data.shares
    );

    // update the certificate
    certificateData[certificateId].redeemed = redeemedAmount;
    certificateData[certificateId].closed = true;
    emit MetadataUpdate(certificateId);
  }

  /* ========== PRIVATE FUNCTIONS ========== */
}
