// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

// import files from common directory
import { TokenInterface , MemoryInterface, EventInterface} from "../common/interfaces.sol";
import { Stores } from "../common/stores.sol";
import { DSMath } from "../common/math.sol";

interface AaveInterface {
    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;
    function redeemUnderlying(
        address _reserve,
        address payable _user,
        uint256 _amount,
        uint256 _aTokenBalanceAfterRedeem
    ) external;
    function setUserUseReserveAsCollateral(address _reserve, bool _useAsCollateral) external;
    function getUserReserveData(address _reserve, address _user) external view returns (
        uint256 currentATokenBalance,
        uint256 currentBorrowBalance,
        uint256 principalBorrowBalance,
        uint256 borrowRateMode,
        uint256 borrowRate,
        uint256 liquidityRate,
        uint256 originationFee,
        uint256 variableBorrowIndex,
        uint256 lastUpdateTimestamp,
        bool usageAsCollateralEnabled
    );
    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) external;
    function repay(address _reserve, uint256 _amount, address payable _onBehalfOf) external payable;
}

interface AaveProviderInterface {
    function getLendingPool() external view returns (address);
    function getLendingPoolCore() external view returns (address);
}

interface AaveCoreInterface {
    function getReserveATokenAddress(address _reserve) external view returns (address);
}

interface ATokenInterface {
    function redeem(uint256 _amount) external;
    function balanceOf(address _user) external view returns(uint256);
    function principalBalanceOf(address _user) external view returns(uint256);
}

contract AaveHelpers is DSMath, Stores {

    /**
     * @dev get Aave Provider
    */
    function getAaveProvider() internal pure returns (AaveProviderInterface) {
        return AaveProviderInterface(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8); //mainnet
        // return AaveProviderInterface(0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5); //kovan
    }

    /**
     * @dev get Referral Code
    */
    function getReferralCode() internal pure returns (uint16) {
        return 3228;
    }

    function getIsColl(AaveInterface aave, address token) internal view returns (bool isCol) {
        (, , , , , , , , , isCol) = aave.getUserReserveData(token, address(this));
    }

    function getWithdrawBalance(address token) internal view returns (uint bal) {
        AaveInterface aave = AaveInterface(getAaveProvider().getLendingPool());
        (bal, , , , , , , , , ) = aave.getUserReserveData(token, address(this));
    }

    function getPaybackBalance(AaveInterface aave, address token) internal view returns (uint bal, uint fee) {
        (, bal, , , , , fee, , , ) = aave.getUserReserveData(token, address(this));
    }
}


contract BasicResolver is AaveHelpers {
    event LogDeposit(address indexed token, uint256 tokenAmt);
    event LogWithdraw(address indexed token, uint256 tokenAmt);
    event LogBorrow(address indexed token, uint256 tokenAmt);
    event LogPayback(address indexed token, uint256 tokenAmt);
    event LogEnableCollateral(address[] tokens);

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @param token token address to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to deposit.
    */
    function deposit(address token, uint amt) external payable {
        AaveInterface aave = AaveInterface(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);
        uint ethAmt;
        uint _amt = amt;
        if (token == getEthAddr()) {
            _amt = _amt == uint(-1) ? address(this).balance : _amt;
            ethAmt = _amt;
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            _amt = _amt == uint(-1) ? tokenContract.balanceOf(address(this)) : _amt;
            tokenContract.approve(getAaveProvider().getLendingPoolCore(), _amt);
        }

        aave.deposit{value: ethAmt}(token, _amt, getReferralCode());

        if (!getIsColl(aave, token)) aave.setUserUseReserveAsCollateral(token, true);

        emit LogDeposit(token, _amt);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @param token token address to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to withdraw.
    */
    function withdraw(address token, uint amt) external payable {
        AaveCoreInterface aaveCore = AaveCoreInterface(getAaveProvider().getLendingPoolCore());
        ATokenInterface atoken = ATokenInterface(aaveCore.getReserveATokenAddress(token));
        TokenInterface tokenContract = TokenInterface(token);

        uint initialBal = token == getEthAddr() ? address(this).balance : tokenContract.balanceOf(address(this));
        atoken.redeem(amt);
        uint finalBal = token == getEthAddr() ? address(this).balance : tokenContract.balanceOf(address(this));

        amt = sub(finalBal, initialBal);

        emit LogWithdraw(token, amt);
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @param token token address to borrow.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to borrow.
    */
    function borrow(address token, uint amt) external payable {
        AaveInterface aave = AaveInterface(getAaveProvider().getLendingPool());
        aave.borrow(token, amt, 2, getReferralCode());

        emit LogBorrow(token, amt);
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @param token token address to payback.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to payback.
    */
    function payback(address token, uint amt) external payable {
        AaveInterface aave = AaveInterface(getAaveProvider().getLendingPool());

        uint _amt = amt;

        if (_amt == uint(-1)) {
            uint fee;
            (_amt, fee) = getPaybackBalance(aave, token);
            _amt = add(_amt, fee);
        }
        uint ethAmt;
        if (token == getEthAddr()) {
            ethAmt = _amt;
        } else {
            TokenInterface(token).approve(getAaveProvider().getLendingPoolCore(), _amt);
        }

        aave.repay.value(ethAmt)(token, _amt, payable(address(this)));

        emit LogPayback(token, _amt);
    }

    /**
     * @dev Enable collateral
     * @param tokens Array of tokens to enable collateral
    */
    function enableCollateral(address[] calldata tokens) external payable {
        uint _length = tokens.length;
        require(_length > 0, "0-tokens-not-allowed");

        AaveInterface aave = AaveInterface(getAaveProvider().getLendingPool());

        for (uint i = 0; i < _length; i++) {
            address token = tokens[i];
            if (getWithdrawBalance(token) > 0 && !getIsColl(aave, token)) {
                aave.setUserUseReserveAsCollateral(token, true);
            }
        }

        emit LogEnableCollateral(tokens);
    }
}

contract ConnectAave is BasicResolver {
    string public name = "Aave-v1.1";
}
