// SPDX-License-Identifier : MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract NftMarketplace is ReentrancyGuard {

    struct Listing {
    uint256 price;
    address seller;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

     event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    mapping(address=>mapping(uint256=>Listing)) private s_listings;
    mapping(address=>uint256) private s_proceeds;

    modifier notListed(address nftAddress,uint256 tokenId,address owner){
        Listing memory listing= s_listings[nftAddress][tokenId];
        require(listing.price==0);
        _;
    }

    modifier isOwner(address nftAddress,uint256 tokenId, address spender){
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);

        require(owner==spender);
        _;

    }


    function ListItem(address nftAddress, uint256 tokenId, uint256 price) external notListed(nftAddress, tokenId,msg.sender) isOwner(nftAddress,tokenId,msg.sender){

        require(price>0);
//        IERC721 nft = IERC721(nftAddress);

        s_listings[nftAddress][tokenId]=Listing(price,msg.sender);

        emit ItemListed(msg.sender,nftAddress,tokenId,price);
    }

    function CancelListing(address nftAddress, uint256 tokenId) external isOwner(nftAddress,tokenId,msg.sender){

        delete(s_listings[nftAddress][tokenId]);
    }


    // The BuyItem() is externally callable, accepts payments, and protects against re-entrancy.
    // The payment received is not less than the listing’s price.
    // The payment received is added to the seller’s proceeds.
    // The listing is deleted after the exchange of value.
    // The token is actually transferred to the buyer.
    // The right event is emitted.

    function buyItem(address nftAddress, uint256 tokenId) external payable nonReentrant{

        require(msg.value>=s_listings[nftAddress][tokenId].price);

        s_proceeds[s_listings[nftAddress][tokenId].seller]+=msg.value;
        delete(s_listings[nftAddress][tokenId]);

        IERC721(nftAddress).safeTransferFrom(s_listings[nftAddress][tokenId].seller, msg.sender, tokenId);
        emit ItemBought(msg.sender, nftAddress, tokenId, s_listings[nftAddress][tokenId].price);

    }


    // Checking that the item is already listed and the caller owns the token.
    // Checking that the new price is not zero.
    // Guarding against re-entrancy. 
    // Updating the s_listing state mapping so that the correct Listing data object now refers to the updated price.
    // Emitting the right event. 

    function updateListing(address nftAddress, uint256 tokenId,uint newPrice) external isOwner(nftAddress,tokenId,msg.sender){

        require(newPrice>0);
        s_listings[nftAddress][tokenId]=Listing(newPrice,msg.sender);
    }

    function withdrawProceeds(address nftAddress, uint256 tokenId) external isOwner(nftAddress,tokenId,msg.sender){
       // delete(s_listings[nftAddress][tokenId]);
       uint256 proceeds = s_proceeds[msg.sender];
       require(proceeds>0);

       s_proceeds[msg.sender]=0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        require(success,"Transfer Failed");
    }

    function getListing(address nftAddress,uint256 tokenURI) external view returns(Listing memory){
        return s_listings[nftAddress][tokenURI];
    }
    function getProceeding(address seller) external view returns(uint256){
        return s_proceeds[seller];
    }

}