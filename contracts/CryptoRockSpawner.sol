//SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol"
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/ERC165.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/IERC165.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/cryptonaut420/crypto-corgis-breeder/blob/main/contracts/interfaces/FactoryERC1155.sol?1";

//Conract code copied from CryptoRocksBreeder https://github.com/CryptoRocks/crypto-rocks-breeder
contract CryptoRockSpawner is Ownable, FactoryERC1155, ERC1155 {
  using SafeMath for uint256;

  event RockSold(uint256 rockNumber, uint256 blockNumber, address owner);
  event UniqueSold(uint256 uniqueNumber, address owner);

  uint256 public constant MAX_INT_128 = 2**128 - 1;
  uint256 public constant MAX_ROCKS_MINTED = 4200;
  uint256 public constant ROCK_LIFESPAN_BLOCKS = 128;
  uint256 public constant FIRST_ROCK_PRICE_ETH = 1e15;
  uint256 public constant INCREMENTAL_PRICE_ETH = 5e13;
  uint256 public constant MAX_UNIQUES_MINTED = 12;
  uint256 public constant UNIQUE_COST_FACTOR = 2;

  address payable public treasuryAddress;
  IERC20 public rewardToken;
  uint256 public rocksMinted = 0;
  uint256 public uniquesMinted = 0;
  uint256 public uniqueCost = 512 * 1e18;
  uint256 public stoneReward = 0;

  mapping(uint256 => uint256) public rockNumberToBlockNumber;
  mapping(uint256 => uint256) public blockNumberToRockNumber;
  mapping (uint256 => bytes32) public blockNumberToRockDNA;
  mapping(uint256 => string) public rockIdToName;

  string private contractDataURI;

  constructor(
    string memory _metadataURI,
    string memory _contractDataURI,
    address payable _treasuryAddress,
    IERC20 _rewardToken
  ) ERC1155(_metadataURI) {
    contractDataURI = _contractDataURI;
    treasuryAddress = _treasuryAddress;
    rewardToken = _rewardToken;
  }

  /// @dev https://docs.opensea.io/docs/2-custom-sale-contract-viewing-your-sale-assets-on-opensea
  function name() external pure override returns (string memory) {
    return "Crypto Rocks Spawner";
  }

  function symbol() external pure override returns (string memory) {
    return "ROCK";
  }

  function numOptions() external pure override returns (uint256) {
    return MAX_INT_128;
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
  function nameRock(uint256 id, string memory _name) public {
    require(balanceOf(msg.sender, id) == 1, "CryptoRocksSpawner: Cannot name a rock you do not own");
    require(bytes(_name).length > 0, "CryptoRocksSpawner: Cannot erase a rock name");
    require(bytes(rockIdToName[id]).length == 0, "CryptoRocksSpawner: Can only name a rock once");
    rockIdToName[id] = _name;
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

  function dnaForBlockNumber(uint256 _blockNumber) external view returns (bytes32) {
    return blockNumberToRockDNA[_blockNumber];
  }

  /**
   * @dev Returns whether the option ID can be minted. Can return false if the developer wishes to
   * restrict a total supply per option ID (or overall).
   */
  function canMint(uint256 _blockNumber, uint256 _amount) public view override returns (bool) {
    (bool _s, uint256 subResult) = block.number.trySub(ROCK_LIFESPAN_BLOCKS);
    require(_s, "Block life not in range");
    if (_blockNumber > block.number || _blockNumber < subResult || _amount > 1) {
      return false;
    }
    return blockNumberToRockNumber[_blockNumber] == 0;
  }


  function priceForRock(uint256 _rockNumber, uint256 _blockNumber) public view returns (uint256) {
    (bool _s, uint256 rockAge) = block.number.trySub(_blockNumber);
    require(_s, "Block life not in range");
    uint256 price_ceiling = FIRST_ROCK_PRICE_ETH.add(INCREMENTAL_PRICE_ETH.mul(_rockNumber.sub(1)));
    (bool _ps, uint256 price_floor) = price_ceiling.trySub(INCREMENTAL_PRICE_ETH.mul(ROCK_LIFESPAN_BLOCKS.mul(2)));
    if(_ps == false){
        price_floor = FIRST_ROCK_PRICE_ETH;
    }
    if(price_floor < FIRST_ROCK_PRICE_ETH){
        price_floor = FIRST_ROCK_PRICE_ETH;
    }
    uint256 discount = INCREMENTAL_PRICE_ETH.mul((rockAge.mul(2)).sub(1));
    (bool _ts, uint256 this_price) = price_ceiling.trySub(discount);
    if(_ts == false){
        this_price = price_floor;
    }
    if(this_price < price_floor){
        this_price = price_floor;
    }
    return this_price;
  }

  function mint(uint256 _blockNumber, bytes calldata _data) public payable {
    address payable refundAddress = payable(msg.sender);
    mint(_blockNumber, msg.sender, 1, refundAddress, _data);
  }

  function mint(
    uint256 _blockNumber,
    address _toAddress,
    uint256 _amount,
    bytes calldata _data
  ) public payable override {
    address payable refundAddress = payable(msg.sender);
    mint(_blockNumber, _toAddress, _amount, refundAddress, _data);
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

    //STONE rewards
    stoneReward = nextRockId * 1e18;
    rewardToken.mint(_toAddress, stoneReward);

    // Use _blockNumber as ID.
    _mint(_toAddress, _blockNumber, 1, _data);
    rocksMinted = nextRockId;
    emit RockSold(nextRockId, _blockNumber, _toAddress);
  }

  function mintUnique(
    bytes calldata _data
  ) public payable {
    //do checks
    require(uniquesMinted < MAX_UNIQUES_MINTED, "CryptoRocksSpawner: Cannot mint any more Unique Crypto Rocks");
    require(rewardToken.balanceOf(msg.sender) >= uniqueCost, "CryptoRocksSpawner: Insufficient STONE balance to mint Unique");

    //burn the reward tokens
    rewardToken.burn(msg.sender, uniqueCost);

    //mint the unique rock
    uniquesMinted = uniquesMinted + 1; //increment the amount minted, and also use it as the ID... so rocks ID 1, 2, 3, 4 etc. are all uniques
    _mint(msg.sender, uniquesMinted, 1, _data);
    rockNumberToBlockNumber[uniquesMinted] = uniquesMinted;
    blockNumberToRockNumber[uniquesMinted] = uniquesMinted;
    blockNumberToRockDNA[uniquesMinted] = keccak256(abi.encodePacked(uniquesMinted)));

    //increase the cost for the next person
    uniqueCost = uniqueCost * UNIQUE_COST_FACTOR;
    emit UniqueSold(uniquesMinted, _toAddress);
  }
}
