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

// Initialze configurable with script
configurable {
    /// The only sub vault that can be deposited and withdrawn from this vault.
    ACCEPTED_SUB_VAULT: SubId = SubId::zero(),
    PRE_CALCULATED_SHARE_VAULT_SUB_ID: SubId = SubId::zero(), //does this matters?

}
 
storage {
    /// The total amount of assets managed by this vault.
    managed_assets: u64 = 0,
    /// The total amount of shares minted by this vault.
    total_supply: u64 = 0,
    // Strategy Contract
    STRATEGY_CONTRACT_ID: ContractId = ContractId::zero(),
    // Strategy Asset Ids
    STRATEGY_ASSET_ID: AssetId = AssetId::zero(),
    // Strategy Sub Ids
    STRATEGY_SUB_ID: SubId = SubId::zero(),

    UNDERLYING_PRECISION: u64 = 1_000_000_000u64,

    // Check if vault has been initialized
    init: bool = false,
}
 
impl SRC6 for Contract {
    #[payable]
    #[storage(read, write)]
    fn deposit(receiver: Identity, vault_sub_id: SubId) -> u64 {
        reentrancy_guard();
        require(vault_sub_id == ACCEPTED_SUB_VAULT, "INVALID_vault_sub_id");

        let underlying_asset = msg_asset_id();
        require(underlying_asset == storage.STRATEGY_ASSET_ID.read(), "INVALID_ASSET_ID");

        let asset_amount = msg_amount();
        require(asset_amount != 0, "ZERO_ASSETS");

        let b256_from_contract_id: b256 = storage.STRATEGY_CONTRACT_ID.read().into();
        
        let strategy = abi(YuneStrategy, b256_from_contract_id);

        strategy.beforeDeposit();
        
        let shares = preview_deposit(asset_amount);
 
        _mint(receiver, shares);
 
        storage
            .managed_assets
            .write(storage.managed_assets.read() + asset_amount);
 
        Deposit::new(
            msg_sender()
                .unwrap(),
            receiver,
            underlying_asset,
            vault_sub_id,
            asset_amount,
            shares,
        )
            .log();
 
        shares
    }
 
    #[payable]
    #[storage(read, write)]
    fn withdraw(
        receiver: Identity,
        underlying_asset: AssetId,
        vault_sub_id: SubId,
    ) -> u64 {
        reentrancy_guard();
        require(underlying_asset == storage.STRATEGY_ASSET_ID.read(), "INVALID_ASSET_ID");
        require(vault_sub_id == ACCEPTED_SUB_VAULT, "INVALID_vault_sub_id");
 
        let shares = msg_amount();
        require(shares != 0, "ZERO_SHARES");
 
        let share_asset_id = vault_assetid();
 
        require(msg_asset_id() == share_asset_id, "INVALID_ASSET_ID");
        let assets = preview_withdraw(shares);
 
        storage
            .managed_assets
            .write(storage.managed_assets.read() - shares);
 
        _burn(share_asset_id, shares);
 
        transfer(receiver, underlying_asset, assets);
 
        Withdraw::new(
            msg_sender()
                .unwrap(),
            receiver,
            underlying_asset,
            vault_sub_id,
            assets,
            shares,
        )
            .log();
 
        assets
    }
    
    //Total balance of assets in this vault
    #[storage(read)]
    fn managed_assets(underlying_asset: AssetId, vault_sub_id: SubId) -> u64 {
        if underlying_asset == storage.STRATEGY_ASSET_ID.read() && vault_sub_id == ACCEPTED_SUB_VAULT {
            // In this implementation managed_assets and max_withdrawable are the same. However in case of lending out of assets, managed_assets should be greater than max_withdrawable.
            storage.managed_assets.read()
        } else {
            0
        }
    }
    
    //Available amount of max depositable
    #[storage(read)]
    fn max_depositable(
        _receiver: Identity,
        underlying_asset: AssetId,
        vault_sub_id: SubId,
    ) -> Option<u64> {
        if underlying_asset == AssetId::base() && vault_sub_id == ACCEPTED_SUB_VAULT {
            // This is the max value of u64 minus the current managed_assets. Ensures that the sum will always be lower than u64::MAX.
            Some(u64::max() - storage.managed_assets.read())
        } else {
            None
        }
    }
 
