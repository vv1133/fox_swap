# Sui Fox Swap

## Introduce

FOX Swap is a platform on the Sui blockchain. FOX Swap allows users to engage in transactions and add liquidity, among other activities.
A distinctive feature of this project is that users can acquire Liquidity Provider Tokens (LPs) by adding liquidity. Upon acquiring LPs, users are entitled to claim one free lottery ticket each epoch. FOX Swap features multiple lottery pools, with each offering a unique drawing method. Users can choose to receive lottery tickets from any of these pools. Should a user win in a lottery draw, they are rewarded with Fox tokens as their prize.

## Structs

### fox_swap::LP
After adding liquidity, users can receive Liquidity Provider Tokens (LPs).

### fox_swap::Pool
Swap pool where users can swap tokens or add liquidity to earn rewards (coupons).

### fox_swap::Coupon
Represents coupon information.

### fox_lottery::LotteryPoolA
Lottery reward pool used for distributing rewards to winning users.

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

## UNITTEST
```bash
$ sui --version
sui 1.25.0-homebrew

$ sui move test
INCLUDING DEPENDENCY fox_coin
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING fox_swap
Running Move unit tests
[ PASS    ] 0x0::fox_swap_tests::test_fox_lottery
[ PASS    ] 0x0::fox_swap_tests::test_fox_lp
[ PASS    ] 0x0::fox_swap_tests::test_fox_swap
Test result: OK. Total tests: 3; passed: 3; failed: 0
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
$ FOX_COIN_500_OBJ=0xed8210abf24e18adcd64f2e143b027751e14ca3c2431bc6713a2a8d31db03c91 # 500 fox
$ FOX_COIN_25_OBJ=0x4f5d6b1c4ee6bc59a72cfc8c086e2cc1081daebcb0477cf360557fa362bb6350 # 25 fox
$ FOX_COIN_1000_OBJ=0x72467eb52574ca870001bb898e3ba96bfd18e4c6be6726cbf1d958ae967c14ae # 1000 fox
$ 
$ SUI_COIN_100_OBJ=0x1c0c45fcff2f322cf9a9d1104eea295306c62f59dd1ba3c12488bb12a3cd2075 # 100 sui
$ SUI_COIN_5_OBJ=0xe5c8acf6375177a808d1893bef1c04e95b64a5196a929827069f1107ef35aa26 # 5 sui
```

### 1. Deploy FOX Swap Contract

```bash
$ sui client publish --gas-budget 50000000
```

Retrieve the package_id and set it as the environment variable:
```bash
$ PACKAGE_ID=0xdfc1261a459ae9e37edcadfead4bc9362ac659d6f72f54fc3083ddd12e6cec94
```

### 2. Create Swap Pool

```bash
$ sui client call --package $PACKAGE_ID --module fox_swap --function create_swap_pool --args $FOX_COIN_500_OBJ $SUI_COIN_100_OBJ 0x6 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 10000000
```

Retrieve the pool_id and set it as the environment variable:
```bash
SWAP_POOL=0x63fbd4f662a24824c14d6a6054526c00bf623e36b31140de91732e5c443b8459
```

### 3. Create Instant-Win Prize Pool And Inject Prize Amount

```bash
# sui client call --package $PACKAGE_ID --module fox_lottery --function create_lottery_pool_a --args $FOX_COIN_1000_OBJ $PUBLIC_KEY --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN --gas-budget 10000000
```

Retrieve the pool_id and set it as the environment variable:
```bash
LOTTERY_POOL=0x2804b9969332fd6f767f2391280c378c5358816ccd263e9fd6c4cbf3cc8c7708
```

### 4. Add Liquidity And Obtain LP Tokens

```bash
$ sui client call --package $PACKAGE_ID --module fox_swap --function add_liquidity --args $SWAP_POOL $FOX_COIN_25_OBJ $SUI_COIN_5_OBJ 0x6 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
```

Retrieve the LP and set it as the environment variable:
```bash
LP=0x9ad48fda7d25ebaa3df6ff1f966e67149337e2e1876507b6fa0920d18e359f0e
```

### 5. After One Epoch, Obtain Instant-Win Lottery Tickets Through LP Tokens

```bash
$ sui client call --package $PACKAGE_ID --module fox_swap --function get_daily_coupon --args $SWAP_POOL 1 --type-args $FOX_COIN_PACKAGE_ID::fox_coin::FOX_COIN 0x2::sui::SUI --gas-budget 5000000
```

### 6. Get Winning Numbers Via Off-Chain Code


### 7. Draw And Claim Prizes


## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

## License

This project is licensed under the MIT License.

