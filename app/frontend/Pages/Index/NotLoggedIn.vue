<script setup lang="ts"></script>

<template>
  <div class="flex items-center justify-center" style="min-height: 60vh">
    <div class="fac-panel" style="min-width: 320px; max-width: 480px">
      <div class="fac-title-bar" style="text-align: center">
        ⬡ LOOT BOX RECURSION
      </div>

      <div style="padding: 32px 24px; text-align: center">
        <!-- Icon -->
        <div
          style="
            font-size: 3rem;
            margin-bottom: 16px;
            filter: drop-shadow(0 0 8px rgba(232, 160, 32, 0.5));
          "
        >
          🔒
        </div>

        <!-- Heading -->
        <p
          style="
            font-size: 1rem;
            font-weight: 700;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--color-fac-orange);
            margin-bottom: 8px;
          "
        >
          Access Restricted
        </p>

        <!-- Sub-text -->
        <p
          style="
            font-size: 0.8rem;
            color: var(--color-fac-text-dim);
            margin-bottom: 24px;
            line-height: 1.6;
          "
        >
          You must be logged in to access the production facility.<br />
          Please authenticate to continue.
        </p>

        <!-- Divider -->
        <div
          style="
            border-top: 1px solid var(--color-fac-border);
            margin-bottom: 20px;
          "
        ></div>

        <!-- Login link -->
        <a
          href="/users/sign_in"
          class="fac-btn"
          style="
            display: inline-flex;
            text-decoration: none;
            font-size: 0.85rem;
            padding: 6px 24px;
            color: var(--color-fac-orange-light);
          "
        >
          ▶ &nbsp; Log In
        </a>
      </div>
    </div>
  </div>
</template>