    //Available amount of max withdrawable
    #[storage(read)]
    fn max_withdrawable(underlying_asset: AssetId, vault_sub_id: SubId) -> Option<u64> {
        if underlying_asset == AssetId::base() && vault_sub_id == ACCEPTED_SUB_VAULT {
            // In this implementation managed_assets and max_withdrawable are the same. However in case of lending out of assets, managed_assets should be greater than max_withdrawable.
            Some(storage.managed_assets.read())
        } else {
            None
        }
    }
}
 
impl SRC20 for Contract {
    #[storage(read)]
    fn total_assets() -> u64 {
        1
    }
 
    #[storage(read)]
    fn total_supply(asset: AssetId) -> Option<u64> {
        if asset == vault_assetid() {
            Some(storage.total_supply.read())
        } else {
            None
        }
    }
 
    #[storage(read)]
    fn name(asset: AssetId) -> Option<String> {
        if asset == vault_assetid() {
            Some(String::from_ascii_str("Vault Shares"))
        } else {
            None
        }
    }
 
    #[storage(read)]
    fn symbol(asset: AssetId) -> Option<String> {
        if asset == vault_assetid() {
            Some(String::from_ascii_str("VLTSHR"))
        } else {
            None
        }
    }
 
    #[storage(read)]
    fn decimals(asset: AssetId) -> Option<u8> {
        if asset == vault_assetid() {
            Some(9_u8)
        } else {
            None
        }
    }
}

impl SRC5 for Contract {
    #[storage(read)]
    fn owner() -> State {
        _owner()
    }
}

impl YuneVault for Contract {

    #[storage(read,write)]
    fn initialize(owner: Identity, strategy_address: ContractId, asset_id: AssetId, sub_id: SubId, underlying_precision: u64){
        require(storage.init.read() == false,"Vault has been initialized");
        storage.init.write(true);
        initialize_ownership(owner);

        storage.STRATEGY_CONTRACT_ID.write(strategy_address);
        storage.STRATEGY_ASSET_ID.write(asset_id);
        storage.STRATEGY_SUB_ID.write(sub_id);
        storage.UNDERLYING_PRECISION.write(underlying_precision);

        // @note need to add log
    }    

    // Returns the address of the underlying farm token (e.g. the LP token) used in both the Yune Vault and Strategy contracts. Note that this is not the same as the underlying assets used for the farm.
    #[storage(read)]
    fn want() -> AssetId{
        let strategy_contract_id = storage.STRATEGY_CONTRACT_ID.try_read().unwrap_or(ContractId::zero());
        let strategy_sub_id = storage.STRATEGY_SUB_ID.try_read().unwrap_or(SubId::zero());
        let asset_id: AssetId = AssetId::new(strategy_contract_id, strategy_sub_id);
        asset_id
    }
    /**
     * @dev It calculates the total underlying value of {token} held by the system.
     * It takes into account the vault contract balance, the strategy contract balance
     *  and the balance deployed in other contracts as part of the strategy.
     */ 
    #[storage(read)]
    fn balance() -> u64{
        let amount = _balance();
        amount
    }
    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    #[storage(read)]
    fn available() -> u64{
        let available = _available();
        available
    }
    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an u64 with 9 decimals of how much underlying asset one vault share represents.
     */
    #[storage(read)]
    fn total_supply2() -> u64{
        let supply = _total_supply();
        supply
    }

    #[storage(read)]
    fn get_price_per_full_share() -> u64{
        let _totalsupply: u64  = _total_supply(); 
        let _balance: u64  = _balance();
        let precision: u64 = storage.UNDERLYING_PRECISION.read(); 
        let mut amount:u64 = 0u64;
        if _totalsupply == 0 {
            amount = precision; 
        } else {
            amount = (_balance * precision) / _totalsupply;
        }
        amount
    }

