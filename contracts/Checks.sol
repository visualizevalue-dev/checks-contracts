// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IChecks.sol";
import "./interfaces/IChecksEdition.sol";
import "./libraries/ChecksArt.sol";
import "./libraries/ChecksMetadata.sol";
import "./libraries/Utilities.sol";
import "./standards/CHECKS721.sol";

/**
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓  ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓          ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓                      ✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓                        ✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓                ✓✓       ✓✓✓✓✓✓✓
✓✓✓✓✓                 ✓✓✓          ✓✓✓✓✓
✓✓✓✓                 ✓✓✓            ✓✓✓✓
✓✓✓✓✓          ✓✓  ✓✓✓             ✓✓✓✓✓
✓✓✓✓✓✓✓          ✓✓✓             ✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓                        ✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓                      ✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓          ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓  ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓
@title  Checks
@author VisualizeValue
@notice This artwork is notable.
*/
contract Checks is IChecks, CHECKS721 {

    /// @notice The VV Checks Edition contract.
    IChecksEdition public editionChecks;

    /// @dev We use this database for persistent storage.
    Checks checks;

    /// @dev Initializes the Checks Originals contract and links the Edition contract.
    constructor(address _checksEdition) {
        editionChecks = IChecksEdition(_checksEdition/*0x34eEBEE6942d8Def3c125458D1a86e0A897fd6f9*/);
        checks.day0 = uint32(block.timestamp);
        checks.epoch = 1;
    }

    /// @dev Based on MouseDev's commit-reveal scheme.
    function advanceEpoch() public {
        IChecks.Epoch storage currentEpoch = checks.epochs[checks.epoch];

        if (
            // If epoch has not been commited,
            currentEpoch.commited == false ||
            // Or the reveal commitment timed out.
            (currentEpoch.revealed == false && currentEpoch.revealBlock < block.number - 256)
        ) {
            // This means the epoch has not been commited, OR the epoch was commited but has expired.
            // Set commited to true, and record the reveal block.
            currentEpoch.revealBlock = uint64(block.number + 5);
            currentEpoch.commited = true;

        } else if (block.number > currentEpoch.revealBlock) {
            // Epoch has been commited and is within range to be revealed.
            // Set its randomness to the target block
            currentEpoch.randomness = uint128(uint256(blockhash(currentEpoch.revealBlock)) % (2 ** 128 - 1));
            currentEpoch.revealed = true;

            checks.epoch++;

            return advanceEpoch();
        }
    }

    /// @notice Migrate Checks Editions to Checks Originals by burning the Editions.
    ///         Requires the Approval of this contract on the Edition contract.
    /// @param tokenIds The Edition token IDs you want to migrate.
    /// @param recipient The address to receive the tokens.
    function mint(uint256[] calldata tokenIds, address recipient) external {
        uint256 count = tokenIds.length;

        // Initialize new epoch / resolve previous epoch.
        advanceEpoch();

        // Burn the Editions for the given tokenIds & mint the Originals.
        for (uint256 i; i < count;) {
            uint256 id = tokenIds[i];
            address owner = editionChecks.ownerOf(id);

            // Check whether we're allowed to migrate this Edition.
            if (
                owner != msg.sender &&
                (! editionChecks.isApprovedForAll(owner, msg.sender)) &&
                editionChecks.getApproved(id) != msg.sender
            ) { revert NotAllowed(); }

            // Burn the Edition.
            editionChecks.burn(id);

            // Initialize our Check.
            StoredCheck storage check = checks.all[id];
            check.day = Utilities.day(checks.day0, block.timestamp);
            check.epoch = uint32(checks.epoch);
            check.divisorIndex = 0;

            // Mint the original.
            // If we're minting to a vault, transfer it there.
            if (msg.sender != recipient) {
                _safeMintVia(recipient, msg.sender, id);
            } else {
                _safeMint(msg.sender, id);
            }

            unchecked { ++i; }
        }

        // Keep track of how many checks have been minted.
        unchecked { checks.minted += uint32(count); }
    }

    /// @notice Get a specific check with its genome settings.
    /// @param tokenId The token ID to fetch.
    function getCheck(uint256 tokenId) external view returns (Check memory check) {
        _requireMinted(tokenId);

        return ChecksArt.getCheck(tokenId, checks);
    }

    /// @notice Sacrifice a token to transfer its visual representation to another token.
    /// @param tokenId The token ID transfer the art into.
    /// @param burnId The token ID to sacrifice.
    function inItForTheArt(uint256 tokenId, uint256 burnId) external {
        _sacrifice(tokenId, burnId);

        unchecked { ++checks.burned; }
    }

    /// @notice Sacrifice multiple tokens to transfer their visual to other tokens.
    /// @param tokenIds The token IDs to transfer the art into.
    /// @param burnIds The token IDs to sacrifice.
    function inItForTheArts(uint256[] calldata tokenIds, uint256[] calldata burnIds) external {
        uint256 pairs = _multiTokenOperation(tokenIds, burnIds);

        for (uint256 i; i < pairs;) {
            _sacrifice(tokenIds[i], burnIds[i]);

            unchecked { ++i; }
        }

        unchecked { checks.burned += uint32(pairs); }
    }

    /// @notice Composite one token into another. This mixes the visual and reduces the number of checks.
    /// @param tokenId The token ID to keep alive. Its visual will change.
    /// @param burnId The token ID to composite into the tokenId.
    function composite(uint256 tokenId, uint256 burnId) external {
        _composite(tokenId, burnId);

        unchecked { ++checks.burned; }
    }

    /// @notice Composite multiple tokens. This mixes the visuals and checks in remaining tokens.
    /// @param tokenIds The token IDs to keep alive. Their art will change.
    /// @param burnIds The token IDs to composite.
    function compositeMany(uint256[] calldata tokenIds, uint256[] calldata burnIds) external {
        uint256 pairs = _multiTokenOperation(tokenIds, burnIds);

        for (uint256 i; i < pairs;) {
            _composite(tokenIds[i], burnIds[i]);

            unchecked { ++i; }
        }

        unchecked { checks.burned += uint32(pairs); }
    }

    /// @notice Sacrifice 64 single-check tokens to form a black check.
    /// @param tokenIds The token IDs to burn for the black check.
    /// @dev The check at index 0 survives.
    function infinity(uint256[] calldata tokenIds) external {
        uint256 count = tokenIds.length;
        if(count != 64) {
            revert InvalidTokenCount();
        }
        for (uint256 i; i < count;) {
            uint256 id = tokenIds[i];
            if (checks.all[id].divisorIndex != 6 || ! _isApprovedOrOwner(msg.sender, id)) {
                revert BlackCheck__InvalidCheck();
            }
            if (!_isApprovedOrOwner(msg.sender, id)) {
                revert NotAllowed();
            }

            unchecked { ++i; }
        }

        // Complete final composite.
        uint256 blackCheckId = tokenIds[0];
        StoredCheck storage check = checks.all[blackCheckId];
        check.day = Utilities.day(checks.day0, block.timestamp);
        check.divisorIndex = 7;

        // Burn all 63 other Checks.
        for (uint i = 1; i < count;) {
            _burn(tokenIds[i]);

            unchecked { ++i; }
        }
        unchecked { checks.burned += 63; }

        // When one is released from the prison of self, that is indeed freedom.
        // For the most great prison is the prison of self.
        emit Infinity(blackCheckId, tokenIds[1:]);
        emit MetadataUpdate(blackCheckId);
    }

    /// @notice Burn a check. Note: This burn does not composite or swap tokens.
    /// @param tokenId The token ID to burn.
    /// @dev A common purpose burn method.
    function burn(uint256 tokenId) external {
        if (! _isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotAllowed();
        }

        // Perform the burn.
        _burn(tokenId);

        // Keep track of supply.
        unchecked { ++checks.burned; }
    }

    /// @notice Get the colors of all checks in a given token.
    /// @param tokenId The token ID to get colors for.
    /// @dev Consider using the ChecksArt and EightyColors Libraries
    ///      in combination with the getCheck function to resolve this yourself.
    function colors(uint256 tokenId) external view returns (string[] memory, uint256[] memory)
    {
        return ChecksArt.colors(ChecksArt.getCheck(tokenId, checks), checks);
    }

    /// @notice Render the SVG for a given token.
    /// @param tokenId The token to render.
    /// @dev Consider using the ChecksArt Library directly.
    function svg(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);

        return string(ChecksArt.generateSVG(tokenId, checks));
    }

    /// @notice Get the metadata for a given token.
    /// @param tokenId The token to render.
    /// @dev Consider using the ChecksMetadata Library directly.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        return ChecksMetadata.tokenURI(tokenId, checks);
    }

    /// @notice Returns how many tokens this contract currently manages.
    function totalSupply() public view returns (uint256) {
        return checks.minted - checks.burned;
    }

    /// @dev Sacrifice one token to transfer its art to another.
    /// @param tokenId The token ID to keep.
    /// @param burnId The token ID to burn.
    function _sacrifice(uint256 tokenId, uint256 burnId) internal {
        (,StoredCheck storage toBurn,) = _tokenOperation(tokenId, burnId);

        // Copy over static genome settings
        checks.all[tokenId] = toBurn;

        // Update the birth date for this token.
        checks.all[tokenId].day = Utilities.day(checks.day0, block.timestamp);

        // Perform the burn.
        _burn(burnId);

        // Notify DAPPs about the Sacrifice.
        emit IChecks.Sacrifice(burnId, tokenId);
        emit MetadataUpdate(tokenId);
    }

    /// @dev Composite one token into to another and burn it.
    /// @param tokenId The token ID to keep. Its art and check-count will change.
    /// @param burnId The token ID to burn in the process.
    function _composite(uint256 tokenId, uint256 burnId) internal {
        (
            StoredCheck storage toKeep,
            StoredCheck storage toBurn,
            uint256 divisorIndex
        ) = _tokenOperation(tokenId, burnId);

        // Composite our check
        toKeep.day = Utilities.day(checks.day0, block.timestamp);
        toKeep.composites[divisorIndex] = uint16(burnId);
        toKeep.divisorIndex += 1;

        if (toKeep.divisorIndex < 6) {
            // Need a randomizer for gene manipulation.
            // uint256 randomizer = Utilities.seed(checks.burned);
            uint256 randomizer = uint256(keccak256(abi.encodePacked(
                // keccak256(abi.encodePacked(Randomizer.seedForEpoch(toKeep.epoch), tokenId)),
                toKeep.divisorIndex,
                "composite-divisor"
            )));

            // We take the smallest gradient in 20% of cases, or continue as random checks.
            toKeep.gradients[toKeep.divisorIndex - 1] = Utilities.random(randomizer, 100) > 80
                ? Utilities.minGt0(toKeep.gradients[divisorIndex], toBurn.gradients[divisorIndex])
                : Utilities.min(toKeep.gradients[divisorIndex], toBurn.gradients[divisorIndex]);

            // We breed the lower end average color band when breeding.
            toKeep.colorBands[toKeep.divisorIndex - 1] = Utilities.avg(
                toKeep.colorBands[divisorIndex],
                toBurn.colorBands[divisorIndex]
            );

            // TODO: Figure out animation breeding
            // // Coin-toss keep either one or the other animation setting.
            // toKeep.animation = (randomizer % 2 == 1) ? toKeep.animation : toBurn.animation;
        }

        // Perform the burn.
        _burn(burnId);

        // Notify DAPPs about the Composite.
        emit IChecks.Composite(tokenId, burnId, ChecksArt.DIVISORS()[toKeep.divisorIndex]);
        emit MetadataUpdate(tokenId);
    }

    /// @dev Make sure this is a valid request to composite/switch with multiple tokens.
    /// @param tokenIds The token IDs to keep.
    /// @param burnIds The token IDs to burn.
    function _multiTokenOperation(uint256[] calldata tokenIds, uint256[] calldata burnIds)
        internal pure returns (uint256 pairs)
    {
        pairs = tokenIds.length;
        if (pairs != burnIds.length) {
            revert InvalidTokenCount();
        }
    }

    /// @dev Make sure this is a valid request to composite/switch a token pair.
    /// @param tokenId The token ID to keep.
    /// @param burnId The token ID to burn.
    function _tokenOperation(uint256 tokenId, uint256 burnId)
        internal view returns (
            StoredCheck storage toKeep,
            StoredCheck storage toBurn,
            uint8 divisorIndex
        )
    {
        toKeep = checks.all[tokenId];
        toBurn = checks.all[burnId];
        divisorIndex = toKeep.divisorIndex;

        if (
            ! _isApprovedOrOwner(msg.sender, tokenId) ||
            ! _isApprovedOrOwner(msg.sender, burnId) ||
            divisorIndex != toBurn.divisorIndex ||
            tokenId == burnId ||
            divisorIndex > 5
        ) {
            revert NotAllowed();
        }
    }

    /// @dev Get the index for a token gradient based on a number between 1 and 100.
    /// @param input The pseudorandom input to base the index on.
    function _gradient(uint256 input) internal pure returns(uint8) {
        return input > 10 ? 0
             : uint8(1 + (input % 6));
    }

    /// @dev Get the index for a token color band based on a number between 1 and 160.
    /// @param input The pseudorandom input to base the index on.
    function _band(uint256 input) internal pure returns(uint8) {
        return input > 80 ? 0
             : input > 40 ? 1
             : input > 20 ? 2
             : input > 10 ? 3
             : input >  8 ? 4
             : input >  2 ? 5
             : 6;
    }
}
