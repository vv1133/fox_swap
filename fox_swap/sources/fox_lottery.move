/// Module: fox_lottery
module fox_swap::fox_lottery {
    use std::hash::sha3_256;
    use sui::tx_context::{sender, epoch};
    use sui::math;
    use sui::balance::{self, Balance};
    use sui::coin::{self, Coin};
    use sui::random::{self, Random};
    use sui::ecvrf;
    use sui::event;
    use sui::object::{self, UID};
    use sui::transfer;
    use fox_swap::fox_swap::{self, Coupon, Pool};
    use fox_swap::utils;

    const EAmount: u64 = 1;
    const ELotteryInvalidTime: u64 = 2;
    const ELotteryInvalidPool: u64 = 3;
    const ELotteryVerifyFail: u64 = 4;
    const ELotteryFrozen: u64 = 5;
    const ELotteryUnFrozen: u64 = 6;

    const INSTANT_LOTTERY_POOL_ID: u64 = 1;
    const LOTTO_POOL_ID: u64 = 2;

    public struct LotteryPoolA<phantom CoinA> has key {
        id: UID,
        public_key: vector<u8>,
        coin_bal: Balance<CoinA>,
    }

    public struct PoolAOutcome has drop, copy {
        lp_amount: u64,
        bonus_coin_amount: u64,
        number: u16,
    }

    public struct PoolBUserTicketsInfo has store, drop {
        ticket_begin_index: u64,
        tickets_num: u64,
        owner: address,
    }

    public struct LotteryPoolB<phantom CoinA> has key {
        id: UID,
        public_key: vector<u8>,
        coin_bal: Balance<CoinA>,
        total_tickets_num: u64,
        epoch: u64,
        frozen: bool,
        tickets_info_vector: vector<PoolBUserTicketsInfo>,
    }

    public struct PoolBOutcome has drop, copy {
        bonus_coin_amount: u64,
        number: u64,
        winner: address,
    }

    public struct PoolBAdminCap has key {
        id: UID,
    }

    // Create a Lottery Pool A with the provided coin and public key
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

