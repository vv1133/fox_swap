// Module: fox_lottery
module fox_swap::fox_lottery {
    use std::hash::sha3_256;
    use sui::tx_context::{sender, epoch};
    use sui::math;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::random::{Self, Random};
    use sui::ecvrf;
    use sui::event;
    use fox_swap::fox_swap::{Self, Coupon, Pool};
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
    entry fun draw_pool_a_instant_lottery<CoinA, CoinB>(coupon: Coupon, pool: &Pool<CoinA, CoinB>,
        lottery_pool_a: &mut LotteryPoolA<CoinA>, lottery_number: vector<u8>, proof: vector<u8>, r: &Random, ctx: &mut TxContext) {

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
        // 1/8192概率中100%的金额, 10/8192概率中10%的金额, 500/8192概率中1%的金额
        let swap_factor = fox_swap::get_swap_factor(pool); // swap_factor是10000*coin_a/coin_b
        // sui_amt = 10000 * fox_amt / swap_factor
        // fox_amt * sui_amt = fox_amt * 10000 * fox_amt / swap_factor = lp * lp
        // fox_amt = sqrt(lp * lp * swap_factor / 10000)
        // 用户质押为等值的2*fox_amt
        let full_bonus_coin_amount = math::sqrt(coupon_lp_amount) * math::sqrt(coupon_lp_amount * swap_factor / 10000) * 2;
        let bonus_coin_amount;
        if (lucky_number == 0u16) {
           bonus_coin_amount = full_bonus_coin_amount;
        } else if (lucky_number <= 10u16) {
           bonus_coin_amount = full_bonus_coin_amount / 10;
        } else if (lucky_number <= 510u16) {
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

        let pool_a_outcom = PoolAOutcome {
            lp_amount: coupon_lp_amount,
            bonus_coin_amount,
            number: lucky_number,
        };
        event::emit(pool_a_outcom);
        //std::debug::print(&pool_a_outcom);
    }

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

    public entry fun add_pool_b_bonous<CoinA> (pool: &mut LotteryPoolB<CoinA>, coin_a: Coin<CoinA>, _ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin_a);
        assert!(coin_amount > 0, EAmount);
        balance::join(&mut pool.coin_bal, coin::into_balance(coin_a));
    }

    // 投入乐透型彩票
    public entry fun place_bet_to_pool_b<CoinA>(coupon: Coupon, lottery_pool_b: &mut LotteryPoolB<CoinA>, ctx: &mut TxContext) {

        let coupon_lottery_type = fox_swap::get_coupon_lottery_type(&coupon);
        let coupon_lp_amount = fox_swap::get_coupon_lp_amount(&coupon);
        let coupon_epoch = fox_swap::get_coupon_epoch(&coupon);

        assert!(!lottery_pool_b.frozen, ELotteryFrozen);
        assert!(coupon_lottery_type == LOTTO_POOL_ID, ELotteryInvalidPool);
        assert!(coupon_epoch + 1 >= epoch(ctx), ELotteryInvalidTime);

        let tickets_num = coupon_lp_amount / 10000; // lp/10000为1个ticket
        let ticket_begin_index = lottery_pool_b.total_tickets_num;
        let tickets_info = PoolBUserTicketsInfo {
            ticket_begin_index,
            tickets_num,
            owner: sender(ctx),
        };

        lottery_pool_b.tickets_info_vector.push_back(tickets_info);
        lottery_pool_b.total_tickets_num = lottery_pool_b.total_tickets_num + tickets_num;

        //std::debug::print(&coupon);
        fox_swap::release_coupon(coupon);
    }

    // 关闭投注乐透型彩票奖池
    public entry fun pool_b_close_betting<CoinA>(_: &PoolBAdminCap, lottery_pool_b: &mut LotteryPoolB<CoinA>, ctx: &mut TxContext) {
        lottery_pool_b.frozen = true;
        assert!(lottery_pool_b.epoch < epoch(ctx), ELotteryInvalidTime); // 一个epoch只能开一次奖
        lottery_pool_b.epoch = epoch(ctx);
        //std::debug::print(&lottery_pool_b.coin_bal);
        //std::debug::print(&lottery_pool_b.total_tickets_num);
        //std::debug::print(&lottery_pool_b.epoch);
    }

