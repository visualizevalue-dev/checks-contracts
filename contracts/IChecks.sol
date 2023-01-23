// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IChecks {

    struct Check {
        uint32 seed;          // The seed is based the mint and enables pseudo-randomisation
        uint16[7] composite; // The tokenIds that were composited into this one
        uint8 divisorIndex; // Easy access to next / previous divisor
        uint8 checksCount; // How many checks this token has
        uint8 colorBand;  // 100%, 50%, 25%, 12.5%, 6.25%, 5%, 1.25%
        uint8 gradient;  // Whether to omit randomisation and just go through the gradient
        uint8 speed;    // Animation speed
    }

    struct Checks {
        uint32 minted;
        uint32 burned;
        mapping(uint256 => Check) all;
    }

    event Composite(
        uint256 indexed tokenId,
        uint256 indexed burnedId,
        uint8 indexed checks
    );

    event Infinity(
        uint256 indexed tokenId,
        uint256[] indexed burnedIds
    );

}
