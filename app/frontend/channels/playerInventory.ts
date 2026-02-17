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
        connected: () => {
          try {
            // send a lightweight client ping to the server
            this.subscription?.send({
              type: "client_ping",
              timestamp: Date.now(),
            });
          } catch (e) {
            // ignore connection ping errors
          }
        },
        disconnected: () => {
          // handle disconnection silently
        },
        received: (data: any) => this.receive(data),
      }
    );
  }

  receive(mutations: Array<InventoryMutation>) {
    try {
      const store = usePlayerStore();
      store.mutateInventory(mutations);
    } catch (err) {
      // silently handle mutation application errors
    }
  }

  send(mutations: Array<InventoryMutation>) {
    this.subscription?.send({ mutations: mutations });
  }
}

export default PlayerInventoryChannel;
