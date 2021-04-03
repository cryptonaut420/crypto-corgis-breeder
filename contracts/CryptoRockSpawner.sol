//SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/FactoryERC1155.sol";

//Conract code copied from CryptoRocksBreeder https://github.com/CryptoRocks/crypto-rocks-breeder
contract CryptoRockSpawner is Ownable, FactoryERC1155, ERC1155 {
  using SafeMath for uint256;

  event RockSold(uint256 rockNumber, uint256 blockNumber, address owner);

  uint256 public constant MAX_INT_256 = 2**256 - 1;
  uint256 public constant MAX_ROCKS_MINTED = 5000;
  uint256 public constant ROCK_LIFESPAN_BLOCKS = 128;
  uint256 public constant FIRST_ROCK_PRICE_ETH = 1e16;
  uint256 public constant INCREMENTAL_PRICE_ETH = 5e13;

  address payable public treasuryAddress;
  uint256 public rocksMinted = 0;

  mapping(uint256 => uint256) public rockNumberToBlockNumber;
  mapping(uint256 => uint256) public blockNumberToRockNumber;
  mapping (uint256 => bytes32) public blockNumberToRockDNA;
  mapping(uint256 => string) public rockIdToName;

  string private contractDataURI;

  constructor(
    string memory _metadataURI,
    string memory _contractDataURI,
    address payable _treasuryAddress
  ) ERC1155(_metadataURI) {
    contractDataURI = _contractDataURI;
    treasuryAddress = _treasuryAddress;
  }

  /// @dev https://docs.opensea.io/docs/2-custom-sale-contract-viewing-your-sale-assets-on-opensea
  function name() external pure override returns (string memory) {
    return "Crypto Rocks Spawner";
  }

  function symbol() external pure override returns (string memory) {
    return "ROCK";
  }

  function numOptions() external pure override returns (uint256) {
    return MAX_INT_256;
  }

  /**
   * Indicates that this is a factory contract.
   */
  function supportsFactoryInterface() external pure override returns (bool) {
    return true;
  }

  /**
   * Indicates the Wyvern schema name for assets in this factory, e.g. "ERC1155"
   */
  function factorySchemaName() external pure override returns (string memory) {
    return "ERC1155";
  }

  function getClaimedRocks() external view returns (uint256[] memory) {
    uint256[] memory blockNumbers = new uint256[](rocksMinted);
    for (uint256 i = 0; i < rocksMinted; i++) {
      blockNumbers[i] = rockNumberToBlockNumber[i + 1];
    }
    return blockNumbers;
  }

  /// @dev can only can a rock once and only if you own it.
  function nameRock(uint256 id, string memory name) public {
    require(balanceOf(msg.sender, id) == 1, "CryptoRocksSpawner: Cannot name a rock you do not own");
    require(bytes(name).length > 0, "CryptoRocksSpawner: Cannot erase a rock name");
    require(bytes(rockIdToName[id]).length == 0, "CryptoRocksSpawner: Can only name a rock once");
    rockIdToName[id] = name;
  }

  /// @dev https://docs.opensea.io/docs/contract-level-metadata
  function contractURI() public view returns (string memory) {
    return contractDataURI;
  }

  /// @dev Allow the deployer to change the smart contract meta-data.
  function setContractDataURI(string memory _contractDataURI) public onlyOwner {
    contractDataURI = _contractDataURI;
  }

  // @dev Allow the deployer to change the ERC-1155 URI
  function setURI(string memory _uri) public onlyOwner {
    _setURI(_uri);
  }

  function dnaForBlockNumber(uint256 _blockNumber) external pure returns (bytes32) {
    return blockNumberToRockDNA[_blockNumber];
  }

  /**
   * @dev Returns whether the option ID can be minted. Can return false if the developer wishes to
   * restrict a total supply per option ID (or overall).
   */
  function canMint(uint256 _blockNumber, uint256 _amount) public view override returns (bool) {
    (bool _, uint256 subResult) = block.number.trySub(ROCK_LIFESPAN_BLOCKS);
    if (_blockNumber > block.number || _blockNumber < subResult || _amount > 1) {
      return false;
    }
    return blockNumberToRockNumber[_blockNumber] == 0;
  }

  function priceForRock(uint256 _rockNumber, uint256 _blockNumber) public pure returns (uint256) {
    uint256 rockAge = block.number.trySub(_blockNumber);
    uint256 this_price = FIRST_ROCK_PRICE_ETH.add(INCREMENTAL_PRICE_ETH.mul(_rockNumber.sub(1))).sub(INCREMENTAL_PRICE_ETH.mul(rockAge.sub(1).mul(2)));
    if(this_price < FIRST_ROCK_PRICE_ETH){
      return FIRST_ROCK_PRICE_ETH; //price floor
    }
    return this_price;
  }

  function mint(uint256 _blockNumber, bytes calldata _data) public payable {
    mint(_blockNumber, msg.sender, 1, msg.sender, _data);
  }

  function mint(
    uint256 _blockNumber,
    address _toAddress,
    uint256 _amount,
    bytes calldata _data
  ) public payable override {
    mint(_blockNumber, _toAddress, _amount, msg.sender, _data);
  }

  function mint(
    uint256 _blockNumber,
    address _toAddress,
    uint256 _amount,
    address payable _refundAddress,
    bytes calldata _data
  ) public payable {
    require(rocksMinted < MAX_ROCKS_MINTED, "CryptoRocksSpawner: Cannot mint any more Crypto Rocks");
    require(canMint(_blockNumber, _amount), "CryptoRocksSpawner: Not allowed to mint for that block number");
    uint256 nextRockId = rocksMinted + 1;
    uint256 price = priceForRock(nextRockId, _blockNumber);
    require(msg.value >= price, "CryptoRocksSpawner: Insufficient funds to mint a Crypto Rock");
    treasuryAddress.transfer(price);
    _refundAddress.transfer(msg.value.sub(price));
    bytes32 rockDna = blockhash(_blockNumber);

    rockNumberToBlockNumber[nextRockId] = _blockNumber;
    blockNumberToRockNumber[_blockNumber] = nextRockId;
    blockNumberToRockDNA[_blockNumber] = rockDna;

    // Use _blockNumber as ID.
    _mint(_toAddress, _blockNumber, 1, _data);
    rocksMinted = nextRockId;
    emit RockSold(nextRockId, _blockNumber, _toAddress);
  }
}
