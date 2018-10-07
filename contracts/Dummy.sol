pragma solidity ^0.4.24;

contract Dummy {
    event DummyEvent(address sender);

    function testDummy()
    public {
        emit DummyEvent(msg.sender);
    }
}