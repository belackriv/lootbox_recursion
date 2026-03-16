export const LOOTBOX_ITEM_TYPE = "LootBoxInventoryItem";
export const IRRADIATION_ENCLOSURE_ITEM_TYPE =
  "IrradiationEnclosureInventoryItem";

export const PLACEABLE_ITEM_TYPES: ReadonlyArray<string> = [
  IRRADIATION_ENCLOSURE_ITEM_TYPE,
];

export type Flash = {
  notice?: string;
  alert?: string;
};

export type SharedProps = {
  flash: Flash;
};

export type PlayerStore = {
  inventory: Array<InventoryItem>;
  availableActions: Array<PlayerAction>;
};

export type User = {
  id: number;
  emailAdress: string;
};

export type Entity = {
  id: number;
  user: User | null;
};

export type InventoryItem = {
  type: string;
  count: number;
  displayName?: string | null;
  tooltip?: string | null;
};

export type InventorySlot = {
  inventoryItem: InventoryItem | null;
  slot: number;
  //entity: Entity;
};

export type InventoryGridSlot = {
  slot: InventorySlot;
  row: number;
  column: number;
};

export type PlayerAction = {
  name: string;
  label: string;
  tooltip?: string | null;
  disabled: boolean;
  revealed: boolean;
  cooldown: number;
  onCooldownUntil?: string | null;
  castTime: number;
  choices: Array<PlayerActionChoice>;
  requirements: Array<PlayerActionReqiurement>;
  revealRequirements: Array<PlayerActionReqiurement>;
};

export type PlayerActionData = {
  [key: string]: string | number | CraftingCost | null | undefined;
};

export type CraftingCost = {
  wood: number;
  iron: number;
};

export type PlayerActionChoice = {
  name: string;
  label: string;
  cost?: CraftingCost | null;
  [key: string]: string | number | CraftingCost | null | undefined;
};

export type PlayerCraftingChoices = Array<PlayerActionChoice>;

export type PlayerActionReqiurement = {
  [key: string]: string | number | null;
};

export type InventoryMutation = {
  inventorySlot: InventorySlot;
  itemType: string | null;
  delta: number;
  applied: boolean;
};

export type InventoryChannelEnvelope =
  | { action: "inventory_mutations"; data: Array<InventoryMutation> }
  | { action: "inventory_snapshot"; data: Array<InventorySlot> };
