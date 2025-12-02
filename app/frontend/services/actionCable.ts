import { createConsumer } from "@rails/actioncable";
import { App } from "vue";
import PlayerActionsChannel from "@/channels/playerActions.ts";
import PlayerInventoryChannel from "@/channels/playerInventory.ts";

const cable = createConsumer("ws://localhost:3100/cable");

export default {
  install: (app: App) => {
    app.config.globalProperties.$cable = cable;
    app.provide("cable", cable);

    const playerActionsChannel = new PlayerActionsChannel(cable);
    app.provide("playerActionsChannel", playerActionsChannel);

    const playerInventoryChannel = new PlayerInventoryChannel(cable);
    app.provide("playerInventoryChannel", playerInventoryChannel);
  },
};
