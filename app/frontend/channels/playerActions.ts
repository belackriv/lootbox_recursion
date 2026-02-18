import type {
  PlayerAction,
  PlayerActionData,
  InventoryMutation,
} from "@/types";
import type { Consumer, Subscription } from "@rails/actioncable";
import { usePlayerStore } from "@/store/player.ts";

class PlayerActionsChannel {
  subscription: Subscription | null = null;

  constructor(cable: Consumer) {
    this.subscription = cable.subscriptions.create(
      { channel: "PlayerActionsChannel" },
      {
        connected: () => {},
        disconnected: () => {},
        received: (playerActions: Array<PlayerAction>) => {
          console.log("Received player actions:", playerActions);
          const store = usePlayerStore();
          store.updateAvailableActions(playerActions);
        },
      }
    );
  }

  send(
    playerAction: PlayerAction,
    playerActionData: PlayerActionData | null | undefined
  ) {
    this.subscription?.send({
      playerAction: playerAction,
      playerActionData: playerActionData,
    });
  }
}

export default PlayerActionsChannel;
