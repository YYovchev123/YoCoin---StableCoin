// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";

contract RoleManager is IRoleManager, Ownable {

    /// @notice Entity -> Role -> hasRole
    mapping(address entity => mapping(Role role => bool hasRole)) public roles;

    /**
     * @notice Constructor
     * @param owner Owner address
     */ 
    constructor(address owner) Ownable(owner) {}

    // MODIFIERS
    /**
     * @notice Modifier that checks if the `msg.sender` has the given `role`
     * @param role Role
     */ 
    modifier onlyRole(Role role) {
        if(!hasRole(msg.sender, role)) revert InsufficientRole();
        _;
    }
    
    // PUBLIC FUNCTIONS
    /**
     * @notice Function to give a role to the specified `entity`
     * @dev Only callable by owner
     * @param entity The address that the role is given to
     * @param role Role
     */ 
    function grantRole(address entity, Role role) public onlyOwner {
        _grantRole(entity, role);
    }

    /**
     * @notice Function to revokes a role from the specified `entity`
     * @dev Only callable by owner
     * @param entity The address that the role is rovoked from
     * @param role Role
     */ 
    function revokeRole(address entity, Role role) public onlyOwner {
        _revokeRole(entity, role);
    }

    /**
     * @notice Public view function to check if `entity` has `role`
     * @param entity The address that is being checked for having the role
     * @param role Role
     */ 
    function hasRole(address entity, Role role) public view returns(bool) {
        return roles[entity][role];
    }

    // INTERNAL FUNCTIONS
    function _grantRole(address entity, Role role) internal {
        if(hasRole(entity, role)) revert AlreadyHasRole();
        roles[entity][role] = true;
        emit RoleGranted(entity, role);
    }

    function _revokeRole(address entity, Role role) internal {
        if(!hasRole(entity, role)) revert DoesNotHaveRole();
        roles[entity][role] = false;
        emit RoleRevoked(entity, role);
    }
}