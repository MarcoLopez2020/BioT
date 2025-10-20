// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./WaterToken.sol";

contract WaterManagement is Ownable, AccessControl {

    uint private requestId;
    address[] private entities;
    mapping(address => uint[]) private companyToRequest;
    mapping(address => uint[]) private govToRequest;
    mapping(address => string[]) private companyToSensorIds;
    mapping(address => Entity) private addressToEntityData;
    mapping(uint => Request) private requestIdToRequest;
    mapping(address => Site[]) private companyToSites;
    mapping(address => SensorData[]) private companyToSensorData;


    bytes32 public constant COMPANY_ROLE = keccak256("COMPANY");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT");
    WaterToken waterToken;

    struct Entity {
        address entity;
        string name;
        string nif;
    }

    struct Request {
        uint id;
        address company;
        address gov;
        bool answered;
        Status status;
    }

    struct Site{
        string siteId;
        string latitude;
        string longitude;
        uint benchmark;
    }

    
    struct SensorData{
        string sensorId;
        string siteId;
        uint value;
        uint timestamp;
    }

    enum Status {
        PENDING,
        APPROVED,
        DENIED
    }

    
    event EntityAdded(address indexed entity);
    event DataRequested(address indexed company, address indexed government);

    constructor(address _waterAddress) Ownable(msg.sender) {
        waterToken = WaterToken(_waterAddress);
        requestId = 1;
    }

    modifier onlyCompany(address _company) {
        require(
            hasRole(COMPANY_ROLE, _company),
            "La direecion no es el rol de Company"
        );
        _;
    }

        modifier onlyGovernment(address _government) {
        require(
            hasRole(GOVERNMENT_ROLE, _government),
            "La direecion no es GOVERNMENT"
        );
        _;
    }

    function addEntity(
        address _entityAddress,
        string calldata _name,
        string calldata _nif,
        string calldata _role
    ) external onlyOwner {
        require(
            owner() != _entityAddress,
            "La direecion no es la misama qie el owner del contrato"
        );
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
        require(
            hasRole(GOVERNMENT_ROLE, msg.sender) ||
                hasRole(COMPANY_ROLE, msg.sender),
            "La entidad no tiene rol"
        );

        Entity[] memory data = new Entity[](entities.length);
        // IF GOVERNMENT ROLE, RETURN ALL COMPANY ACCOUNTS
        if (hasRole(GOVERNMENT_ROLE, msg.sender)) {
            for (uint i = 0; i < entities.length; i++) {
                if (hasRole(COMPANY_ROLE, entities[i])) {
                    (
                        address entity,
                        string memory name,
                        string memory nif
                    ) = fetchEntityData(entities[i]);
                    data[i] = Entity(entity, name, nif);
                }
            }
        }

        // IF COMPANY ROLE, RETURN ONLY THEIR ACCOUNT
        if (hasRole(COMPANY_ROLE, msg.sender)) {
            for (uint i = 0; i < entities.length; i++) {
                if (hasRole(GOVERNMENT_ROLE, entities[i])) {
                    (
                        address entity,
                        string memory name,
                        string memory nif
                    ) = fetchEntityData(entities[i]);
                    data[i] = Entity(entity, name, nif);
                }
            }
        }
        return data;
    }

    function fetchEntityData(
        address _entity
    ) public view returns (address, string memory, string memory) {
        return (
            addressToEntityData[_entity].entity,
            addressToEntityData[_entity].name,
            addressToEntityData[_entity].nif
        );
    }

    function createRequest(
        address _company
    ) external onlyGovernment(msg.sender) returns (bool) {
        Request memory request = Request(
            requestId,
            _company,
            msg.sender,
            false,
            Status.PENDING
        );
        requestIdToRequest[requestId] = request;
        companyToRequest[_company].push(requestId);
        govToRequest[msg.sender].push(requestId);
        requestId += 1;
        emit DataRequested(_company, msg.sender);
        return true;
    }
    function answerRequest(uint _requestld, string calldata _newStatus) external onlyCompany(msg.sender){
        if (Strings.equal(_newStatus, "aprovado" )){
            requestIdToRequest [_requestld].status = Status.APPROVED;
        }else {
            requestIdToRequest[_requestld].status= Status.DENIED;
        }
        requestIdToRequest[_requestld].answered = true;
    }
    
    function checkRequestExists(address _company) external view onlyGovernment (msg. sender) returns(uint){
        uint[] memory ids = govToRequest[msg.sender];
           for (uint i = 0; i < ids.length; i++) {
                if (requestIdToRequest[ids[i]].company == _company && requestIdToRequest[ids[i]].gov == msg.sender) {
                    return ids[i];
                }
            }
        return 0;
    }

    function fetchRequestStatus(uint _requestId) external view onlyGovernment(msg. sender) returns(Status){
    return requestIdToRequest[_requestId].status;
    }

    function fetchRequests() external view onlyCompany (msg.sender) returns (Request[] memory){
        Request[] memory requests = new Request[] (companyToRequest [msg. sender] . length);
        uint[] memory ids = companyToRequest[msg.sender] ;
        for (uint i = 0; i < ids.length; i++) {
            requests [i] = requestIdToRequest[ids[i]];
        }
       return requests;
    }

    function fetchRequestData(uint _requestId) external view returns (address, address, bool, Status) {
        return (
        requestIdToRequest [_requestId].company,
        requestIdToRequest [_requestId].gov,
        requestIdToRequest [_requestId].answered,
        requestIdToRequest [_requestId].status    
        );
    }

    function registerSensor(string calldata _sensorId) external onlyCompany(msg.sender) {
        companyToSensorIds[msg.sender].push(_sensorId) ;
    }

    function registerSite(string calldata _siteId, string calldata _latitude, string calldata _longitude, uint _benchmark) external onlyCompany(msg.sender) {
         companyToSites[msg.sender].push(Site( _siteId, _latitude, _longitude, _benchmark));
    }

    function pushData (string calldata _sensorId, string calldata _siteId, uint _value, uint _timestamp) external onlyCompany(msg.sender) returns(bool)  {
        require (bytes ( _sensorId).length > 0, "Sensor ID data cannot be NULL" ) ;
        require (bytes ( _siteId).length > 0, "Site ID data cannot be NULL" ) ;
        require(_value > 0, "Mas de 0 litros de agua");
       require(_timestamp > 0, "Tiempo no puede ser 0");

        uint benchmark = checkSiteToCompany(_siteId, msg. sender) ;
        if (checkSensorIdToCompany(_sensorId, msg. sender) && benchmark !=0){
            SensorData memory sensorData = SensorData(_sensorId, _siteId, _value, _timestamp);
            companyToSensorData[msg.sender].push(sensorData) ;

            return true;
        }else{
            return false;
        }
    }

    function checkSensorIdToCompany(string calldata _sensorId, address _company) private view returns (bool) {
        string[] memory ids = companyToSensorIds[_company];
        for (uint i = 0; i < ids.length; i++){
          if (Strings.equal(ids[i], _sensorId)) {
            return true;  
            }
        }
        return false;
    }

        function checkSiteToCompany(string calldata _siteId, address _company) private view returns (uint) {
        Site[] memory sites = companyToSites[_company];
        for (uint i = 0; i < sites.length; i++){
          if (Strings.equal(sites[i].siteId, _siteId)) {
            return sites[i].benchmark;  
            }
        }
        return 0;
    }
}       