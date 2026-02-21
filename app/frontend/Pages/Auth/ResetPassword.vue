<script setup lang="ts">
import { reactive } from "vue";
import { router, usePage } from "@inertiajs/vue3";

defineOptions({ layout: null });

const props = defineProps<{
  token: string;
  errors: Record<string, string | string[]>;
}>();

const page = usePage<{ flash: Record<string, string> }>();

const form = reactive({
  password: "",
  password_confirmation: "",
});

function submit() {
  router.put(`/passwords/${props.token}`, form);
}
</script>

<template>
  <div class="fac-auth-page">
    <div
      class="fac-panel"
      style="min-width: 320px; max-width: 420px; width: 100%"
    >
      <div class="fac-title-bar" style="text-align: center">
        ⬡ LOOT BOX RECURSION
      </div>

      <div style="padding: 32px 24px">
        <div style="text-align: center; margin-bottom: 24px">
          <div
            style="
              font-size: 2.5rem;
              margin-bottom: 12px;
              filter: drop-shadow(0 0 8px rgba(232, 160, 32, 0.5));
            "
          >
            🔐
          </div>
          <p
            style="
              font-size: 1rem;
              font-weight: 700;
              letter-spacing: 0.1em;
              text-transform: uppercase;
              color: var(--color-fac-orange);
              margin: 0 0 6px;
            "
          >
            New Password
          </p>
          <p
            style="
              font-size: 0.8rem;
              color: var(--color-fac-text-dim);
              margin: 0;
              line-height: 1.6;
            "
          >
            Choose a new password to restore your access.
          </p>
        </div>

        <div v-if="page.props.flash?.notice" class="fac-flash-notice">
          ✔ {{ page.props.flash.notice }}
        </div>
        <div v-if="errors?.base" class="fac-flash-alert">
          ⚠ {{ errors.base }}
        </div>

        <form @submit.prevent="submit">
          <div style="margin-bottom: 14px">
            <label class="fac-label" for="password">New Password</label>
            <input
              id="password"
              v-model="form.password"
              type="password"
              class="fac-input"
              placeholder="Enter new password"
              required
              autofocus
              autocomplete="new-password"
              maxlength="72"
            />
          </div>

          <div style="margin-bottom: 24px">
            <label class="fac-label" for="password_confirmation"
              >Confirm Password</label
            >
            <input
              id="password_confirmation"
              v-model="form.password_confirmation"
              type="password"
              class="fac-input"
              placeholder="Repeat new password"
              required
              autocomplete="new-password"
              maxlength="72"
            />
          </div>

          <button
            type="submit"
            class="fac-btn"
            style="
              width: 100%;
              font-size: 0.85rem;
              padding: 8px;
              color: var(--color-fac-orange-light);
            "
          >
            ▶&nbsp; Save New Password
          </button>
        </form>

        <div
          style="
            border-top: 1px solid var(--color-fac-border);
            margin-top: 20px;
            padding-top: 16px;
            text-align: center;
          "
        >
          <a
            href="/session/new"
            style="
              color: var(--color-fac-text-dim);
              font-size: 0.78rem;
              text-decoration: none;
              letter-spacing: 0.04em;
            "
            >Back to Sign In</a
          >
        </div>
      </div>
    </div>
  </div>
</template>
