export * from "./typechain";
import { BigNumber } from "ethers";
import { soliditySha3, hexToNumber } from "web3-utils";

export const NUMBER_MUTANT_ROCKS = 31;
export const ROCK_LIFESPAN_BLOCKS = 16;
export const MUTANT_ROCK_PROBABILITY = NUMBER_MUTANT_ROCKS * 6;
export const FIRST_ROCK_PRICE_ETH = BigNumber.from("10000000000000000");
export const INCREMENTAL_PRICE_ETH = BigNumber.from("100000000000000");

export const blockNumberToDnaHex = (blockNumber: number): string => {
  const hex = soliditySha3(blockNumber);
  if (!hex) {
    throw new Error("Could not find SHA of blockNumber" + blockNumber);
  }
  return hex;
};

export const isMutantBlockNumber = (blockNumber: number): [boolean, number] => {
  const hex = blockNumberToDnaHex(blockNumber);
  if (!hex) {
    throw new Error("Could not find dna");
  }
  return isMutantDnaHex(hex);
};

export const isMutantDnaHex = (hex: string): [boolean, number] => {
  const mutantGene = hexToNumber("0x" + hex.slice(-4));
  if (mutantGene < MUTANT_ROCK_PROBABILITY) {
    return [true, ~~(mutantGene / 6) + 1];
  }
  return [false, 0];
};

export const priceForRock = (rockNumber: number): BigNumber => {
  return FIRST_ROCK_PRICE_ETH.add(INCREMENTAL_PRICE_ETH.mul(rockNumber - 1));
};

interface Deployment {
  cryptoRocksBreeder: string;
}

export const DEPLOYMENTS: Record<number, Deployment> = {
  [1]: {
    cryptoRocksSpawner: "0x51e613727fdd2e0B91b51c3E5427E9440a7957E4",
  },
  [4]: {
    cryptoRocksSpawner: "0x23d47718DA298b020291901F3e9B46eCBd081f1b",
  },
};

export const getDeployment = (chainId: number): Deployment => {
  const deployment = DEPLOYMENTS[chainId];
  if (!deployment) {
    throw new Error("Could not find deployments for chain id " + chainId);
  }
  return deployment;
};
