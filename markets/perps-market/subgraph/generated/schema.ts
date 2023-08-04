// THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.

import {
  TypedMap,
  Entity,
  Value,
  ValueKind,
  store,
  Bytes,
  BigInt,
  BigDecimal,
} from '@graphprotocol/graph-ts';

export class Account extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save Account entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Account must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('Account', id.toString(), this);
    }
  }

  static loadInBlock(id: string): Account | null {
    return changetype<Account | null>(store.get_in_block('Account', id));
  }

  static load(id: string): Account | null {
    return changetype<Account | null>(store.get('Account', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get accountId(): BigInt {
    let value = this.get('accountId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set accountId(value: BigInt) {
    this.set('accountId', Value.fromBigInt(value));
  }

  get owner(): string {
    let value = this.get('owner');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set owner(value: string) {
    this.set('owner', Value.fromString(value));
  }
}

export class LiquidatedAccount extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save LiquidatedAccount entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type LiquidatedAccount must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('LiquidatedAccount', id.toString(), this);
    }
  }

  static loadInBlock(id: string): LiquidatedAccount | null {
    return changetype<LiquidatedAccount | null>(store.get_in_block('LiquidatedAccount', id));
  }

  static load(id: string): LiquidatedAccount | null {
    return changetype<LiquidatedAccount | null>(store.get('LiquidatedAccount', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get accountId(): BigInt {
    let value = this.get('accountId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set accountId(value: BigInt) {
    this.set('accountId', Value.fromBigInt(value));
  }

  get keeperLiquidationReward(): BigInt | null {
    let value = this.get('keeperLiquidationReward');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set keeperLiquidationReward(value: BigInt | null) {
    if (!value) {
      this.unset('keeperLiquidationReward');
    } else {
      this.set('keeperLiquidationReward', Value.fromBigInt(<BigInt>value));
    }
  }

  get accountFullyLiquidated(): boolean {
    let value = this.get('accountFullyLiquidated');
    if (!value || value.kind == ValueKind.NULL) {
      return false;
    } else {
      return value.toBoolean();
    }
  }

  set accountFullyLiquidated(value: boolean) {
    this.set('accountFullyLiquidated', Value.fromBoolean(value));
  }
}

export class LiquidatedPosition extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save LiquidatedPosition entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type LiquidatedPosition must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('LiquidatedPosition', id.toString(), this);
    }
  }

  static loadInBlock(id: string): LiquidatedPosition | null {
    return changetype<LiquidatedPosition | null>(store.get_in_block('LiquidatedPosition', id));
  }

  static load(id: string): LiquidatedPosition | null {
    return changetype<LiquidatedPosition | null>(store.get('LiquidatedPosition', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get accountId(): BigInt {
    let value = this.get('accountId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set accountId(value: BigInt) {
    this.set('accountId', Value.fromBigInt(value));
  }

  get marketId(): BigInt | null {
    let value = this.get('marketId');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set marketId(value: BigInt | null) {
    if (!value) {
      this.unset('marketId');
    } else {
      this.set('marketId', Value.fromBigInt(<BigInt>value));
    }
  }

  get amountLiquidated(): BigInt | null {
    let value = this.get('amountLiquidated');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set amountLiquidated(value: BigInt | null) {
    if (!value) {
      this.unset('amountLiquidated');
    } else {
      this.set('amountLiquidated', Value.fromBigInt(<BigInt>value));
    }
  }

  get currentPositionSize(): BigInt | null {
    let value = this.get('currentPositionSize');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set currentPositionSize(value: BigInt | null) {
    if (!value) {
      this.unset('currentPositionSize');
    } else {
      this.set('currentPositionSize', Value.fromBigInt(<BigInt>value));
    }
  }
}

export class Market extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save Market entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Market must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('Market', id.toString(), this);
    }
  }

  static loadInBlock(id: string): Market | null {
    return changetype<Market | null>(store.get_in_block('Market', id));
  }

  static load(id: string): Market | null {
    return changetype<Market | null>(store.get('Market', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get perpsMarketId(): BigInt {
    let value = this.get('perpsMarketId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set perpsMarketId(value: BigInt) {
    this.set('perpsMarketId', Value.fromBigInt(value));
  }

  get marketName(): string | null {
    let value = this.get('marketName');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set marketName(value: string | null) {
    if (!value) {
      this.unset('marketName');
    } else {
      this.set('marketName', Value.fromString(<string>value));
    }
  }

  get marketSymbol(): string | null {
    let value = this.get('marketSymbol');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set marketSymbol(value: string | null) {
    if (!value) {
      this.unset('marketSymbol');
    } else {
      this.set('marketSymbol', Value.fromString(<string>value));
    }
  }

  get price(): BigInt | null {
    let value = this.get('price');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set price(value: BigInt | null) {
    if (!value) {
      this.unset('price');
    } else {
      this.set('price', Value.fromBigInt(<BigInt>value));
    }
  }

  get skew(): BigInt | null {
    let value = this.get('skew');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set skew(value: BigInt | null) {
    if (!value) {
      this.unset('skew');
    } else {
      this.set('skew', Value.fromBigInt(<BigInt>value));
    }
  }

  get size(): BigInt | null {
    let value = this.get('size');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set size(value: BigInt | null) {
    if (!value) {
      this.unset('size');
    } else {
      this.set('size', Value.fromBigInt(<BigInt>value));
    }
  }

  get sizeDelta(): BigInt | null {
    let value = this.get('sizeDelta');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set sizeDelta(value: BigInt | null) {
    if (!value) {
      this.unset('sizeDelta');
    } else {
      this.set('sizeDelta', Value.fromBigInt(<BigInt>value));
    }
  }

  get currentFundingRate(): BigInt | null {
    let value = this.get('currentFundingRate');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set currentFundingRate(value: BigInt | null) {
    if (!value) {
      this.unset('currentFundingRate');
    } else {
      this.set('currentFundingRate', Value.fromBigInt(<BigInt>value));
    }
  }

  get currentFundingVelocity(): BigInt | null {
    let value = this.get('currentFundingVelocity');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set currentFundingVelocity(value: BigInt | null) {
    if (!value) {
      this.unset('currentFundingVelocity');
    } else {
      this.set('currentFundingVelocity', Value.fromBigInt(<BigInt>value));
    }
  }

  get feedId(): Bytes | null {
    let value = this.get('feedId');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBytes();
    }
  }

  set feedId(value: Bytes | null) {
    if (!value) {
      this.unset('feedId');
    } else {
      this.set('feedId', Value.fromBytes(<Bytes>value));
    }
  }

  get maxFundingVelocity(): BigInt | null {
    let value = this.get('maxFundingVelocity');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set maxFundingVelocity(value: BigInt | null) {
    if (!value) {
      this.unset('maxFundingVelocity');
    } else {
      this.set('maxFundingVelocity', Value.fromBigInt(<BigInt>value));
    }
  }

  get skewScale(): BigInt | null {
    let value = this.get('skewScale');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set skewScale(value: BigInt | null) {
    if (!value) {
      this.unset('skewScale');
    } else {
      this.set('skewScale', Value.fromBigInt(<BigInt>value));
    }
  }

  get lockedOiPercent(): BigInt | null {
    let value = this.get('lockedOiPercent');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set lockedOiPercent(value: BigInt | null) {
    if (!value) {
      this.unset('lockedOiPercent');
    } else {
      this.set('lockedOiPercent', Value.fromBigInt(<BigInt>value));
    }
  }

  get marketOwner(): string | null {
    let value = this.get('marketOwner');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set marketOwner(value: string | null) {
    if (!value) {
      this.unset('marketOwner');
    } else {
      this.set('marketOwner', Value.fromString(<string>value));
    }
  }

  get owner(): string | null {
    let value = this.get('owner');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set owner(value: string | null) {
    if (!value) {
      this.unset('owner');
    } else {
      this.set('owner', Value.fromString(<string>value));
    }
  }

  get initialMarginRatioD18(): BigInt | null {
    let value = this.get('initialMarginRatioD18');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set initialMarginRatioD18(value: BigInt | null) {
    if (!value) {
      this.unset('initialMarginRatioD18');
    } else {
      this.set('initialMarginRatioD18', Value.fromBigInt(<BigInt>value));
    }
  }

  get maintenanceMarginRatioD18(): BigInt | null {
    let value = this.get('maintenanceMarginRatioD18');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set maintenanceMarginRatioD18(value: BigInt | null) {
    if (!value) {
      this.unset('maintenanceMarginRatioD18');
    } else {
      this.set('maintenanceMarginRatioD18', Value.fromBigInt(<BigInt>value));
    }
  }

  get liquidationRewardRatioD18(): BigInt | null {
    let value = this.get('liquidationRewardRatioD18');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set liquidationRewardRatioD18(value: BigInt | null) {
    if (!value) {
      this.unset('liquidationRewardRatioD18');
    } else {
      this.set('liquidationRewardRatioD18', Value.fromBigInt(<BigInt>value));
    }
  }

  get maxSecondsInLiquidationWindow(): BigInt | null {
    let value = this.get('maxSecondsInLiquidationWindow');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set maxSecondsInLiquidationWindow(value: BigInt | null) {
    if (!value) {
      this.unset('maxSecondsInLiquidationWindow');
    } else {
      this.set('maxSecondsInLiquidationWindow', Value.fromBigInt(<BigInt>value));
    }
  }

  get minimumPositionMargin(): BigInt | null {
    let value = this.get('minimumPositionMargin');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set minimumPositionMargin(value: BigInt | null) {
    if (!value) {
      this.unset('minimumPositionMargin');
    } else {
      this.set('minimumPositionMargin', Value.fromBigInt(<BigInt>value));
    }
  }

  get maxLiquidationLimitAccumulationMultiplier(): BigInt | null {
    let value = this.get('maxLiquidationLimitAccumulationMultiplier');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set maxLiquidationLimitAccumulationMultiplier(value: BigInt | null) {
    if (!value) {
      this.unset('maxLiquidationLimitAccumulationMultiplier');
    } else {
      this.set('maxLiquidationLimitAccumulationMultiplier', Value.fromBigInt(<BigInt>value));
    }
  }

  get makerFee(): BigInt | null {
    let value = this.get('makerFee');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set makerFee(value: BigInt | null) {
    if (!value) {
      this.unset('makerFee');
    } else {
      this.set('makerFee', Value.fromBigInt(<BigInt>value));
    }
  }

  get takerFee(): BigInt | null {
    let value = this.get('takerFee');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set takerFee(value: BigInt | null) {
    if (!value) {
      this.unset('takerFee');
    } else {
      this.set('takerFee', Value.fromBigInt(<BigInt>value));
    }
  }

  get factoryInitialized(): boolean {
    let value = this.get('factoryInitialized');
    if (!value || value.kind == ValueKind.NULL) {
      return false;
    } else {
      return value.toBoolean();
    }
  }

  set factoryInitialized(value: boolean) {
    this.set('factoryInitialized', Value.fromBoolean(value));
  }
}

export class Order extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save Order entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type Order must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('Order', id.toString(), this);
    }
  }

  static loadInBlock(id: string): Order | null {
    return changetype<Order | null>(store.get_in_block('Order', id));
  }

  static load(id: string): Order | null {
    return changetype<Order | null>(store.get('Order', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get marketId(): BigInt | null {
    let value = this.get('marketId');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set marketId(value: BigInt | null) {
    if (!value) {
      this.unset('marketId');
    } else {
      this.set('marketId', Value.fromBigInt(<BigInt>value));
    }
  }

  get accountId(): BigInt | null {
    let value = this.get('accountId');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set accountId(value: BigInt | null) {
    if (!value) {
      this.unset('accountId');
    } else {
      this.set('accountId', Value.fromBigInt(<BigInt>value));
    }
  }

  get amountProvided(): BigInt | null {
    let value = this.get('amountProvided');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set amountProvided(value: BigInt | null) {
    if (!value) {
      this.unset('amountProvided');
    } else {
      this.set('amountProvided', Value.fromBigInt(<BigInt>value));
    }
  }

  get orderType(): i32 {
    let value = this.get('orderType');
    if (!value || value.kind == ValueKind.NULL) {
      return 0;
    } else {
      return value.toI32();
    }
  }

  set orderType(value: i32) {
    this.set('orderType', Value.fromI32(value));
  }

  get size(): BigInt | null {
    let value = this.get('size');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set size(value: BigInt | null) {
    if (!value) {
      this.unset('size');
    } else {
      this.set('size', Value.fromBigInt(<BigInt>value));
    }
  }

  get acceptablePrice(): BigInt | null {
    let value = this.get('acceptablePrice');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set acceptablePrice(value: BigInt | null) {
    if (!value) {
      this.unset('acceptablePrice');
    } else {
      this.set('acceptablePrice', Value.fromBigInt(<BigInt>value));
    }
  }

  get settlementTime(): BigInt | null {
    let value = this.get('settlementTime');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set settlementTime(value: BigInt | null) {
    if (!value) {
      this.unset('settlementTime');
    } else {
      this.set('settlementTime', Value.fromBigInt(<BigInt>value));
    }
  }

  get expirationTime(): BigInt | null {
    let value = this.get('expirationTime');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set expirationTime(value: BigInt | null) {
    if (!value) {
      this.unset('expirationTime');
    } else {
      this.set('expirationTime', Value.fromBigInt(<BigInt>value));
    }
  }

  get trackingCode(): Bytes | null {
    let value = this.get('trackingCode');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBytes();
    }
  }

  set trackingCode(value: Bytes | null) {
    if (!value) {
      this.unset('trackingCode');
    } else {
      this.set('trackingCode', Value.fromBytes(<Bytes>value));
    }
  }

  get owner(): string | null {
    let value = this.get('owner');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set owner(value: string | null) {
    if (!value) {
      this.unset('owner');
    } else {
      this.set('owner', Value.fromString(<string>value));
    }
  }

  get fillPrice(): BigInt | null {
    let value = this.get('fillPrice');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set fillPrice(value: BigInt | null) {
    if (!value) {
      this.unset('fillPrice');
    } else {
      this.set('fillPrice', Value.fromBigInt(<BigInt>value));
    }
  }

  get accountPnlRealized(): BigInt | null {
    let value = this.get('accountPnlRealized');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set accountPnlRealized(value: BigInt | null) {
    if (!value) {
      this.unset('accountPnlRealized');
    } else {
      this.set('accountPnlRealized', Value.fromBigInt(<BigInt>value));
    }
  }

  get newSize(): BigInt | null {
    let value = this.get('newSize');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set newSize(value: BigInt | null) {
    if (!value) {
      this.unset('newSize');
    } else {
      this.set('newSize', Value.fromBigInt(<BigInt>value));
    }
  }

  get collectedFees(): BigInt | null {
    let value = this.get('collectedFees');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set collectedFees(value: BigInt | null) {
    if (!value) {
      this.unset('collectedFees');
    } else {
      this.set('collectedFees', Value.fromBigInt(<BigInt>value));
    }
  }

  get settelementReward(): BigInt | null {
    let value = this.get('settelementReward');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set settelementReward(value: BigInt | null) {
    if (!value) {
      this.unset('settelementReward');
    } else {
      this.set('settelementReward', Value.fromBigInt(<BigInt>value));
    }
  }

  get settler(): string | null {
    let value = this.get('settler');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set settler(value: string | null) {
    if (!value) {
      this.unset('settler');
    } else {
      this.set('settler', Value.fromString(<string>value));
    }
  }

  get block(): BigInt {
    let value = this.get('block');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set block(value: BigInt) {
    this.set('block', Value.fromBigInt(value));
  }

  get timestamp(): BigInt {
    let value = this.get('timestamp');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set timestamp(value: BigInt) {
    this.set('timestamp', Value.fromBigInt(value));
  }
}

export class SettlementStrategy extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save SettlementStrategy entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type SettlementStrategy must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('SettlementStrategy', id.toString(), this);
    }
  }

  static loadInBlock(id: string): SettlementStrategy | null {
    return changetype<SettlementStrategy | null>(store.get_in_block('SettlementStrategy', id));
  }

  static load(id: string): SettlementStrategy | null {
    return changetype<SettlementStrategy | null>(store.get('SettlementStrategy', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get strategyId(): BigInt {
    let value = this.get('strategyId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set strategyId(value: BigInt) {
    this.set('strategyId', Value.fromBigInt(value));
  }

  get marketId(): BigInt {
    let value = this.get('marketId');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toBigInt();
    }
  }

  set marketId(value: BigInt) {
    this.set('marketId', Value.fromBigInt(value));
  }

  get enabled(): boolean {
    let value = this.get('enabled');
    if (!value || value.kind == ValueKind.NULL) {
      return false;
    } else {
      return value.toBoolean();
    }
  }

  set enabled(value: boolean) {
    this.set('enabled', Value.fromBoolean(value));
  }

  get strategyType(): i32 {
    let value = this.get('strategyType');
    if (!value || value.kind == ValueKind.NULL) {
      return 0;
    } else {
      return value.toI32();
    }
  }

  set strategyType(value: i32) {
    this.set('strategyType', Value.fromI32(value));
  }

  get settlementDelay(): BigInt | null {
    let value = this.get('settlementDelay');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set settlementDelay(value: BigInt | null) {
    if (!value) {
      this.unset('settlementDelay');
    } else {
      this.set('settlementDelay', Value.fromBigInt(<BigInt>value));
    }
  }

  get settlementWindowDuration(): BigInt | null {
    let value = this.get('settlementWindowDuration');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set settlementWindowDuration(value: BigInt | null) {
    if (!value) {
      this.unset('settlementWindowDuration');
    } else {
      this.set('settlementWindowDuration', Value.fromBigInt(<BigInt>value));
    }
  }

  get priceVerificationContract(): string | null {
    let value = this.get('priceVerificationContract');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set priceVerificationContract(value: string | null) {
    if (!value) {
      this.unset('priceVerificationContract');
    } else {
      this.set('priceVerificationContract', Value.fromString(<string>value));
    }
  }

  get feedId(): Bytes | null {
    let value = this.get('feedId');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBytes();
    }
  }

  set feedId(value: Bytes | null) {
    if (!value) {
      this.unset('feedId');
    } else {
      this.set('feedId', Value.fromBytes(<Bytes>value));
    }
  }

  get url(): string | null {
    let value = this.get('url');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set url(value: string | null) {
    if (!value) {
      this.unset('url');
    } else {
      this.set('url', Value.fromString(<string>value));
    }
  }

  get settlementReward(): BigInt | null {
    let value = this.get('settlementReward');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set settlementReward(value: BigInt | null) {
    if (!value) {
      this.unset('settlementReward');
    } else {
      this.set('settlementReward', Value.fromBigInt(<BigInt>value));
    }
  }

  get priceDeviationTolerance(): BigInt | null {
    let value = this.get('priceDeviationTolerance');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set priceDeviationTolerance(value: BigInt | null) {
    if (!value) {
      this.unset('priceDeviationTolerance');
    } else {
      this.set('priceDeviationTolerance', Value.fromBigInt(<BigInt>value));
    }
  }

  get minimumUsdExchangeAmount(): BigInt | null {
    let value = this.get('minimumUsdExchangeAmount');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set minimumUsdExchangeAmount(value: BigInt | null) {
    if (!value) {
      this.unset('minimumUsdExchangeAmount');
    } else {
      this.set('minimumUsdExchangeAmount', Value.fromBigInt(<BigInt>value));
    }
  }

  get maxRoundingLoss(): BigInt | null {
    let value = this.get('maxRoundingLoss');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set maxRoundingLoss(value: BigInt | null) {
    if (!value) {
      this.unset('maxRoundingLoss');
    } else {
      this.set('maxRoundingLoss', Value.fromBigInt(<BigInt>value));
    }
  }
}

export class ReferrerShare extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save ReferrerShare entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type ReferrerShare must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('ReferrerShare', id.toString(), this);
    }
  }

  static loadInBlock(id: string): ReferrerShare | null {
    return changetype<ReferrerShare | null>(store.get_in_block('ReferrerShare', id));
  }

  static load(id: string): ReferrerShare | null {
    return changetype<ReferrerShare | null>(store.get('ReferrerShare', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get referrer(): string | null {
    let value = this.get('referrer');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set referrer(value: string | null) {
    if (!value) {
      this.unset('referrer');
    } else {
      this.set('referrer', Value.fromString(<string>value));
    }
  }

  get shareRatioD18(): BigInt | null {
    let value = this.get('shareRatioD18');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toBigInt();
    }
  }

  set shareRatioD18(value: BigInt | null) {
    if (!value) {
      this.unset('shareRatioD18');
    } else {
      this.set('shareRatioD18', Value.fromBigInt(<BigInt>value));
    }
  }
}

export class GlobalConfiguration extends Entity {
  constructor(id: string) {
    super();
    this.set('id', Value.fromString(id));
  }

  save(): void {
    let id = this.get('id');
    assert(id != null, 'Cannot save GlobalConfiguration entity without an ID');
    if (id) {
      assert(
        id.kind == ValueKind.STRING,
        `Entities of type GlobalConfiguration must have an ID of type String but the id '${id.displayData()}' is of type ${id.displayKind()}`
      );
      store.set('GlobalConfiguration', id.toString(), this);
    }
  }

  static loadInBlock(id: string): GlobalConfiguration | null {
    return changetype<GlobalConfiguration | null>(store.get_in_block('GlobalConfiguration', id));
  }

  static load(id: string): GlobalConfiguration | null {
    return changetype<GlobalConfiguration | null>(store.get('GlobalConfiguration', id));
  }

  get id(): string {
    let value = this.get('id');
    if (!value || value.kind == ValueKind.NULL) {
      throw new Error('Cannot return null for a required field.');
    } else {
      return value.toString();
    }
  }

  set id(value: string) {
    this.set('id', Value.fromString(value));
  }

  get feeCollector(): string | null {
    let value = this.get('feeCollector');
    if (!value || value.kind == ValueKind.NULL) {
      return null;
    } else {
      return value.toString();
    }
  }

  set feeCollector(value: string | null) {
    if (!value) {
      this.unset('feeCollector');
    } else {
      this.set('feeCollector', Value.fromString(<string>value));
    }
  }
}
