#[starknet::contract]
mod StarkNotes {
    use core::starknet::ContractAddress;
    use core::integer::{u256, u64};
    use starknet::storage;
    use starknet::Store;
    use starknet::Event;

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
    }

    // Events
    #[event]
    #[derive(Drop, Event)]
    enum ContractEvent {
        LogoProposed(LogoProposed),
        VoteCast: VoteCast,
        LogoConcluded: LogoConcluded,
        DistributionTriggered: DistributionTriggered,
    }

    #[derive(Drop, Event)]
    struct LogoProposed {
        logo_id: u64,
        proposer: ContractAddress,
        statement: felt252,
        bounty: u256,
    }

    #[derive(Drop, Event)]
    struct DistributionTriggered {
        logo_id: u64,
        final_outcome: felt252,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, bounty_token_address: ContractAddress, min_votes: u64, grace_length: u64) {
        self.bounty_token.write(bounty_token_address);
        self.min_votes_required.write(min_votes);
        self.logo_count.write(0);
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
        

        fn cast_vote(ref self: ContractState, logo_id: u64, vote: bool) {
            // Implementation for casting a vote
        }


        fn get_logo(self: @ContractState, logo_id: u64) -> Logo {
            // Implementation to retrieve logo details
        }

        fn get_reviewer(self: @ContractState, address: ContractAddress) -> Reviewer {
            // Implementation to retrieve reviewer details
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update_reputation(ref self: ContractState, reviewer: ContractAddress, change: i64) {
            // Implementation to update reviewer reputation
        }

        fn _distribute_bounty(ref self: ContractState, logo_id: u64, is_yes_outcome: bool) {
            let bounty_amount = self.bounty_pots.read(logo_id);
            let logo = self.logos.read(logo_id);
            let winning_votes = if is_yes_outcome { logo.yes_votes } else { logo.no_votes };
            
            // Calculate share per winning vote
            let share_per_vote = bounty_amount / winning_votes;
            
            // Distribute to winning voters
            // Iterate through votes and transfer shares to winning voters
        }

        fn _finalize_logo_if_unchallenged(ref self: ContractState, logo_id: u64) {
            // Implementation for finalizing a logo if it hasn't been challenged
        }
        fn _is_bounty_locked(self: @ContractState, logo_id: u64) -> bool {
            let logo = self.logos.read(logo_id);
            // Check if logo is still in voting or grace period
            // Return true if locked, false if can be distributed
        }
    }
}

#[starknet::interface]
trait IStarkNotes<TContractState> {
    fn propose_logo(ref self: TContractState, statement: felt252);
    fn deposit_bounty(ref self: TContractState, logo_id: u64, deposit_amount: u256);
    fn cast_vote(ref self: TContractState, logo_id: u64, vote: bool);
    fn get_logo(self: @TContractState, logo_id: u64) -> Logo;
    fn get_reviewer(self: @TContractState, address: ContractAddress) -> Reviewer;
}
