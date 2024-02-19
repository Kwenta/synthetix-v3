//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

contract SomeUnit {
    struct SomeStruct {
        string name;
        uint256 value;
    }

    function add(SomeStruct memory a, SomeStruct memory b) public pure returns (SomeStruct memory) {
        return SomeStruct({name: a.name, value: a.value + b.value});
    }
}
