#[test_only]
module fox_swap::fox_swap_tests {
    use fox_swap::fox_swap;
    use fox_swap::fox_lottery;
    use sui::coin;
    use sui::test_scenario;
    use sui::math;
    use sui::sui::SUI;
    use sui::clock;
    use fox_coin::fox_coin::FOX_COIN;

    const ELpAmountInvalid: u64 = 1;

    const FoxCreateAmount: u64 = 5000000000000;
    const SuiCreateAmount: u64 = 1000000000000;
    const FoxAddAmount: u64 = 500000000000;
    const SuiAddAmount: u64 = 100000000000;

    const LotteryPoolCreateAmount: u64 = 5000000000000;
    const LotteryPoolAddAmount: u64 = 5000000000000;

    const ECVRF_PROOF: vector<u8> = x"f82429bb25385cf60e14c5c160d4fb0614c64923308c83e3c2bd9da36efeb63ad594442fcf2f47e82fbc176f5993715999176bc16f699ea3955df3d2a439a7728c95fa324906306c44ff6f0df2833e00";
    const ECVRF_OUTPUT: vector<u8> = x"87cb7951dbb68b628a6fda43236de3544e4a8d70a77b6390e0d1743b1b57091563b5721a15de4befe0247fb06c853ebe13e217ea730e010a9eef4b7544e06a8e";

    #[test]
    fun test_fox_swap() {
        let jason = @0x11;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::swap_coin_b_to_coin_a(pool_ref, coin_b2, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_a2 = test_scenario::take_from_sender<coin::Coin<FOX_COIN>>(scenario);
            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::add_liquidity(pool_ref, coin_a2, coin_b2, &clock, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_fox_lp() {
        let jason = @0x11;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_a2 = coin::mint_for_testing<FOX_COIN>(FoxAddAmount, test_scenario::ctx(scenario));
            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::add_liquidity(pool_ref, coin_a2, coin_b2, &clock, test_scenario::ctx(scenario));

            // next epoch
            test_scenario::ctx(scenario).increment_epoch_number();

            let lottery_type = 1; // instant lottery
            fox_swap::get_daily_coupon(pool_ref, lottery_type, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let coupon = test_scenario::take_from_sender<fox_swap::Coupon>(scenario);
            let lp_amount = fox_swap::get_coupon_lp_amount(&coupon);
            let pool_new_lp_amount = math::sqrt(FoxCreateAmount + FoxAddAmount) * math::sqrt(SuiCreateAmount + SuiAddAmount);
            let pool_old_lp_amount = math::sqrt(FoxCreateAmount) * math::sqrt(SuiCreateAmount);
            let expected_lp_amount = pool_new_lp_amount - pool_old_lp_amount;
            assert!(lp_amount == expected_lp_amount, ELpAmountInvalid);
            test_scenario::return_to_sender(scenario, coupon);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fox_lottery() {
        let jason = @0x11;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            let coin = coin::mint_for_testing<FOX_COIN>(LotteryPoolCreateAmount, test_scenario::ctx(scenario));
            fox_lottery::create_pool(coin, test_scenario::ctx(scenario));

            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut lottery_pool_a = test_scenario::take_shared<fox_lottery::LotteryPoolA<FOX_COIN>>(scenario);
            let lottery_pool_ref = &mut lottery_pool_a;

            let swap_pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);

            let coin2 = coin::mint_for_testing<FOX_COIN>(LotteryPoolAddAmount, test_scenario::ctx(scenario));
            fox_lottery::add_pool_bonous(lottery_pool_ref, coin2, test_scenario::ctx(scenario));

            let ecvrf_proof = ECVRF_PROOF;
            let ecvrf_output = ECVRF_OUTPUT;
            let coupon = fox_swap::get_coupon_for_testing(328474789, 1, 99999999999, 100, test_scenario::ctx(scenario));
            fox_lottery::draw_instant_lottery(coupon, &swap_pool, lottery_pool_ref,
                     ecvrf_output, ecvrf_proof, test_scenario::ctx(scenario));

            test_scenario::return_shared(lottery_pool_a);
            test_scenario::return_shared(swap_pool);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }
}
