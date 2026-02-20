<script setup lang="ts">
import NavLink from "@/Shared/NavLink.vue";

const { loginPath = "", logoutPath = "" } = defineProps<{
  currentUser: {
    emailAddress: string;
  } | null;
  loginPath?: string;
  logoutPath?: string;
}>();
</script>

<template>
  <div
    class="min-h-screen flex flex-col"
    style="background-color: var(--color-fac-bg)"
  >
    <!-- Header -->
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

    <!-- Main content -->
    <main class="flex-1 p-2">
      <slot />
    </main>

    <!-- Footer -->
    <footer
      class="text-center pb-2"
      style="
        font-size: 0.65rem;
        color: var(--color-fac-text-dim);
        letter-spacing: 0.06em;
      "
    >
      LOOT BOX RECURSION &nbsp;|&nbsp; PRODUCTION FACILITY
    </footer>
  </div>
</template>
