// SPDX-License-Identifier : MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract NftMarketplace is ReentrancyGuard {

    //bool isETHsale;
    //address private saleTokenAddress;
    //IERC20 salesToken;


    /* constructor(bool _isETHsale, address _saleTokenAddress){

        isETHsale=_isETHsale;
       // saleTokenAddress=_saleTokenAddress;
        salesToken = IERC20(_saleTokenAddress);
    }
        */

    //salesToken = IERC20(saleTokenAddress);




    //modifiers list

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
    
    modifier isAuctionable(address nftAddress,uint256 tokenId,address caller){
        require(sale_type[nftAddress][tokenId]==true);
        IERC721 nft =IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);

        require(owner==caller);
        _;
    }

    modifier onlyFactory(address nftAddress,uint256 tokenId){
        require(msg.sender==s_listings[nftAddress][tokenId].factory);
        _;
    }

    modifier onlyAfterStart(address nftAddress,uint256 tokenId){
        require(a_listing[nftAddress][tokenId].startBlock>block.number);
        _;
    }

    modifier onlyBeforeEnd(address nftAddress,uint256 tokenId){
        require(a_listing[nftAddress][tokenId].endBlock<block.number);
        _;
    }


        struct Listing {
        uint256 price;
        address seller;
        bool _isETHsale;
        address _saleTokenAddress;
        address factory;
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
        mapping(address=>mapping(uint256=>bool)) public sale_type;

        
// #####  Listing the item on the marketplace


        function ListItem(address nftAddress, uint256 tokenId, uint256 price, bool auction, bool _isEthSale, address _saleTokenAddress,address _factory) external notListed(nftAddress, tokenId,msg.sender) isOwner(nftAddress,tokenId,msg.sender){

            require(msg.sender==_factory);
            require(price>0);
    //        IERC721 nft = IERC721(nftAddress);

            s_listings[nftAddress][tokenId]=Listing(price,msg.sender,_isEthSale,_saleTokenAddress,_factory);
            sale_type[nftAddress][tokenId]=auction;

            emit ItemListed(msg.sender,nftAddress,tokenId,price);
        }

        function CancelListing(address nftAddress, uint256 tokenId) external onlyFactory(nftAddress,tokenId){

            delete(s_listings[nftAddress][tokenId]);
            delete(sale_type[nftAddress][tokenId]);
        }

        // if one wishes to change direct sale to auctions and vice versa
        //bool data type in struct set by user to decide if the nft goes on direct sale or auction

        function ChangeSaleType(address nftAddress, uint256 tokenId, bool auction) external onlyFactory(nftAddress,tokenId){

            sale_type[nftAddress][tokenId]=auction;

        }


        function buyItemWithEth(address nftAddress, uint256 tokenId) external payable nonReentrant{

            require(s_listings[nftAddress][tokenId]._isETHsale==true,"ETH sale should be the token");
            require(msg.value>=s_listings[nftAddress][tokenId].price);

            s_proceeds[s_listings[nftAddress][tokenId].seller]+=msg.value;
            delete(s_listings[nftAddress][tokenId]);

            IERC721(nftAddress).safeTransferFrom(s_listings[nftAddress][tokenId].seller, msg.sender, tokenId);
            emit ItemBought(msg.sender, nftAddress, tokenId, s_listings[nftAddress][tokenId].price);

        }

        function buyItemWithToken(address nftAddress, uint256 tokenId) external payable{
            require(s_listings[nftAddress][tokenId]._isETHsale==false);
            s_proceeds[s_listings[nftAddress][tokenId].seller]+=msg.value;
            delete(s_listings[nftAddress][tokenId]);

            IERC20 salesToken;
            salesToken = IERC20(s_listings[nftAddress][tokenId]._saleTokenAddress);

            salesToken.transferFrom(msg.sender,s_listings[nftAddress][tokenId].seller,s_listings[nftAddress][tokenId].price);
            IERC721(nftAddress).safeTransferFrom(s_listings[nftAddress][tokenId].seller, msg.sender, tokenId);

        }


        // Checking that the item is already listed and the caller owns the token.
        // Checking that the new price is not zero.

        function updateListing(address nftAddress, uint256 tokenId,uint newPrice) external onlyFactory(nftAddress,tokenId){

            require(newPrice>0);
            s_listings[nftAddress][tokenId].price=newPrice;
        }



        function withdrawProceeds(address nftAddress, uint256 tokenId) external onlyFactory(nftAddress,tokenId){
        // delete(s_listings[nftAddress][tokenId]);
        uint256 proceeds = s_proceeds[msg.sender];
        require(proceeds>0);

        s_proceeds[msg.sender]=0;
            (bool success, ) = payable(msg.sender).call{value: proceeds}("");
            require(success,"Transfer Failed");
        }

        //get listings and proceedings

        function getListing(address nftAddress,uint256 tokenURI) external view returns(Listing memory){
            return s_listings[nftAddress][tokenURI];
        }
        function getProceeding(address seller) external view returns(uint256){
            return s_proceeds[seller];
        }



        // ************AUCTION*************AUCTION***************** //

        struct nftForAuction{
            address seller;
            uint256 startBlock;
            uint256 endBlock;
            uint256 currentPrice;
            address highest_bidder;
            bool start;
            bool _isETHsale;
            address _saleTokenAddress;
            address factory;
            uint256 unique;
        }

        mapping(address=>mapping(uint256=>nftForAuction)) a_listing;
       // mapping(address=>uint256) balance;



        //uint256 private salesStartBlock;
        //uint256 private salesEndBlock;

        uint256 _unique;   // a unique token id for each nft, helps in getting the balance of each user for different nfts 
        mapping(uint256=>mapping(address=>uint256)) _balance;   


        //Participate in auction!!

        function setAuction(address nftAddress, uint256 tokenId, uint256 _salesStartBlock, uint256 _salesEndBlock, uint256 startPrice, bool _isEthSale, address _saleTokenAddress, address _factory) external isAuctionable(nftAddress,tokenId,msg.sender){

            require(_salesEndBlock>_salesStartBlock);
            require(_salesStartBlock>block.number);

            //mapping(address=>uint256) _balance;

            nftForAuction memory nft = nftForAuction(msg.sender,_salesStartBlock,_salesEndBlock,startPrice,address(0),true,_isEthSale,_saleTokenAddress,_factory,_unique);

            _unique++;

            a_listing[nftAddress][tokenId]=nft;

        }



        function withdrawFromAuction(address nftAddress,uint256 tokenId) external onlyFactory(nftAddress,tokenId){

            require(msg.sender!=a_listing[nftAddress][tokenId].highest_bidder);
            
            uint256 x=a_listing[nftAddress][tokenId].unique;  // x represents unique nft number, subs for token id
            uint256 amt = _balance[x][msg.sender];

            _balance[x][msg.sender]=0;

            payable(msg.sender).transfer(amt);

        }


        //place a bid in the auctions
        //update in the listings

        function bid(address nftAddress,uint256 tokenId,uint256 amount) external payable onlyAfterStart(nftAddress,tokenId) onlyBeforeEnd(nftAddress,tokenId){
            
            uint256 x=a_listing[nftAddress][tokenId].unique;
            uint256 newBid= _balance[x][msg.sender]+amount;

            require(newBid>a_listing[nftAddress][tokenId].currentPrice);

            _balance[x][msg.sender]=newBid;

            a_listing[nftAddress][tokenId].currentPrice=newBid;
            a_listing[nftAddress][tokenId].highest_bidder=msg.sender;

        }

        //tranfer nft ownership after the end of the time for each nft

        function resolve(address nftAddress,uint256 tokenId) external onlyFactory(nftAddress,tokenId){

            require(block.number>a_listing[nftAddress][tokenId].endBlock);

            IERC721(nftAddress).safeTransferFrom(a_listing[nftAddress][tokenId].seller,a_listing[nftAddress][tokenId].highest_bidder,tokenId);

            if(a_listing[nftAddress][tokenId]._isETHsale==false){

                IERC20 salesToken;
                salesToken = IERC20(a_listing[nftAddress][tokenId]._saleTokenAddress);

                salesToken.transferFrom(msg.sender,a_listing[nftAddress][tokenId].seller,a_listing[nftAddress][tokenId].currentPrice);

            }

        }



    }
