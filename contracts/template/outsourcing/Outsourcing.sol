// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Outsourcing is Ownable, ReentrancyGuard {
    using safeERC20 for IERC20;

    IERC20 public rToken;

    struct Request {
        uint256 amount;
        address who;
        uint8 state; // none=0, ask, cancle, accept, reject
        // uint88 extra;
    }
    Request[] internal _requests;

    event AskRequest(address who, uint256 amount, uint256 indexed id);
    event CancleRequest(address who, uint256 amount, uint256 indexed id);
    event AcceptRequest(address who, uint256 amount, uint256 indexed id);
    event RejectRequest(address who, uint256 amount, uint256 indexed id);

    //==================== Initialization ====================//

    constructor(address rToken_) {
        // require(rToken_.owner() == _msgSender(), "Outsourcing: INVALID_OWNER");

        rToken = IERC20(rToken_);
    }

    //==================== View ====================//

    function requestsLength() public view returns (uint256) {
        return _requests.length;
    }

    function allRequests() public view returns (Request[] memory requests) {
        return _requests;
    }

    function askedRequests() public view returns (Request[] memory requests) {
        for (uint256 i = 0; i < _requests.length; i++) {
            if (_requests[i].state == 1) { // ask
                requests.push(_requests[i]);
            }
        }
    }

    function cancledRequests() public view returns (Request[] memory requests) {
        for (uint256 i = 0; i < _requests.length; i++) {
            if (_requests[i].state == 2) { // cancle
                requests.push(_requests[i]);
            }
        }
    }

    function acceptedRequests() public view returns (Request[] memory requests) {
        for (uint256 i = 0; i < _requests.length; i++) {
            if (_requests[i].state == 3) { // accept
                requests.push(_requests[i]);
            }
        }
    }

    function rejectedRequests() public view returns (request[] memory requests) {
        for (uint256 i = 0; i < _requests.length; i++) {
            if (_requests[i].state == 4) { // reject
                requests.push(_requests[i]);
            }
        }
    }
    
    //==================== Methods ====================//

    /**
     * @notice User spends RepuERC20 for some request.
     */
    function ask(uint256 amount_) public {
        address msgSender = _msgSender();

        _requests.push(Request({
            amount: amount_,
            who: msgSender,
            state: 1 // ask
        }));

        transferFrom(msgSender, address(this), amount_);
        emit AskRequest(msgSender, amount_, _requests.length);
    }

    /**
     * @notice User cancles request.
     */
    function cancle(uint256 id_) public nonReentrant {
        address msgSender = _msgSender();

        _requests[id_].state = 2; // cancle
        uint256 amount_ = _requests[id_].amount;

        transfer(msgSender, amount_);
        emit CancleRequest(msgSender, amount_, id_);
    }

    /**
     * @notice Accept the `id_` request.
     */
    function accept(uint256 id_) public onlyOwner nonReentrant {
        address msgSender = _msgSender(); // owner

        _requests[id_].state = 3; // accept
        address who_ = _requests[id_].who;
        uint256 amount_ = _requests[id_].amount;

        transfer(msgSender, amount_);
        emit AcceptRequest(who_, amount_, id_);
    }

    /**
     * @notice Reject the `id_` request.
     */
    function reject(uint256 id_) public onlyOwner nonReentrant {
        address msgSender = _msgSender(); // owner

        _requests[id_].state = 4; // reject
        address who_ = _requests[id_].who;
        uint256 amount_ = _requests[id_].amount;

        transfer(who_, amount_);
        emit RejectRequest(who_, amount_, id_);
    }

    //==================== Owner ====================//

    function withdraw(uint256 amount_) public onlyOwner {
        transfer(_msgSender(), amount_);
    }
}
