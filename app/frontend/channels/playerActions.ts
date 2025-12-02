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
        connected: function (message) {},
        disconnected: function (message) {},
        received: this.receive,
      },
    );
  }

  receive(playerActions: Array<PlayerAction>) {
    const store = usePlayerStore();
    store.updateAvailableActions(playerActions);
  }

  send(
    playerAction: PlayerAction,
    playerActionData: PlayerActionData | null | undefined,
  ) {
    this.subscription?.send({
      playerAction: playerAction,
      playerActionData: playerActionData,
    });
  }
}

export default PlayerActionsChannel;
