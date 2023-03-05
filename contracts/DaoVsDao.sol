//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/ISponsorshipRedeemer.sol";
import "./interfaces/ISponsorshipCertificate.sol";
import "./helpers/EditedERC20Upgradeable.sol";
import "./DaoVsDaoStorage.sol";

contract DaoVsDao is
  ISponsorshipRedeemer,
  OwnableUpgradeable,
  UUPSUpgradeable,
  EditedERC20Upgradeable,
  DaoVsDaoStorageV1
{
  uint256 constant WORTH_PERCENTAGE_TO_PERFORM_SWAP = 120;

  /* ========== EVENTS ========== */

  /* ========== CONSTRUCTOR & INITIALIZER ========== */

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external virtual initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
    __ERC20_init_unchained("DaoVsDao Token", "DVD");
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /* ========== MODIFIERS ========== */

  /* ========== VIEWS ========== */

  /** Retrieve the last row of a realm */
  function getLastRow(uint64 _realm) external view returns (address[] memory) {
    address[][] memory chosenRealm = lands[_realm];
    return chosenRealm[chosenRealm.length - 1];
  }

  /**
   * Fetch the list of neighbors of the specified player.
   * @dev The returned array has a fixed size of 6 and will contain address(0)
   * in case of out-of bound coordinates
   * @param _sender The address of the player to retrieve the neighbors of.
   */
  function getNeighboringAddresses(address _sender) external view returns (address[] memory) {
    require(players[_sender], "Not a player");
    Coordinates memory coords = userCoord[_sender];

    address[] memory neighbors = new address[](6);
    address[][] memory realm = lands[coords.realm];

    // add top row neighbors
    if (coords.row > 0) {
      if (coords.column > 0) neighbors[0] = realm[coords.row - 1][coords.column - 1];
      neighbors[1] = realm[coords.row - 1][coords.column];
    }

    // add same row neighbors
    if (coords.column > 0) neighbors[2] = realm[coords.row][coords.column - 1];
    if (coords.column < realm[coords.row].length - 1)
      neighbors[3] = realm[coords.row][coords.column + 1];

    // add bottom row neighbors
    if (coords.row < realm.length - 1) {
      neighbors[4] = realm[coords.row + 1][coords.column];
      neighbors[5] = realm[coords.row + 1][coords.column + 1];
    }

    return neighbors;
  }

  /**
   * Check whether two sets of coordinates are neighboring, that means their distance is <= 1.
   * @param c1 The first set of coordinates.
   * @param c2 The second set of coordinates.
   */
  function isNeighbor(Coordinates memory c1, Coordinates memory c2) public pure returns (bool) {
    if (c1.realm != c2.realm) return false;
    uint64 deltaRow = c1.row > c2.row ? c1.row - c2.row : c2.row - c1.row;
    uint64 deltaColumn = c1.column > c2.column ? c1.column - c2.column : c2.column - c1.column;
    return (deltaRow <= 1 && deltaColumn <= 1);
  }

  /**
   * Calculate the worth of the given address.
   * @dev The worth is the sum of the balance and the amount the user has been sponsored with.
   * @param _user The address of the player to check.
   */
  function worth(address _user) public view returns (uint256) {
    return sponsorships[_user] + balanceOf(_user);
  }

  /**
   * Get the amount given to the player as sponsorship.
   * @param _user The address of the player to check.
   */
  function sponsorshipsOf(address _user) public view returns (uint256) {
    return sponsorships[_user];
  }

  /* ========== SETTERS ========== */

  /** Add a new 1x1 realm to the lands matrix. */
  function addRealm() external onlyOwner {
    address[] memory row = new address[](1);
    address[][] memory realm = new address[][](1);

    uint256 realmIndex = lands.length;
    lands.push(realm);
    lands[realmIndex].push(row);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /**
   * Place a user into a coordinate decided by the game master
   */
  function placeUser(Coordinates calldata _coord, bool _addRow) external {
    require(!players[msg.sender], "Already a player");

    address[][] memory _chosenRealm = lands[_coord.realm];
    require(_chosenRealm[_coord.row][_coord.column] == address(0), "Land not empty");

    _chosenRealm[_coord.row][_coord.column] = msg.sender;
    userCoord[msg.sender] = _coord;
    players[msg.sender] = true;

    if (!_addRow) return;
    uint256 latestRowLength = _chosenRealm[_chosenRealm.length - 1].length;
    address[] memory row = new address[](latestRowLength + 1);
    lands[_coord.realm].push(row);
  }

  /**
   * Moves the calling user to the specified coordinates.
   * @notice If the coordinates are occupied by another user, this will be slashed.
   * @param _coords The coordinates the caller wants to move to.
   * They must be neighboring to their current position.
   */
  function swap(Coordinates calldata _coords) external {
    // check coordinates validity
    require(_coords.realm < lands.length, "Realm out of bound");
    require(_coords.row >= 0, "Row out of bound");
    require(_coords.row < lands[_coords.realm].length, "Row out of bound");
    require(_coords.column >= 0, "Column out of bound");
    require(_coords.column < lands[_coords.realm][_coords.row].length, "Column out of bound");

    // check that caller is a neighbor
    require(players[msg.sender], "User isn't a player");
    Coordinates memory _coordsSender = userCoord[msg.sender];
    require(isNeighbor(_coords, _coordsSender), "Swap too far from user coords");
    require(_coords.row >= _coordsSender.row, "Cannot swap with a lower row");

    // check the attacked user's worth
    address attackedUser = lands[_coords.realm][_coords.row][_coords.column];
    if (attackedUser != address(0))
      require(
        worth(msg.sender) > (worth(attackedUser) * WORTH_PERCENTAGE_TO_PERFORM_SWAP) / 100,
        "User has higher worth"
      );

    // swap users and, eventually, slash attacked user
    (
      lands[_coords.realm][_coords.row][_coords.column],
      lands[_coordsSender.realm][_coordsSender.row][_coordsSender.column]
    ) = (msg.sender, attackedUser);
    userCoord[msg.sender] = _coords;
    if (attackedUser != address(0)) {
      userCoord[attackedUser] = _coordsSender;
      slash(attackedUser, msg.sender);
    }
  }

  /**
   * Give a certain amount to a user as a sponsorship.
   * @notice This will cause the minting of a sponsorship NFT.
   * @param _user The user the caller wants to sponsor.
   * @param _amount The amount that will be given as sponsorship.
   */
  function sponsor(address _user, uint256 _amount) external {
    require(_amount > 0, "Amount must be greater than 0");
    require(players[_user], "User isn't a player");
    require(balanceOf(msg.sender) >= _amount, "Insufficient balance to sponsor");

    // calculate the amount of shares for this sponsorship
    uint256 _currentSponsorship = sponsorships[_user];
    uint256 _shares = _currentSponsorship == 0
      ? _amount
      : (_amount * sponsorshipShares[_user]) / _currentSponsorship;

    // create a certificate that will keep track of the sponsorship
    ISponsorshipCertificate(sponsorshipCertificateEmitter).emitCertificate(
      msg.sender,
      _user,
      _amount,
      _shares
    );

    //finally, update the bookkeeping variables
    unchecked {
      // Overflow not possible: the sum of all balances is capped by totalSupply,
      // and the sum is preserved by decrementing then incrementing.
      _balances[msg.sender] -= _amount;
      sponsorships[_user] += _amount;
    }
    sponsorshipShares[_user] += _shares;
  }

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
  ) external override returns (uint256) {
    require(msg.sender == sponsorshipCertificateEmitter, "Only emitter can revoke sponsor");
    require(_shares > 0, "Cannot reimburse 0 shares");

    // calculate the due amount
    uint256 _dueAmount = (sponsorships[_receiver] * _shares) / sponsorshipShares[_receiver];

    //return the due amount to the sponsor
    unchecked {
      // Overflow not possible: the sum of all balances is capped by totalSupply,
      // and the sum is preserved by decrementing then incrementing.
      sponsorships[_receiver] -= _dueAmount;
      _balances[_sponsor] += _dueAmount;
    }
    sponsorshipShares[_receiver] -= _shares;

    return _dueAmount;
  }

  /* ========== PRIVATE FUNCTIONS ========== */

  /**
   * Removes a certain amount of tokens owned by an attacked user and
   * redistributes them to the attacker.
   * @dev no check will be performed on the addresses, but they should both belong to players.
   * @param _attacked The user to slash.
   * @param _attacker The user that will receive the funds.
   */
  function slash(address _attacked, address _attacker) private {}
}
