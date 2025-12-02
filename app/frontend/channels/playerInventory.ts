import type {
  PlayerAction,
  PlayerActionData,
  InventoryMutation,
} from "@/types";
import type { Consumer, Subscription } from "@rails/actioncable";
import { usePlayerStore } from "@/store/player.ts";

class PlayerInventoryChannel {
  subscription: Subscription | null = null;

  constructor(cable: Consumer) {
    this.subscription = cable.subscriptions.create(
      { channel: "PlayerInventoryChannel" },
      {
        connected: function (message) {},
        disconnected: function (message) {},
        received: this.receive,
      },
    );
  }

  receive(mutations: Array<InventoryMutation>) {
    const store = usePlayerStore();
    store.mutateInventory(mutations);
  }

  send(mutations: Array<InventoryMutation>) {
    this.subscription?.send({ mutations: mutations });
  }
}

export default PlayerInventoryChannel;
