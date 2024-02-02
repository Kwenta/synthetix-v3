import { ethers } from 'ethers';

export type GetQuantoPnlArgs = {
  baseAssetStartPrice: ethers.BigNumber;
  baseAssetEndPrice: ethers.BigNumber;
  quantoAssetStartPrice: ethers.BigNumber;
  quantoAssetEndPrice: ethers.BigNumber;
  baseAssetSizeDelta: ethers.BigNumber;
};

const ONE_ETHER = ethers.utils.parseEther('1');

export const getQuantoPnl = ({
  baseAssetStartPrice,
  baseAssetEndPrice,
  quantoAssetStartPrice,
  quantoAssetEndPrice,
  baseAssetSizeDelta,
}: GetQuantoPnlArgs): ethers.BigNumber => {
  const baseAssetPriceChange = baseAssetEndPrice.sub(baseAssetStartPrice);
  const quantoMultiplier = quantoAssetEndPrice.mul(ONE_ETHER).div(quantoAssetStartPrice);
  return baseAssetPriceChange
    .mul(baseAssetSizeDelta)
    .mul(quantoMultiplier)
    .div(ONE_ETHER)
    .div(ONE_ETHER);
};

export type GetQuantoPositionSizeArgs = {
  sizeInBaseAsset: ethers.BigNumber;
  quantoAssetPrice: ethers.BigNumber;
};

export const getQuantoPositionSize = ({
  sizeInBaseAsset,
  quantoAssetPrice,
}: GetQuantoPositionSizeArgs): ethers.BigNumber => {
  return sizeInBaseAsset.mul(ONE_ETHER).div(quantoAssetPrice);
};

// Calculates PD
const calculatePD = (skew: ethers.BigNumber, skewScale: ethers.BigNumber) => skew.div(skewScale);

// Calculates the price with pd applied
const calculateAdjustedPrice = (price: ethers.BigNumber, pd: ethers.BigNumber) =>
  price.add(price.mul(pd));

export function calculateFillPrice(
  skew: ethers.BigNumber,
  skewScale: ethers.BigNumber,
  size: ethers.BigNumber,
  price: ethers.BigNumber
) {
  if (skewScale.eq(0)) {
    return price;
  }

  const pdBefore = calculatePD(skew, skewScale);
  const pdAfter = calculatePD(skew.add(size), skewScale);

  const priceBefore = calculateAdjustedPrice(price, pdBefore);
  const priceAfter = calculateAdjustedPrice(price, pdAfter);

  return priceBefore.add(priceAfter).div(2);
}

export function calculateQuantoPricePnl(
  startingSkew: ethers.BigNumber,
  skewScale: ethers.BigNumber,
  size: ethers.BigNumber,
  startingPrice: ethers.BigNumber
) {
  const fillPrice = calculateFillPrice(startingSkew, skewScale, size, startingPrice);
  return startingPrice.sub(fillPrice).mul(size);
}
