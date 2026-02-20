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
  <Link class="fac-btn" :href="url" :method="method" :as="as">
    {{ label ? label : url }}
  </Link>
</template>
