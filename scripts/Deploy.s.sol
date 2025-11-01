// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StableWrapper} from "../src/StableWrapper.sol";
import {console2} from "forge-std/console2.sol";
import {StreamVault} from "../src/StreamVault.sol";
import {Vault} from "../src/lib/Vault.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Asset
        address asset = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; 
        string memory name = "Grizzly USD"; 
        string memory symbol = "grzUSD";
        uint8 underlyingDecimals = 6;
        address keeper = deployer;

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        //
        // Deploy StableWrapper
        //
        console2.log("Deploying StableWrapper...");
        StableWrapper wrapper = new StableWrapper(
            asset,
            name,
            symbol,
            underlyingDecimals,
            keeper
        );
        console2.log("StableWrapper deployed to:", address(wrapper));

        //
        // Deploy StreamVault
        //
        Vault.VaultParams memory vaultParams = Vault.VaultParams({
            decimals: 8,
            cap: 100 * 10**8, // 100 BTC cap
            minimumSupply: 1 * 10**4 // 0.05 BTC minimum
        });

        console2.log("Deploying StreamVault...");
        StreamVault vault = new StreamVault(
            "Staked Grizzly USD", // name
            "sgrzUSD", // symbol
            address(wrapper), // stableWrapper
            vaultParams // vaultParams
        );
        console2.log("StreamVault deployed to:", address(vault));

        //
        // Transfer StableWrapper ownership to vault
        //
        wrapper.setKeeper(address(vault));
        console2.log("StableWrapper keeper transferred to vault");

        vm.stopBroadcast();

        console2.log("\nDeployment Summary:");
        console2.log("-------------------");
        console2.log("StableWrapper:", address(wrapper));
        console2.log("StreamVault:", address(vault));
    }
}