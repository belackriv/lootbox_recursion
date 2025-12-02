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
  cooldown: number;
  castTime: number;
};

export type PlayerActionData = {
  [key: string]: string;
};

export type InventoryMutation = {
  delta: number;
  slot: number;
  itemType: string | null;
  applied: boolean;
};
