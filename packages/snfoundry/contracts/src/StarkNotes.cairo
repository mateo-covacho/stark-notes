#[starknet::contract]
mod StarkNotes {
    use core::starknet::ContractAddress;
    use core::integer::{u256, u64};
        use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    
    #[starknet::interface]
    trait IStarkNotes<TContractState> {
        fn propose_logo(ref self: TContractState, statement: felt252);
        fn get_logo(self: @TContractState, logo_id: u64) -> Logo;
        fn deposit_bounty(ref self: TContractState, logo_id: u64, deposit_amount: u256);
        fn cast_vote(ref self: TContractState, logo_id: u64, vote: bool);
        fn get_reviewer(self: @TContractState, address: ContractAddress) -> Reviewer;
        fn claim_bounty(ref self: TContractState, logo_id: u64) -> bool;
    }

    // Data Structures
    #[derive(Drop, Serde, starknet::Store)]
    struct Reviewer {
        address: ContractAddress,
        reputation: u64,
        stake: u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Logo {
        id: u64,
        statement: felt252,
        proposer: ContractAddress,
        bounty: u256,
        yes_votes: u64,
        no_votes: u64,
        total_votes: u64,
        grace_start: u64,
        settled_outcome: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Vote {
        reviewer: ContractAddress,
        logo_id: u64,
        vote: bool,
    }

    // Storage
    #[storage]
    struct Storage {
        reviewers: Map<ContractAddress, Reviewer>,
        logos: Map<u64, Logo>,
        votes: Map<(u64, ContractAddress), Vote>,
        logo_count: u64,
        min_votes_required: u64,
        grace_period_length: u64,
        bounty_pots: Map<u64, u256>, // Maps logo_id to bounty amount
        bounty_token: ContractAddress,
        creation_timestamp: u64 
    }

    // starknet::Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LogoProposed: LogoProposed ,
        VoteCast: VoteCast,
        LogoConcluded: LogoConcluded,
        DistributionTriggered: DistributionTriggered,
    }

