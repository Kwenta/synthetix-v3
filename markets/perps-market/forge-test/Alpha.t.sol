//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {Cannon, Vm, Test} from "cannon-std/Cannon.sol";

import {Alpha} from "../contracts/dimensions/Alpha.sol";
import {PerpsAccountModule} from "../contracts/modules/PerpsAccountModule.sol";

contract AlphaTest is Test {
    using Cannon for Vm;

    PerpsAccountModule internal perpsAccountModule;
    Alpha internal alpha;

    function setUp() public {
        perpsAccountModule = PerpsAccountModule(vm.getAddress("PerpsAccountModule"));
        alpha = Alpha(vm.getAddress("Alpha"));
    }

    function test_alpha() public pure {
        assert(1 == 1);
    }
}
