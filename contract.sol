
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

    // The EIP-712 Domain separator for this contract
    // solhint-disable-next-line private-vars-leading-underscore, var-name-mixedcase
    bytes32 private DOMAIN_SEPARATOR;

    // The name of this contract
    string private _name;

    // The IPFS gateway to use see {uri}
    string private _ipfsGatewayURIPrefix;

    //when we call functions on _thisAsOperator we can change msg.sender to be this contract, making sure isApprovedForAll passes when transfering tokens
    //see {ERC1155Upgradeable-safeTransferFrom}
    NFT1155ContentAddressedLazyMint private _thisAsOperator;

    address public childChainManagerAddress;

    function initialize(
        string memory name,
        string memory version,
        string memory ipfsGatewayURIPrefix,
         address _childChainManagerAddress
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        ERC1155Upgradeable.__ERC1155_init("");
        AccessControlUpgradeable.__AccessControl_init();

        _ipfsGatewayURIPrefix = ipfsGatewayURIPrefix;

        uint256 chainId;

        // solhint-disable-next-line
        assembly {
            chainId := chainid()
        }

        _name = name;

        DOMAIN_SEPARATOR = _hash(
            EIP712Domain({
                name: _name,
                version: version,
                chainId: chainId,
                verifyingContract: address(this)
            })
        );

        _thisAsOperator = NFT1155ContentAddressedLazyMint(address(this));

        childChainManagerAddress = _childChainManagerAddress;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev we override isApprovedForAll to return true if the operator is this contract
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        if (operator == address(this)) {
            return true;
        }

        return ERC1155Upgradeable.isApprovedForAll(account, operator);
    }



    /*============================ MATIC functions ================================*/

    /**
     * @notice called when tokens are deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required tokens for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded ids array and amounts array
     */
    function deposit(address user, bytes calldata depositData)
        external
        // onlyRole(DEPOSITOR_ROLE)
    {
        require(_msgSender() == childChainManagerAddress, "ChildMintableERC1155 : only child chain manager can deposit");

        (uint256[] memory ids, uint256[] memory amounts, bytes memory data) =
            abi.decode(depositData, (uint256[], uint256[], bytes));

        require(
            user != address(0),
            "ChildMintableERC1155: INVALID_DEPOSIT_USER"
        );

        _mintBatch(user, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _isMinted[ids[i]] = true;
        }
    }

    /**
     * @notice called when user wants to withdraw single token back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param id id to withdraw
     * @param amount amount to withdraw
     */
    function withdrawSingle(uint256 id, uint256 amount) external {
        _burn(_msgSender(), id, amount);
    }

    /**
     * @notice called when user wants to batch withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param ids ids to withdraw
     * @param amounts amounts to withdraw
     */