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

interface SSUSDController {
  function vaults(address) external view returns (address);
  function rewards() external view returns (address);
}

interface SSUSDGauge {
  function deposit(uint) external;
  function balanceOf(address) external view returns (uint);
  function withdraw(uint) external;
}

interface SSUSDMintr {
  function mint(address) external;
}

interface SSUSDUniswapRouter {
  function swapExactTokensForTokens(uint, uint, address[] calldata, address, uint) external;
}

interface ISwerveFi {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[4] calldata amounts,
    uint256 min_mint_amount
  ) external;
  function remove_liquidity_imbalance(
    uint256[4] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[4] calldata amounts
  ) external;
  function exchange(
    int128 from,
    int128 to,
    uint256 _from_amount,
    uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[4] calldata amounts,
    bool deposit
  ) external view returns(uint);
  function calc_withdraw_one_coin(
    uint256 _token_amount,
    int128 i) external view returns (uint256);
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 min_amount) external;
}

contract StrategySwerveUSD {
  using Address for address;
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  enum TokenIndex {
    DAI,
    USDC,
    USDT,
    TUSD
  }

  mapping(uint256 => address) public tokenIndexAddress;
  address public want;
  // the matching enum record used to determine the index
  TokenIndex tokenIndex;
  address constant public swusd = address(0x77C6E4a580c0dCE4E5c7a17d0bc077188a83A059); // (swerve combo Swerve.fi DAI/USDC/USDT/TUSD (swUSD))
  address constant public curve = address(0xa746c67eB7915Fa832a4C2076D403D4B68085431);
  address constant public gauge = address(0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa);
  address constant public mintr = address(0x2c988c3974AD7E604E276AE0294a7228DEf67974);
  address constant public swrv = address(0xB8BAa0e4287890a5F79863aB62b7F175ceCbD433);
  address constant public uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address constant public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // used for swrv <> weth <> want route
  // liquidation path to be used
  address[] public uniswap_swrv2want;

  uint public performanceFee = 500;
  uint constant public performanceMax = 10000;

  uint public withdrawalFee = 50;
  uint constant public withdrawalMax = 10000;

  address public governance;
  address public controller;

  constructor(uint256 _tokenIndex, address _controller) public {
    tokenIndexAddress[0] = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    tokenIndexAddress[1] = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    tokenIndexAddress[2] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    tokenIndexAddress[3] = address(0x0000000000085d4780B73119b644AE5ecd22b376);
    tokenIndex = TokenIndex(_tokenIndex);
    want = tokenIndexAddress[_tokenIndex];
    uniswap_swrv2want = [swrv, weth, want];
    governance = tx.origin;
    controller = _controller;
  }

  function getName() external pure returns (string memory) {
    return "StrategySwerveUSD";
  }

  function setWithdrawalFee(uint _withdrawalFee) external {
    require(msg.sender == governance, "!governance");
    withdrawalFee = _withdrawalFee;
  }

  function setPerformanceFee(uint _performanceFee) external {
    require(msg.sender == governance, "!governance");
    performanceFee = _performanceFee;
  }

  function wrapCoinAmount(uint256 amount) internal view returns (uint256[4] memory) {
    uint256[4] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
    amounts[uint56(tokenIndex)] = amount;
    return amounts;
  }

  function swusdFromWant() internal {
    uint256 wantBalance = IERC20(want).balanceOf(address(this));
    if (wantBalance > 0) {
      IERC20(want).safeApprove(curve, 0);
      IERC20(want).safeApprove(curve, wantBalance);
      // we can accept 0 as minimum because this is called only by a trusted role
      uint256 minimum = 0;
      uint256[4] memory coinAmounts = wrapCoinAmount(wantBalance);
      ISwerveFi(curve).add_liquidity(coinAmounts, minimum);
    }
    // now we have the swusd token
  }

  function deposit() public {
    // convert the entire balance not yet invested into swusd first
    swusdFromWant();

    // then deposit into the swusd vault
    uint256 swusdBalance = IERC20(swusd).balanceOf(address(this));
    if (swusdBalance > 0) {
      IERC20(swusd).safeApprove(gauge, 0);
      IERC20(swusd).safeApprove(gauge, swusdBalance);
      SSUSDGauge(gauge).deposit(swusdBalance);
    }
  }

  // Controller only function for creating additional rewards from dust
  function withdraw(IERC20 _asset) external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    require(want != address(_asset), "want");
    require(swusd != address(_asset), "swusd");
    require(swrv != address(_asset), "swrv");
    balance = _asset.balanceOf(address(this));
    _asset.safeTransfer(controller, balance);
  }

  function wantValueFromSWUSD(uint256 swusdBalance) public view returns (uint256) {
    return ISwerveFi(curve).calc_withdraw_one_coin(swusdBalance, int128(tokenIndex));
  }

  function swusdToWant(uint256 wantLimit) internal {
    uint256 swusdBalance = IERC20(swusd).balanceOf(address(this));

    // this is the maximum number of want we can get for our swusd token
    uint256 wantMaximumAmount = wantValueFromSWUSD(swusdBalance);
    if (wantMaximumAmount == 0) {
      return;
    }

    if (wantLimit < wantMaximumAmount) {
      // we want less than what we can get, we ask for the exact amount
      // now we can remove the liquidity
      uint256[4] memory tokenAmounts = wrapCoinAmount(wantLimit);
      IERC20(swusd).safeApprove(curve, 0);
      IERC20(swusd).safeApprove(curve, swusdBalance);
      ISwerveFi(curve).remove_liquidity_imbalance(tokenAmounts, swusdBalance);
    } else {
      // we want more than we can get, so we withdraw everything
      IERC20(swusd).safeApprove(curve, 0);
      IERC20(swusd).safeApprove(curve, swusdBalance);
      ISwerveFi(curve).remove_liquidity_one_coin(swusdBalance, int128(tokenIndex), 0);
    }
    // now we have want asset
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

    IERC20(want).safeTransfer(SSUSDController(controller).rewards(), _fee);
    address _vault = SSUSDController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

    IERC20(want).safeTransfer(_vault, _amount.sub(_fee));

    // invest back the rest
    deposit();
  }

  // Withdraw all funds, normally used when migrating strategies
  function withdrawAll() external returns (uint balance) {
    require(msg.sender == controller, "!controller");
    _withdrawAll();

    // we can transfer the asset to the vault
    balance = IERC20(want).balanceOf(address(this));

    if (balance > 0) {
      address _vault = SSUSDController(controller).vaults(address(want));
      require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
      IERC20(want).safeTransfer(_vault, balance);
    }
  }

  function _withdrawAll() internal {
    // withdraw all from gauge
    SSUSDGauge(gauge).withdraw(SSUSDGauge(gauge).balanceOf(address(this)));
    // convert the swusd to want, we want the entire balance
    swusdToWant(uint256(~0));
  }

  function harvest() public {
    require(msg.sender == governance, "!authorized");
    SSUSDMintr(mintr).mint(gauge);
    uint _before = IERC20(want).balanceOf(address(this));
    // claiming rewards and liquidating them
    uint256 swrvBalance = IERC20(swrv).balanceOf(address(this));
    if (swrvBalance > 0) {
      IERC20(swrv).safeApprove(uni, 0);
      IERC20(swrv).safeApprove(uni, swrvBalance);
      SSUSDUniswapRouter(uni).swapExactTokensForTokens(swrvBalance, uint(0), uniswap_swrv2want, address(this), now.add(1800));
    }
    uint _after = IERC20(want).balanceOf(address(this));
    if (_after > _before) {
      uint profit = _after.sub(_before);
      uint _fee = profit.mul(performanceFee).div(performanceMax);
      IERC20(want).safeTransfer(SSUSDController(controller).rewards(), _fee);
      deposit();
    }
  }

  function _withdrawSome(uint256 _amount) internal returns (uint) {
    uint _before = IERC20(want).balanceOf(address(this));
    // withdraw all from gauge
    SSUSDGauge(gauge).withdraw(SSUSDGauge(gauge).balanceOf(address(this)));
    // convert the swusd to want, but get at most _amount
    swusdToWant(_amount);
    uint _after = IERC20(want).balanceOf(address(this));
    return _after.sub(_before);
  }

  function balanceOfWant() public view returns (uint) {
    return IERC20(want).balanceOf(address(this));
  }

  function balanceOfPool() public view returns (uint) {
    return SSUSDGauge(gauge).balanceOf(address(this));
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
