//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library SharedStructs {
  // Events
  event ERC20Transfer(
    address indexed from,
    address indexed to,
    uint256 amount
  );
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 amount
  );
  event Transfer(
    address indexed from,
    address indexed to,
    uint256 indexed id
  );
  event ERC721Approval(
    address indexed owner,
    address indexed spender,
    uint256 indexed id
  );
  event ApprovalForAll(
    address indexed owner,
    address indexed operator,
    bool approved
  );

  // Errors
  error NotFound();
  error AlreadyExists();
  error InvalidRecipient();
  error InvalidSender();
  error UnsafeRecipient();
  error InvalidId();
  error IdNotAssigned();
  error PoolIsEmpty();
  error InvalidSetWhitelistCondition();
}