// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "./IRewardDistributionRecipient.sol";
import "./LPTokenWrapper.sol";

contract PloutoRewards is LPTokenWrapper, IRewardDistributionRecipient {
  IERC20 public plu;
  uint256 public constant DURATION = 60 days;

  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;
  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  constructor (address _lp, address _plu) public LPTokenWrapper(_lp) {
    plu = IERC20(_plu);
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    return Math.min(block.timestamp, periodFinish);
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply() == 0) {
      return rewardPerTokenStored;
    }
    return rewardPerTokenStored.add(
        lastTimeRewardApplicable()
          .sub(lastUpdateTime)
          .mul(rewardRate)
          .mul(1e18)
          .div(totalSupply())
    );
  }

  function earned(address account) public view returns (uint256) {
    return balanceOf(account)
      .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
      .div(1e18)
      .add(rewards[account]);
  }

  // stake visibility is public as overriding LPTokenWrapper's stake() function
  function stake(uint256 amount) public updateReward(msg.sender) {
    require(amount > 0, "Cannot stake 0");
    super.stake(amount);
    emit Staked(msg.sender, amount);
  }

  function withdraw(uint256 amount) public updateReward(msg.sender) {
    require(amount > 0, "Cannot withdraw 0");
    super.withdraw(amount);
    emit Withdrawn(msg.sender, amount);
  }

  function exit() external {
    withdraw(balanceOf(msg.sender));
    getReward();
  }

  function getReward() public updateReward(msg.sender) {
    uint256 reward = earned(msg.sender);
    if (reward > 0) {
      rewards[msg.sender] = 0;
      plu.safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  function notifyRewardAmount(uint256 reward)
      external
      onlyRewardDistribution
      updateReward(address(0)) {
    if (block.timestamp >= periodFinish) {
      rewardRate = reward.div(DURATION);
    } else {
      uint256 remaining = periodFinish.sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRate);
      rewardRate = reward.add(leftover).div(DURATION);
    }
    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp.add(DURATION);
    emit RewardAdded(reward);
  }
}
