/// Module: fox_swap
module fox_swap::fox_swap {
    use sui::tx_context::{sender, epoch};
    use sui::math;
    use sui::balance::{self, Balance, Supply};
    use sui::coin::{self, Coin};
    use sui::table::{self, Table};
    use sui::clock::{self, Clock};
    use sui::transfer;
    use sui::object::{self, UID};

    const EAmount: u64 = 1;
    const ELotteryInvalidTime: u64 = 2;
    const ELPInvalid: u64 = 3;

    public struct LP<phantom CoinA, phantom CoinB> has drop {}

    public struct CouponData has store, drop {
        coupon_id: u64,
        lp_amount: u64,
        last_update_epoch: u64,
    }

    public struct Pool<phantom CoinA, phantom CoinB> has key {
        id: UID,
        coin_a_bal: Balance<CoinA>,
        coin_b_bal: Balance<CoinB>,
        lp_supply: Supply<LP<CoinA, CoinB>>,
        coupon_table: Table<address, CouponData>,
    }

    public struct Coupon has key {
        id: UID,
        coupon_id: u64,
        lottery_type: u64,
        lp_amount: u64,
        epoch: u64,
    }

    // Create a new swap pool with CoinA and CoinB
    public entry fun create_swap_pool<CoinA, CoinB>(coin_a: Coin<CoinA>, coin_b: Coin<CoinB>, clock: &Clock, ctx: &mut TxContext) {
        let coin_a_amount = coin::value(&coin_a);
        let coin_b_amount = coin::value(&coin_b);
        assert!(coin_a_amount > 0 && coin_b_amount > 0, EAmount);

        let coin_a_balance = coin::into_balance(coin_a);
        let coin_b_balance = coin::into_balance(coin_b);

        let lp_amount = math::sqrt(coin_a_amount) * math::sqrt(coin_b_amount); // Calculate initial LP
        let mut lp_supply = balance::create_supply(LP<CoinA, CoinB> {});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_amount);

        let mut pool = Pool {
            id: object::new(ctx),
            coin_a_bal: coin_a_balance,
            coin_b_bal: coin_b_balance,
            lp_supply,
            coupon_table: table::new<address, CouponData>(ctx),
        };

        // Record in coupon_table
        let coupon_data = CouponData {
            coupon_id: clock::timestamp_ms(clock),
            lp_amount,
            last_update_epoch: epoch(ctx),
        };
        pool.coupon_table.add(sender(ctx), coupon_data);

