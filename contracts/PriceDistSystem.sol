// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrizeDistribution is VRFConsumerBase, Ownable {
    // Chainlink VRF variables
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    // ERC20 token
    IERC20 public token;

    // Participant structure
    struct Participant {
        uint256 entries;
        bool registered;
    }

    // Mapping of participant address to Participant struct
    mapping(address => Participant) public participants;

    // Total number of registered participants
    //uint256 public ParticipantsCount = 0;
    uint256 public totalParticipants;

    //Array to record Participants
    //uint256[] public TotalParticipants;

    // Prize distribution event
    event PrizeDistributionEvent(uint256 indexed randomNumber, address[] winners, uint256[] rewards);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address _tokenAddress,
        address _owner
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken)
        Ownable(_owner)
    {
        keyHash = _keyHash;
        fee = _fee;
        token = IERC20(_tokenAddress);
    }

    // Register participant
    function register() external {
        require(!participants[msg.sender].registered, "Already registered");
        participants[msg.sender].registered = true;
        totalParticipants ++;
        //TotalParticipants.push(ParticipantsCount);
    }

    // Submit activity and earn entries
    function submitActivity(uint256 _entries) external {
        require(participants[msg.sender].registered, "Not registered");
        participants[msg.sender].entries += _entries;
    }

    // Trigger prize distribution
    function triggerPrizeDistribution(uint256 _numberOfWinners, uint256 _prizePool) external onlyOwner {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK balance for VRF");
        require(_numberOfWinners > 0 && _numberOfWinners <= 10, "Invalid number of winners");
        require(_prizePool > 0 && _prizePool <= token.balanceOf(address(this)), "Invalid prize pool");

        // Request randomness from Chainlink VRF
        requestRandomness(keyHash, fee);

        // Emit event for transparency
        emit PrizeDistributionEvent(randomResult, selectWinners(_numberOfWinners), calculateRewards(_numberOfWinners, _prizePool, selectWinners(_numberOfWinners)));
    }

    // Callback function used by Chainlink VRF
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }

        // Select winners based on random number
    function selectWinners(uint256 _numberOfWinners) internal view returns (address[] memory) {
        address[] memory winners = new address[](_numberOfWinners);
        uint256 totalRegisteredParticipants = totalParticipants;

        // Ensure we have enough participants for the given number of winners
        require(totalRegisteredParticipants >= _numberOfWinners, "Not enough participants");

        // Randomly select winners from registered participants
        uint256[] memory selectedIndices = new uint256[](_numberOfWinners);
        for (uint256 i = 0; i < _numberOfWinners; i++) {
            uint256 selectedIndex = randomResult % totalRegisteredParticipants;

            // Find an unselected index
            for (uint256 j = 0; j < i; j++) {
                require(selectedIndices[j] != selectedIndex, "Duplicate winner");
            }

            selectedIndices[i] = selectedIndex;
            winners[i] = getAddressAtIndex(selectedIndex);
        }

        return winners;
    }

    // Calculate rewards for winners
    function calculateRewards(uint256 _numberOfWinners, uint256 _prizePool, address[] memory _winners) internal view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](_numberOfWinners);
        uint256 allEntries = totalEntries();

        for (uint256 i = 0; i < _numberOfWinners; i++) {
            rewards[i] = (_prizePool * participants[_winners[i]].entries) / allEntries;
        }

        return rewards;
    }

    // Get participant address at a given index
    function getAddressAtIndex(uint256 _index) internal view returns (address) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalParticipants; i++) {
            if (participants[address(i)].registered) {
                if (count == _index) {
                    return address(i);
                }
                count++;
            }
        }
        revert("Invalid index");
    }

    // Total number of entries
    function totalEntries() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < totalParticipants; i++) {
            total += participants[address(i)].entries;
        }
        return total;
    }

    // Distribute ERC20 tokens to winners
    function distributeTokens(address[] memory _winners, uint256[] memory _rewards) internal {
        for (uint256 i = 0; i < _winners.length; i++) {
            token.transfer(_winners[i], _rewards[i]);
        }
    }
}