    // Add bonus to Lottery Pool A
    public entry fun add_pool_a_bonus<CoinA>(pool: &mut LotteryPoolA<CoinA>, coin_a: Coin<CoinA>, _ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);
        assert!(coin_amount > 0, EAmount);
        balance::join(&mut pool.coin_bal, coin::into_balance(coin_a));
    }

    // Instant lottery drawing function for Pool A
    entry fun draw_pool_a_instant_lottery<CoinA, CoinB>(coupon: Coupon, pool: &Pool<CoinA, CoinB>, lottery_pool_a: &mut LotteryPoolA<CoinA>, lottery_number: vector<u8>, proof: vector<u8>, r: &Random, ctx: &mut TxContext) {
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

        let mut generator = random::new_generator(r, ctx);
        let random_u16 = random::generate_u16(&mut generator);

        let number0 = *vector::borrow<u8>(&lottery_number, 0);
        let number1 = *vector::borrow<u8>(&lottery_number, 1);
        let number = (((number0 & 0x1f) as u16) << 8u8) | (number1 as u16);
        let lucky_number_u32: u32 = (number as u32) * (random_u16 as u32);
        let lucky_number: u16 = (lucky_number_u32 & 0xffffu32) as u16;
        
        let swap_factor = fox_swap::get_swap_factor(pool);
        let full_bonus_coin_amount = math::sqrt(coupon_lp_amount) * math::sqrt(coupon_lp_amount * swap_factor / 10000) * 2;
        let bonus_coin_amount = match lucky_number {
            0u16 => full_bonus_coin_amount,
            1u16..=10u16 => full_bonus_coin_amount / 10,
            11u16..=510u16 => full_bonus_coin_amount / 100,
            _ => 0,
        };

        let pool_coin_amount = balance::value(&lottery_pool_a.coin_bal);
        assert!(pool_coin_amount >= bonus_coin_amount, EAmount);

        if bonus_coin_amount > 0 {
            let bonus_balance = balance::split(&mut lottery_pool_a.coin_bal, bonus_coin_amount);
            transfer::public_transfer(coin::from_balance(bonus_balance, ctx), sender(ctx));
        };

        fox_swap::release_coupon(coupon);

        let pool_a_outcome = PoolAOutcome {
            lp_amount: coupon_lp_amount,
            bonus_coin_amount,
            number: lucky_number,
        };
        event::emit(pool_a_outcome);
    }

    // Create a Lottery Pool B with the provided coin and public key
    public entry fun create_lottery_pool_b<CoinA>(coin_a: Coin<CoinA>, public_key: vector<u8>, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);
        assert!(coin_amount > 0, EAmount);

        let coin_balance = coin::into_balance(coin_a);
        let pool = LotteryPoolB {
            id: object::new(ctx),
            public_key,
            coin_bal: coin_balance,
            total_tickets_num: 0,
            epoch: 0,
            frozen: false,
            tickets_info_vector: vector::empty<PoolBUserTicketsInfo>(),
        };

        transfer::share_object(pool);

        let pool_b_admin_cap = PoolBAdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(pool_b_admin_cap, sender(ctx));
    }

    // Add bonus to Lottery Pool B
    public entry fun add_pool_b_bonus<CoinA>(pool: &mut LotteryPoolB<CoinA>, coin_a: Coin<CoinA>, _ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);
        assert!(coin_amount > 0, EAmount);
        balance::join(&mut pool.coin_bal, coin::into_balance(coin_a));
    }

    // Place bet in Lottery Pool B
    public entry fun place_bet_to_pool_b<CoinA>(coupon: Coupon, lottery_pool_b: &mut LotteryPoolB<CoinA>, ctx: &mut TxContext) {
        let coupon_lottery_type = fox_swap::get_coupon_lottery_type(&coupon);
        let coupon_lp_amount = fox_swap::get_coupon_lp_amount(&coupon);
        let coupon_epoch = fox_swap::get_coupon_epoch(&coupon);

        assert!(!lottery_pool_b.frozen, ELotteryFrozen);
        assert!(coupon_lottery_type == LOTTO_POOL_ID, ELotteryInvalidPool);
        assert!(coupon_epoch + 1 >= epoch(ctx), ELotteryInvalidTime);

        let tickets_num = coupon_lp_amount / 10000;
        let ticket_begin_index = lottery_pool_b.total_tickets_num;
        let tickets_info = PoolBUserTicketsInfo {
            ticket_begin_index,
            tickets_num,
            owner: sender(ctx),
        };

        lottery_pool_b.tickets_info_vector.push_back(tickets_info);
        lottery_pool_b.total_tickets_num += tickets_num;

        fox_swap::release_coupon(coupon);
    }

    // Close betting for Lottery Pool B
    public entry fun pool_b_close_betting<CoinA>(_: &PoolBAdminCap, lottery_pool_b: &mut LotteryPoolB<CoinA>, ctx: &mut TxContext) {
        lottery_pool_b.frozen = true;
        assert!(lottery_pool_b.epoch < epoch(ctx), ELotteryInvalidTime);
        lottery_pool_b.epoch = epoch(ctx);
    }

    // Draw and distribute the prize for Lottery Pool B
    entry fun pool_b_draw_and_distribute<CoinA, CoinB>(_: &PoolBAdminCap, pool: &Pool<CoinA, CoinB>, lottery_pool_b: &mut LotteryPoolB<CoinA>, lottery_number: vector<u8>, proof: vector<u8>, r: &Random, ctx: &mut TxContext) {
        assert!(lottery_pool_b.frozen, ELotteryUnFrozen);
        lottery_pool_b.frozen = false;

        let pool_coin_bal_amount = balance::value(&lottery_pool_b.coin_bal);
        let pool_total_tickets_num = lottery_pool_b.total_tickets_num;
        let pool_epoch = lottery_pool_b.epoch;

        let mut pool_vector = vector::empty<u8>();
        pool_vector.append(utils::split_u64_into_u8s(pool_coin_bal_amount));
        pool_vector.append(utils::split_u64_into_u8s(pool_total_tickets_num));
        pool_vector.append(utils::split_u64_into_u8s(pool_epoch));

        let lottery_input = sha3_256(pool_vector);
        let public_key = lottery_pool_b.public_key;
        assert!(ecvrf::ecvrf_verify(&lottery_number, &lottery_input, &public_key, &proof), ELotteryVerifyFail);

        let mut number_u64 = 0u64;
        for i in 0..8 {
            let number_u8 = *vector::borrow<u8>(&lottery_number, i);
            number_u64 = (number_u64 << 8) | (number_u8 as u64);
        }

        let mut generator = random::new_generator(r, ctx);
        let random_u64 = random::generate_u64(&mut generator);
        let lucky_number = (((number_u64 as u128) * (random_u64 as u128)) % (lottery_pool_b.total_tickets_num as u128)) as u64;

        let total_tickets_num = lottery_pool_b.total_tickets_num;
        let swap_factor = fox_swap::get_swap_factor(pool);
        let bonus_coin_amount = math::sqrt(total_tickets_num * 10000) * math::sqrt(total_tickets_num * swap_factor) / 500;

        for i in 0..lottery_pool_b.tickets_info_vector.length() {
            let ticket_begin_index = lottery_pool_b.tickets_info_vector[i].ticket_begin_index;
            let tickets_num = lottery_pool_b.tickets_info_vector[i].tickets_num;
            if lucky_number >= ticket_begin_index && lucky_number < ticket_begin_index + tickets_num {
                let winner = lottery_pool_b.tickets_info_vector[i].owner;
                let bonus_balance = balance::split(&mut lottery_pool_b.coin_bal, bonus_coin_amount);
                transfer::public_transfer(coin::from_balance(bonus_balance, ctx), winner);
                let pool_b_outcome = PoolBOutcome {
                    bonus_coin_amount,
                    number: lucky_number,
                    winner,
                };
                event::emit(pool_b_outcome);
                break;
            }
        }

        lottery_pool_b.total_tickets_num = 0;
        while !lottery_pool_b.tickets_info_vector.is_empty() {
            lottery_pool_b.tickets_info_vector.pop_back();
        }
    }

    // Fetch the balance of Lottery Pool B
    #[test_only]
    public fun get_pool_b_coin_bal_amount<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>): u64 {
        balance::value(&lottery_pool_b.coin_bal)
    }

    // Fetch the total number of tickets in Lottery Pool B
    #[test_only]
    public fun get_pool_b_total_tickets_num<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>): u64 {
        lottery_pool_b.total_tickets_num
    }

    // Fetch the epoch of Lottery Pool B
    #[test_only]
    public fun get_pool_b_epoch<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>): u64 {
        lottery_pool_b.epoch
    }

    // New Feature: View all users participating in Lottery Pool B
    public fun get_pool_b_participants<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>): vector<address> {
        let mut participants = vector::empty<address>();
        for ticket_info in &lottery_pool_b.tickets_info_vector {
            participants.push_back(ticket_info.owner);
        }
        participants
    }
}
