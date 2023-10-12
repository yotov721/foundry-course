// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNFT is Script {
    function run() external returns (MoodNFT) {
        string memory happySvg = vm.readFile("./img/dynamicNft/happy.svg");
        string memory sadSvg = vm.readFile("./img/dynamicNft/sad.svg");
        // console.log(happySvg);
        // console.log(sadSvg);

        vm.startBroadcast();
        MoodNFT moodNft = new MoodNFT(
            svgToImageURI(happySvg),
            svgToImageURI(sadSvg)
        );
        vm.stopBroadcast();
        return moodNft;
    }

    function svgToImageURI(
        string memory svg
    ) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(svg)))
        );

        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }
}
