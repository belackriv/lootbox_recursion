<script setup lang="ts">
import { Link } from "@inertiajs/vue3";

const { method = "get", as = "a" } = defineProps<{
    url: string;
    method?: "get" | "delete";
    label?: string;
    as?: string;
}>();
</script>

<template>
    <Link
        class="bg-gray-400 hover:bg-gray-500 border-gray-300 border-2 rounded-lg underline p-1 pl-2 pr-2 m-1 cursor-pointer"
        :href="url"
        :method="method"
        :as="as"
    >
        {{ label ? label : url }}
    </Link>
</template>
