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

contract AugurAdapter {
    using SafeMath for uint256;

    IController public augurController;
    ICash public cash;

    constructor(address _augurController, address _cash)
    public {
        require(_augurController != address(0x0), "Invalid Augur controller address");
        require(_cash != address(0x0), "Invalid ICash address");
        
        augurController = IController(_augurController);
        cash = ICash(_cash);
    }

    function approve(address _token, address _to, uint256 _amount)
    public
    returns (bool) {
        return ERC20(_token).approve(_to, _amount);
    }

    function withdraw(address _token, uint256 _amount)
    public
    returns (bool) {
        return ERC20(_token).transfer(msg.sender, _amount);
    }
    
    function trade(
        address _src, 
        uint _srcAmount, 
        address _dest, 
        address _destAddress, 
        uint _maxDestAmount, 
        uint _price) 
    public
    payable 
    returns (uint) {
            // checkpoint: there should be only Cash-ShareToken pair
            require((isCashToken(_src) && isShareToken(_dest)) || 
                    (isShareToken(_src) && isCashToken(_dest)), 
                    "AugurAdapter::trade: unsupported token pair");

            // calculate trade params            
            IShareToken shares = isShareToken(_src) ? IShareToken(_src) : IShareToken(_dest);
            
            Order.TradeDirections direction = calcTradeDirection(_src, _dest); 
            IMarket market = shares.getMarket();
            uint256 outcome = shares.getOutcome();                        
            uint256 tradeGroupID = 1;
            
            // trade with Augur
            ITrade tradeService = ITrade(augurController.lookup("Trade"));
            uint256 sharesAmount = tradeService.publicFillBestOrder(direction, market, outcome, _maxDestAmount, _price, tradeGroupID);        

            return sharesAmount;
    }

    function getExpectedRate(
        address _src, 
        address _dest, 
        uint _srcQty)         
    public
    view
    returns (uint expectedRate, uint slippageRate) {            
        IOrders ordersService = IOrders(augurController.lookup("Orders"));

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

    function calcTradeDirection(address _src, address _dest)
    public
    view
    returns (Order.TradeDirections) {
        if (isCashToken(_src) && isShareToken(_dest)) {
            return Order.TradeDirections.Long;
        }
        
        assert(isShareToken(_src) && isCashToken(_dest));
        return Order.TradeDirections.Short;
    }

    function calcOrderType(address _src, address _dest)
    public
    view
    returns (Order.Types) {
        if (isCashToken(_src) && isShareToken(_dest)) {
            return Order.Types.Ask;
        }
        
        assert(isShareToken(_src) && isCashToken(_dest));
        return Order.Types.Bid;
    }

    function isTokenSupported(address _token) 
    public
    view
    returns (bool) {
        return isCashToken(_token) || isShareToken(_token);
    }

    function isCashToken(address _token) 
    public
    view
    returns (bool) {
        if (_token == address(0x0)) {
            return false;
        }
        
        return (_token == address(cash));
    }

    function isShareToken(address _token) 
    public
    view
    returns (bool) {
        if (_token == address(0x0)) {
            return false;
        }
        
        return _token.call.value(0)(bytes4(keccak256('getTypeName()')))
                && IShareToken(_token).getTypeName() == "ShareToken";
    }
}