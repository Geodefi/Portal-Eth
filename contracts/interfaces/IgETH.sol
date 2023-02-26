// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IgETH {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function uri(uint256) external view returns (string memory);

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) external view returns (uint256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function burn(address account, uint256 id, uint256 value) external;

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) external;

    function totalSupply(uint256 id) external view returns (uint256);

    function exists(uint256 id) external view returns (bool);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function pause() external;

    function unpause() external;

    // gETH Specials

    function denominator() external view returns (uint256);

    function pricePerShare(uint256 id) external view returns (uint256);

    function priceUpdateTimestamp(uint256 id) external view returns (uint256);

    function setPricePerShare(uint256 price, uint256 id) external;

    function isInterface(
        address _interface,
        uint256 id
    ) external view returns (bool);

    function isAvoider(
        address account,
        uint256 id
    ) external view returns (bool);

    function avoidInterfaces(uint256 id, bool isAvoid) external;

    function setInterface(address _interface, uint256 id, bool isSet) external;

    function updateMinterRole(address Minter) external;

    function updatePauserRole(address Pauser) external;

    function updateOracleRole(address Oracle) external;
}
