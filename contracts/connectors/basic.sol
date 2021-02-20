// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import files from common directory
import { TokenInterface , MemoryInterface, EventInterface} from "../common/interfaces.sol";
import { Stores } from "../common/stores.sol";
import { DSMath } from "../common/math.sol";

interface AccountInterface {
    function isAuth(address _user) external view returns (bool);
}
/**
 * @title ConnectBasic.
 * @dev Connector to deposit/withdraw assets.
 */

contract BasicResolver is Stores {
    event LogDeposit(address indexed erc20, uint256 tokenAmt);
    event LogWithdraw(address indexed erc20, uint256 tokenAmt, address indexed to);

    using SafeERC20 for IERC20;

    /**
     * @dev Deposit Assets To Smart Account.
     * @param erc20 Token Address.
     * @param tokenAmt Token Amount.
     */
    function deposit(address erc20, uint tokenAmt) public payable {
        uint amt = tokenAmt;

        if (erc20 != getEthAddr()) {
            IERC20 token = IERC20(erc20);
            amt = amt == uint(-1) ? token.balanceOf(msg.sender) : amt;
            token.safeTransferFrom(msg.sender, address(this), amt);
        } else {
            require(msg.value == amt || amt == uint(-1), "invalid-ether-amount");
            amt = msg.value;
        }
        emit LogDeposit(erc20, amt);

        bytes32 _eventCode = keccak256("LogDeposit(address,uint256)");
        bytes memory _eventParam = abi.encode(erc20, amt);
        emitEvent(_eventCode, _eventParam);
    }

   /**
     * @dev Withdraw Assets To Smart Account.
     * @param erc20 Token Address.
     * @param tokenAmt Token Amount.
     * @param to Withdraw token address.
     */
    function withdraw(
        address erc20,
        uint tokenAmt,
        address payable to
    ) public payable {
        uint amt = tokenAmt;
        if (erc20 == getEthAddr()) {
            amt = amt == uint(-1) ? address(this).balance : amt;
            to.transfer(amt);
        } else {
            IERC20 token = IERC20(erc20);
            amt = amt == uint(-1) ? token.balanceOf(address(this)) : amt;
            token.safeTransfer(to, amt);
        }

        emit LogWithdraw(erc20, amt, to);

        bytes32 _eventCode = keccak256("LogWithdraw(address,uint256,address)");
        bytes memory _eventParam = abi.encode(erc20, amt, to);
        emitEvent(_eventCode, _eventParam);
    }
}


contract ConnectBasic is BasicResolver {
    string public constant name = "Basic-v1.1";
}
