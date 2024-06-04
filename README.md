# Sui Fox Swap

## Introduction

FOX Swap is a platform on the Sui blockchain. FOX Swap allows users to engage in transactions and add liquidity, among other activities.

A distinctive feature of this project is that users can acquire Liquidity Provider Tokens (LPs) by adding liquidity. Upon acquiring LPs, users are entitled to claim one free lottery ticket each epoch. FOX Swap features multiple lottery pools, with each offering a unique drawing method. Users can choose to receive lottery tickets from any of these pools. Should a user win in a lottery draw, they are rewarded with Fox tokens as their prize.

[Video Introduction](https://www.loom.com/share/64d3c0dd3908427ba0bd89fc9804a2af)

## Structs

### fox_swap::LP
After adding liquidity, users can receive Liquidity Provider Tokens (LPs).

### fox_swap::Pool
Swap pool where users can swap tokens or add liquidity to earn rewards (coupons).

### fox_swap::Coupon
Represents coupon information.

### fox_lottery::LotteryPoolA
Lottery reward pool used for storing lottery status and distributing rewards to winning users.

### fox_lottery::LotteryPoolB
Lottery reward pool used for storing lottery status and distributing rewards to winning users.

## Functions
### fox_swap::create_swap_pool
Creates a swap pool.

### fox_swap::add_liquidity
Adds liquidity to the swap pool.

### fox_swap::remove_liquidity
Removes liquidity from the swap pool.

### fox_swap::swap_coin_a_to_coin_b
Swaps Coin A for Coin B in the swap pool.

### fox_swap::swap_coin_b_to_coin_a
Swaps Coin B for Coin A in the swap pool.

### fox_swap::get_daily_coupon
Retrieves the daily coupon.

### fox_lottery::create_lottery_pool_a
Creates an instant lottery reward pool.

### fox_lottery::add_pool_a_bonus
Adds a bonus to the reward pool.

### fox_lottery::draw_pool_a_instant_lottery
Draws an instant lottery and burns the ticket

### fox_lottery::create_lottery_pool_b
Creates an lotto lottery reward pool.

### fox_lottery::add_pool_b_bonus
Adds a bonus to the reward pool.

### fox_lottery::place_bet_to_pool_b
Place tickets in the prize pool.

### fox_lottery::pool_b_close_betting
Close the pool.

### fox_lottery::pool_b_draw_and_distrubute
Draw and distrubute prize.

## UNITTEST
```bash
$ sui --version
sui 1.26.0-homebrew

$ sui move test
INCLUDING DEPENDENCY fox_coin
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING fox_swap
Running Move unit tests
[ PASS    ] 0x0::fox_swap_tests::test_fox_lottery_pool_a
[ PASS    ] 0x0::fox_swap_tests::test_fox_lottery_pool_b
[ PASS    ] 0x0::fox_swap_tests::test_fox_lp
[ PASS    ] 0x0::fox_swap_tests::test_fox_swap
Test result: OK. Total tests: 4; passed: 4; failed: 0
```

## Prerequisites

### Generate And Set Key Pair

#### Generate Key Pair

```bash
$ git clone git@github.com:MystenLabs/fastcrypto.git
$ cd fastcrypto/
$ cargo run --bin ecvrf-cli keygen
```

This sequence of commands will output Secret Key and Public Key.

#### Create And Edit .env

```bash
$ cd fox_swap/app
$ touch .env
```

Set `FASTCRYPTO_PATH` and `SECRET_KEY`：

```bash
$ FASTCRYPTO_PATH=/path/to/your/fastcrypto/project
$ SECRET_KEY=your_generated_secret_key
```

#### Set the Public Key Environment Variable 

```bash
$ PUBLIC_KEY=0x1a90ed7e9e18a9f2db1f7fbabfe002745000b19b44fd68d87d97c6785460714e
```

### Deploy the fox_coin Contract

```bash
$ sui client publish --gas-budget 50000000
```

Retrieve the package_id and set it as the environment variable:

```bash
$ FOX_COIN_PACKAGE_ID=0x37d5b2a5f825631abf466e57626ae8ffed8195956327d8de5db5d6262c08b0c3
```

### Mint FOX tokens

```bash
$ ADDRESS=0x5bd66f0b7d9eecf2a05b29f8456f3e69d0ef79c289b613d2ff54c9a4c26fcb00
$ ADDRESS2=0x389f5a3253ff5e7058ca59ced00b377693ac86fad5721c20ffad36f68a583bfb
$ MINT_AMOUNT=500000000000
$ sui client call --package $FOX_COIN_PACKAGE_ID --module fox_coin --function mint --args 0xa6684dda21b3694de0858d340ca3a9c7e4dfb857b188c56985c61413d65c442a $MINT_AMOUNT $ADDRESS --gas-budget 5000000
```

### Request test SUI tokens

Refer to: [Get SUI Tokens](https://docs.sui.io/guides/developer/getting-started/get-coins)

## Deployment

Based on the previous preparations, the following environment variables have been set:

```bash
$ PUBLIC_KEY=0x1a90ed7e9e18a9f2db1f7fbabfe002745000b19b44fd68d87d97c6785460714e
$
$ FOX_COIN_500_OBJ=0xdb3bdb73a0ddcbdcee4463eb3044ac78234e4cb87d948b49bcb1ede6e778284d # 500 fox
$ SUI_COIN_100_OBJ=0xb2512bf5552b95dbbea87149ed39f7246e519325882d1f23ee278ad322c7316e # 100 sui
$
$ FOX_COIN_1000_OBJ=0xf47a913d84bc3505dfb0c678bb72450dfc294708f66d7d2ecd7472ceb09d7a18 # 1000 fox
$ FOX_COIN_2000_OBJ=0xdeb60f82a283e3ce0fd9aac48587d31e5f1251298794b054f4ca466d0e18556f # 2000 fox
$
$ FOX_COIN_25_OBJ=0x9c048a07f75cad41fd2d39318aeec5fe47b3f203aed4892a4dc6f740f50698ff # 25 fox
$ SUI_COIN_5_OBJ=0x1a7baee13bc95312362caf9b3a8c45dc989d62825b43167940f4215be91b4309 # 5 sui
$
$ ACC2_FOX_COIN_20_OBJ=0x0119090e9c98954914e22deb0289d308f895f737cd55e75e0f09e4eca252fcef # account2 20 fox
$ ACC2_SUI_COIN_4_OBJ=0x20c60075d326ddb4723526c666ee5b03a92cd32fe4dec0cdbbc7e1776d10d6a0 # account2 4 sui
```

### 1. Deploy FOX Swap Contract

```bash
$ sui client publish --gas-budget 100000000
```

Retrieve the package_id and set it as the environment variable:
```bash
$ PACKAGE_ID=0x5567394cd735476ec75dc4fd9977520557cc9645c34487bb97dc73dd10cd02b9
```

### 2. Create Swap Pool

```bash
$ sui client call --package $PACKAGE_ID --module fox_swap --function create_swap_pool --args $FOX_COIN_500_OBJ $SUI_COIN_100_OBJ 0x6 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 10000000
```

Retrieve the pool_id and set it as the environment variable:
```bash
$ SWAP_POOL=0xa17105fc695f7c35fc803e5aaceb8be05d1ada822709baa132495c099ac8e3d2
```

### 3. Create Prize Pool And Inject Prize Amount

Create instant-win prize pool:
```bash
$ sui client call --package $PACKAGE_ID --module fox_lottery --function create_lottery_pool_a --args $FOX_COIN_1000_OBJ $PUBLIC_KEY --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN --gas-budget 10000000
```

Retrieve the pool_id and set it as the environment variable:
```bash
$ LOTTERY_POOL_A=0xc86083ca3f59b804c8417428ee05fc35dfb11dde63634d3952a54b47170d0421
```

Create lotto prize pool:
```bash
$ sui client call --package $PACKAGE_ID --module fox_lottery --function create_lottery_pool_b --args $FOX_COIN_1000_OBJ $PUBLIC_KEY --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN --gas-budget 10000000
```

Retrieve the pool_id, admin_cap and set as the environment variables:
```bash
$ LOTTERY_POOL_B=0xb82ac4b7c530302ec9b02c6722db512621cad6ba611e5ab051cbb534f0a29876
$ POOL_B_ADMIN_CAP=0x55e765af0699eef62cc8c6d8483ca28d75ebd4240357d28100ee8795ce6da6d0
```

### 4. Add Liquidity And Obtain LP Tokens

```bash
$ sui client call --package $PACKAGE_ID --module fox_swap --function add_liquidity --args $SWAP_POOL $FOX_COIN_25_OBJ $SUI_COIN_5_OBJ 0x6 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
$
$ sui client switch --address $ADDRESS2 # switch to account2
$ sui client call --package $PACKAGE_ID --module fox_swap --function add_liquidity --args $SWAP_POOL $ACC2_FOX_COIN_20_OBJ $ACC2_SUI_COIN_4_OBJ 0x6 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
$ sui client switch --address $ADDRESS # switch back to account1
```

### 5. Obtain a Lottery Ticket Through LP Tokens And Participate In the Draw

After one epoch, you can obtain a lottery ticket through LP tokens with a choice between instant Or lotto type.

#### Instant Type

##### 5.1 Obtain a Lottery Ticket With Instant Lottery Ticket

```bash
$ LOTTERY_TYPE=1 # instant type
$ sui client call --package $PACKAGE_ID --module fox_swap --function get_daily_coupon --args $SWAP_POOL $LOTTERY_TYPE --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
```

Retrieve the COUPON_OBJ (ObjectType: ...::fox_swap::Coupon) and set it as the environment variable:
```bash
$ COUPON_OBJ=0xa4f7faddb493f4eed0adfdb6b96cd33f17667c4f018eb760e2c9554483a3eb0f
```

##### 5.2 Get Drawing Numbers Via Off-Chain Code

Obtaining coupon information through Coupon_obj and suivision.xyz:

```bash
{
    "coupon_id":"1717341932355",
    "epoch":"390",
    "lottery_type":"1",
    "lp_amount":"234783942744"
}
```

Modify `app/index.ts`,

```bash
const couponId = "1717341932355";
const lotteryType = "1";
const lpAmount = "234783942744";
const epoch = "390";
```

Compile and run:
```bash
$ npx tsc
$ node dist/index.js

input:61b751dca085b29cb208c08b00cc724143461713179c4cea7aa1b98710b05323
proof:8897c2e421a17f53c51bfff82e8f4bfe89a234b63c2b63daeee3814128749f2ce21b1df288fab720a6d7b570ae5f00e286e964186de4e22066bed5c96a038d415f0149bf860aabdd61e4b7baf428dd0b
output:11160a451377e193e423a261559f26b1d80fa4db171e4d8301df10df88c19e29cc16df4815c752f2546ed06f93423f947a1f49eee5eeb67ef82a58a7d526f7b6
```

Set environment variables:
```bash
$ PROOF=0x8897c2e421a17f53c51bfff82e8f4bfe89a234b63c2b63daeee3814128749f2ce21b1df288fab720a6d7b570ae5f00e286e964186de4e22066bed5c96a038d415f0149bf860aabdd61e4b7baf428dd0b
$ LOTTERY_NUMBER=0x11160a451377e193e423a261559f26b1d80fa4db171e4d8301df10df88c19e29cc16df4815c752f2546ed06f93423f947a1f49eee5eeb67ef82a58a7d526f7b6
```

##### 5.3 Draw And Claim Prizes

```bash
$ sui client call --package $PACKAGE_ID --module fox_lottery --function draw_pool_a_instant_lottery --args $COUPON_OBJ $SWAP_POOL $LOTTERY_POOL_A $LOTTERY_NUMBER $PROOF 0x8 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000

│  │   ┌───────────────────┬──────────────┐                                                                   │
│  │   │ bonus_coin_amount │ 0            │                                                                   │
│  │   ├───────────────────┼──────────────┤                                                                   │
│  │   │ lp_amount         │ 234783942744 │                                                                   │
│  │   ├───────────────────┼──────────────┤                                                                   │
│  │   │ number            │ 7460         │                                                                   │
│  │   └───────────────────┴──────────────┘
```

The output of `bonus_coin_amount` is 0, indicating that the user did not win.

#### Lotto Type

##### 5.1 Obtain a Lottery Ticket With Lotto Lottery Ticket

```bash
$ sui client switch --address $ADDRESS2 # switch to account2
$ LOTTERY_TYPE=2 # lotto type
$ sui client call --package $PACKAGE_ID --module fox_swap --function get_daily_coupon --args $SWAP_POOL $LOTTERY_TYPE --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
```

Retrieve the COUPON_OBJ (ObjectType: ...::fox_swap::Coupon) and set it as the environment variable:
```bash
$ COUPON_OBJ=0x5285951451242d588446f51426dcde7a11277807e8d91542deabf68483bf3c0d
```

##### 5.2 Tickets Placed in Prize Pool

```bash
$ sui client call --package $PACKAGE_ID --module fox_lottery --function place_bet_to_pool_b --args $COUPON_OBJ $LOTTERY_POOL_B --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN --gas-budget 5000000
```

##### 5.3 Administrator Closes the Pool

```bash
$ sui client switch --address $ADDRESS # switch to account1
$ sui client call --package $PACKAGE_ID --module fox_lottery --function pool_b_close_betting --args $POOL_B_ADMIN_CAP $LOTTERY_POOL_B --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN --gas-budget 5000000
```

##### 5.4 Get Drawing Numbers Via Off-Chain Code

Obtaining pool_b information through $LOTTERY_POOL_B id and suivision.xyz:

```bash
{
    "coin_bal":"2000000000000",
    "epoch":"390",
    "total_tickets_num":"894484",
    ...
}
```
Modify `app/index.ts`,

```bash
const coinBalAmount = "2000000000000";
const totalTicketsNum = "894484";
const poolBEpoch = "390";
```

Compile and run:
```bash
$ npx tsc
$ node dist/index.js

input:be89cb8d2acf2d122b71deb482ce43b1095746f1e626dc71b7ac81ad1dee8162
proof:0c43fa7c20ff255fb9d9b2cd3a62f18b820dbbd860e3e56a153b50c7ad3cbd0bb7cd33ac3c759723867aeed5986d862d9b8a6fdc51dca68ee9e994691e5a4d850ff06bfd382be4e11f8a2ea9f7911303
output:b5fe4560c744c40d72df215b7054fcdb1962d1f13afcf8f7d788cd2333b82f8aa49545f06e05e5fc15d85191ddca36b9ea4d3dc9a5d8ab9bb51f904f9a25d2d5
```

Set environment variables:
```bash
$ PROOF=0x0c43fa7c20ff255fb9d9b2cd3a62f18b820dbbd860e3e56a153b50c7ad3cbd0bb7cd33ac3c759723867aeed5986d862d9b8a6fdc51dca68ee9e994691e5a4d850ff06bfd382be4e11f8a2ea9f7911303
$ LOTTERY_NUMBER=0xb5fe4560c744c40d72df215b7054fcdb1962d1f13afcf8f7d788cd2333b82f8aa49545f06e05e5fc15d85191ddca36b9ea4d3dc9a5d8ab9bb51f904f9a25d2d5
```

##### 5.5 Administrator Conducts the Draw

```bash
$ sui client call --package $PACKAGE_ID --module fox_lottery --function pool_b_draw_and_distrubute --args $POOL_B_ADMIN_CAP $SWAP_POOL $LOTTERY_POOL_B $LOTTERY_NUMBER $PROOF 0x8 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000

│  │   ┌───────────────────┬────────────────────────────────────────────────────────────────────┐             │
│  │   │ bonus_coin_amount │ 40002287                                                           │             │
│  │   ├───────────────────┼────────────────────────────────────────────────────────────────────┤             │
│  │   │ number            │ 55228                                                              │             │
│  │   ├───────────────────┼────────────────────────────────────────────────────────────────────┤             │
│  │   │ winner            │ 0x389f5a3253ff5e7058ca59ced00b377693ac86fad5721c20ffad36f68a583bfb │             │
│  │   └───────────────────┴────────────────────────────────────────────────────────────────────┘
```
The output of `winner` is 0x389f5a3253ff5e7058ca59ced00b377693ac86fad5721c20ffad36f68a583bfb , indicating that $ADDRESS2 wins the reward.

## Contribution

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

## License

This project is licensed under the MIT License.

