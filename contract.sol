
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
    function withdrawBatch(uint256[] calldata ids, uint256[] calldata amounts)
        external
    {
        _burnBatch(_msgSender(), ids, amounts);
    }

    /*========================================================================================*/


    /*============================ EIP-712 encoding functions ================================*/

    /**
     * @dev see https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
     */
    function _hash(EIP712Domain memory eip712Domain)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    /*========================================================================================*/

    /**
     * @notice revoke all MintPermits issued for token ID `tokenId` with nonce lower than `accountTransactionCount`
     * @param tokenId the token ID for which to revoke permits
     * @param accountTransactionCount IMPORTANT:  the current account transaction count should be passed
     */
    function revokeMintPermitsUnderNonce(
        uint256 tokenId,
        uint256 accountTransactionCount
    ) external {
        _lazyMint.revokeMintPermitsUnderNonce(tokenId, accountTransactionCount);
    }

    /**
     * @notice revoke a MintPermitForAddress
     * @param permit the MintPermitForAddress to revoke
     */
    function revokeMintPermitForAddress(
        LazyMint.MintPermitForAddress calldata permit
    ) public {
        _lazyMint.revokeMintPermitForAddress(permit, DOMAIN_SEPARATOR);
    }

    /**
     * @notice Check if a NFT has been minted
     */
    function isMinted(uint256 tokenId) external view returns (bool minted) {
        return _isMinted[tokenId];
    }

    /**
     * @notice Call this function to buy a not yet minted NFT
     * @param permit The MintPermit signed by the NFT creator
     * @param recipient The address that will receive the newly minted NFT
     * @param v The v portion of the secp256k1 permit signature
     * @param r The r portion of the secp256k1 permit signature
     * @param s The s portion of the secp256k1 permit signature
     */
    function buyAndMint(
        LazyMint.MintPermit calldata permit,
        address recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        require(
            msg.sender != address(0),
            "ERC1155: transfer to the zero address"
        );
        require(!_isMinted[permit.tokenId], "lazy-mint/already-minted");

        require(
            msg.value >= permit.minimumPrice,
            "lazy-mint/buy-and-mint-under-minimum-price"
        );

        address signer =
            _lazyMint.requireValidMintPermit(permit, DOMAIN_SEPARATOR, v, r, s);

        payable(signer).transfer(msg.value);

        address from = signer;

        uint256 tokenId = permit.tokenId;

        _mint(signer, tokenId, 1, "");
        _thisAsOperator.safeTransferFrom(from, recipient, tokenId, 1, "");
    }

    /**
     * @notice Call this function to buy a not yet minted NFT with a permit addressed to yourself
     * @param permit The MintPermitForAddress signed by the NFT creator
     * @param v The v portion of the secp256k1 permit signature
     * @param r The r portion of the secp256k1 permit signature
     * @param s The s portion of the secp256k1 permit signature
     */
    function buyAndMintForAddress(
        LazyMint.MintPermitForAddress calldata permit,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        require(
            msg.sender != address(0),
            "ERC1155: transfer to the zero address"
        );
        require(!_isMinted[permit.tokenId], "lazy-mint/already-minted");

        require(
            msg.value >= permit.minimumPrice,
            "lazy-mint/buy-and-mint-under-minimum-price"
        );

        require(
            msg.sender == permit.recipient,
            "lazy-mint/invalid-recipient-for-mint-permit"
        );

        address signer =
            _lazyMint.requireValidMintPermitForAddress(
                permit,
                DOMAIN_SEPARATOR,
                v,
                r,
                s
            );

        payable(signer).transfer(msg.value);

        address from = signer;
        address to = msg.sender;

        uint256 tokenId = permit.tokenId;

        _mint(signer, tokenId, 1, "");
        _thisAsOperator.safeTransferFrom(from, to, tokenId, 1, "");
    }

    /**
     * @notice A creator can call this function to mint an NFT for themselves (no lazy mint)
     * @param tokenId The tokenID to mint needs to adhere to this contract token ID format
     * @dev for the token ID format see "../docs/lazyminting.md" or {computeTokenId}
     */
    function mint(uint256 tokenId) external {
        require(
            LazyMint.tokenIdMatchesCreator(tokenId, msg.sender),
            "lazy-mint/sender-not-in-token-id"
        );
        require(!_isMinted[tokenId], "lazy-mint/already-minted");

        _mint(msg.sender, tokenId, 1, "");
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     */
    function uri(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        /*
         extract the JSON metadata sha1 digest from `tokenId` and convert to hex string
         */
        bytes32 value = bytes32(tokenId >> 96);
        bytes memory alphabet = "0123456789abcdef";

        bytes memory sha1Hex = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            sha1Hex[i * 2] = alphabet[(uint8)(value[i + 12] >> 4)];
            sha1Hex[1 + i * 2] = alphabet[(uint8)(value[i + 12] & 0x0f)];
        }

        //with IPFS we can retrieve a SHA1 hashed file with a CID of the following format : "f01551114{_sha1}"
        //only works if the file has been uploaded with "ipfs add --raw-leaves --hash=sha1 <path>"
        // see {#../docs/lazyminting.md#Notes-on-IPFS-compatibility}
        return
            string(
                abi.encodePacked(_ipfsGatewayURIPrefix, "f01551114", sha1Hex)
            );
    }

    function _mint(
        address account,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) internal override {
        ERC1155Upgradeable._mint(account, tokenId, amount, data);
        _isMinted[tokenId] = true;
    }

    /**
     * @dev thanks to this contract token ID format (see "../docs/lazyminting.md" or {computeTokenId}) a creator can have a balance of 1 on a not-yet-minted NFT
     */
    function balanceOf(address account, uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        if (_isMinted[tokenId]) {
            return ERC1155Upgradeable.balanceOf(account, tokenId);
        }

        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );

        return LazyMint.tokenIdMatchesCreator(tokenId, account) ? 1 : 0;
    }
