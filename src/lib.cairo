use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

#[starknet::interface]
pub trait IAuction<TContractState> {
    fn place_bid(ref self: TContractState, bid_amount: u64);
    fn end_auction(ref self: TContractState);
    fn get_highest_bidder(self: @TContractState) -> ContractAddress;
    fn get_highest_bid(self: @TContractState) -> u64;
    fn get_auction_end(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod Auction {
    use super::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        nft_contract: ContractAddress,
        initial_price: u64,
        end_time: u64,
        highest_bidder: ContractAddress,
        highest_bid: u64,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BidPlaced: BidPlaced,
        AuctionEnded: AuctionEnded,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BidPlaced {
        pub bidder: ContractAddress,
        pub amount: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuctionEnded {
        pub winner: ContractAddress,
        pub amount: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, initial_price: u64, duration: u64, nft_contract: ContractAddress
    ) {
        let now = get_block_timestamp();

        self.end_time.write(now + duration);
        self.owner.write(owner);
        self.initial_price.write(initial_price);
        self.highest_bid.write(initial_price);
        self.nft_contract.write(nft_contract);
    }

    #[abi(embed_v0)]
    impl AuctionImpl of super::IAuction<ContractState> {
        fn place_bid(ref self: ContractState, bid_amount: u64) {
            assert(get_block_timestamp() < self.end_time.read(), 'Ended');
            assert(bid_amount > self.highest_bid.read(), 'bid_amount < highest');

            let bidder = get_caller_address();
            self.highest_bidder.write(bidder);
            self.highest_bid.write(bid_amount);

            self.emit(BidPlaced { bidder, amount: bid_amount });
        }

        fn end_auction(ref self: ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Not authorized');
            assert(get_block_timestamp() >= self.end_time.read(), 'Auction still ongoing');

            let winner = self.highest_bidder.read();
            let amount = self.highest_bid.read();

            self.emit(AuctionEnded { winner, amount });
        }

        fn get_highest_bidder(self: @ContractState) -> ContractAddress {
            self.highest_bidder.read()
        }

        fn get_highest_bid(self: @ContractState) -> u64 {
            self.highest_bid.read()
        }

        fn get_auction_end(self: @ContractState) -> u64 {
            self.end_time.read()
        }
    }
}
