/// Module: fox_coin
module fox_coin::fox_coin {
    use sui::coin::{Self, TreasuryCap};
    use sui::tx_context::{sender};

    /// The type identifier of coin. The coin will have a type
    /// tag of kind: `Coin<package_object::fox_coin::FOX_COIN>`
    /// Make sure that the name of the type matches the module's name.
    public struct FOX_COIN has drop {}

    /// Module initializer is called once on module publish. A treasury
    /// cap is sent to the publisher, who then controls minting and burning
    fun init(witness: FOX_COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"FOX", b"FOXCOIN", b"FOXCOIN", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, sender(ctx))
    }

    public fun mint (treasury_cap: &mut TreasuryCap<FOX_COIN>, 
                     amount: u64, 
                     recipient: address, 
                     ctx: &mut TxContext) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient)
    }
}
