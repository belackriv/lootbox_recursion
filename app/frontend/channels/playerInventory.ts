import type {
  PlayerAction,
  PlayerActionData,
  InventoryMutation,
  InventoryChannelEnvelope,
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

  receive(envelope: InventoryChannelEnvelope) {
    try {
      const store = usePlayerStore();
      switch (envelope.action) {
        case "inventory_mutations":
          store.mutateInventory(envelope.data);
          break;
        case "inventory_snapshot":
          store.snapshotInventory(envelope.data);
          break;
        default:
          console.warn(
            "[PlayerInventoryChannel] unknown action:",
            (envelope as any).action
          );
      }
    } catch (err) {
      // silently handle envelope processing errors
    }
  }

  send(mutations: Array<InventoryMutation>) {
    this.subscription?.send({ mutations: mutations });
  }
}

export default PlayerInventoryChannel;