    #[storage(read)]
    fn strategy() -> ContractId{
        storage.STRATEGY_CONTRACT_ID.try_read().unwrap_or(ContractId::zero())
    }
    #[storage(read, write)]
    fn earn(){
        _earn();
    }

    #[storage(read, write)]
    fn transfer_ownership(new_owner: Identity) {
        if _owner() == State::Uninitialized {
            initialize_ownership(new_owner);
        } else {
            transfer_ownership(new_owner);
        }
    }
}
// @note may need to move all internal functions into a library
#[storage(read)]
fn _balance() -> u64{
    let asset_id = storage.STRATEGY_ASSET_ID.try_read().unwrap_or(AssetId::zero());
    let contract_id = storage.STRATEGY_CONTRACT_ID.try_read().unwrap_or(ContractId::zero());
    let want_balance:u64 = this_balance(asset_id);

    let b256_from_contract_id: b256 = storage.STRATEGY_CONTRACT_ID.read().into();
    let strategy_instance = abi(YuneStrategy, b256_from_contract_id);

    let strategy_balance:u64 = strategy_instance.balanceOf();
    let amount = want_balance + strategy_balance;
    
    amount
}

#[storage(read)]
fn _available() -> u64{
    let asset_id = storage.STRATEGY_ASSET_ID.try_read().unwrap_or(AssetId::zero());
    let available = this_balance(asset_id);
    available
}

#[storage(read)]
fn _total_supply() -> u64{
    let vault_id = vault_assetid();
    let amount = this_balance(vault_id);
    amount  
}

#[storage(read, write)]
fn _earn(){
    let contract_id = storage.STRATEGY_CONTRACT_ID.read();
    let b256_from_contract_id: b256 = storage.STRATEGY_CONTRACT_ID.read().into();
    let asset_id = storage.STRATEGY_ASSET_ID.try_read().unwrap_or(AssetId::zero()); 
    let strategy_instance = abi(YuneStrategy, b256_from_contract_id);
    let underlying_balance = _available();
    let strategy: Identity = Identity::ContractId(contract_id);
    transfer(strategy, asset_id, underlying_balance);
    strategy_instance.deposit();
}
/// Returns the vault shares assetid for the given assets assetid and the vaults sub id
fn vault_assetid() -> AssetId {
    let share_asset_id = AssetId::new(ContractId::this(), PRE_CALCULATED_SHARE_VAULT_SUB_ID);
    share_asset_id
}
 

#[storage(read)]
fn preview_deposit(assets: u64) -> u64 {
    let total_balance: u64 = _balance();
    let shares_supply = storage.total_supply.try_read().unwrap_or(0);
    if shares_supply == 0 {
        assets
    } else {
        assets * shares_supply / total_balance
    }
}
  // Returns the current price per share of the vault (i.e. per yuToken) as an integer denominated in the "want" (i.e. underlying farm token). 
 // This is calculated as Price per Full Share = balance() / total_supply().
#[storage(read)]
fn preview_withdraw(shares: u64) -> u64 {
    let total_balance: u64 = _balance();

    let supply = storage.total_supply.read();
    if supply == shares {
        storage.managed_assets.read()
    } else {
        shares * (storage.managed_assets.read() / supply)
    }
}
 
#[storage(read, write)]
pub fn _mint(recipient: Identity, amount: u64) {
 
    let supply = storage.total_supply.read();
    storage.total_supply.write(supply + amount);
    mint_to(recipient, PRE_CALCULATED_SHARE_VAULT_SUB_ID, amount);
}
 
#[storage(read, write)]
pub fn _burn(asset_id: AssetId, amount: u64) {

 
    require(
        this_balance(asset_id) >= amount,
        "BurnError::NotEnoughCoins",
    );
    // If we pass the check above, we can assume it is safe to unwrap.
    let supply = storage.total_supply.read();
    storage.total_supply.write(supply - amount);
    burn(PRE_CALCULATED_SHARE_VAULT_SUB_ID, amount);
}
 