    #[derive(Drop, starknet::Event)]
    struct LogoProposed {
        logo_id: u64,
        proposer: ContractAddress,
        statement: felt252,
        bounty: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        logo_id: u64,
        voter: ContractAddress,
        vote: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct LogoConcluded {
        logo_id: u64,
        outcome: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DistributionTriggered {
        logo_id: u64,
        final_outcome: felt252,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, bounty_token_address: ContractAddress, min_votes: u64, grace_length: u64) 
    {
        self.bounty_token.write(bounty_token_address);
        self.min_votes_required.write(min_votes);
        self.logo_count.write(0);
        self.creation_timestamp.write(starknet::get_block_timestamp());
        self.grace_period_length.write(grace_length);
    }

    // External functions
    #[external(v0)]
    impl StarkNotesImpl of super::IStarkNotes<ContractState> {


        fn propose_logo(ref self: ContractState, statement: felt252) {
            // Get the caller's address
            let proposer = starknet::get_caller_address();
    
            // Increment the logo count
            let logo_id = self.logo_count.read() + 1;
            self.logo_count.write(logo_id);
    
            // Create a new Logo struct
            let new_logo = Logo {
                id: logo_id,
                statement: statement,
                proposer: proposer,
                bounty: 0, // Initial bounty is 0 yes_votes no_votes total_votes
                grace_start: 0, // Grace period hasn't started yet
                settled_outcome: 0, // Not settled  yet
            };
    
            // Store the new logo
            self.logos.write(logo_id, new_logo);
    
            // Emit LogoProposed event
            self.emit(LogoProposed {
                logo_id: logo_id,
                proposer: proposer,
                statement: statement,
                bounty: 0,
            });
        }
    

        fn deposit_bounty(ref self: ContractState, logo_id: u64, amount: u256) {
            let caller = starknet::get_caller_address();
            let token_address = self.bounty_token.read(); // Assuming you store the token address
            
            // Transfer tokens from caller to contract
            IERC20Dispatcher { contract_address: token_address }.transfer_from(caller, starknet::get_contract_address(), amount);
            
            // Update bounty amount for the logo
            let current_bounty = self.bounty_pots.read(logo_id);
            self.bounty_pots.write(logo_id, current_bounty + amount);
            
            // Emit event
            self.emit(BountyDeposited { logo_id, depositor: caller, amount });
        }
        
        fn claim_bounty(ref self: ContractState, logo_id: u64) -> bool {
            let caller = starknet::get_caller_address();
            let logo = self.logos.read(logo_id);
            
            assert(logo.id != 0, 'Logo does not exist');
            assert(!self._is_bounty_locked(logo_id), 'Bounty is locked');
            
            let vote = self.votes.read((logo_id, caller));
            assert(vote.reviewer != ContractAddress::zero(), 'No vote cast');
            
            let winning_outcome = self._winning_votes_percentage(logo_id) > 0.5;
            assert(vote.vote == winning_outcome, 'Did not vote for winning outcome');
            
            self._distribute_bounty(logo_id, winning_outcome);
            true
        }

        fn cast_vote(ref self: ContractState, logo_id: u64, vote: bool) {
        let caller = starknet::get_caller_address();
        let mut logo = self.logos.read(logo_id);

        // Check if the logo exists
        assert(logo.id != 0, 'Logo does not exist');

        // Check if the user has already voted
        let existing_vote = self.votes.read((logo_id, caller));
        assert(existing_vote.reviewer == ContractAddress::zero(), 'Already voted');

        // Update vote counts
        if vote {
        logo.yes_votes += 1;
        } else {
        logo.no_votes += 1;
        }
        logo.total_votes += 1;

        // Store the updated logo
        self.logos.write(logo_id, logo);

        // Record the vote
        let new_vote = Vote { reviewer: caller, logo_id, vote };
        self.votes.write((logo_id, caller), new_vote);

        // Emit VoteCast event
        self.emit(VoteCast { logo_id, voter: caller, vote });

        // Check if the logo can be finalized
        self._finalize_logo_if_requirements_met(logo_id);
        }


        fn get_logo(self: @ContractState, logo_id: u64) -> Logo {
            let logo = self.logos.read(logo_id);
            assert(logo.id != 0, 'Logo does not exist');
            logo
        }

        fn get_reviewer(self: @ContractState, address: ContractAddress) -> Reviewer {
            let reviewer = self.reviewers.read(address);
            assert(reviewer.address != ContractAddress::zero(), 'Reviewer does not exist');
            reviewer
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update_reputation(ref self: ContractState, reviewer: ContractAddress, change: i64) {
            let mut reviewer_data = self.reviewers.read(reviewer);
            if reviewer_data.address == ContractAddress::zero() {
                reviewer_data = Reviewer { address: reviewer, reputation: 0, stake: 0 };
            }
            
            if change >= 0 {
                reviewer_data.reputation += change.try_into().unwrap();
            } else {
                let abs_change: u64 = (-change).try_into().unwrap();
                reviewer_data.reputation = reviewer_data.reputation.saturating_sub(abs_change);
            }
            
            self.reviewers.write(reviewer, reviewer_data);
        }

        fn _distribute_bounty(ref self: ContractState, logo_id: u64, is_yes_outcome: bool) {
            let bounty_amount = self.bounty_pots.read(logo_id);
            let logo = self.logos.read(logo_id);
            let winning_votes = if is_yes_outcome { logo.yes_votes } else { logo.no_votes };
            
            let share_per_vote = bounty_amount / winning_votes;
            
            // Iterate through votes and transfer shares to winning voters
            // Note: This is a simplified version. In practice, you might want to use a more gas-efficient method.
            let mut distributed_amount = 0;
            for voter in self.votes.iter() {
                if voter.1.logo_id == logo_id && voter.1.vote == is_yes_outcome {
                    let voter_address = voter.1.reviewer;
                    IERC20Dispatcher { contract_address: self.bounty_token.read() }
                        .transfer(voter_address, share_per_vote);
                    distributed_amount += share_per_vote;
                }
            };
            
            // Transfer any remaining dust to the contract owner or a designated address
            if distributed_amount < bounty_amount {
                let remaining = bounty_amount - distributed_amount;
                IERC20Dispatcher { contract_address: self.bounty_token.read() }
                    .transfer(self.owner.read(), remaining);
            }
        }


        fn _winning_votes_percentage(self: @ContractState, logo_id: u64) -> u64 {
            let logo: Logo = self.logos.read(logo_id);
            let total_votes = logo.yes_votes + logo.no_votes;
            if total_votes == 0 {
                return 0;
            }
            (logo.yes_votes * 100) / total_votes
        }

        fn _finalize_logo_if_requirements_met(ref self: ContractState, logo_id: u64) {
            let logo = self.logos.read(logo_id);
            let min_votes = self.min_votes_required.read();
            let winning_percentage = self._winning_votes_percentage(logo_id);

            if logo.total_votes >= min_votes && (winning_percentage >= 0.66 || winning_percentage <= 0.34) {
                let grace_start = starknet::get_block_timestamp();
                let updated_logo = Logo {
                    grace_start,
                    settled_outcome: if winning_percentage > 0.5 { 'Yes' } else { 'No' },
                    ..logo
                };
                self.logos.write(logo_id, updated_logo);
                
                // Emit LogoConcluded event
                self.emit(LogoConcluded { logo_id, outcome: updated_logo.settled_outcome });
            }
        }

        fn _is_bounty_locked(self: @ContractState, logo_id: u64) -> bool {
            let logo = self.logos.read(logo_id);
            let current_time = starknet::get_block_timestamp();
            let grace_period = self.grace_period_length.read();
            
            // Bounty is locked if:
            // 1. Logo hasn't reached minimum votes
            // 2. Logo is still in voting phase (no grace period started)
            // 3. Logo is in grace period
            logo.total_votes < self.min_votes_required.read() ||
            logo.grace_start == 0 ||
            (logo.grace_start != 0 && current_time < logo.grace_start + grace_period)
        }
    }

}
