# Starknet NFT Auction Smart Contract

## Overview

This is a Starknet smart contract where users can place bids for an NFT. The highest bidder at the end of the auction wins.

## Features

- Create auctions for NFTs
- Place bids for NFTs
- Track highest bid and highest bidder
- Event logging for placed bids and auction ending

## Contract Interface

The contract provides the following functions:

- `constructor`: Initializes the auction with NFT details and parameters
- `place_bid(bid_amount: u256)`: Allows users to place bids for NFTs on auction
- `end_auction`: Allows owner to end the auction after duration
- `get_highest_bidder`: View current highest bidder
- `get_highest_bid`: View current highest bid
- `get_auction_end`: View auction end time

## Events

The contract emits two types of events:

- `BidPlaced`: Triggered when a bid for the nft is placed
- `AuctionEnded`: Triggered when auction is finalized

## Security Features

- Ensures proper access control for admin functions
- Prevents bid amounts lower than the current highest bid
- Checks auction timeframe before closing auction

## Technical Details

- Written in Cairo
- Developed for Starknet Cairo Bootcamp III

## Deployment

To deploy this contract, you'll need:

- Starknet development environment
- Cairo compiler
- Starknet CLI or compatible deployment tool
