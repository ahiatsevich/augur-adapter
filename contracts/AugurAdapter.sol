pragma solidity 0.4.24;

pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

library Order {
    using SafeMath for uint256;

    enum Types {
        Bid, Ask
    }

    enum TradeDirections {
        Long, Short
    }
}

contract ITyped {
    function getTypeName() public view returns (bytes32);
}

contract ICash is ERC20 {
    function depositEther() external payable returns(bool);
    function depositEtherFor(address _to) external payable returns(bool);
    function withdrawEther(uint256 _amount) external returns(bool);
    function withdrawEtherTo(address _to, uint256 _amount) external returns(bool);
    function withdrawEtherToIfPossible(address _to, uint256 _amount) external returns (bool);
}

contract IWETH is ERC20 {
    function deposit() external payable;    
    function withdraw(uint wad) public;
}

contract IShareToken is ITyped, ERC20 {
    function initialize(IMarket _market, uint256 _outcome) external returns (bool);
    function createShares(address _owner, uint256 _amount) external returns (bool);
    function destroyShares(address, uint256 balance) external returns (bool);
    function getMarket() external view returns (IMarket);
    function getOutcome() external view returns (uint256);
    function trustedOrderTransfer(address _source, address _destination, uint256 _attotokens) public returns (bool);
    function trustedFillOrderTransfer(address _source, address _destination, uint256 _attotokens) public returns (bool);
    function trustedCancelOrderTransfer(address _source, address _destination, uint256 _attotokens) public returns (bool);
}

interface IController {
    function lookup(bytes32 _key) external view returns(address);  
    function getAugur() public view returns (address);
}

interface ITrade {    
    function publicFillBestOrder(
        Order.TradeDirections _direction, 
        IMarket _market, 
        uint256 _outcome, 
        uint256 _amount, 
        uint256 _price, 
        uint256 _tradeGroupID) 
        external 
        payable
        returns (uint256);    

    function publicFillBestOrderWithLimit(
        Order.TradeDirections _direction, 
        IMarket _market, 
        uint256 _outcome, 
        uint256 _fxpAmount, 
        uint256 _price, 
        bytes32 _tradeGroupId, 
        uint256 _loopLimit) 
        external 
        payable 
        returns (uint256);
}

contract IMarket  {
    enum MarketType {
        YES_NO,
        CATEGORICAL,
        SCALAR
    }

    //function getFeeWindow() public view returns (IFeeWindow);
    function getNumberOfOutcomes() public view returns (uint256);
    function getNumTicks() public view returns (uint256);
    function getDenominationToken() public view returns (ICash);
    function getShareToken(uint256 _outcome)  public view returns (IShareToken);
    function isInvalid() public view returns (bool);    
}

contract IOrders {    
    function getMarket(bytes32 _orderId) public view returns (IMarket);
    function getOrderType(bytes32 _orderId) public view returns (Order.Types);
    function getOutcome(bytes32 _orderId) public view returns (uint256);
    function getAmount(bytes32 _orderId) public view returns (uint256);
    function getPrice(bytes32 _orderId) public view returns (uint256);
    function getBetterOrderId(bytes32 _orderId) public view returns (bytes32);
    function getWorseOrderId(bytes32 _orderId) public view returns (bytes32);
    function getBestOrderId(Order.Types _type, IMarket _market, uint256 _outcome) public view returns (bytes32);
    function getWorstOrderId(Order.Types _type, IMarket _market, uint256 _outcome) public view returns (bytes32);
    function getLastOutcomePrice(IMarket _market, uint256 _outcome) public view returns (uint256);    
    function isBetterPrice(Order.Types _type, uint256 _price, bytes32 _orderId) public view returns (bool);
    function isWorsePrice(Order.Types _type, uint256 _price, bytes32 _orderId) public view returns (bool);
}

