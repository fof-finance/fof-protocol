// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface SDFController {
  function vaults(address) external view returns (address);
  function rewards() external view returns (address);
}

interface dRewards {
  function withdraw(uint) external;
  function getReward() external;
  function stake(uint) external;
  function balanceOf(address) external view returns (uint);
  function exit() external;
}

interface dERC20 {
  function mint(address, uint256) external;
  function redeem(address, uint) external;
  function getTokenBalance(address) external view returns (uint);
  function getExchangeRate() external view returns (uint);
}

interface SDFUniswapRouter {
  function swapExactTokensForTokens(uint, uint, address[] calldata, address, uint) external;
}

/*
 A strategy must implement the following calls;
 
 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()
 
 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller
*/

contract StrategyDForce {
  using Address for address;
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public want;
  address public dwant;
  address public pool;
  address constant public df = address(0x431ad2ff6a9C365805eBaD47Ee021148d6f7DBe0);
  address constant public unirouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address constant public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // used for df <> weth <> want route

  uint public performanceFee = 500;
  uint constant public performanceMax = 10000;

  uint public withdrawalFee = 50;
  uint constant public withdrawalMax = 10000;

  address public governance;
  address public controller;

  constructor(address _want, address _dwant, address _pool, address _controller) public {
    want = _want;
    dwant = _dwant;
    pool = _pool;
    governance = tx.origin;
    controller = _controller;
  }

  function getName() external pure returns (string memory) {
    return "StrategyDForce";
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
      IERC20(want).safeApprove(dwant, 0);
      IERC20(want).safeApprove(dwant, _want);
      dERC20(dwant).mint(address(this), _want);
    }

    uint _dwant = IERC20(dwant).balanceOf(address(this));
    if (_dwant > 0) {
      IERC20(dwant).safeApprove(pool, 0);
      IERC20(dwant).safeApprove(pool, _dwant);
      dRewards(pool).stake(_dwant);
    }
  }

  // Controller only function for creating additional rewards from dust
  function withdraw(IERC20 _asset) external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    require(want != address(_asset), "want");
    require(dwant != address(_asset), "dwant");
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

    uint _fee = _amount.mul(withdrawalFee).div(withdrawalMax);

    IERC20(want).safeTransfer(SDFController(controller).rewards(), _fee);
    address _vault = SDFController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

    IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
  }

  // Withdraw all funds, normally used when migrating strategies
  function withdrawAll() external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    _withdrawAll();

    balance = IERC20(want).balanceOf(address(this));

    address _vault = SDFController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
    IERC20(want).safeTransfer(_vault, balance);
  }

  function _withdrawAll() internal {
    dRewards(pool).exit();
    uint _dwant = IERC20(dwant).balanceOf(address(this));
    if (_dwant > 0) {
      dERC20(dwant).redeem(address(this), _dwant);
    }
  }

  function harvest() public {
    require(msg.sender == governance, "!authorized");
    dRewards(pool).getReward();
    uint _df = IERC20(df).balanceOf(address(this));
    if (_df > 0) {
      IERC20(df).safeApprove(unirouter, 0);
      IERC20(df).safeApprove(unirouter, _df);

      address[] memory path = new address[](3);
      path[0] = df;
      path[1] = weth;
      path[2] = want;

      SDFUniswapRouter(unirouter).swapExactTokensForTokens(_df, uint(0), path, address(this), now.add(1800));
    }
    uint _want = IERC20(want).balanceOf(address(this));
    if (_want > 0) {
      uint _fee = _want.mul(performanceFee).div(performanceMax);
      IERC20(want).safeTransfer(SDFController(controller).rewards(), _fee);
      deposit();
    }
  }

  function _withdrawSome(uint256 _amount) internal returns (uint) {
    uint _dwant = _amount.mul(1e18).div(dERC20(dwant).getExchangeRate());
    uint _before = IERC20(dwant).balanceOf(address(this));
    dRewards(pool).withdraw(_dwant);
    uint _after = IERC20(dwant).balanceOf(address(this));
    uint _withdrew = _after.sub(_before);
    _before = IERC20(want).balanceOf(address(this));
    dERC20(dwant).redeem(address(this), _withdrew);
    _after = IERC20(want).balanceOf(address(this));
    _withdrew = _after.sub(_before);
    return _withdrew;
  }

  function balanceOfWant() public view returns (uint) {
    return IERC20(want).balanceOf(address(this));
  }

  function balanceOfPool() public view returns (uint) {
    return (dRewards(pool).balanceOf(address(this))).mul(dERC20(dwant).getExchangeRate()).div(1e18);
  }

  function getExchangeRate() public view returns (uint) {
    return dERC20(dwant).getExchangeRate();
  }

  function balanceOfD() public view returns (uint) {
    return dERC20(dwant).getTokenBalance(address(this));
  }

  function balanceOf() public view returns (uint) {
    return balanceOfWant().add(balanceOfD()).add(balanceOfPool());
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
