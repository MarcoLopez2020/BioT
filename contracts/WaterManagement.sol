// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./WaterToken.sol";

contract WaterManagement is Ownable, AccessControl {

    address[] private entities;

    mapping(address => Entity) public addressToEntityData;

    bytes32 public constant COMPANY_ROLE = keccak256("COMPANY");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT");
    WaterToken waterToken;

    struct Entity {
        address entity;
        string name;
        string nif;
    }

    event EntityAdded(address indexed entity);

    constructor(address _waterAddress) Ownable(msg.sender) {
        waterToken = WaterToken(_waterAddress);
    }

    function addEntity(address _entityAddress, string calldata _name, string calldata _nif, string calldata _role) external onlyOwner {
        require(owner() != _entityAddress, "La direecion no es la misama qie el owner del contrato");
        Entity memory entity = Entity(_entityAddress, _name, _nif);
        addressToEntityData[_entityAddress] = entity;

        if (Strings.equal(_role, "company")) {
            waterToken.addMinter(_entityAddress);
            _grantRole(COMPANY_ROLE, _entityAddress);
        }
        if (Strings.equal(_role, "government")) {
            _grantRole(GOVERNMENT_ROLE, _entityAddress);
        }

        entities.push(_entityAddress);
        emit EntityAdded(_entityAddress);

    }

    function fetchEntities() external view returns (Entity[] memory) {
        require(hasRole(GOVERNMENT_ROLE, msg.sender) || hasRole(COMPANY_ROLE, msg.sender), "La entidad no tiene rol");

        Entity[] memory data = new Entity[](entities.length);
        // IF GOVERNMENT ROLE, RETURN ALL COMPANY ACCOUNTS
         if(hasRole(GOVERNMENT_ROLE, msg.sender)) {
            for (uint i = 0; i < entities.length;  i++) {
                if (hasRole(COMPANY_ROLE, entities [i])) {
                     (address entity, string memory name, string memory nif) = fetchEntityData(entities[i]);
                     data[i] = Entity(entity, name, nif);

                    }
                }
        }   
        
        // IF COMPANY ROLE, RETURN ONLY THEIR ACCOUNT
         if(hasRole(COMPANY_ROLE, msg.sender)) {
            for (uint i = 0; i < entities.length;  i++) {
              if (hasRole(GOVERNMENT_ROLE, entities [i])) {
                    (address entity, string memory name, string memory nif) = fetchEntityData(entities[i]);
                    data[i] = Entity(entity, name, nif);
                }
            }
         }
         return  data;
    }
    
    function fetchEntityData(address _entity) public view returns (address, string memory, string memory) {
        return (addressToEntityData[_entity].entity, addressToEntityData[_entity].name, addressToEntityData[_entity].nif);
    }

}