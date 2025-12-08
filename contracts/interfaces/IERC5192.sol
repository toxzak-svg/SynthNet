// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/**
 * @title IERC5192 - Minimal Soulbound NFTs
 * @notice Interface for Soulbound Tokens (SBTs) - non-transferable NFTs
 * @dev See https://eips.ethereum.org/EIPS/eip-5192
 *      Interface ID: 0xb45a3c0e
 */
interface IERC5192 {
    /**
     * @notice Emitted when the locking status is changed to locked
     * @dev If a token is minted and the status is locked, this event should be emitted
     * @param tokenId The identifier for a token
     */
    event Locked(uint256 tokenId);

    /**
     * @notice Emitted when the locking status is changed to unlocked
     * @dev If a token is minted and the status is unlocked, this event should be emitted
     * @param tokenId The identifier for a token
     */
    event Unlocked(uint256 tokenId);

    /**
     * @notice Returns the locking status of a Soulbound Token
     * @dev SBTs assigned to zero address are considered invalid, and queries
     *      about them do throw
     * @param tokenId The identifier for a token
     * @return bool True if the token is locked (non-transferable), false otherwise
     */
    function locked(uint256 tokenId) external view returns (bool);
}
