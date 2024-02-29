// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

//importing contract
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./Initializable.sol";
import "./IERC20.sol";

contract TokenStaking is Ownable, ReentrancyGuard, Initializable {
    // struct to store the users details
    struct User {
        uint256 stakeAmount;
        uint256 rewardAmount;
        uint256 lastStakeTime;
        uint256 lastRewardCalculationTime;
        uint256 rewardsClaimedSoFar;
    }

    uint256 _minimumStakingAmount;

    uint256 _maxStakeTokenLimit;

    uint256 _stakeEndDate;

    uint256 _stakeStartDate;

    uint256 _totalStakedTokens;

    uint256 _totalUsers;

    uint256 _stakeDays;

    uint256 _earlyUnstakeFeePercentage;

    bool _isStakingPaused;

    address private _tokenAddress;

    //APY
    uint256 _apyRate;

    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;
    uint256 public constant APY_RATE_CHANGE_THRESHOLD = 10;

    // user address
    mapping(address => User) private _users;

    event Stake(address indexed user, uint256 amount);
    event UnStake(address indexed user, uint256 amount);
    event EarlyUnStakeFee(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    modifier whenTreasuryHasBalance(uint256 amount) {
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) >= amount,
            "TokenStaking: insufficient funds in the treasury"
        );
        _;
    }

    function initialize(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit_,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) public virtual initializer {
        __TokenStaking_init_unChained(
            owner_,
            tokenAddress_,
            apyRate_,
            minimumStakingAmount_,
            maxStakeTokenLimit_,
            stakeStartDate_,
            stakeEndDate_,
            stakeDays_,
            earlyUnstakeFeePercentage_
        );
    }

    function __TokenStaking_init_unChained(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit_,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) internal onlyInitializing {
        require(
            _apyRate <= 10000,
            "TokenStaking: apy rate should be less than 10000"
        );
        require(stakeDays_ > 0, "TokenStaking: stake days must be non-zero");
        require(
            tokenAddress_ != address(0),
            "TokenStaking: token address cannot be 0 address"
        );
        require(
            stakeStartDate_ < stakeEndDate_,
            "TokenStaking: start date must be less than end date"
        );

        _transferOwnership(owner_);
        _tokenAddress = tokenAddress_;
        _apyRate = apyRate_;
        _minimumStakingAmount = minimumStakingAmount_;
        _maxStakeTokenLimit = maxStakeTokenLimit_;
        _stakeStartDate = stakeStartDate_;
        _stakeEndDate = stakeEndDate_;
        _stakeDays = stakeDays_ * 1 days;
        _earlyUnstakeFeePercentage = earlyUnstakeFeePercentage_;
    }

    /* View Methods Start */

    /**
     * @notice this function is used to get the minimum staking amount
     */
    function getMinimumStakingAmount() external view returns (uint256) {
        return _minimumStakingAmount;
    }

    /**
     * @notice this for get the maximum
     */
    function getMaxStakingTokenLimit() external view returns (uint256) {
        return _maxStakeTokenLimit;
    }

    /**
     * @notice this for get the staking start
     */
    function getStakeStartDate() external view returns (uint256) {
        return _stakeStartDate;
    }

    /**
     * @notice this for get the staking end
     */
    function getStakeEndDate() external view returns (uint256) {
        return _stakeEndDate;
    }

    /**
     * @notice this for get the total staked token
     */
    function getTotalStakedTokens() external view returns (uint256) {
        return _totalStakedTokens;
    }

    /**
     * @notice this for get the total no of users
     */

    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }

    /**
     * @notice this for get the stake days
     */

    function getStakeDays() external view returns (uint256) {
        return _stakeDays;
    }

    /**
     * @notice this for get the early enstake fee
     */

    function getEarlyUnstakeFeePercentage() external view returns (uint256) {
        return _earlyUnstakeFeePercentage;
    }

    /**
     * @notice this for get the staking status
     */

    function getStakingStatus() external view returns (bool) {
        return _isStakingPaused;
    }

    /**
     * @notice this for get the current apy rate
     * @return Current APY Rate
     */

    function getApy() external view returns (uint256) {
        return _apyRate;
    }

    // /**
    //  * @notice this function is used to get the msg.sender's estimated rewards amount
    //  * @return msg.sender's estimated rewards amount
    //  */

    function getUserEstimatedRewards() external view returns (uint256) {
        (uint256 amount, ) = _getUserEstimatedRewards(msg.sender);
        return _users[msg.sender].rewardAmount + amount;
    }

    /**
     * @notice this for get withdrawable amount from the contract
     */

    function getWithdrawableAmount() external view returns (uint256) {
        return
            IERC20(_tokenAddress).balanceOf(address(this)) - _totalStakedTokens;
    }

    /**
     * @notice this for get user details
     * @param userAddress user address to get details
     * @return User struct
     */

    function getUser(address userAddress) external view returns (User memory) {
        return _users[userAddress];
    }

    /**
     * @notice this for check if user is a stake holded
     * @param _user address of the user to check
     * @return True if user is a StakeHolder
     */
    function isStakeHolder(address _user) external view returns (bool) {
        return _users[_user].stakeAmount != 0;
    }

    /* view methods end */

    /* Owner Methods Start */

    /**
     * @notice this for update minimum staking amount
     */
    function updateMinimumStakingAmount(uint256 newAmount) external onlyOwner {
        _minimumStakingAmount = newAmount;
    }

    /**
     * @notice this for max staking amount
     */
    function updateMaximumStakingAmount(uint256 newAmount) external onlyOwner {
        _maxStakeTokenLimit = newAmount;
    }

    /**
     * @notice this for update staking end date
     */
    function updateStakingEndDate(uint256 newDate) external onlyOwner {
        _stakeEndDate = newDate;
    }

    /**
     * @notice this for update early unstake fee
     */
    function updateEarlyUnstakeFeePercentage(
        uint256 newPercentage
    ) external onlyOwner {
        _earlyUnstakeFeePercentage = newPercentage;
    }

    /**
     * @notice this for stake tokens for specific user
     * @dev stake tokens for specific users
     * @param amount the amount to stake
     * @param user user's address
     */
    function stakeForUser(
        uint256 amount,
        address user
    ) external onlyOwner nonReentrant {
        _stakeTokens(amount, user);
    }

    /**
     * @notice this for enable/disable staking
     * @dev toggle staking status
     */
    function toggleStakingStatus() external onlyOwner {
        _isStakingPaused = !_isStakingPaused;
    }

    /**
     * @notice this for withdraw specified amount if possible
     * @dev withdraw available tokens
     * @param amount withdraw amount
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(
            this.getWithdrawableAmount() >= amount,
            "TokenStaking: not enough withdrawable tokens"
        );
        IERC20(_tokenAddress).transfer(msg.sender, amount);
    }

    /* Owner Methods End */

    /* User Methdos Start */

    /**
     * @notice this for stake tokens
     * @param _amount to be staked
     */
    function stake(uint256 _amount) external nonReentrant {
        _stakeTokens(_amount, msg.sender);
    }

    function _stakeTokens(uint256 _amount, address user_) private {
        require(!_isStakingPaused, "TokenStaking: staking is paused");

        uint256 currentTime = getCurretTime();
        require(
            currentTime > _stakeStartDate,
            "TokenStaking: staking not started yet"
        );
        require(currentTime < _stakeEndDate, "TokenStaking: staking ended");
        require(
            _totalStakedTokens + _amount <= _maxStakeTokenLimit,
            "TokenStaking:max staking token limit is reached"
        );
        require(_amount > 0, "TokenStaking: stake amount must be non-zero");
        require(
            _amount >= _minimumStakingAmount,
            "TokenStaking: stake amount must greater than minimum amount allowed"
        );
        if (_users[user_].stakeAmount != 0) {
            _calculateRewards(user_);
        } else {
            _users[user_].lastRewardCalculationTime = currentTime;
            _totalUsers += 1;
        }

        _users[user_].stakeAmount += _amount;
        _users[user_].lastStakeTime = currentTime;

        _totalStakedTokens += _amount;

        require(
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "TokenStaking: failed to transfer tokens"
        );
        emit Stake(user_, _amount);
    }

    /**
     * @notice this for unstake tokens
     * @param _amount to be unstaked
     */
    function unstake(
        uint256 _amount
    ) external nonReentrant whenTreasuryHasBalance(_amount) {
        address user = msg.sender;

        require(_amount != 0, "TokenStaking: amount should be non-zero");
        require(this.isStakeHolder(user), "TokenStaking: not a stakeholder");
        require(
            _users[user].stakeAmount >= _amount,
            "TokenStaking: not enough stake to unstake"
        );

        //calculate users rewards untill now
        _calculateRewards(user);

        uint256 feeEarlyUnstake;

        if (getCurretTime() <= _users[user].lastStakeTime + _stakeDays) {
            feeEarlyUnstake = ((_amount * _earlyUnstakeFeePercentage) /
                PERCENTAGE_DENOMINATOR);
            emit EarlyUnStakeFee(user, feeEarlyUnstake);
        }

        uint256 amountToUnstake = _amount - feeEarlyUnstake;

        _users[user].stakeAmount -= _amount;

        _totalStakedTokens -= _amount;

        if (_users[user].stakeAmount == 0) {
            // delete _users[user];
            _totalUsers -= 1;
        }

        require(
            IERC20(_tokenAddress).transfer(user, amountToUnstake),
            "TokenStaking: failed to transfer"
        );
        emit UnStake(user, _amount);
    }

    /**
     * @notice this for claim users rewards
     */
    function claimReward()
        external
        nonReentrant
        whenTreasuryHasBalance(_users[msg.sender].rewardAmount)
    {
        _calculateRewards(msg.sender);
        uint256 rewardAmount = _users[msg.sender].rewardAmount;

        require(rewardAmount > 0, "TokenStaking: no reward to claim");

        require(
            IERC20(_tokenAddress).transfer(msg.sender, rewardAmount),
            "tpkenStaking: failed to transfer"
        );

        _users[msg.sender].rewardAmount = 0;
        _users[msg.sender].rewardsClaimedSoFar += rewardAmount;

        emit ClaimReward(msg.sender, rewardAmount);
    }

    /* User Methods End*/

    /* Private Helper Methods Start */

    /**
     * @notice this for calculate rewards for a user
     * @param _user address of the user
     */
    function _calculateRewards(address _user) private {
        (uint256 userReward, uint256 currentTime) = _getUserEstimatedRewards(
            _user
        );

        _users[_user].rewardAmount += userReward;
        _users[_user].lastRewardCalculationTime = currentTime;
    }

    /**
     * @notice this for get estimated rewards for a user
     * @param _user address of the user
     * @return Estimated rewards for the user
     */
    function _getUserEstimatedRewards(
        address _user
    ) private view returns (uint256, uint256) {
        uint256 userReward;
        uint256 userTimestamp = _users[_user].lastRewardCalculationTime;

        uint256 currentTime = getCurretTime();

        if (currentTime > _users[_user].lastStakeTime + _stakeDays) {
            currentTime = _users[_user].lastStakeTime + _stakeDays;
        }
        uint256 totalStakedTime = currentTime - userTimestamp;

        userReward +=
            ((totalStakedTime * _users[_user].stakeAmount * _apyRate) /
                365 days) /
            PERCENTAGE_DENOMINATOR;

        return (userReward, currentTime);
    }

    function getCurretTime() internal view returns (uint256) {
        return block.timestamp;
    }
}
