// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelancerReputation {
    bool private locked;
    modifier noReentrant() {
        require(!locked, "No reentrancy!");
        locked = true;
        _;
        locked = false;
    }

    address public owner;

    struct Freelancer {
        string name;
        uint256 totalJobs;
        uint256 reputation;
        bool exists;
    }

    struct Job {
        address client;
        address freelancer;
        uint256 amount;
        bool completed;
        bool paid;
        bool disputed;
        uint256 rating;
        uint256 timestamp;
    }

    mapping(address => Freelancer) public freelancers;
    mapping(uint256 => Job) public jobs;
    address[] public freelancerList;
    uint256 public jobCount;

    event FreelancerRegistered(address freelancer, string name);
    event JobCreated(uint256 jobId, address client, address freelancer, uint256 amount);
    event JobCompleted(uint256 jobId, uint256 rating);
    event PaymentReleased(uint256 jobId, address freelancer, uint256 amount);
    event DisputeRaised(uint256 jobId, address by);
    event DisputeResolved(uint256 jobId, address winner);

    constructor() {
        owner = msg.sender;
    }

    function registerFreelancer(string memory _name) public {
        require(!freelancers[msg.sender].exists, "Already registered!");
        require(bytes(_name).length > 0, "Name empty!");
        freelancers[msg.sender] = Freelancer(_name, 0, 0, true);
        freelancerList.push(msg.sender);
        emit FreelancerRegistered(msg.sender, _name);
    }

    function createJob(address _freelancer) public payable {
        require(msg.value > 0, "Must send payment!");
        require(_freelancer != address(0), "Invalid address!");
        require(_freelancer != msg.sender, "Cannot hire yourself!");
        require(freelancers[_freelancer].exists, "Freelancer not registered!");
        jobs[jobCount] = Job(msg.sender, _freelancer, msg.value, false, false, false, 0, block.timestamp);
        emit JobCreated(jobCount, msg.sender, _freelancer, msg.value);
        jobCount++;
    }

    function confirmAndPay(uint256 _jobId, uint256 _rating) public noReentrant {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.client, "Only client!");
        require(!job.completed, "Already done!");
        require(!job.paid, "Already paid!");
        require(!job.disputed, "Job disputed!");
        require(_rating >= 1 && _rating <= 5, "Rating 1-5 only!");

        job.completed = true;
        job.paid = true;
        job.rating = _rating;
        freelancers[job.freelancer].totalJobs += 1;
        freelancers[job.freelancer].reputation += _rating * 10;

        (bool success, ) = payable(job.freelancer).call{value: job.amount}("");
        require(success, "Payment failed!");

        emit JobCompleted(_jobId, _rating);
        emit PaymentReleased(_jobId, job.freelancer, job.amount);
    }

    function raiseDispute(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.client || msg.sender == job.freelancer, "Not in this job!");
        require(!job.completed, "Already completed!");
        require(!job.disputed, "Already disputed!");
        job.disputed = true;
        emit DisputeRaised(_jobId, msg.sender);
    }

    function resolveDispute(uint256 _jobId, address _winner) public noReentrant {
        require(msg.sender == owner, "Only owner!");
        Job storage job = jobs[_jobId];
        require(job.disputed, "Not disputed!");
        require(!job.paid, "Already paid!");
        require(_winner == job.client || _winner == job.freelancer, "Invalid winner!");

        job.paid = true;
        job.completed = true;

        if (_winner == job.freelancer) {
            freelancers[job.freelancer].totalJobs += 1;
            freelancers[job.freelancer].reputation += 30;
        }

        (bool success, ) = payable(_winner).call{value: job.amount}("");
        require(success, "Transfer failed!");
        emit DisputeResolved(_jobId, _winner);
    }

    function getReputation(address _freelancer) public view returns (
        string memory name, uint256 totalJobs, uint256 reputation
    ) {
        require(freelancers[_freelancer].exists, "Not found!");
        Freelancer memory f = freelancers[_freelancer];
        return (f.name, f.totalJobs, f.reputation);
    }

    function getJob(uint256 _jobId) public view returns (
        address client, address freelancer, uint256 amount,
        bool completed, bool paid, bool disputed, uint256 rating, uint256 timestamp
    ) {
        Job memory j = jobs[_jobId];
        return (j.client, j.freelancer, j.amount, j.completed, j.paid, j.disputed, j.rating, j.timestamp);
    }

    function getFreelancerCount() public view returns (uint256) {
        return freelancerList.length;
    }

    function getFreelancerAt(uint256 index) public view returns (address) {
        return freelancerList[index];
    }
}
