//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../modules/UpgradeModule.sol";

contract UpgradeModuleMock is UpgradeModule {
    // solhint-disable-next-line private-vars-leading-underscore
    function __setOwner(address newOwner) public {
        _ownableStorage().owner = newOwner;
    }

    // solhint-disable-next-line private-vars-leading-underscore
    function __setSimulatingUpgrade(bool simulatingUpgrade) public {
        _setSimulatingUpgrade(simulatingUpgrade);
    }
}