        transfer::share_object(pool);
        // Add LP amount to the pool and return the certificate to the user
        transfer::public_transfer(coin::from_balance(lp_balance, ctx), sender(ctx));
    }

    // Add liquidity to the swap pool
    public entry fun add_liquidity<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, coin_a: Coin<CoinA>, coin_b: Coin<CoinB>, clock: &Clock, ctx: &mut TxContext) {
        let coin_a_amount = coin::value(&coin_a);
        let coin_b_amount = coin::value(&coin_b);
        assert!(coin_a_amount > 0 && coin_b_amount > 0, EAmount);

        let coin_a_amount_in_pool = balance::value(&pool.coin_a_bal);
        let coin_b_amount_in_pool = balance::value(&pool.coin_b_bal);

        // Add coin_a and coin_b to the pool
        balance::join(&mut pool.coin_a_bal, coin::into_balance(coin_a));
        balance::join(&mut pool.coin_b_bal, coin::into_balance(coin_b));

        let factor_a = coin_a_amount_in_pool / coin_a_amount;
        let factor_b = coin_b_amount_in_pool / coin_b_amount;
        let (add_coin_a_amount, add_coin_b_amount, refund_coin_a_amount, refund_coin_b_amount);

        // Ensure the provided coin_a and coin_b are in the correct ratio, refund excess if necessary
        if factor_a == factor_b {
            add_coin_a_amount = coin_a_amount;
            add_coin_b_amount = coin_b_amount;
            refund_coin_a_amount = 0;
            refund_coin_b_amount = 0;
        } else if factor_a < factor_b {
            add_coin_a_amount = coin_a_amount_in_pool / factor_b;
            add_coin_b_amount = coin_b_amount;
            refund_coin_a_amount = coin_a_amount - add_coin_a_amount;
            refund_coin_b_amount = 0;
        } else {
            add_coin_a_amount = coin_a_amount;
            add_coin_b_amount = coin_b_amount_in_pool / factor_a;
            refund_coin_a_amount = 0;
            refund_coin_b_amount = coin_b_amount - add_coin_b_amount;
        }

        if refund_coin_a_amount > 0 {
            let refund_coin_a_balance = balance::split(&mut pool.coin_a_bal, refund_coin_a_amount);
            transfer::public_transfer(coin::from_balance(refund_coin_a_balance, ctx), sender(ctx));
        }

        if refund_coin_b_amount > 0 {
            let refund_coin_b_balance = balance::split(&mut pool.coin_b_bal, refund_coin_b_amount);
            transfer::public_transfer(coin::from_balance(refund_coin_b_balance, ctx), sender(ctx));
        }

        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);
        let new_lp_amount = math::sqrt(coin_a_amount_in_pool + add_coin_a_amount) * math::sqrt(coin_b_amount_in_pool + add_coin_b_amount); // Calculate new LP
        let add_lp_amount = new_lp_amount - lp_amount_in_pool;

        // Increase LP amount in the pool and return the certificate to the user
        let lp_balance = balance::increase_supply(&mut pool.lp_supply, add_lp_amount);
        transfer::public_transfer(coin::from_balance(lp_balance, ctx), sender(ctx));

        // Record in coupon_table
        let cur_epoch = epoch(ctx);
        if table::contains(&pool.coupon_table, sender(ctx)) {
            let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));
            coupon_data.lp_amount += add_lp_amount;
            coupon_data.last_update_epoch = cur_epoch;
        } else {
            let coupon_data = CouponData {
                coupon_id: clock::timestamp_ms(clock),
                lp_amount: add_lp_amount,
                last_update_epoch: cur_epoch,
            };
            pool.coupon_table.add(sender(ctx), coupon_data);
        }
    }

    // Remove liquidity from the swap pool
    public entry fun remove_liquidity<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, lp: Coin<LP<CoinA, CoinB>>, ctx: &mut TxContext) {
        let lp_amount = coin::value(&lp);
        assert!(lp_amount > 0, ELPInvalid);

        let coin_a_amount_in_pool = balance::value(&pool.coin_a_bal);
        let coin_b_amount_in_pool = balance::value(&pool.coin_b_bal);
        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);

        let factor = lp_amount / lp_amount_in_pool;
        let remove_coin_a_amount = factor * coin_a_amount_in_pool;
        let remove_coin_b_amount = factor * coin_b_amount_in_pool;

        // Remove coin_a and coin_b from the pool
        let coin_a_balance = balance::split(&mut pool.coin_a_bal, remove_coin_a_amount);
        let coin_b_balance = balance::split(&mut pool.coin_b_bal, remove_coin_b_amount);

        // Decrease LP amount in the pool and return coin_a and coin_b to the user
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));
        transfer::public_transfer(coin::from_balance(coin_a_balance, ctx), sender(ctx));
        transfer::public_transfer(coin::from_balance(coin_b_balance, ctx), sender(ctx));

        // Remove record from coupon_table
        assert!(table::contains(&pool.coupon_table, sender(ctx)), ELPInvalid);
        let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));
        coupon_data.lp_amount -= lp_amount;
        if coupon_data.lp_amount == 0 {
            table::remove(&mut pool.coupon_table, sender(ctx));
        }
    }

    // Swap CoinA for CoinB
    public entry fun swap_coin_a_to_coin_b<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, coin_a: Coin<CoinA>, ctx: &mut TxContext) {
        let swap_coin_a_amount = coin::value(&coin_a) as u128;
        let coin_a_amount_in_pool = balance::value(&pool.coin_a_bal) as u128;
        let coin_b_amount_in_pool = balance::value(&pool.coin_b_bal) as u128;
        assert!(swap_coin_a_amount > 0, EAmount);

        let new_coin_b_amount = coin_a_amount_in_pool * coin_b_amount_in_pool / (coin_a_amount_in_pool + swap_coin_a_amount);
        let swap_coin_b_amount = (coin_b_amount_in_pool - new_coin_b_amount) as u64;
        balance::join(&mut pool.coin_a_bal, coin::into_balance(coin_a));
        let coin_b_balance = balance::split(&mut pool.coin_b_bal, swap_coin_b_amount);
        transfer::public_transfer(coin::from_balance(coin_b_balance, ctx), sender(ctx));
    }

    // Swap CoinB for CoinA
    public entry fun swap_coin_b_to_coin_a<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, coin_b: Coin<CoinB>, ctx: &mut TxContext) {
        let swap_coin_b_amount = coin::value(&coin_b) as u128;
        let coin_a_amount_in_pool = balance::value(&pool.coin_a_bal) as u128;
        let coin_b_amount_in_pool = balance::value(&pool.coin_b_bal) as u128;
        assert!(swap_coin_b_amount > 0, EAmount);

        let new_coin_a_amount = coin_b_amount_in_pool * coin_a_amount_in_pool / (coin_b_amount_in_pool + swap_coin_b_amount);
        let swap_coin_a_amount = (coin_a_amount_in_pool - new_coin_a_amount) as u64;
        balance::join(&mut pool.coin_b_bal, coin::into_balance(coin_b));
        let coin_a_balance = balance::split(&mut pool.coin_a_bal, swap_coin_a_amount);
        transfer::public_transfer(coin::from_balance(coin_a_balance, ctx), sender(ctx));
    }

    // Retrieve daily coupon for lottery
    public entry fun get_daily_coupon<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, lottery_type: u64, ctx: &mut TxContext) {
        assert!(table::contains(&pool.coupon_table, sender(ctx)), EAmount);
        let coupon_data = table::borrow_mut(&mut pool.coupon_table, sender(ctx));

        let lp_amount = coupon_data.lp_amount;
        assert!(lp_amount > 0, EAmount);

        let lp_amount_in_pool = balance::supply_value(&pool.lp_supply);
        assert!(lp_amount_in_pool > 0, EAmount);

        let lp_factor = lp_amount_in_pool / lp_amount;
        assert!(lp_factor < 100000, EAmount); // Ensure LP amount is not less than 1/100000 of total LP

        let cur_epoch = epoch(ctx);
        assert!(coupon_data.last_update_epoch < cur_epoch, ELotteryInvalidTime); // Ensure the user can get a new coupon

        coupon_data.last_update_epoch = cur_epoch;

        let coupon = Coupon {
            id: object::new(ctx),
            coupon_id: coupon_data.coupon_id,
            lottery_type,
            lp_amount,
            epoch: cur_epoch,
        };

        transfer::transfer(coupon, sender(ctx));
    }

    // Return the swap factor (10000 * coin_a / coin_b)
    public entry fun get_swap_factor<CoinA, CoinB>(pool: &Pool<CoinA, CoinB>) : u64 {
        let coin_a_amount_in_pool = balance::value(&pool.coin_a_bal);
        let coin_b_amount_in_pool = balance::value(&pool.coin_b_bal);
        10000 * coin_a_amount_in_pool / coin_b_amount_in_pool
    }

    public fun get_coupon_id(coupon: &Coupon) : u64 {
        coupon.coupon_id
    }

    public fun get_coupon_lottery_type(coupon: &Coupon) : u64 {
        coupon.lottery_type
    }

    public fun get_coupon_lp_amount(coupon: &Coupon) : u64 {
        coupon.lp_amount
    }

    public fun get_coupon_epoch(coupon: &Coupon) : u64 {
        coupon.epoch
    }

    public fun release_coupon(coupon: Coupon) {
        let Coupon { id, coupon_id:_, lottery_type:_, lp_amount:_, epoch:_ } = coupon;
        id.delete();
    }

    #[test_only]
    public fun get_coupon_for_testing(coupon_id: u64, lottery_type: u64, lp_amount: u64, epoch: u64, ctx: &mut TxContext): Coupon {
        Coupon {
            id: object::new(ctx),
            coupon_id,
            lottery_type,
            lp_amount,
            epoch
        }
    }

    // New Feature: Get pool balances
    public fun get_pool_balances<CoinA, CoinB>(pool: &Pool<CoinA, CoinB>): (u64, u64) {
        let coin_a_balance = balance::value(&pool.coin_a_bal);
        let coin_b_balance = balance::value(&pool.coin_b_bal);
        (coin_a_balance, coin_b_balance)
    }
}
