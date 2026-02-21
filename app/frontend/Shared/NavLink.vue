<script setup lang="ts">
import { Link } from "@inertiajs/vue3";

const { method = "get" } = defineProps<{
  url: string;
  method?: "get" | "delete";
  label?: string;
  as?: string;
}>();
</script>

<template>
  <a v-if="method === 'get'" class="fac-btn" :href="url">
    {{ label ? label : url }}
  </a>
  <Link v-else class="fac-btn" :href="url" :method="method" as="button">
    {{ label ? label : url }}
  </Link>
</template>
