// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRoleManager {
    enum Role {
        ADMIN,
        UNISWAP_MANAGER,
        MINTER,
        BURNER
    }

    error InsufficientRole();
    error AlreadyHasRole();
    error DoesNotHaveRole();
    error OnlyYoCoinCore();
    error NotMinter();
    error NotBurner();
    error NotAdmin();

    event RoleGranted(address entitiy, Role role);
    event RoleRevoked(address entitiy, Role role);

    function grantRole(address entity, Role role) external;
    function revokeRole(address entity, Role role) external;
    function hasRole(address entity, Role role) external view returns(bool);
}