<script setup lang="ts">
const { method = "get" } = defineProps<{
  url: string;
  method?: "get" | "delete";
  label?: string;
  as?: string;
}>();

const csrfToken = (): string => {
  return (
    (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)
      ?.content ?? ""
  );
};
</script>

<template>
  <a v-if="method === 'get'" class="fac-btn" :href="url">
    {{ label ? label : url }}
  </a>
  <form v-else :action="url" method="post" style="display: inline">
    <input type="hidden" name="_method" :value="method" />
    <input type="hidden" name="authenticity_token" :value="csrfToken()" />
    <button type="submit" class="fac-btn">
      {{ label ? label : url }}
    </button>
  </form>
</template>
