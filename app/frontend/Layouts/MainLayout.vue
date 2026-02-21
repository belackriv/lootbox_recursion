<script setup lang="ts">
import NavLink from "@/Shared/NavLink.vue";
import { storeToRefs } from "pinia";
import { usePlayerStore } from "@/store/player.ts";

const {
  loginPath = "",
  logoutPath = "",
  currentUser = null,
} = defineProps<{
  currentUser?: {
    emailAddress: string;
  } | null;
  loginPath?: string;
  logoutPath?: string;
}>();

const store = usePlayerStore();
const { hoveredTooltip } = storeToRefs(store);
</script>

<template>
  <div
    class="min-h-screen flex flex-col"
    style="background-color: var(--color-fac-bg)"
  >
    <!-- Header (full width) -->
    <header class="fac-panel mx-2 mt-2 mb-0">
      <div class="fac-title-bar flex items-center justify-between px-3 py-1">
        <!-- Logo / Title -->
        <div class="flex items-center gap-3">
          <span
            style="
              font-size: 1.05rem;
              letter-spacing: 0.12em;
              color: var(--color-fac-orange);
              text-shadow: 0 0 8px rgba(232, 160, 32, 0.5);
            "
          >
            ⬡ LOOT BOX RECURSION
          </span>
          <span
            v-if="currentUser"
            style="
              font-size: 0.7rem;
              color: var(--color-fac-text-dim);
              letter-spacing: 0.04em;
              text-transform: none;
              font-weight: 400;
            "
          >
            — {{ currentUser.emailAddress }}
          </span>
        </div>

        <!-- Nav -->
        <nav class="flex items-center gap-1">
          <NavLink url="/" label="Home" />
          <NavLink v-if="!currentUser" :url="loginPath" label="Login" />
          <NavLink
            v-if="currentUser"
            :url="logoutPath"
            label="Logout"
            method="delete"
            as="button"
          />
        </nav>
      </div>
    </header>

    <!-- Body row: main content + right tooltip sidebar -->
    <div class="flex flex-1" style="min-height: 0; gap: 0">
      <!-- Main content -->
      <main class="flex-1 p-2" style="min-width: 0">
        <slot />
      </main>

      <!-- Right sidebar: tooltip panel (only shown when logged in) -->
      <aside
        v-if="currentUser"
        style="
          width: 180px;
          flex: none;
          padding: 8px 8px 8px 0;
          display: flex;
          flex-direction: column;
        "
      >
        <div
          class="fac-panel"
          style="flex: 1; display: flex; flex-direction: column; min-height: 0"
        >
          <div class="fac-title-bar">ℹ Info</div>
          <div
            class="fac-panel-inner"
            style="flex: 1; padding: 8px; min-height: 0"
          >
            <Transition name="tooltip-info" mode="out-in">
              <div v-if="hoveredTooltip" :key="hoveredTooltip.title">
                <div
                  style="
                    font-size: 0.8rem;
                    font-weight: 700;
                    letter-spacing: 0.06em;
                    text-transform: uppercase;
                    color: var(--color-fac-orange);
                    margin-bottom: 6px;
                  "
                >
                  {{ hoveredTooltip.title }}
                </div>
                <div
                  style="
                    font-size: 0.76rem;
                    line-height: 1.5;
                    color: var(--color-fac-text-dim);
                  "
                >
                  {{ hoveredTooltip.body }}
                </div>
              </div>
              <div
                v-else
                style="
                  font-size: 0.72rem;
                  color: var(--color-fac-text-dark);
                  font-style: italic;
                "
              >
                Hover an action to see details.
              </div>
            </Transition>
          </div>
        </div>
      </aside>
    </div>

    <!-- Footer -->
    <footer
      class="text-center"
      style="
        height: 2vh;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 0.65rem;
        color: var(--color-fac-text-dim);
        letter-spacing: 0.06em;
      "
    >
      LOOT BOX RECURSION &nbsp;|&nbsp; PRODUCTION FACILITY
    </footer>
  </div>
</template>

<style scoped>
.tooltip-info-enter-active,
.tooltip-info-leave-active {
  transition: opacity 0.2s ease;
}
.tooltip-info-enter-from,
.tooltip-info-leave-to {
  opacity: 0;
}
</style>
