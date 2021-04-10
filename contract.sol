
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
