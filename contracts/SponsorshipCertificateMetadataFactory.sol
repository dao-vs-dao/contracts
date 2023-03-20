//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

import "./CertificateData.sol";
import "./interfaces/ISponsorshipCertificateMetadataFactory.sol";

contract SponsorshipCertificateMetadataFactory is
  OwnableUpgradeable,
  UUPSUpgradeable,
  ISponsorshipCertificateMetadataFactory
{
  /* ========== CONSTRUCTOR & INITIALIZER ========== */

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external virtual initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /* ========== PURE FUNCTIONS ========== */

  /**
   * Creates the metadata for the specified certificate.
   */
  function createCertificateMetadata(
    uint256 _certificateId,
    CertificateData calldata _certificateData
  ) external pure override returns (string memory) {
    string memory name = generateName(_certificateId, _certificateData.closed);
    string memory description = generateDescription(_certificateData);
    string memory image = Base64.encode(bytes(generateSVGImage(_certificateData)));

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                name,
                '", "description":"',
                description,
                '", "external_url": "https://wip.com",',
                '"image": "',
                "data:image/svg+xml;base64,",
                image,
                '"}'
              )
            )
          )
        )
      );
  }

  /* ========== PRIVATE FUNCTIONS ========== */

  function generateName(uint256 _certificateId, bool closed) private pure returns (string memory) {
    string memory baseName = "DVD Sponsorship Certificate #";
    string memory redeemed = closed ? " - REEDEMED" : "";
    return string(abi.encodePacked(baseName, Strings.toString(_certificateId), redeemed));
  }

  function generateDescription(
    CertificateData calldata _data
  ) private pure returns (string memory) {
    return
      _data.closed
        ? generateClosedCertificateDescription(_data)
        : generateOpenCertificateDescription(_data);
  }

  function generateOpenCertificateDescription(
    CertificateData calldata _data
  ) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          "This certificate represents the ownership of ",
          Strings.toString(_data.shares),
          " shares in the sponsorship of ",
          Strings.toHexString(uint160(_data.receiver), 20)
        )
      );
  }

  function generateClosedCertificateDescription(
    CertificateData calldata _data
  ) private pure returns (string memory) {
    string memory profitLossText = _data.amount < _data.redeemed ? "profit" : "loss";
    uint256 profitLossValue = _data.amount < _data.redeemed
      ? _data.redeemed - _data.amount
      : _data.amount - _data.redeemed;
    return
      string(
        abi.encodePacked(
          "This certificate represented a participation in the sponsorship of ",
          Strings.toHexString(uint160(_data.receiver), 20),
          " and has been redeemed with a ",
          profitLossText,
          " of ",
          Strings.toString(profitLossValue),
          " DVD"
        )
      );
  }

  function generateSVGImage(CertificateData calldata) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<svg viewBox="0 0 100 100" ',
          'xmlns="http://www.w3.org/2000/svg">',
          '<rect width="100%" height="100%" fill="#000000"/>',
          '<polygon points="50,10 90,80 10,80" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FFD800; #FFC200; #FFAB00; #FF9700; #FF8200; #FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,15 85,75 15,75" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FFC200; #FFAB00; #FF9700; #FF8200; #FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,20 80,70 20,70" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FFAB00; #FF9700; #FF8200; #FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200; #FFAB00;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,25 75,65 25,65" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FF9700; #FF8200; #FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200; #FFAB00; #FF9700;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,30 70,60 30,60" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FF8200; #FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200; #FFAB00; #FF9700; #FF8200; " dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,35 65,55 35,55" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FF6E00; #FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200; #FFAB00; #FF9700; #FF8200; #FF6E00;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          '<polygon points="50,40 60,50 40,50" stroke="#FFFFFF" stroke-width="1">',
          '<animate attributeName="fill" values="#FF5900; #FF6E00; #FF8200; #FF9700; #FFAB00; #FFC200; #FFD800; #FFC200; #FFAB00; #FF9700; #FF8200; #FF6E00; #FF5900;" dur="10s" repeatCount="indefinite"/>',
          "</polygon>",
          "</svg>"
        )
      );
  }
}
