// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BasePaint.sol";
import "./BasePaintAnimation.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract MintAndBurn is ERC1155Holder {
    BasePaint public constant CANVAS_CONTRACT = BasePaint(0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83);
    BasePaintAnimation public constant BURN_CONTRACT = BasePaintAnimation(0xC59F475122e914aFCf31C0a9E0A2274666135e4E);

    function mintAndBurn() external payable {
        uint256 singlePrice = CANVAS_CONTRACT.openEditionPrice();
        require(msg.value >= singlePrice, "Insufficient ETH sent");

        uint256 amount = msg.value / singlePrice;
        uint256 totalPrice = amount * singlePrice;

        uint256 today = CANVAS_CONTRACT.today();

        try CANVAS_CONTRACT.mint{value: totalPrice}(today, amount) {
            // Minting successful
            IERC1155(address(CANVAS_CONTRACT)).setApprovalForAll(address(BURN_CONTRACT), true);

            uint256 burnAmount = amount - (amount % 2);  // Round down to nearest even number
            uint256 remainderAmount = amount % 2;

            if (burnAmount >= 2) {
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
        uint256 excess = msg.value - totalPrice;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

}
