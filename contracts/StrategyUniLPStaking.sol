// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/*
 A strategy must implement the following calls;

 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()

 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller
*/

interface SULPSController {
  function vaults(address) external view returns (address);
  function rewards() external view returns (address);
}

interface SULPSStakingRewards {
  function stake(uint) external;
  function balanceOf(address) external view returns (uint);
  function withdraw(uint) external;
  function getReward() external;
}

interface SULPSUniswapRouter {
  function swapExactTokensForTokens(uint, uint, address[] calldata, address, uint) external;
}

contract StrategyUniLPStaking {
  using Address for address;
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public want;
  address public pool;
  address constant public uni = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  address constant public unirouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address constant public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // used for uni <> weth route
  // liquidation path to be used
  address[] public uniswap_uni2weth;

  uint public performanceFee = 500;
  uint constant public performanceMax = 10000;

  uint public withdrawalFee = 50;
  uint constant public withdrawalMax = 10000;

  address public governance;
  address public controller;

  constructor(address _want, address _pool, address _controller) public {
    want = _want;
    pool = _pool;
    uniswap_uni2weth = [uni, weth];
    governance = tx.origin;
    controller = _controller;
  }

  function getName() external pure returns (string memory) {
    return "StrategyUniLPStaking";
  }

  function setWithdrawalFee(uint _withdrawalFee) external {
    require(msg.sender == governance, "!governance");
    withdrawalFee = _withdrawalFee;
  }

  function setPerformanceFee(uint _performanceFee) external {
    require(msg.sender == governance, "!governance");
    performanceFee = _performanceFee;
  }

  function deposit() public {
    uint _want = IERC20(want).balanceOf(address(this));
    if (_want > 0) {
      IERC20(want).safeApprove(pool, 0);
      IERC20(want).safeApprove(pool, _want);
      SULPSStakingRewards(pool).stake(_want);
    }
  }

  // Controller only function for creating additional rewards from dust
  function withdraw(IERC20 _asset) external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    require(want != address(_asset), "want");
    require(uni != address(_asset), "uni");
    balance = _asset.balanceOf(address(this));
    _asset.safeTransfer(controller, balance);
  }

  // Withdraw partial funds, normally used with a vault withdrawal
  function withdraw(uint _amount) external {
    require(msg.sender == controller, "!controller");
    uint _balance = IERC20(want).balanceOf(address(this));
    if (_balance < _amount) {
      _amount = _withdrawSome(_amount.sub(_balance));
      _amount = _amount.add(_balance);
    }

    address _vault = SULPSController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

    IERC20(want).safeTransfer(_vault, _amount);
  }

  // Withdraw all funds, normally used when migrating strategies
  function withdrawAll() external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    _withdrawAll();

    // we can transfer the asset to the vault
    balance = IERC20(want).balanceOf(address(this));

    if (balance > 0) {
      address _vault = SULPSController(controller).vaults(address(want));
      require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
      IERC20(want).safeTransfer(_vault, balance);
    }
  }

  function _withdrawAll() internal {
    uint _balance = SULPSStakingRewards(pool).balanceOf(address(this));
    SULPSStakingRewards(pool).withdraw(_balance);
  }

  function harvest() public {
    require(msg.sender == governance, "!authorized");
    SULPSStakingRewards(pool).getReward();
    uint256 uniBalance = IERC20(uni).balanceOf(address(this));
    if (uniBalance > 0) {
      IERC20(uni).safeApprove(unirouter, 0);
      IERC20(uni).safeApprove(unirouter, uniBalance);
      SULPSUniswapRouter(unirouter).swapExactTokensForTokens(uniBalance, uint(0), uniswap_uni2weth, address(this), now.add(1800));
    }
    uint wethBalance = IERC20(weth).balanceOf(address(this));
    if (wethBalance > 0) {
      IERC20(weth).safeTransfer(SULPSController(controller).rewards(), wethBalance);
    }
  }

  function _withdrawSome(uint256 _amount) internal returns (uint) {
    uint _before = IERC20(want).balanceOf(address(this));
    SULPSStakingRewards(pool).withdraw(_amount);
    uint _after = IERC20(want).balanceOf(address(this));
    return _after.sub(_before);
  }

  function balanceOfWant() public view returns (uint) {
    return IERC20(want).balanceOf(address(this));
  }

  function balanceOfPool() public view returns (uint) {
    return SULPSStakingRewards(pool).balanceOf(address(this));
  }

  function balanceOf() public view returns (uint) {
    return balanceOfWant().add(balanceOfPool());
  }

  function setGovernance(address _governance) external {
    require(msg.sender == governance, "!governance");
    governance = _governance;
  }

  function setController(address _controller) external {
    require(msg.sender == governance, "!governance");
    controller = _controller;
  }
}
