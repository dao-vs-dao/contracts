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
    string memory image = Base64.encode(
      bytes(generateSVGImage(_certificateId, _certificateData.receiver))
    );

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

  function generateSVGImage(
    uint256 _certificateId,
    address _receiver
  ) private pure returns (string memory) {
    string memory strokeWidth = getStrokeWidth(_certificateId, _receiver);
    bytes[7] memory animations = getAnimations(getPalette(_certificateId, _receiver));

    return
      string(
        abi.encodePacked(
          '<svg viewBox="0 0 100 100" ',
          'xmlns="http://www.w3.org/2000/svg">',
          '<rect width="100%" height="100%" fill="#000000"/>',
          abi.encodePacked(
            '<polygon points="50,10 90,80 10,80" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[0],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,15 85,75 15,75" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[1],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,20 80,70 20,70" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[2],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,25 75,65 25,65" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[3],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,30 70,60 30,60" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[4],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,35 65,55 35,55" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[5],
          "</polygon>",
          abi.encodePacked(
            '<polygon points="50,40 60,50 40,50" stroke="#FFFFFF" stroke-width="',
            strokeWidth,
            '">'
          ),
          animations[6],
          "</polygon>",
          "</svg>"
        )
      );
  }

  function getStrokeWidth(
    uint256 _certificateId,
    address _receiver
  ) private pure returns (string memory) {
    uint256 receiver = uint256(uint160(_receiver));
    uint256 val = receiver > _certificateId ? receiver - _certificateId : _certificateId - receiver;
    uint256 index = val % 100;
    if (index < 50) return "0"; // 50%
    if (index < 80) return "0.25"; // 30%
    return "0.5"; // 20%
  }

  function getPalette(
    uint256 _certificateId,
    address _receiver
  ) private pure returns (string[7] memory) {
    string[7][32] memory palettes = [
      ["#FFD800", "#FFC200", "#FFAB00", "#FF9700", "#FF8200", "#FF6E00", "#FF5900"],
      ["#90E0EF", "#48CAE4", "#00B4D8", "#0096C7", "#0077B6", "#023E8A", "#03045E"],
      ["#370617", "#6A040F", "#9D0208", "#D00000", "#DC2F02", "#E85D04", "#F48C06"],
      ["#C77DFF", "#9D4EDD", "#7B2CBF", "#5A189A", "#3C096C", "#240046", "#10002B"],
      ["#1E6091", "#1A759F", "#168AAD", "#34A0A4", "#52B69A", "#76C893", "#99D98C"],
      ["#005F73", "#0A9396", "#94D2BD", "#E9D8A6", "#EE9B00", "#CA6702", "#BB3E03"],
      ["#7209B7", "#560BAD", "#480CA8", "#3A0CA3", "#3F37C9", "#4361EE", "#4895EF"],
      ["#F3722C", "#F8961E", "#F9C74F", "#90BE6D", "#43AA8B", "#4D908E", "#577590"],
      ["#95D5B2", "#74C69D", "#52B788", "#40916C", "#2D6A4F", "#1B4332", "#081C15"],
      ["#2C699A", "#048BA8", "#0DB39E", "#16DB93", "#83E377", "#B9E769", "#EFEA5A"],
      ["#E5B3FE", "#E2AFFF", "#DEAAFF", "#D8BBFF", "#D0D1FF", "#C8E7FF", "#C0FDFF"],
      ["#660708", "#A4161A", "#BA181B", "#E5383B", "#B1A7A6", "#D3D3D3", "#F5F3F4"],
      ["#936639", "#A68A64", "#B6AD90", "#C2C5AA", "#A4AC86", "#656D4A", "#414833"],
      ["#023E7D", "#002855", "#001845", "#001233", "#33415C", "#5C677D", "#7D8597"],
      ["#00897B", "#00796B", "#00695C", "#00574B", "#004D40", "#004044", "#00363B"],
      ["#6A1B9A", "#8E24AA", "#E91E63", "#F06292", "#64B5F6", "#039BE5", "#1E88E5"],
      ["#A7ACD9", "#8C94C3", "#726A95", "#5D4E6D", "#4B2F48", "#2C132A", "#0A041A"],
      ["#4C6172", "#6A8E95", "#A3BCB6", "#D0E8D5", "#E5B098", "#D56C46", "#AA4203"],
      ["#57385C", "#9D8CA1", "#E2D4E6", "#D3E7CA", "#ACD0C4", "#648381", "#334E68"],
      ["#324376", "#4F5D95", "#7E92AB", "#B4C4D9", "#E7D4B5", "#D7A46A", "#B96B1C"],
      ["#75616B", "#9C8AA5", "#C5BAD0", "#E6E2EF", "#C7EAE4", "#88C3A1", "#3EACA8"],
      ["#5E2750", "#8E4A81", "#C5BAD0", "#E9D2EE", "#B7E3CC", "#6E8F7E", "#27634B"],
      ["#1B2330", "#3E517A", "#56A3DC", "#9CDFF9", "#F1B1C6", "#D65D7A", "#7E103C"],
      ["#294936", "#4D7559", "#81A87C", "#B5D8AF", "#E7D5C4", "#D8A593", "#AA6F60"],
      ["#453823", "#7A6A40", "#D0BA7C", "#FFEBC7", "#C5D0E6", "#648FC9", "#0C3D79"],
      ["#6B1229", "#AD1F45", "#E04A67", "#FFB1BB", "#C5E0DC", "#79B8C1", "#2E758C"],
      ["#F76F8E", "#F78CA0", "#F3C3A3", "#E1F0C4", "#9AE19D", "#58CCA6", "#3FA7D6"],
      ["#FF9B42", "#FFDA77", "#E0E5A9", "#C2EABD", "#A2D6F9", "#5C95FF", "#755FEC"],
      ["#FD8E7B", "#FDCB6E", "#D6E5C2", "#9FD1BE", "#3EB5C0", "#466BDF", "#7F5AF0"],
      ["#E63946", "#F1A9A0", "#F1E3CB", "#A8DADC", "#457B9D", "#1D3557", "#5E60CE"],
      ["#9EE493", "#FDFFB6", "#FFD98E", "#FFB8B8", "#E5A4CB", "#BFA2E8", "#72A0C1"],
      ["#B7094C", "#A01A58", "#892B64", "#723C70", "#5C4D7D", "#455E89", "#2E6F95"]
    ];

    uint256 index = (_certificateId + uint256(uint160(_receiver))) % palettes.length;
    return palettes[index];
  }

  function getAnimations(string[7] memory c) private pure returns (bytes[7] memory) {
    bytes[7] memory animations = [
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[5],
        ";",
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        '" dur="10s" repeatCount="indefinite"/>'
      ),
      abi.encodePacked(
        '<animate attributeName="fill" values="',
        c[6],
        ";",
        c[5],
        ";",
        c[4],
        ";",
        c[3],
        ";",
        c[2],
        ";",
        c[1],
        ";",
        c[0],
        ";",
        c[1],
        ";",
        c[2],
        ";",
        c[3],
        ";",
        c[4],
        ";",
        c[5],
        ";",
        c[6],
        '" dur="10s" repeatCount="indefinite"/>'
      )
    ];

    return animations;
  }
}
