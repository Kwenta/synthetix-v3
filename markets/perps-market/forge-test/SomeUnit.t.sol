//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "forge-std/Test.sol";
// import "cannon-std/Cannon.sol";

contract SomeUnitTest is Test {
    // using Cannon for Vm;

    function setUp() public {
        /// @custom:todo fetch contract deployment from cannon deployment
    }

    function test_poc_0() public pure {
        assert(1 == 1);
    }
}
