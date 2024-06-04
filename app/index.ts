import * as dotenv from 'dotenv';
import { exec } from "child_process";
import { sha3_256 } from 'js-sha3';

dotenv.config();

const fastcryptoPath = process.env.FASTCRYPTO_PATH;
const privateKeyHex = process.env.SECRET_KEY;

async function callback(stdout: string, input: string) {
  let [proof, output] = stdout.split('\n');
  proof = proof.replace("Proof:  ", "");
  output = output.replace("Output: ", "");
  const proofArray = Array.from(Uint8Array.from(Buffer.from(proof, 'hex')));
  const outputArray = Array.from(Uint8Array.from(Buffer.from(output, 'hex')));
  const inputArray = Array.from(Uint8Array.from(Buffer.from(input, 'hex')));
  console.log("input:"+input)
  console.log("proof:"+proof)
  console.log("output:"+output)
}

function getOutput(input: string, callback: any) {
  let hexStr = input;
  const buffer = Buffer.from(hexStr, 'hex');
  const uint8Array = new Uint8Array(buffer);
  let result = "";
  exec(
    `cd ${fastcryptoPath} \n cargo run --bin ecvrf-cli prove --input ${hexStr} --secret-key ${privateKeyHex}`,
    (err, stdout, _stderr) => {
      if (err) {
        console.error(err);
      } else {
        callback(stdout, hexStr);
      }
    }
  );
};

function splitU64ToU8Array(value: string): Uint8Array {
    let u64 = BigInt(value);
    let result: number[] = [];
    for (let i = 0; i < 8; i++) {
        // 右移以获得最低8位并将其转换为number类型
        let byte = Number((u64 >> BigInt(8 * i)) & BigInt(0xFF));
        result.push(byte);
    }
    return new Uint8Array(result);
}

function genPoolAOutput(couponId: string, lotteryType: string, lpAmount: string, epoch: string) {
    let couponIdArray = splitU64ToU8Array(couponId);
    let lotteryTypeArray = splitU64ToU8Array(lotteryType);
    let lpAmountArray = splitU64ToU8Array(lpAmount);
    let epochArray = splitU64ToU8Array(epoch);
    
    let totalLength = 8 * 4;
    let totalArray = new Uint8Array(totalLength);
    
    totalArray.set(couponIdArray, 0);
    totalArray.set(lotteryTypeArray, 8);
    totalArray.set(lpAmountArray, 16);
    totalArray.set(epochArray, 24);
    
    //console.log(couponIdArray);
    //console.log(lotteryTypeArray);
    //console.log(lpAmountArray);
    //console.log(epochArray);
    //console.log(totalArray);
    
    const hash = sha3_256(totalArray);
    //console.log("hash:"+hash);
    
    getOutput(hash, callback);
}


function genPoolBOutput(coinBalAmount: string, totalTicketsNum: string, epoch: string) {
    let coinBalAmountArray = splitU64ToU8Array(coinBalAmount);
    let totalTicketsNumArray = splitU64ToU8Array(totalTicketsNum);
    let epochArray = splitU64ToU8Array(epoch);
    
    let totalLength = 8 * 3;
    let totalArray = new Uint8Array(totalLength);
    
    totalArray.set(coinBalAmountArray, 0);
    totalArray.set(totalTicketsNumArray, 8);
    totalArray.set(epochArray, 16);
    
    //console.log(coinBalAmountArray);
    //console.log(totalTicketsNumArray);
    //console.log(epochArray);
    //console.log(totalArray);
    
    const hash = sha3_256(totalArray);
    //console.log("hash:"+hash);
    
    getOutput(hash, callback);
}


const couponId = "1717341932355";
const lotteryType = "1";
const lpAmount = "234783942744";
const poolAEpoch = "390";
genPoolAOutput(couponId, lotteryType, lpAmount, poolAEpoch);

const coinBalAmount = "2000000000000";
const totalTicketsNum = "894484";
const poolBEpoch = "390";
genPoolBOutput(coinBalAmount, totalTicketsNum, poolBEpoch);

