<script setup lang="ts">
import NavLink from "@/Shared/NavLink.vue";

const { loginPath = "", logoutPath = "" } = defineProps<{
    currentUser: {
        email_address: string;
    } | null;
    loginPath?: string;
    logoutPath?: string;
}>();
</script>

<template>
    <header class="columns-2 m-2">
        <div>
            <p>Welcome to Loot Box Recusion, {{ currentUser?.emailAddress }}</p>
        </div>
        <nav class="flex justify-end">
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
    </header>
    <main>
        <slot />
    </main>
</template>
