library;

abi YuneVault {
    // Read-only storage functions
    #[storage(read)]
    fn want() -> AssetId;
    #[storage(read)]
    fn balance() -> u64;

    #[storage(read)]
    fn available() -> u64;

    #[storage(read)]
    fn total_supply() -> u64;


    #[storage(read)]
    fn get_price_per_full_share() -> u64;

    #[storage(read)]
    fn strategy() -> ContractId;

    #[storage(read, write)]
    fn initialize(owner: Identity, strategy_address: ContractId, asset_id: AssetId,sub_id: SubId, underlying_precision: u64);
    
    // Not sure need if got script
    // #[storage(read, write)]
    // fn deposit_all(owner: Identity, strategy_address: ContractId, asset_id: AssetId);
    
    #[storage(read, write)]
    fn earn();

    #[storage(read, write)]
    fn transfer_ownership(new_owner: Identity);

  
}