    // 开奖并发奖
    entry fun pool_b_draw_and_distrubute<CoinA, CoinB>(_: &PoolBAdminCap, pool: &Pool<CoinA, CoinB>, lottery_pool_b: &mut LotteryPoolB<CoinA>,
             lottery_number: vector<u8>, proof: vector<u8>, r: &Random, ctx: &mut TxContext) {

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

        // get lucky number
        let mut number_u64 = 0u64;
        let mut i = 0;
        while (i < 8) {
            let number_u8 = *vector::borrow<u8>(&lottery_number, i);
            number_u64 = (number_u64 << 8) | (number_u8 as u64);
            i = i + 1;
        };

        let mut generator = random::new_generator(r, ctx);
        let random_u64 = random::generate_u64(&mut generator);
        let lucky_number = (((number_u64 as u128) * (random_u64 as u128)) % (lottery_pool_b.total_tickets_num as u128)) as u64;

        // get bonus_coin_amount
        let total_tickets_num = lottery_pool_b.total_tickets_num;
        let swap_factor = fox_swap::get_swap_factor(pool); // swap_factor是10000*coin_a/coin_b
        // sui_amt = 10000 * fox_amt / swap_factor
        // fox_amt * sui_amt = fox_amt*10000*fox_amt/swap_factor = lp*lp = (total_tickets_num*10000)*(total_tickets_num*10000)
        // fox_amt = sqrt(lp*lp*swap_factor/10000) = sqrt(total_tickets_num*10000*total_tickets_num*swap_factor)
        // 用户质押为等值的2*fox_amt
        let bonus_coin_amount = math::sqrt(total_tickets_num*10000) * math::sqrt(total_tickets_num* swap_factor) / 500; // 奖励为总奖金池的1/1000

        // get winner and transfer bonus
        i = 0;
        while (i < lottery_pool_b.tickets_info_vector.length()) {
            let ticket_begin_index = lottery_pool_b.tickets_info_vector[i].ticket_begin_index;
            let tickets_num = lottery_pool_b.tickets_info_vector[i].tickets_num;
            if (lucky_number >= ticket_begin_index && lucky_number < ticket_begin_index + tickets_num) {
                let winner = lottery_pool_b.tickets_info_vector[i].owner;
                let bonus_balance = balance::split(&mut lottery_pool_b.coin_bal, bonus_coin_amount);
                transfer::public_transfer(coin::from_balance(bonus_balance, ctx), winner);
                let pool_b_outcom = PoolBOutcome {
                    bonus_coin_amount,
                    number: lucky_number,
                    winner,
                };
                event::emit(pool_b_outcom);
                //std::debug::print(&pool_b_outcom);
                break
            };
            i = i + 1;
        };

        // reset lottery pool
        lottery_pool_b.total_tickets_num = 0;
        while (!lottery_pool_b.tickets_info_vector.is_empty()) {
           let PoolBUserTicketsInfo{ticket_begin_index:_ticket_begin_index, tickets_num:_tickets_num, owner:_owner} = lottery_pool_b.tickets_info_vector.pop_back();
        };
    }

    #[test_only]
    public fun get_pool_b_coin_bal_amount<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>) : u64 {
        let pool_coin_bal_amount = balance::value(&lottery_pool_b.coin_bal);
        pool_coin_bal_amount
    }

    #[test_only]
    public fun get_pool_b_total_tickets_num<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>) : u64 {
        lottery_pool_b.total_tickets_num
    }

    #[test_only]
    public fun get_pool_b_epoch<CoinA>(lottery_pool_b: &LotteryPoolB<CoinA>) : u64 {
        lottery_pool_b.epoch
    }
}

