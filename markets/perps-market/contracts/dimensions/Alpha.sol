//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

contract Alpha {
    struct Unit {
        string name;
        uint256 value;
    }

    function add(Unit memory a, Unit memory b) public pure returns (Unit memory) {
        return Unit({name: a.name, value: a.value + b.value});
    }
}
