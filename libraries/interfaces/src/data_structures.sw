library;

pub struct VaultInfo {
    /// Amount of assets currently managed by this vault
    pub managed_assets: u64,
    /// The vault_sub_id of this vault.
    pub vault_sub_id: SubId,
    /// The asset being managed by this vault
    pub asset: AssetId,
}
 