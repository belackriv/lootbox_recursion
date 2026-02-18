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
  [key: string]: string | number | null;
};

export type PlayerActionChoice = {
  name: string;
  label: string;
  [key: string]: string | number | null;
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
