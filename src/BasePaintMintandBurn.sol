// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

// Add this interface above your contract
interface ICustomCanvas {
    function mint(uint256 day, uint256 count) external payable;
    function openEditionPrice() external view returns (uint256);
    function today() external view returns (uint256);
}

contract MintAndBurn is ERC1155Holder {
    ICustomCanvas public CANVAS_CONTRACT = ICustomCanvas(0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83);
    IERC1155 public constant BURN_CONTRACT = IERC1155(0xC59F475122e914aFCf31C0a9E0A2274666135e4E);

    function mintAndBurn(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 price = CANVAS_CONTRACT.openEditionPrice() * amount;
        require(msg.value >= price, "Insufficient ETH sent");

        uint256 today = CANVAS_CONTRACT.today();

        try CANVAS_CONTRACT.mint{value: price}(today, amount) {
            // Minting successful
            IERC1155(address(CANVAS_CONTRACT)).setApprovalForAll(address(BURN_CONTRACT), true);

            uint256 burnAmount = amount - (amount % 2);  // Round down to nearest even number
            uint256 remainderAmount = amount % 2;

            if (burnAmount > 0) {
                try BURN_CONTRACT.safeTransferFrom(address(this), msg.sender, today, burnAmount, "") {
                    // Burning successful, user will receive burnAmount/2 new tokens from BURN_CONTRACT
                } catch {
                    // If burning fails, transfer burned amount back to the sender
                    IERC1155(address(CANVAS_CONTRACT)).safeTransferFrom(address(this), msg.sender, today, burnAmount, "");
                }
            }

            // Transfer any remainder tokens to the sender
            if (remainderAmount > 0) {
                IERC1155(address(CANVAS_CONTRACT)).safeTransferFrom(address(this), msg.sender, today, remainderAmount, "");
            }
        } catch {
            // If minting fails, refund the sender
            payable(msg.sender).transfer(msg.value);
            return;
        }

        // Refund any excess ETH sent by the user
        uint256 excess = msg.value - price;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

}
