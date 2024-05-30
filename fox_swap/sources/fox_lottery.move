/// Module: fox_lottery
module fox_swap::fox_lottery {
    use std::hash::sha3_256;
    use sui::tx_context::{sender, epoch};
    use sui::math;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::ecvrf;
    use sui::event;
    use fox_swap::fox_swap::{Self, Coupon, Pool};
    use fox_swap::utils;

    const EAmount: u64 = 1;
    const ELotteryInvalidTime: u64 = 2;
    const ELotteryInvalidPool: u64 = 3;
    const ELotteryVerifyFail: u64 = 4;

    const INSTANT_LOTTERY_POOL_ID: u64 = 1;

    public struct LotteryPoolA<phantom CoinA> has key {
        id: UID,
        public_key: vector<u8>,
        coin_bal: Balance<CoinA>,
    }

    public struct LotteryOutcome has drop, copy {
        lp_amount: u64,
        bonus_coin_amount: u64,
        number: u16,
    }

    public entry fun create_lottery_pool_a<CoinA>(coin_a: Coin<CoinA>, public_key: vector<u8>, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);

        assert!(coin_amount > 0, EAmount);

        let coin_balance = coin::into_balance(coin_a);

        let pool = LotteryPoolA {
            id: object::new(ctx),
            public_key,
            coin_bal: coin_balance,
        };
        
        transfer::share_object(pool);
    }

    public entry fun add_pool_a_bonous<CoinA> (pool: &mut LotteryPoolA<CoinA>, coin_a: Coin<CoinA>, _ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);
        assert!(coin_amount > 0, EAmount);
        balance::join(&mut pool.coin_bal, coin::into_balance(coin_a));
    }

    // 即开型彩票
    public entry fun draw_pool_a_instant_lottery<CoinA, CoinB>(coupon: Coupon, pool: &Pool<CoinA, CoinB>,
        lottery_pool_a: &mut LotteryPoolA<CoinA>, lottery_number: vector<u8>, proof: vector<u8>, ctx: &mut TxContext) {

        let coupon_id = fox_swap::get_coupon_id(&coupon);
        let coupon_lottery_type = fox_swap::get_coupon_lottery_type(&coupon);
        let coupon_lp_amount = fox_swap::get_coupon_lp_amount(&coupon);
        let coupon_epoch = fox_swap::get_coupon_epoch(&coupon);
        let mut coupon_vector = vector::empty<u8>();
        coupon_vector.append(utils::split_u64_into_u8s(coupon_id));
        coupon_vector.append(utils::split_u64_into_u8s(coupon_lottery_type));
        coupon_vector.append(utils::split_u64_into_u8s(coupon_lp_amount));
        coupon_vector.append(utils::split_u64_into_u8s(coupon_epoch));

        let lottery_input = sha3_256(coupon_vector);

        assert!(coupon_lottery_type == INSTANT_LOTTERY_POOL_ID, ELotteryInvalidPool);
        assert!(coupon_epoch + 1 >= epoch(ctx), ELotteryInvalidTime);
        let public_key = lottery_pool_a.public_key;
        assert!(ecvrf::ecvrf_verify(&lottery_number, &lottery_input, &public_key, &proof), ELotteryVerifyFail);

        let number0 = *vector::borrow<u8>(&lottery_number, 0);
        let number1 = *vector::borrow<u8>(&lottery_number, 1);
        let number = (((number0 & 0xf) as u16) << 8u8) | (number1 as u16);
        // 1/8192概率中100%的金额, 10/8192概率中10%的金额, 500/8192概率中1%的金额
        let swap_factor = fox_swap::get_swap_factor(pool);
        // b = 10000 * a / swap_factor
        // a * b = a * 10000 * a / swap_factor = lp * lp
        // a = sqrt(lp * lp * swap_factor / 10000)
        let full_bonus_coin_amount = math::sqrt(coupon_lp_amount) * math::sqrt(coupon_lp_amount) * swap_factor / 10000;
        let bonus_coin_amount;
        if (number == 0u16) {
           bonus_coin_amount = full_bonus_coin_amount;
        } else if (number <= 10u16) {
           bonus_coin_amount = full_bonus_coin_amount / 10;
        } else if (number <= 510u16) {
           bonus_coin_amount = full_bonus_coin_amount / 100;
        } else {
           bonus_coin_amount = 0;
        };

        let pool_coin_amount = balance::value(&lottery_pool_a.coin_bal);
        assert!(pool_coin_amount >= bonus_coin_amount, EAmount);

        if (bonus_coin_amount > 0) {
            let bonus_balance = balance::split(&mut lottery_pool_a.coin_bal, bonus_coin_amount);
            transfer::public_transfer(coin::from_balance(bonus_balance, ctx), sender(ctx));
        };

        //std::debug::print(&coupon);
        fox_swap::release_coupon(coupon);

        let lottery_outcom = LotteryOutcome {
            lp_amount: coupon_lp_amount,
            bonus_coin_amount,
            number,
        };
        event::emit(lottery_outcom);
        //std::debug::print(&lottery_outcom);
    }
}
