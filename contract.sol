
//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {
    SafeMathUpgradeable
} from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {
    AddressUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {LazyMint} from "./LazyMint.sol";

// This is the main building block for smart contracts.
contract NFT1155ContentAddressedLazyMint is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    using LazyMint for LazyMint.LazyMintStorage;

    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    /*=========== EIP-712 types ============*/

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    LazyMint.LazyMintStorage private _lazyMint;

    //keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /*======================================*/

    // Mapping from token ID to minted state
    mapping(uint256 => bool) private _isMinted;
