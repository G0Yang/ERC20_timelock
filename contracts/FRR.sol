// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FRR is ERC20, ERC20Pausable, ERC20Burnable {
    using SafeMath for uint256;
    struct LockInfo {
        uint256 _releaseTime;
        uint256 _amount;
    }

    mapping(address => LockInfo[]) public timelockList;
    mapping(address => uint256) public lockedBalance;
    mapping(address => bool) public frozenAccount;
    mapping(address => bool) public isAdmin;

    address public implementation = address(0);
    address public owner;

    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);
    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event Unlock(address indexed holder, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier notFrozen(address _holder) {
        require(!frozenAccount[_holder]);
        _;
    }
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || isOwner(msg.sender));
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() ERC20("Frontrow", "FRR") {
        //_mint(msg.sender, 10000000000 * (10 ** decimals()));
        _mint(msg.sender, 100 * (10 ** decimals()));
        isAdmin[msg.sender] = true;
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() public onlyAdmin whenNotPaused {
        _pause();
    }

    function unpause() public onlyAdmin whenPaused {
        _unpause();
    }

    function isOwner(address holder) public view returns (bool) {
        return owner == holder;
    }

    function addAdmin(address account) public onlyAdmin {
        isAdmin[account] = true;
    }

    function renounceAdmin() public {
        isAdmin[msg.sender] = false;
    }

    function removeAdmin(address account) public onlyOwner {
        isAdmin[account] = false;
    }

    function freezeAccount(address holder) public onlyAdmin returns (bool) {
        require(!frozenAccount[holder]);
        frozenAccount[holder] = true;
        emit Freeze(holder);
        return true;
    }

    function unfreezeAccount(address holder) public onlyAdmin returns (bool) {
        require(frozenAccount[holder]);
        frozenAccount[holder] = false;
        emit Unfreeze(holder);
        return true;
    }

    function lock(address holder, uint256 value, uint256 releaseTime) public onlyAdmin returns (bool) {
        require(balanceOf(holder) - lockedBalance[holder] >= value, "There is not enough balance of holder.");
        require(releaseTime >= block.timestamp, "releaseTime is past current time");
        _lock(holder, value, releaseTime);
        return true;
    }

    function transferWithLock(address holder, uint256 value, uint256 releaseTime) public onlyAdmin returns (bool) {
        require(releaseTime >= block.timestamp, "releaseTime is past current time");
        _transfer(msg.sender, holder, value);
        _lock(holder, value, releaseTime);
        return true;
    }

    function unlock(address holder, uint256 idx) public onlyAdmin returns (bool) {
        require(timelockList[holder].length > idx, "There is not lock info.");
        _unlock(holder, idx);
        return true;
    }

    function _lock(address holder, uint256 value, uint256 releaseTime) internal returns (bool) {
        require(balanceOf(holder) - lockedBalance[holder] >= value, "There is not enough balance of holder.");
        lockedBalance[holder] = SafeMath.add(value, lockedBalance[holder]);
        timelockList[holder].push(LockInfo(releaseTime, value));
        emit Lock(holder, value, releaseTime);
        return true;
    }

    function _unlock(address holder, uint256 idx) internal returns (bool) {
        LockInfo storage lockinfo = timelockList[holder][idx];
        uint256 releaseAmount = lockinfo._amount;
        if(timelockList[holder].length > 1){
            if(timelockList[holder].length - 1 == idx){
                timelockList[holder].pop();
            }else{
                timelockList[holder][idx] = timelockList[holder][timelockList[holder].length - 1];
                timelockList[holder].pop();
            }
        }else{
            delete timelockList[holder];
        }
        lockedBalance[holder] = SafeMath.sub(lockedBalance[holder], releaseAmount);
        emit Unlock(holder, releaseAmount);
        return true;
    }

    function _autoUnlock(address holder) internal returns (bool) {
        for (uint256 idx = 0; idx < timelockList[holder].length; idx++) {
            if (timelockList[holder][idx]._releaseTime <= block.timestamp) {
                if (_unlock(holder, idx)) {
                    idx -= 1;
                }
            }
        }
        return true;
    }

    function transfer(address to, uint256 value) public notFrozen(msg.sender) whenNotPaused override returns (bool) {
        if (timelockList[msg.sender].length > 0) {
            _autoUnlock(msg.sender);
        }
        require(balanceOf(msg.sender) - lockedBalance[msg.sender] >= value);
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public notFrozen(from) whenNotPaused override returns (bool) {
        if (timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        require(balanceOf(msg.sender) - lockedBalance[msg.sender] >= value);
        return super.transferFrom(from, to, value);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function burn(uint256 amount) public override {
        require(balanceOf(msg.sender) - lockedBalance[msg.sender] >= amount, "There is not enough balance of holder.");
        _burn(_msgSender(), amount);
    }

    function approve(address spender, uint256 value) public whenNotPaused override returns (bool) {
        require(balanceOf(msg.sender) - lockedBalance[msg.sender] >= value);
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused override returns (bool success) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused override returns (bool success) {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}
