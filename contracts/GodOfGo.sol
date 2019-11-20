pragma solidity ^0.4.26;

// * https://godofgo.com/ - First decentralized GO learning and playing.
// *
// * @author SN, tien.tran
// * @date 01/10/2019
contract GodOfGo {
    uint public constant PIXEL_PRICE_IN_WEI = 1 ether;
    uint public constant LAND_SIZE = 1000;
    uint public constant CELL_SIZE = 10;
    uint public constant CELL_AREA = CELL_SIZE * CELL_SIZE;
    uint public constant AUTO_APPROVE_PENDING_TIME = 2 * 24 * 60 * 60; // 2 days
    uint public constant MAX_EDIT_TIME = 30 * 24 * 60 * 60; // 30 days

    uint constant MINIMUM_WAGE_AMOUNT = 1000000; // 0.01 MCASH
    uint constant MAXIMUM_COMMISSION_PERCENT = 10; // 10%
    uint constant MAXIMUM_NUM_PLAYERS = 9;

    struct Game {
        address[MAXIMUM_NUM_PLAYERS] players;
        uint8 nPlayers;
        uint8 nJoined;
        uint wageAmount;
        uint8 status; // 0-new, 1-pending, 2-finished, 3-cancelled
    }

    mapping(uint => Game) public games;
    uint public numberCreatedGames = 0;

    // Standard contract ownership transfer.
    address public owner;
    address private nextOwner;

    // Admin account.
    address public admin;

    // Standard modifier on methods invokable only by contract owner.
    modifier onlyOwner {
        require(msg.sender == owner, "OnlyOwner methods called by non-owner.");
        _;
    }

    // Standard modifier on methods invokable only by contract owner.
    modifier onlyAdmin {
        require(msg.sender == admin, "OnlyAdmin methods called by non-admin.");
        _;
    }

    // Standard modifier on methods invokable only by contract owner and admin.
    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner || msg.sender == admin, "OnlyOwnerOrAdmin methods called by non-owner/admin.");
        _;
    }

    // Standard contract ownership transfer implementation,
    function approveNextOwner(address _nextOwner) external onlyOwner {
        require(_nextOwner != owner, "Cannot approve current owner.");
        nextOwner = _nextOwner;
    }

    function acceptNextOwner() external {
        require(msg.sender == nextOwner, "Can only accept preapproved new owner.");
        owner = nextOwner;
    }

    // Change admin account.
    function setAdmin(address newAdmin) external onlyOwner {
        admin = newAdmin;
    }

    event GameCreate(uint gameId, address indexed player);
    event GameJoin(uint gameId, address indexed player, uint playerIndex);
    event GameCancel(uint gameId);
    event GameFinish(uint gameId, address indexed winner, uint payout);

    constructor() public {
        owner = msg.sender;
        admin = msg.sender;
    }

    function createGame(uint8 nPlayers) external payable returns (uint _idx) {
        require(nPlayers > 1, "nPlayers must be greater than 1");
        require(nPlayers <= MAXIMUM_NUM_PLAYERS, "nPlayers must be smaller than or equal to 9");
        require(msg.value >= MINIMUM_WAGE_AMOUNT, "wage must be greater than or equal to 0.01 MCASH");

        _idx = numberCreatedGames;
        Game storage game = games[_idx];
        game.nPlayers[0] = msg.sender;
        game.nPlayers = nPlayers;
        game.nJoined = 1;
        game.wageAmount = msg.value;
        game.status = 0;

        emit GameCreate(_idx, msg.sender);
        emit GameJoin(_idx, msg.sender, 0);

        return _idx;
    }

    function joinGame(uint gameId) external payable returns (uint playerIndex) {
        require(gameId >= numberCreatedGames, "There is no game with this gameId");
        Game storage game = games[gameId];
        require(game.status != 0, "This game is not available to join");
        require(msg.value >= game.wageAmount, "Not sending enough wage");

        playerIndex = game.nJoined;
        game.nJoined = playerIndex + 1;
        game.nPlayers[playerIndex] = msg.sender;

        if (playerIndex + 1 == game.nPlayers) {
            game.status = 1;
        }

        emit GameJoin(gameId, msg.sender, playerIndex);

        return playerIndex;
    }

    function cancelGame(uint gameId) external onlyOwnerOrAdmin {
        require(gameId >= numberCreatedGames, "There is no game with this gameId");
        Game storage game = games[gameId];
        require(game.status == 0 || game.status == 1, "This game is no longer cancellable");

        for (uint8 i = 0; i < game.nJoined; i++) {
            address player = game.players[i];
            player.send(game.wageAmount);
        }

        game.status = 3;

        emit GameCancel(gameId);
    }

    function finishGame(uint gameId, address payable winner, uint8 commissionPercent) external onlyOwnerOrAdmin {
        require(gameId >= numberCreatedGames, "There is no game with this gameId");
        Game storage game = games[gameId];
        require(game.status == 1, "This game is no longer pending");
        require(commissionPercent <= MAXIMUM_COMMISSION_PERCENT, "commissionPercent should not be greater than 10%");

        uint totalAmount = game.wageAmount * game.nPlayers;
        uint commission = totalAmount * commissionPercent / 100;
        uint payout = totalAmount - commission;

        winner.send(payout);

        emit GameFinish(gameId, winner, payout);
    }
}
