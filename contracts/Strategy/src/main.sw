contract;

use sway_libs::{
    ownership::{
        _owner,
        initialize_ownership,
        only_owner,
        transfer_ownership,
    },
    reentrancy::reentrancy_guard,
};

use std::{
    asset::{transfer, burn,mint_to},
    call_frames::msg_asset_id,
    context::{msg_amount, balance_of,this_balance},
    hash::{
        Hash,
        sha256,
    },
    storage::storage_string::*,
    string::String,
};
use standards::{src20::SRC20, src6::{Deposit, SRC6, Withdraw}, src5::{
        SRC5,
        State,
    },};

use interfaces::data_structures::{VaultInfo};
use interfaces::{YuneStrategy::YuneStrategy, YuneVault::YuneVault};


impl YuneStrategy for Contract {
    // #[storage(read, write)]
    // fn initialize(owner: Identity, strategy_address: ContractId, asset_id: AssetId,sub_id: SubId, underlying_precision: u64);

    #[storage(read)]
    fn vault() -> ContractId;

    #[storage(read)]
    fn want() -> ContractId;

    #[storage(read)]
    fn balanceOf() -> u64;

    #[storage(read)]
    fn balanceOfWant() -> u64;

    #[storage(read)]
    fn balanceOfPool() -> u64;

    #[storage(read)]
    fn paused() -> bool;

    #[storage(read)]
    fn unirouter() -> ContractId;

    #[storage(read, write)]
    fn harvest();

    #[storage(read, write)]
    fn retireStrat();

    #[storage(read, write)]
    fn panic();

    #[storage(read, write)]
    fn pause();

    #[storage(read, write)]
    fn unpause();

    #[storage(read, write)]
    fn beforeDeposit();

    #[payable]
    #[storage(read, write)]
    fn deposit();

    #[payable]
    #[storage(read, write)]
    fn withdraw(amount: u64);
}

#[storage(read)]
fn _balanceOf() -> u64{
    1
}

#[storage(read)]
fn _balanceOfWant() -> u64{
    1
}

#[storage(read)]
fn _balanceOfPool() -> u64{
    1
}