/// @title AugurAdapter contract
contract AugurAdapter {
    uint256 public constant ETERNAL_APPROVAL_VALUE = 2 ** 256 - 1;
    uint256 public constant AUGUR_ORDERS_LOOP_LIMIT = 10; // TODO: @ahiatsevich check gas limit for 10 orders

    uint constant OK = 1;
    uint constant ERR_BZX_AUGUR_UNSUPPORTED_TOKEN = 420001;
    uint constant ERR_BZX_AUGUR_INSUFFICIENT_WETH_ALLOWANCE = 420002;
    uint constant ERR_BZX_AUGUR_INSUFFICIENT_STOKEN_ALLOWANCE = 420003;

    using SafeMath for uint256;

    IController public augurController;
    ICash public cash;
    IWETH public weth;

    event AugurOracleTrade(
        Order.TradeDirections direction, 
        address share,        
        uint256 value, 
        uint256 shareAmount, 
        uint256 price
    );

    event AugurOracleDeposit(address _sender, uint _amount);

    /// @dev Make sure that ETH is not stuck in OracleAdapter after function invocation 
    modifier ensureBalanceUnchanged() {
        uint initialBalance = address(this).balance;
        _;
        require(initialBalance == address(this).balance, "Balance is chanaged");
    }
    
    /// @dev Make sure that given token is not stuck in OracleAdapter after function invocation 
    modifier ensureTokenBalanceUnchanged(ERC20 token) {
        uint initialBalance = token.balanceOf(address(this));
        _;
        require(initialBalance == token.balanceOf(address(this)), "Token balance is chanaged");
    }

    /// @notice Conctructor
    /// @dev Eternal approval of `Cash` token is performed. `Augur` will be permitted to withdraw from the contract unlimited amount of Cash.
    /// @param _augurController is Augur's controller
    /// @param _cash is Cash address
    /// @param _weth is WETH address
    constructor(address _augurController, address _cash, address _weth)
    public {
        require(_augurController != address(0x0), "Invalid Augur controller address");
        require(_cash != address(0x0), "Invalid Cash address");
        require(_weth != address(0x0), "Invalid WETH address");
        
        augurController = IController(_augurController);
        cash = ICash(_cash);
        weth = IWETH(_weth);

        require(cash.approve(augurController.getAugur(), ETERNAL_APPROVAL_VALUE), "Failed to set unlimited allowance");
    }

    /// @notice Trade tokens
    function trade(
        address _src, 
        uint _srcAmount, 
        address _dest, 
        uint _maxDestAmount, 
        uint _price)             
    public
    ensureBalanceUnchanged()
    ensureTokenBalanceUnchanged(ERC20(_src))
    ensureTokenBalanceUnchanged(ERC20(_dest))
    returns (uint, uint) {        
        if(isWETHToken(_src) && isShareToken(_dest)) {
            return buyShares(IWETH(_src), _srcAmount, IShareToken(_dest), _maxDestAmount, _price);
        } else if (isShareToken(_src) && isWETHToken(_dest)) {
            return sellShares(IShareToken(_src), _srcAmount, IWETH(_dest), _maxDestAmount, _price);
        } else {
            return (ERR_BZX_AUGUR_UNSUPPORTED_TOKEN, 0);
        }              
    }

    function getExpectedRate(
        address _src, 
        address _dest, 
        uint _srcQty)         
    public
    view
    returns (uint expectedRate, uint slippageRate) {  
        // TODO: @ahiatsevich check incoming params     
             
        IOrders ordersService = getOrderService();

        IShareToken shares = isShareToken(_src) ? IShareToken(_src) : IShareToken(_dest);
            
        Order.Types orderType = calcOrderType(_src, _dest); 
        IMarket market = shares.getMarket();
        uint256 outcome = shares.getOutcome();  

        bytes32 bestOrderID = ordersService.getBestOrderId(orderType, market, outcome);
        if (bestOrderID == bytes32(0x0)) {
            return (0,0);
        }

        uint totalAmount;
        uint volume;
        do {                  
            uint price = ordersService.getPrice(bestOrderID);
            uint amount = ordersService.getAmount(bestOrderID);    
            
            totalAmount += amount;
            volume += price.mul(amount);

            bestOrderID = ordersService.getWorseOrderId(bestOrderID);            
        } while(totalAmount < _srcQty && bestOrderID != bytes32(0x0));
        
        return (volume.div(totalAmount), volume.div(totalAmount));
    }
    
    function buyShares(IWETH _weth, uint _amountWETH, IShareToken _share, uint _amountShare, uint _price) 
    internal
    returns (uint, uint) {
        // process WETH received
        if (weth.allowance(msg.sender, address(this)) < _amountWETH) {
            return (ERR_BZX_AUGUR_INSUFFICIENT_WETH_ALLOWANCE, 0);
        }
        require(weth.transferFrom(msg.sender, address(this), _amountWETH), "AugurAdapter::buyShares: Unable process WETH");
        weth.withdraw(_amountWETH);

        // do trade
        uint256 remainingShare = getTradeService().publicFillBestOrderWithLimit.value(_amountWETH)(
                                                    Order.TradeDirections.Long, 
                                                    _share.getMarket(), 
                                                    _share.getOutcome(), 
                                                    _amountShare, 
                                                    _price, 
                                                    "some_trade_group_id", 
                                                    AUGUR_ORDERS_LOOP_LIMIT);        

        // transfer bought shares to sender
        require(_share.transfer(msg.sender, _amountShare.sub(remainingShare)), "AugurAdapter::buyShares: Unable transfer shares");

        emit AugurOracleTrade(Order.TradeDirections.Long, _share, _amountWETH, _amountShare.sub(remainingShare), _price);

        return (OK, remainingShare);
    }

    function sellShares(IShareToken _share, uint _amountShare, IWETH _weth, uint _amountWETH, uint _price) 
    internal
    returns (uint, uint) {  
        // process ShareToken received
        if (_share.allowance(msg.sender, address(this)) < _amountShare) {
            return (ERR_BZX_AUGUR_INSUFFICIENT_STOKEN_ALLOWANCE, 0);
        }
        require(_share.transferFrom(msg.sender, address(this), _amountShare), "AugurAdapter::sellShares: Unable process shares");

        uint initialBalance = address(this).balance;
        // do trade
        uint256 remainingShare = getTradeService().publicFillBestOrderWithLimit(
                                    Order.TradeDirections.Short, 
                                    _share.getMarket(), 
                                    _share.getOutcome(), 
                                    _amountShare, 
                                    _price, 
                                    "some_trade_group_id", 
                                    AUGUR_ORDERS_LOOP_LIMIT);        

        // transfer remaining shares to sender
        require(_share.transfer(msg.sender, remainingShare), "AugurAdapter::sellShares: Unable transfer remaining shares");

        // transfer remaining shares to sender
        uint receivedValue = address(this).balance.sub(initialBalance);
        weth.deposit.value(receivedValue)();
        require(weth.transfer(msg.sender, receivedValue), "AugurAdapter::sellShares: Unable transfer received WETH to sender");
        

        emit AugurOracleTrade(Order.TradeDirections.Short, _share, _amountWETH, _amountShare.sub(remainingShare), _price);

        return (OK, remainingShare);
    }

    // /// BUY:  TYPE = 0, WETH -> SHARE
    // /// SELL: TYPE = 1, SHARE -> WETH    
    // function calcTradeDirection(address _src, address _dest)
    // public
    // view
    // returns (Order.TradeDirections) {
    //     if (isWETHToken(_src) && isShareToken(_dest)) {
    //         return Order.TradeDirections.Long;
    //     }
        
    //     assert(isShareToken(_src) && isWETHToken(_dest));
    //     return Order.TradeDirections.Short;
    // }

    function calcOrderType(address _src, address _dest)
    public
    view
    returns (Order.Types) {
        if (isWETHToken(_src) && isShareToken(_dest)) {
            return Order.Types.Ask;
        }
        
        assert(isShareToken(_src) && isWETHToken(_dest));
        return Order.Types.Bid;
    }

    function isWETHToken(address _token) 
    public
    view
    returns (bool) {
        return (_token == address(weth));
    }

    function isShareToken(address _token) 
    public
    view
    returns (bool result) {
        if (_token == address(0x0)) {
            return false;
        }

        // TODO: ahiatsevich: find no so dirty way to perform this check
        _token.call(abi.encodeWithSignature("getTypeName()")); 
        assembly {
            switch returndatasize
            case 32 {
                result := not(0)
            }
            default {
                result := 0
            }
        }

        result = result && IShareToken(_token).getTypeName() == bytes32("ShareToken");
        result = result && isMarketScalar(IShareToken(_token).getMarket());
    }
  
    function isMarketScalar(IMarket _market) 
    public 
    view
    returns (bool) {
        return true; // _market.getNumberOfOutcomes() == 2 && _market.getNumTicks() != 10000;
    }

    function getTradeService()
    public
    view
    returns (ITrade) {
        return ITrade(augurController.lookup("Trade"));
    }

    function getOrderService()
    public
    view
    returns (IOrders) {
        return IOrders(augurController.lookup("Orders"));
    }

    function ()
    public
    payable {
        emit AugurOracleDeposit(msg.sender, msg.value);
    }
}