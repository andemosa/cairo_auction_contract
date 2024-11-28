use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events,
    EventSpyAssertionsTrait, EventSpyTrait
};
use auction_contract::{IAuctionDispatcher, IAuctionDispatcherTrait, Auction};

const INITIAL_PRICE: u64 = 100;
const AUCTION_DURATION: u64 = 3600;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let owner = contract_address_const::<0x123456789>();
    let nft_contract = contract_address_const::<0x123626789>();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(INITIAL_PRICE.into());
    constructor_calldata.append(AUCTION_DURATION.into());
    constructor_calldata.append(nft_contract.into());

    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

#[test]
fn test_constructor() {
    let contract_address = deploy_contract("Auction");

    let auction_contract = IAuctionDispatcher { contract_address };

    let highest_bid = auction_contract.get_highest_bid();

    assert(highest_bid == INITIAL_PRICE, 'wrong highest bid');
}

#[test]
fn test_place_bid() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let bidder1 = contract_address_const::<0x123450011>();
    let bidder2 = contract_address_const::<0x123450022>();

    // First bid
    start_cheat_caller_address(contract_address, bidder1);
    auction_contract.place_bid(150);
    stop_cheat_caller_address(contract_address);

    assert(auction_contract.get_highest_bid() == 150, 'First bid failed');
    assert(auction_contract.get_highest_bidder() == bidder1, 'Incorrect highest bidder');

    // Higher bid from another bidder
    start_cheat_caller_address(contract_address, bidder2);
    auction_contract.place_bid(200);
    stop_cheat_caller_address(contract_address);

    assert(auction_contract.get_highest_bid() == 200, 'Second bid failed');
    assert(auction_contract.get_highest_bidder() == bidder2, 'Incorrect highest bidder');
}

#[test]
#[should_panic(expected: ('bid_amount < highest',))]
fn test_place_bid_too_low() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let bidder1 = contract_address_const::<0x123450011>();

    // Attempt lower bid
    start_cheat_caller_address(contract_address, bidder1);
    auction_contract.place_bid(50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Ended',))]
fn test_place_bid_after_auction_end() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let init_timestamp = get_block_timestamp();
    let current_timestamp = init_timestamp + AUCTION_DURATION + 1;
    let bidder = contract_address_const::<0x123450011>();

    // atempt bid after auction end
    start_cheat_block_timestamp(contract_address, current_timestamp);
    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(150);
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_end_auction_not_owner() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    auction_contract.end_auction();
}

#[test]
#[should_panic(expected: ('Auction still ongoing',))]
fn test_end_auction_too_early() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let owner = contract_address_const::<0x123456789>();

    // Attempt to end auction before it's time
    start_cheat_caller_address(contract_address, owner);
    auction_contract.end_auction();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_end_auction() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let init_timestamp = get_block_timestamp();
    let current_timestamp = init_timestamp + AUCTION_DURATION + 1;

    let owner = contract_address_const::<0x123456789>();
    let bidder = contract_address_const::<0x123450011>();

    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(150);
    stop_cheat_caller_address(contract_address);

    start_cheat_block_timestamp(contract_address, current_timestamp);
    start_cheat_caller_address(contract_address, owner);
    auction_contract.end_auction();
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);

    assert(auction_contract.get_highest_bidder() == bidder, 'Incorrect auction winner');
    assert(auction_contract.get_highest_bid() == 150, 'Incorrect winning bid');
}

/////////////// Testing Events  ////////////////////
#[test]
fn test_place_bid_emit_event() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let bidder = contract_address_const::<0x123450011>();
    let bid_amount = 150;
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(bid_amount);

    let events = spy.get_events();

    assert(events.events.len() == 1, 'There should be one event');

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Auction::Event::BidPlaced(Auction::BidPlaced { bidder, amount: bid_amount })
                )
            ]
        );
}

#[test]
fn test_end_auction_emit_event() {
    let contract_address = deploy_contract("Auction");
    let auction_contract = IAuctionDispatcher { contract_address };

    let mut spy = spy_events();

    let init_timestamp = get_block_timestamp();
    let current_timestamp = init_timestamp + AUCTION_DURATION + 1;
    let bid_amount = 150;
    let owner = contract_address_const::<0x123456789>();
    let bidder = contract_address_const::<0x123450011>();

    // First bid
    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(bid_amount);
    stop_cheat_caller_address(contract_address);

    // End auction
    start_cheat_block_timestamp(contract_address, current_timestamp);
    start_cheat_caller_address(contract_address, owner);
    auction_contract.end_auction();
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);

    let events = spy.get_events();

    assert(events.events.len() == 2, 'There should be two events');

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Auction::Event::AuctionEnded(
                        Auction::AuctionEnded { winner: bidder, amount: bid_amount }
                    )
                )
            ]
        );
}
