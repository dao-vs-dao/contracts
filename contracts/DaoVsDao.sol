//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/ISponsorshipRedeemer.sol";
import "./interfaces/ISponsorshipCertificate.sol";
import "./helpers/EditedERC20Upgradeable.sol";
import "./DaoVsDaoStorage.sol";

struct PlayerData {
  address userAddress;
  Coordinates coords;
  uint256 balance;
  uint256 sponsorships;
  uint256 claimable;
  uint256 attackCoolDownEndTimestamp;
  uint256 recoveryCoolDownEndTimestamp;
}

struct GameData {
  address[][][] lands;
  PlayerData[] players;
}

contract DaoVsDao is
  ISponsorshipRedeemer,
  OwnableUpgradeable,
  UUPSUpgradeable,
  EditedERC20Upgradeable,
  DaoVsDaoStorageV1
{
  uint256 constant WORTH_PERCENTAGE_TO_PERFORM_SWAP = 120;

  /* ========== EVENTS ========== */

  event SponsorshipCertificateEmitterUpdated(address newEmitter);
  event SlashingPercentageUpdated(uint256 newSlashingPercentage);
  event SlashingTaxUpdated(uint256 newSlashingTax);
  event ParticipationFeeUpdated(uint256 newParticipationFee);
  event PercentageForReferrerUpdated(uint256 newPercentageForReferrer);
  event Slashed(
    address indexed attacker,
    address indexed attacked,
    uint256 subtractedFromAttackedBalance,
    uint256 subtractedFromAttackedSponsorships,
    uint256 slashingTaxes,
    uint256 addedToAttackerBalance,
    uint256 addedToAttackerSponsorships
  );

  /* ========== CONSTRUCTOR & INITIALIZER ========== */

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external virtual initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
    __ERC20_init_unchained("DaoVsDao Token", "DVD");

    slashingPercentage = 20; // 20% of the user worth will be slashed when they are attacked
    slashingTax = 10; // 10% of the total amount slashed is kept as tax
    participationFee = 20e16; // 0.20 MATIC as participation fee
    percentageForReferrer = 30; // 30% of the fee goes to the referrer

    // give 1 DVD to the contract owner for testing purposes
    _mint(owner(), 1e18);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

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
    require(latestClaim[_sender] > 0, "Not a player");
    Coordinates memory coords = userCoord[_sender];

    address[] memory neighbors = new address[](6);
    address[][] memory realm = lands[coords.realm];
    bool isNotFirstColumn = coords.column > 0;
    bool isNotLastColumn = coords.column < realm[coords.row].length - 1;

    // add top row neighbors
    if (coords.row > 0) {
      if (isNotFirstColumn) neighbors[0] = realm[coords.row - 1][coords.column - 1];
      if (isNotLastColumn) neighbors[1] = realm[coords.row - 1][coords.column];
    }

    // add same row neighbors
    if (isNotFirstColumn) neighbors[2] = realm[coords.row][coords.column - 1];
    if (isNotLastColumn) neighbors[3] = realm[coords.row][coords.column + 1];

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

    return ((deltaRow == 0 && deltaColumn == 1) || // vertically adjacent
      (deltaRow == 1 && deltaColumn == 0) || // top right or bottom left
      (deltaRow == 1 &&
        deltaColumn == 1 &&
        ((c1.row > c2.row && c1.column > c2.column) || // top left
          (c1.row < c2.row && c1.column < c2.column)))); // bottom right
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

  /**
   * Calculate the amount the user can claim at this time.
   * @param _user The address of the player to check.
   */
  function claimable(address _user) public view returns (uint256) {
    require(latestClaim[_user] > 0, "User isn't a player");

    Coordinates memory _coords = userCoord[_user];
    uint256 realmRows = lands[_coords.realm].length;

    // the reward rate is 2^(# rows below the user)
    uint256 rewardRate = 2 ** (realmRows - _coords.row) * 1e18;
    uint256 duration = block.timestamp - latestClaim[_user];

    return (rewardRate * duration) / 365 days;
  }

  /**
   * Get some information about the game state.
   * @dev Computationally intensive, it should only be called by a dapp/test and not on-chain.
   */
  function getGameData() external view returns (GameData memory) {
    PlayerData[] memory players = new PlayerData[](nrPlayers);

    uint256 index = 0;
    uint256 nrRealms = lands.length;
    for (uint256 i; i < nrRealms; ++i) {
      uint256 rows = lands[i].length;
      for (uint256 r; r < rows; ++r) {
        uint256 columns = lands[i][r].length;
        for (uint256 c; c < columns; ++c) {
          if (lands[i][r][c] != address(0)) players[index++] = getPlayerData(lands[i][r][c]);
        }
      }
    }

    return GameData(lands, players);
  }

  /**
   * Retrieve info about a player.
   * @dev Computationally intensive, it should only be called by a dapp/test and not on-chain.
   */
  function getPlayerData(address _player) public view returns (PlayerData memory) {
    require(latestClaim[_player] > 0, "User isn't a player");
    return
      PlayerData(
        _player,
        userCoord[_player],
        _balances[_player],
        sponsorships[_player],
        claimable(_player),
        attackCoolDowns[_player],
        recoveryCoolDowns[_player]
      );
  }

  /**
   * Calculate how much some shares are now worth.
   * @param _sponsored The user that received the sponsorship
   * @param _shares The amount of shares to be redeemed
   */
  function worthOfSponsorshipShares(
    address _sponsored,
    uint256 _shares
  ) external view override returns (uint256) {
    return (sponsorships[_sponsored] * _shares) / sponsorshipShares[_sponsored];
  }

  /* ========== SETTERS ========== */

  /** Set the sponsorship certificate emitter */
  function setSponsorshipCertificateEmitter(address _emitter) external onlyOwner {
    require(_emitter != address(0), "Invalid emitter");
    sponsorshipCertificateEmitter = _emitter;
    emit SponsorshipCertificateEmitterUpdated(_emitter);
  }

  /** Set the percentage that will be passed from attacked to attacker (minus tax) */
  function setSlashingPercentage(uint256 _slashingPercentage) external onlyOwner {
    require(_slashingPercentage <= 50, "Invalid slashing % value");
    slashingPercentage = _slashingPercentage;
    emit SlashingPercentageUpdated(_slashingPercentage);
  }

  /** Set the participation fee, paid by players to join the game */
  function setParticipationFee(uint256 _participationFee) external onlyOwner {
    participationFee = _participationFee;
    emit ParticipationFeeUpdated(_participationFee);
  }

  /** Set the percentage of the participation fee that will be received by referrers */
  function setPercentageForReferrer(uint256 _percentageForReferrer) external onlyOwner {
    require(_percentageForReferrer <= 100, "Invalid % for referrers value");
    percentageForReferrer = _percentageForReferrer;
    emit PercentageForReferrerUpdated(_percentageForReferrer);
  }

  /** Set the percentage kept as tax on slashed amounts */
  function setSlashingTax(uint256 _slashingTax) external onlyOwner {
    require(_slashingTax <= 100, "Invalid slashing tax value");
    slashingTax = _slashingTax;
    emit SlashingTaxUpdated(_slashingTax);
  }

  /** Add a new 1x1 realm to the lands matrix */
  function addRealm() external onlyOwner {
    lands.push([[0x0000000000000000000000000000000000000000]]);
  }

  /** Add a new row to the specified realm. The row length will be equal to the previous + 1 */
  function addRow(uint256 _realm) external onlyOwner {
    address[][] memory _chosenRealm = lands[_realm];
    uint256 latestRowLength = _chosenRealm[_chosenRealm.length - 1].length;
    lands[_realm].push(new address[](latestRowLength + 1));
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /**
   * Place a user into a set of coordinates they picked
   */
  function placeUser(Coordinates calldata _coord, address payable _referrer) external payable {
    require(latestClaim[msg.sender] == 0, "User is already a player");
    require(msg.value >= participationFee, "Need to pay participation fee");

    // check the chosen area
    address[][] memory _chosenRealm = lands[_coord.realm];
    require(_chosenRealm[_coord.row][_coord.column] == address(0), "Area not empty");

    // split the participation fee (only if referrer is a player)
    uint256 referralPercentage = latestClaim[msg.sender] > 0 ? percentageForReferrer : 0;
    uint256 ownerPercentage = 100 - referralPercentage;
    payable(owner()).transfer((msg.value * ownerPercentage) / 100);
    if (referralPercentage > 0) _referrer.transfer((msg.value * referralPercentage) / 100);

    // place user at the specified coordinates
    lands[_coord.realm][_coord.row][_coord.column] = msg.sender;
    userCoord[msg.sender] = _coord;
    latestClaim[msg.sender] = block.timestamp;
    ++nrPlayers;

    // check if adding a new row is required
    uint256 nrRows = _chosenRealm.length;
    uint256 totalCells = (nrRows * (nrRows + 1)) / 2;
    if (totalCells > nrPlayers) return; // there is still space, no need to add anything.

    // add new row
    uint256 latestRowLength = _chosenRealm[_chosenRealm.length - 1].length;
    lands[_coord.realm].push(new address[](latestRowLength + 1));
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
    require(_coords.row < lands[_coords.realm].length, "Row out of bound");
    require(_coords.column < lands[_coords.realm][_coords.row].length, "Column out of bound");

    // check that caller is a neighbor
    require(latestClaim[msg.sender] > 0, "User isn't a player");
    Coordinates memory _coordsSender = userCoord[msg.sender];
    require(isNeighbor(_coords, _coordsSender), "Swap too far from user coords");
    require(_coords.row <= _coordsSender.row, "Cannot swap with a higher row");

    // check attack cool-down
    uint256 timestamp = block.timestamp;
    require(attackCoolDowns[msg.sender] <= timestamp, "Cannot attack yet");

    // check the attacked user's worth and recovery cool-down
    address attackedUser = lands[_coords.realm][_coords.row][_coords.column];
    _claimTokens(msg.sender);
    if (attackedUser != address(0)) {
      require(recoveryCoolDowns[attackedUser] <= timestamp, "Cannot be attacked yet");
      _claimTokens(attackedUser);
      require(
        worth(msg.sender) > (worth(attackedUser) * WORTH_PERCENTAGE_TO_PERFORM_SWAP) / 100,
        "User has higher worth"
      );
    }

    // swap users positions
    (
      lands[_coords.realm][_coords.row][_coords.column],
      lands[_coordsSender.realm][_coordsSender.row][_coordsSender.column]
    ) = (msg.sender, attackedUser);
    userCoord[msg.sender] = _coords;
    attackCoolDowns[msg.sender] = timestamp + attackCoolDownTime;
    recoveryCoolDowns[msg.sender] = 0;

    // slash attacked user
    if (attackedUser != address(0)) {
      userCoord[attackedUser] = _coordsSender;
      slash(attackedUser, msg.sender);
      recoveryCoolDowns[attackedUser] = timestamp + recoveryCoolDownTime;
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
    require(latestClaim[_user] > 0, "User isn't a player");
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
    require(_shares <= sponsorshipShares[_receiver], "Redeeming more than allowed");

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

  /**
   * Claim the token owned by the player.
   */
  function claimTokens() external {
    _claimTokens(msg.sender);
  }

  /* ========== PRIVATE FUNCTIONS ========== */

  /**
   * Removes a certain amount of tokens owned by an attacked user and
   * redistributes them to the attacker.
   * @dev no check will be performed on the addresses, but they should both belong to players.
   * @param _attacked The user to slash.
   * @param _attacker The user that will receive the funds.
   */
  function slash(address _attacked, address _attacker) private {
    // if the attacked had recently attacked, the slashing is 2x
    uint256 slashingPercentageAdjusted = attackCoolDowns[_attacked] > block.timestamp
      ? slashingPercentage * 2
      : slashingPercentage;

    uint256 slashedBalance = (_balances[_attacked] * slashingPercentageAdjusted) / 100;
    uint256 slashedSponsorships = (sponsorships[_attacked] * slashingPercentageAdjusted) / 100;
    uint256 totalSlashed = slashedBalance + slashedSponsorships;
    uint256 slashingTaxAmount = (totalSlashed * slashingTax) / 100;
    uint256 totalSlashedWithoutTaxes = totalSlashed - slashingTaxAmount;

    // transfer whole value to owner
    address _owner = owner();
    unchecked {
      _balances[_attacked] -= slashedBalance;
      sponsorships[_attacked] -= slashedSponsorships;
      _balances[_owner] += totalSlashed;
    }

    // calculate how much of the slashed amount should go to their balance
    // and how much to their sponsors
    uint256 attackerBalance = _balances[_attacker];
    uint256 receiverBalanceRatio = (attackerBalance * 100) /
      (attackerBalance + sponsorships[_attacker]);
    uint256 addedToBalance = (totalSlashedWithoutTaxes * receiverBalanceRatio) / 100;
    uint256 addedToSponsorships = (totalSlashedWithoutTaxes * (100 - receiverBalanceRatio)) / 100;
    unchecked {
      _balances[_owner] -= totalSlashedWithoutTaxes;
      _balances[_attacker] += addedToBalance;
      sponsorships[_attacker] += addedToSponsorships;
    }

    // emit event
    emit Slashed(
      _attacker,
      _attacked,
      slashedBalance,
      slashedSponsorships,
      slashingTaxAmount,
      addedToBalance,
      addedToSponsorships
    );
  }

  /**
   * Claim the token owned by the specified user.
   */
  function _claimTokens(address _user) private {
    uint256 _amount = claimable(_user);
    latestClaim[_user] = block.timestamp;
    _mint(_user, _amount);
  }
}
