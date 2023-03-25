//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

/**
 * @dev Contract used to easily track Sponsorship certificate beneficiaries, by replicating the
 * mechanism that keeps track of NFT owners.
 */
abstract contract CertificateTargetEnumerable {

    // The amount of tokens associated to an address
    mapping(address => uint256) private _nrTokens;
    // Mapping from address to list of linked token IDs
    mapping(address => mapping(uint256 => uint256)) private _linkedTokens;
    // Mapping from token ID to index of the address tokens list
    mapping(uint256 => uint256) private _linkedTokensIndex;

    /**
     * @dev get the number of linked tokens.
     * @param _user address that will be checked
     */
    function linkedTokens(address _user) public view returns (uint256) {
        return _nrTokens[_user];
    }

    /**
     * @dev get the token ID, linked to _user, at the specified _index.
     * @param _user address representing the address linked to the given token ID
     * @param _index index of the token linked to the given address
     */
    function linkedTokenByIndex(address _user, uint256 _index) public view returns (uint256) {
        require(_index < _nrTokens[_user], "linked token out of bounds");
        return _linkedTokens[_user][_index];
    }

    /**
     * @dev Internal function to link a token to an address.
     * @param _user address representing the address linked to the given token ID
     * @param _tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function linkTokenToAddress(address _user, uint256 _tokenId) internal {
        uint256 _length = _nrTokens[_user];
        _linkedTokens[_user][_length] = _tokenId;
        _linkedTokensIndex[_tokenId] = _length;
        _nrTokens[_user] = _length + 1;
    }

    /**
     * @dev Internal function to remove a token from this extension's linking-tracking data structures.
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param _user address representing the user linked to the given token ID
     * @param _tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function unlinkTokenFromAddress(address _user, uint256 _tokenId) internal {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 _lastTokenIndex = _nrTokens[_user] - 1;
        uint256 tokenIndex = _linkedTokensIndex[_tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != _lastTokenIndex) {
            uint256 lastTokenId = _linkedTokens[_user][_lastTokenIndex];

            _linkedTokens[_user][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _linkedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _linkedTokensIndex[_tokenId];
        delete _linkedTokens[_user][_lastTokenIndex];
        _nrTokens[_user] = _lastTokenIndex;
    }
}
