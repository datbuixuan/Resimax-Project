// contracts/Marvion.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MarvionToken is ERC721Enumerable, IERC2981, Ownable {   
    enum saleState{PrivateSale, PublicSale}
    saleState public SaleState;
   
    mapping (address => bool) private Admin;
    address[] private AdminAddress;

    mapping (address => bool) public IsWhitelist;
    address[] private WhiteListAddress;

    uint256 private PricePerToken;
    uint256 private MaxSupply;
    bool private IsPaused;

    string private ContractURI;
    string public MetadataURI;
   
    uint256 public MaximumDOTPerWallet;

    address public RoyaltyAddress;
    uint96 public RoyaltyPercentage; // *10
    

    modifier CheckMetadata(){
      require(keccak256(abi.encodePacked(MetadataURI)) != keccak256(abi.encodePacked("")), "The Metadata URI is empty");
        _;
    }

    modifier onlyAdmin(){
        require(Admin[msg.sender], "You are not permission");
        _;
    }

    constructor (string memory name, string memory symbol, uint96 royaltyPercentage, address royaltyAddress,
      uint256 pricePerToken, uint256 maxSupply) ERC721(name, symbol){
        
        require(royaltyAddress != address(0));
        require(royaltyPercentage > 0);

        RoyaltyAddress = royaltyAddress;
        RoyaltyPercentage = royaltyPercentage;
        PricePerToken = pricePerToken;
        MaxSupply = maxSupply;

        AdminAddress.push(msg.sender);
        Admin[msg.sender] = true;

        SaleState = saleState.PrivateSale;

        MaximumDOTPerWallet = 3;
    }
    
    event createItemsEvent(uint256 nftId, string uri, uint256 itemId, address owner, address royaltyAddress, uint96 royaltyPercentage);
    event claimItemEvent(string uri, uint256 itemId, address owner, address royaltyAddress, uint96 royaltyPercentage);
    event payForDOTEvent (address from, uint256 totalPrice);
    event addItemsToWhiteListEvent(address[] walletAddresses);
    event removeItemsOnWhiteListEvent(address [] walletAddresses);
    event addItemsToAdminListEvent(address[] walletAddresses);
    event removeItemsOnAdminListEvent(address [] walletAddresses);
    event changeSaleStatusEvent (saleState saleStatus);
    event changeMaxSupplyEvent (uint256 maxSupply);
    event changePricePerTokenEvent (uint256 pricePerToken);
    event changeMaxItemPerWalletEvent(uint256 maximumItem);
    event withdrawEvent(uint256 totalAmount, address toAddress);        
    event changePausedStatusEvent(bool paused);

    function createItems(uint256[] memory nftId, address owner) public CheckMetadata onlyAdmin{ 
        require(nftId.length > 0, "The input data is incorrect");
        require(IsPaused == false, "Contract is paused for minting");
        require((MaxSupply - totalSupply()) >= nftId.length, "The claim left is unavailable");

        for(uint256 i = 0; i < nftId.length; i++){
            uint256 newItemId = totalSupply();
            _safeMint(owner, newItemId);   
                  
            string memory fTokenURI = string.concat(MetadataURI, Strings.toString(newItemId));
        
            emit createItemsEvent(nftId[i], fTokenURI, newItemId, owner, RoyaltyAddress, RoyaltyPercentage);
       }
    }

    function claim(uint256 quantity) payable public CheckMetadata {
        require (quantity > 0, "The input data is incorrect");       
        require(IsPaused == false, "Contract is paused for minting");
        require ((MaxSupply - totalSupply()) >= quantity, "The claim left is unavailable");
   

        if(SaleState == saleState.PrivateSale){             
            require (IsWhitelist[msg.sender], "You are not permission");
            require((balanceOf(msg.sender) + quantity) <= MaximumDOTPerWallet, "You have minted more than the allowed amount");
            
            _mintAsset(quantity);     

            _payout(quantity);                    
        }
        else if(SaleState == saleState.PublicSale){                  
            _mintAsset(quantity);  
            
            _payout(quantity);                 
        }
    }  

    function withdraw(uint256 totalAmount, address payable toAddress) onlyOwner public {                     
        require(toAddress != address(0), "The input data is incorrect");
        require (totalAmount <= address(this).balance, "Insufficient amount");
       
        (toAddress).transfer(totalAmount);
            
        emit withdrawEvent(totalAmount, toAddress);        
    }
     

    function _payout(uint256 quantity) private {
        uint256 totalPrice = PricePerToken * quantity;
        require(msg.value >= totalPrice, "Insufficient payment amount");
    
        emit payForDOTEvent(msg.sender, totalPrice);
    }


    function _mintAsset(uint256 quantity) private {                     
        for(uint256 i = 0; i < quantity; i++){
            uint256 newItemId = totalSupply();
            _safeMint(msg.sender, newItemId);   
                 
            string memory fTokenURI = string.concat(MetadataURI, Strings.toString(newItemId));
            
            emit claimItemEvent(fTokenURI, newItemId, msg.sender, RoyaltyAddress, RoyaltyPercentage);
        }
    }
   

    function setApprovalForItems(address to, uint256[] memory tokenIds) public{
        require(tokenIds.length > 0, "The input data is incorrect");
        
        for(uint256 i = 0; i < tokenIds.length; i++){
            require(_isApprovedOrOwner(msg.sender, tokenIds[i]), "You are not owner of item");

            _approve(to, tokenIds[i]);
        }
    }

    function transfers(address[] memory froms, address[] memory tos, uint256[] memory tokenIds) public{
        require(froms.length == tos.length, "The input data is incorrect");
        require(tokenIds.length == tos.length, "The input data is incorrect");

        for(uint256 i = 0; i < froms.length; i++){
            require(_isApprovedOrOwner(msg.sender, tokenIds[i]), "You are not owner of item");

            _transfer(froms[i], tos[i], tokenIds[i]);
        }
    }

  
    
    // Get Data
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "No Token ID exists");

        return string.concat(MetadataURI, Strings.toString(tokenId)); 
    }

    function contractURI() public view returns (string memory) {
        return ContractURI;
    }

    function getPricePerToken() public view returns (uint256){
        return PricePerToken;
    }

    function getMaxSupply() public view returns (uint256){
        return MaxSupply;
    }

    function isPaused() public view returns (bool){
        return IsPaused;
    }

    function nWhiteListWallet() public view returns (uint256){
        return WhiteListAddress.length;
    }

    function getWalletOnWhiteList(uint256 index) public view returns (address, bool){
        address wlAddress = WhiteListAddress[index];

        bool isWhiteList = IsWhitelist[wlAddress];
     
        return (wlAddress, isWhiteList);
    }

    function nAdmin() public view returns (uint256){
        return AdminAddress.length;
    }

    function getAdminAddress(uint256 index) public view returns (address){
        address t = AdminAddress[index];
        if(Admin[t])
            return t;
        return address(0);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "No token ID exists");
        return (RoyaltyAddress, (salePrice * RoyaltyPercentage) / 1000);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721Enumerable) returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }



    // setting
    function setContractURI(string memory contractUri) public onlyOwner{
        ContractURI = contractUri;
    }

    function setMetadataURI(string memory metadataUri) public onlyOwner{
        MetadataURI = metadataUri;
    }

    function changeRoyaltyReceiver(address royaltyAddress) onlyOwner public{
        require(royaltyAddress != address(0));
        RoyaltyAddress = royaltyAddress;
    }

    function changeRoyaltyPercentage(uint96 royaltyPercentage) onlyOwner public{
        require(royaltyPercentage > 0);
        RoyaltyPercentage = royaltyPercentage;
    }


    // whitelist
    function addWalletToWhiteList(address[] memory wallets) public onlyAdmin{
        for(uint256 i = 0; i < wallets.length; i++){
            require(!IsWhitelist[wallets[i]], "These Wallets are added");
        
            IsWhitelist[wallets[i]] = true;     

            bool isAdded = false;
            for(uint256 j = 0; j < WhiteListAddress.length; j++){
                if(WhiteListAddress[j] == wallets[i]){
                    isAdded = true;
                    break;
                }
            }

            if(isAdded == false){
                WhiteListAddress.push(wallets[i]);
            }
         }    

        emit addItemsToWhiteListEvent(wallets);
    }

    function removeWalletOnWhiteList(address[] memory wallets) public onlyAdmin{
        for(uint256 i = 0; i < wallets.length; i++){                     
            require(IsWhitelist[wallets[i]], "These Wallets have not added");

            IsWhitelist[wallets[i]] = false;            
         }    

        emit removeItemsOnWhiteListEvent(wallets);
    }
  


    // admin permission
    function addWalletToAdminList(address[] memory wallets) public onlyOwner{
        for(uint256 i = 0; i < wallets.length; i++){            
            require(!Admin[wallets[i]], "These Wallets are added");

            bool isAdded = false;
            for(uint256 j = 0; j < AdminAddress.length; j++){
                if(AdminAddress[j] == wallets[i]){
                    isAdded = true;
                    break;
                }
            }
            if(isAdded == false){
                AdminAddress.push(wallets[i]);
            }
            
            Admin[wallets[i]] = true;
         }    

        emit addItemsToAdminListEvent(wallets);
    }
    
    function removeWalletOnAdminList(address[] memory wallets) public onlyOwner{
        for(uint256 i = 0; i < wallets.length; i++){            
            require(Admin[wallets[i]], "These Wallets have not added");

            Admin[wallets[i]] = false;
         }    

        emit removeItemsOnAdminListEvent(wallets);
    }


    // sale setting
    function changeSaleStatus(saleState state) public onlyAdmin{
        SaleState = state;

        emit changeSaleStatusEvent(SaleState);
    }

    function setPausedStatus(bool status) public onlyAdmin{
        IsPaused = status;

        emit changePausedStatusEvent(IsPaused);
    }

    function updateSupplyTotal(uint256 maxSupply) public onlyAdmin{
        MaxSupply = maxSupply;

        emit changeMaxSupplyEvent(MaxSupply);
    }

    function updatePricePerToken(uint256 pricePerToken)public onlyAdmin{
        PricePerToken = pricePerToken;

        emit changePricePerTokenEvent(MaxSupply);
    }

    function setMaximumDOTPerWallet(uint256 maximumDOTPerWallet) public onlyAdmin{
        MaximumDOTPerWallet = maximumDOTPerWallet;

        emit changeMaxItemPerWalletEvent(MaximumDOTPerWallet);
    }
}
