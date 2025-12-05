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

export type InventoryItem = {
  type: string;
  count: number;
  slot: number;
};

export type InventorySlot = {
  item: InventoryItem | null;
  slot: number;
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
  delta: number;
  slot: number;
  itemType: string | null;
  applied: boolean;
};
