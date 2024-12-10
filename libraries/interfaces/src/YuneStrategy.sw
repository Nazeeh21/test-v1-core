library;

abi YuneStrategy {
    // Read-only storage functions
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

    // // Read and write storage functions
    // #[storage(read, write)]
    // fn initialize(owner: Identity, strategy_address: ContractId, asset_id: AssetId,sub_id: SubId, underlying_precision: u64);

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
