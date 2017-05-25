pragma solidity 0.4.8;
import "./Proxy.sol";

contract IdentityManager {
  uint adminRate;

  event IdentityCreated(
    address indexed identity,
    address indexed creator,
    address owner,
    address indexed recoveryKey);

  event OwnerAdded(
    address indexed identity,
    address indexed owner,
    address instigator);

  event OwnerRemoved(
    address indexed identity,
    address indexed owner,
    address instigator);

  event RecoveryChanged(
    address indexed identity,
    address indexed recoveryKey,
    address instigator);

  mapping(address => mapping(address => uint)) owners;
  mapping(address => address) recoveryKeys;
  mapping(address => mapping(address => uint)) limiter;

  modifier onlyOwner(address identity) { 
    if (owners[identity][msg.sender] > 0 && owners[identity][msg.sender] <= now ) _ ;
    else throw; 
  }

  modifier onlyRecovery(address identity) { 
    if (recoveryKeys[identity] == msg.sender) _ ;
    else throw;
  }

  modifier rateLimited(Proxy identity) {
    if (limiter[identity][msg.sender] < (now - adminRate)) {
      limiter[identity][msg.sender] = now;
      _ ;
    } else throw;
  }

  // Instantiate IdentityManager with the following limits:
  // - adminRate - Time period used for rate limiting a given key for admin functionality
  function IdentityManager(uint _adminRate) {
    adminRate = _adminRate;
  }

  // Factory function
  // gas 289,311
  function CreateIdentity(address owner, address recoveryKey) {
    Proxy identity = new Proxy();
    owners[identity][owner] = now; // This is to ensure original owner has full power from day one
    recoveryKeys[identity] = recoveryKey;
    IdentityCreated(identity, msg.sender, owner,  recoveryKey);
  }

  // An identity Proxy can use this to register itself with the IdentityManager
  // Note they also have to change the owner of the Proxy over to this, but after calling this
  function registerIdentity(address owner, address recoveryKey) {
    if (owners[msg.sender][owner] > 0 || recoveryKeys[msg.sender] > 0 ) throw; // Deny any funny business
    owners[msg.sender][owner] = now; // This is to ensure original owner has full power from day one
    recoveryKeys[msg.sender] = recoveryKey;
    IdentityCreated(msg.sender, msg.sender, owner, recoveryKey);
  }

  // Primary forward function
  function forwardTo(Proxy identity, address destination, uint value, bytes data) onlyOwner(identity) {
    identity.forward(destination, value, data);
  }

  // an owner can add a new device instantly
  function addOwner(Proxy identity, address newOwner) onlyOwner(identity) rateLimited(identity) {
    owners[identity][newOwner] = now;
    limiter[identity][newOwner] = now;
    OwnerAdded(identity, newOwner, msg.sender);
  }

  // a recovery key owner can add a new device with 1 days wait time
  function addOwnerForRecovery(Proxy identity, address newOwner) onlyRecovery(identity) rateLimited(identity) {
    if (owners[identity][newOwner] > 0) throw;
    owners[identity][newOwner] = now + adminRate;
    limiter[identity][newOwner] = now;
    OwnerAdded(identity, newOwner, msg.sender);
  }

  // an owner can remove another owner instantly
  function removeOwner(Proxy identity, address owner) onlyOwner(identity) rateLimited(identity) {
    delete owners[identity][owner];
    OwnerRemoved(identity, owner, msg.sender);
  }

  // an owner can add change the recoverykey whenever they want to
  function changeRecovery(Proxy identity, address recoveryKey) onlyOwner(identity) rateLimited(identity) {
    recoveryKeys[identity] = recoveryKey;
    limiter[identity][recoveryKey] = now;
    RecoveryChanged(identity, recoveryKey, msg.sender);
  }
}
