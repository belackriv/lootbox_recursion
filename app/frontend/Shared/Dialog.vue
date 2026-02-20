<script setup lang="ts">
defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits(["update:isOpen"]);

const handleClose = () => {
  emit("update:isOpen", false);
};
</script>

<template>
  <dialog
    :open="isOpen"
    @close="handleClose"
    id="dialog"
    aria-labelledby="dialog-title"
    style="
      position: fixed;
      inset: 0;
      width: auto;
      height: auto;
      max-height: none;
      max-width: none;
      overflow-y: auto;
      background: transparent;
      border: none;
      padding: 0;
      margin: 0;
    "
  >
    <!-- Backdrop -->
    <div
      style="
        position: fixed;
        inset: 0;
        background-color: rgba(0, 0, 0, 0.75);
        transition: opacity 0.2s ease;
      "
    ></div>

    <!-- Dialog positioner -->
    <div
      style="
        display: flex;
        min-height: 100%;
        align-items: center;
        justify-content: center;
        padding: 16px;
        position: relative;
        z-index: 10;
      "
    >
      <!-- Panel -->
      <div
        class="fac-panel"
        style="min-width: 360px; max-width: 520px; width: 100%"
      >
        <!-- Title bar -->
        <div
          class="fac-title-bar"
          style="
            display: flex;
            align-items: center;
            justify-content: space-between;
          "
        >
          <span
            id="dialog-title"
            style="display: flex; align-items: center; gap: 6px"
          >
            <span style="color: var(--color-fac-orange)">⚠</span>
            Perform Action
          </span>
          <button
            type="button"
            command="close"
            commandfor="dialog"
            @click="handleClose"
            style="
              background: none;
              border: none;
              cursor: pointer;
              color: var(--color-fac-text-dim);
              font-size: 1rem;
              line-height: 1;
              padding: 0 2px;
            "
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        <!-- Body -->
        <div
          class="fac-panel-inner"
          style="
            margin: 8px;
            padding: 16px;
            font-size: 0.85rem;
            color: var(--color-fac-text);
            line-height: 1.6;
          "
        >
          <slot></slot>
        </div>

        <!-- Footer / Actions -->
        <div
          style="
            display: flex;
            justify-content: flex-end;
            gap: 6px;
            padding: 8px;
            border-top: 1px solid var(--color-fac-border);
          "
        >
          <form method="dialog" style="display: contents">
            <!-- Cancel -->
            <button
              type="button"
              command="close"
              commandfor="dialog"
              @click="handleClose"
              class="fac-btn"
              style="min-width: 80px"
            >
              Cancel
            </button>

            <!-- Confirm -->
            <button
              type="button"
              command="close"
              commandfor="dialog"
              @click="handleClose"
              class="fac-btn"
              style="
                min-width: 80px;
                background-color: #5a3a1a;
                color: var(--color-fac-orange-light);
                border-color: var(--color-fac-orange);
                box-shadow: inset 0 2px 0 rgba(232, 160, 32, 0.3),
                  inset 0 -2px 0 rgba(0, 0, 0, 0.5),
                  inset 2px 0 0 rgba(232, 160, 32, 0.2),
                  inset -2px 0 0 rgba(0, 0, 0, 0.4);
              "
            >
              Confirm
            </button>
          </form>
        </div>
      </div>
    </div>
  </dialog>
</template>
