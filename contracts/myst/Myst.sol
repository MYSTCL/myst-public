/*
░▒▓██████████████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓███████▓▒░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░  ░▒▓█▓▒░      ░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░  ░▒▓█▓▒░      ░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░          ░▒▓█▓▒░  ░▒▓█▓▒░  ░▒▓█▓▒░      ░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░          ░▒▓█▓▒░  ░▒▓█▓▒░  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        
░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░   ░▒▓███████▓▒░   ░▒▓█▓▒░   ░▒▓██████▓▒░░▒▓████████▓▒░ 
https://mystcl.xyz/
*/

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./Ownable.sol";
import "./Structs.sol";

abstract contract ERC721Receiver {
  function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
    return ERC721Receiver.onERC721Received.selector;
  }
}

contract MYSTCL is Ownable {
  /// NFT Metadata
  string public baseTokenURI = "ipfs://QmR698Qo2f9UuDmxM9CxGsxw9gFJmJyyagXRY3QDqMNhXb/";
  uint256 public erc721totalSupply = 7000;
  uint256[] public tokenIdPool;
  uint256 public maxMintedId;

  // Metadata
  string public name = "MYSTCL";
  string public symbol =  "MYST";
  uint8 public immutable decimals;
  uint256 public immutable totalSupply;

  // Mappings
  /// @dev Mapping to check if id is assigned
  mapping(uint256 => bool) private idAssigned;
  /// @dev Balance of user in fractional representation
  mapping(address => uint256) public balanceOf;
  /// @dev Allowance of user in fractional representation
  mapping(address => mapping(address => uint256)) public allowance;
  /// @dev Approval in native representaion
  mapping(uint256 => address) public getApproved;
  /// @dev Approval for all in native representation
  mapping(address => mapping(address => bool)) public isApprovedForAll;
  /// @dev Owner of id in native representation
  mapping(uint256 => address) internal _ownerOf;
  /// @dev Array of owned ids in native representation
  mapping(address => uint256[]) internal _owned;
  /// @dev Tracks indices for the _owned mapping
  mapping(uint256 => uint256) internal _ownedIndex;
  /// @dev Addresses whitelisted from minting / burning for gas savings (pairs, routers, etc)
  mapping(address => bool) public whitelist;

  // Constructor
  constructor(address _owner) Ownable(_owner) {
    decimals = 18;
    totalSupply = erc721totalSupply * (10 ** decimals);

    whitelist[_owner] = true;
    balanceOf[_owner] = totalSupply;
  }

  /// @notice Initialization function to set pairs / etc saving gas by avoiding mint / burn on unnecessary targets
  function setWhitelist(address target, bool state) public onlyOwner {
    if (balanceOf[target] > 0) revert SharedStructs.InvalidSetWhitelistCondition();
    whitelist[target] = state;
  }

  /// @notice Function to find owner of a given native token
  function ownerOf(uint256 id) public view returns (address owner) {
    owner = _ownerOf[id];
    if (owner == address(0)) revert SharedStructs.NotFound();
  }

  function tokenURI(uint256 id) public view returns (string memory) {
    if (id >= totalSupply || id <= 0) revert SharedStructs.InvalidId();
    return string.concat(baseTokenURI, Strings.toString(id), ".json");
  }

  function setTokenURI(string memory _tokenURI) public onlyOwner {
     baseTokenURI = _tokenURI;
   }

  /// @notice Function for token approvals
  /// @dev This function assumes id / native if amount less than or equal to current max id
  function approve(address spender, uint256 amountOrId) public returns (bool) {
    if (amountOrId <= maxMintedId && amountOrId > 0) {
      address owner = _ownerOf[amountOrId];
      if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert Unauthorized();
      getApproved[amountOrId] = spender;
      emit SharedStructs.Approval(owner, spender, amountOrId);
    } else {
      allowance[msg.sender][spender] = amountOrId;
      emit SharedStructs.Approval(msg.sender, spender, amountOrId);
    }

    return true;
  }

  /// @notice Function native approvals
  function setApprovalForAll(address operator, bool approved) public {
    isApprovedForAll[msg.sender][operator] = approved;
    emit SharedStructs.ApprovalForAll(msg.sender, operator, approved);
  }

  /// @notice Function for mixed transfers
  /// @dev This function assumes id / native if amount less than or equal to current max id
  function transferFrom(address from, address to, uint256 amountOrId) public {
    if (amountOrId <= erc721totalSupply) {
      if (from != _ownerOf[amountOrId]) revert SharedStructs.InvalidSender();
      if (to == address(0)) revert SharedStructs.InvalidRecipient();
      if (
        msg.sender != from &&
        !isApprovedForAll[from][msg.sender] &&
        msg.sender != getApproved[amountOrId]
      ) {
        revert Unauthorized();
      }

      balanceOf[from] -= _getUnit();
      unchecked {
        balanceOf[to] += _getUnit();
      }

      _ownerOf[amountOrId] = to;
      delete getApproved[amountOrId];

      // update _owned for sender
      uint256 updatedId = _owned[from][_owned[from].length - 1];
      _owned[from][_ownedIndex[amountOrId]] = updatedId;
      // pop
      _owned[from].pop();
      // update index for the moved id
      _ownedIndex[updatedId] = _ownedIndex[amountOrId];
      // push token to to owned
      _owned[to].push(amountOrId);
      // update index for to owned
      _ownedIndex[amountOrId] = _owned[to].length - 1;

      emit SharedStructs.Transfer(from, to, amountOrId);
      emit SharedStructs.ERC20Transfer(from, to, _getUnit());
    } else {
      uint256 allowed = allowance[from][msg.sender];
      if (allowed != type(uint256).max) {
        allowance[from][msg.sender] = allowed - amountOrId;
      }
      _transfer(from, to, amountOrId);
    }
  }

  /// @notice Function for fractional transfers
  function transfer(address to, uint256 amount) public returns (bool) {
    return _transfer(msg.sender, to, amount);
  }

  /// @notice Function for native transfers with contract support
  function safeTransferFrom(address from, address to, uint256 id) public {
    transferFrom(from, to, id);
    if (
      to.code.length != 0 &&
      ERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
      ERC721Receiver.onERC721Received.selector
    ) {
      revert SharedStructs.UnsafeRecipient();
    }
  }

  /// @notice Function for native transfers with contract support and callback data
  function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public {
    transferFrom(from, to, id);
    if (
      to.code.length != 0 &&
      ERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
      ERC721Receiver.onERC721Received.selector
    ) {
      revert SharedStructs.UnsafeRecipient();
    }
  }

  /// @notice Internal function for fractional transfers
  function _transfer(address from, address to, uint256 amount) internal returns (bool) {
    uint256 unit = _getUnit();
    uint256 balanceBeforeSender = balanceOf[from];
    uint256 balanceBeforeReceiver = balanceOf[to];

    balanceOf[from] -= amount;
    unchecked {
      balanceOf[to] += amount;
    }

    // Skip burn for certain addresses to save gas
    if (!whitelist[from]) {
      uint256 tokens_to_burn = (balanceBeforeSender / unit) - (balanceOf[from] / unit);
      for (uint256 i = 0; i < tokens_to_burn; i++) {
        _burn(from);
      }
    }

    // Skip minting for certain addresses to save gas
    if (!whitelist[to]) {
      uint256 tokens_to_mint = (balanceOf[to] / unit) - (balanceBeforeReceiver / unit);
      for (uint256 i = 0; i < tokens_to_mint; i++) {
        _mint(to);
      }
    }

    emit SharedStructs.ERC20Transfer(from, to, amount);
    return true;
  }

  // Internal utility logic
  function _getUnit() internal view returns (uint256) {
    return 10 ** decimals;
  }

  function _randomIdFromPool() private returns (uint256) {
    if (tokenIdPool.length == 0) revert SharedStructs.PoolIsEmpty();
    uint256 randomIndex = uint256(
      keccak256(abi.encodePacked(block.timestamp, msg.sender,tokenIdPool.length))
    ) % tokenIdPool.length;
    uint256 id = tokenIdPool[randomIndex];
    tokenIdPool[randomIndex] = tokenIdPool[tokenIdPool.length - 1];
    tokenIdPool.pop();
    idAssigned[id] = true;
    return id;
  }

  function _returnIdToPool(uint256 id) private {
    if (!idAssigned[id]) revert SharedStructs.IdNotAssigned();
    tokenIdPool.push(id);
    idAssigned[id] = false;
  }

  function _mint(address to) internal {
    if (to == address(0)) revert SharedStructs.InvalidRecipient();
    uint256 id;
    if (maxMintedId < erc721totalSupply) {
      maxMintedId++;
      id = maxMintedId;
      idAssigned[id] = true;
    } else if (tokenIdPool.length > 0) {
      id = _randomIdFromPool();
    } else {
      revert SharedStructs.PoolIsEmpty();
    }
    _ownerOf[id] = to;
    _owned[to].push(id);
    _ownedIndex[id] = _owned[to].length - 1;
    emit SharedStructs.Transfer(address(0), to, id);
  }

  function _burn(address from) internal {
    if (from == address(0)) revert SharedStructs.InvalidSender();
    uint256 id = _owned[from][_owned[from].length - 1];
    _returnIdToPool(id);
    _owned[from].pop();
    delete _ownedIndex[id];
    delete _ownerOf[id];
    delete getApproved[id];
    emit SharedStructs.Transfer(from, address(0), id);
  }

  function getTokenIdPool() public view returns (uint256[] memory) {
    return tokenIdPool;
  }
}