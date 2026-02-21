<script setup lang="ts">
import { reactive } from "vue";
import { router } from "@inertiajs/vue3";

defineOptions({ layout: null });

defineProps<{
  errors: Record<string, string | string[]>;
}>();

const form = reactive({
  email_address: "",
  password: "",
  password_confirmation: "",
});

function submit() {
  router.post("/sign_up", { user: form });
}

function firstError(
  errors: Record<string, string | string[]>,
  key: string
): string | null {
  const val = errors?.[key];
  if (!val) return null;
  return Array.isArray(val) ? val[0] : val;
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
            ⚙
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
            New Operative
          </p>
          <p
            style="
              font-size: 0.8rem;
              color: var(--color-fac-text-dim);
              margin: 0;
              line-height: 1.6;
            "
          >
            Register an account to enter the production facility.
          </p>
        </div>

        <div v-if="errors?.base" class="fac-flash-alert">
          ⚠ {{ errors.base }}
        </div>

        <form @submit.prevent="submit">
          <div style="margin-bottom: 14px">
            <label class="fac-label" for="email_address">Email Address</label>
            <input
              id="email_address"
              v-model="form.email_address"
              type="email"
              class="fac-input"
              placeholder="Enter your email address"
              required
              autofocus
              autocomplete="email"
            />
            <div
              v-if="firstError(errors, 'email_address')"
              style="color: #e57373; font-size: 0.75rem; margin-top: 4px"
            >
              ⚠ {{ firstError(errors, "email_address") }}
            </div>
          </div>

          <div style="margin-bottom: 14px">
            <label class="fac-label" for="password">Password</label>
            <input
              id="password"
              v-model="form.password"
              type="password"
              class="fac-input"
              placeholder="Choose a password"
              required
              autocomplete="new-password"
            />
            <div
              v-if="firstError(errors, 'password')"
              style="color: #e57373; font-size: 0.75rem; margin-top: 4px"
            >
              ⚠ {{ firstError(errors, "password") }}
            </div>
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
              placeholder="Repeat your password"
              required
              autocomplete="new-password"
            />
            <div
              v-if="firstError(errors, 'password_confirmation')"
              style="color: #e57373; font-size: 0.75rem; margin-top: 4px"
            >
              ⚠ {{ firstError(errors, "password_confirmation") }}
            </div>
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
            ▶&nbsp; Create Account
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
          <span style="font-size: 0.78rem; color: var(--color-fac-text-dim)"
            >Already have an account?</span
          >
          &nbsp;
          <a
            href="/session/new"
            style="
              color: var(--color-fac-orange-light);
              font-size: 0.78rem;
              text-decoration: none;
              letter-spacing: 0.04em;
              font-weight: 700;
            "
            >Sign In</a
          >
        </div>
      </div>
    </div>
  </div>
</template>
