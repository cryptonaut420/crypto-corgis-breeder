// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


contract StoneToken is ERC20("STONE", "STONE"), Ownable {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
    /// @notice Burns `_amount` token from owner wallet. Must only be called by the owner.
    function burn(uint256 _amount) public onlyOwner {
        _burn(msg.sender, _amount);
    }    

}
