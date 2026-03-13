<template>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="100%" height="100%">
    <!-- Shadow -->
    <ellipse cx="16" cy="30" rx="11" ry="1.8" fill="#0d0b08" opacity="0.5"/>

    <!-- Outer casing body -->
    <rect x="4" y="12" width="24" height="16" rx="2" fill="#4a4a52" stroke="#26262e" stroke-width="1.2"/>

    <!-- Casing highlight (top edge) -->
    <rect x="5" y="13" width="22" height="2.5" rx="1" fill="#7a7a88" opacity="0.45"/>

    <!-- Casing bottom shadow -->
    <rect x="4" y="23" width="24" height="5" rx="2" fill="#26262e" opacity="0.35"/>

    <!-- Lid / top cap -->
    <rect x="4" y="7" width="24" height="6" rx="2" fill="#5a5a64" stroke="#26262e" stroke-width="1.2"/>

    <!-- Lid highlight -->
    <rect x="5" y="8" width="22" height="2" rx="1" fill="#9a9aaa" opacity="0.4"/>

    <!-- Lid / body seam band -->
    <rect x="4" y="12" width="24" height="1.8" fill="#1a1a20" opacity="0.6"/>

    <!-- Horizontal reinforcement ribs on body -->
    <rect x="4" y="17" width="24" height="1.5" fill="#26262e" opacity="0.4"/>
    <rect x="4" y="21" width="24" height="1.5" fill="#26262e" opacity="0.4"/>

    <!-- Vertical corner bolts -->
    <rect x="5"  y="14" width="2" height="9" rx="0.5" fill="#32323a" opacity="0.5"/>
    <rect x="25" y="14" width="2" height="9" rx="0.5" fill="#32323a" opacity="0.5"/>

    <!-- Radiation hazard glow (soft aura behind symbol) -->
    <circle cx="16" cy="19" r="6.5" fill="#39ff14" opacity="0.08"/>
    <circle cx="16" cy="19" r="4.5" fill="#39ff14" opacity="0.10"/>

    <!-- Radiation symbol — 3 blades + centre circle -->
    <!-- Blade 1 — top -->
    <path d="M16,19 L14.2,13.8 A3.8,3.8 0 0,1 17.8,13.8 Z"
          fill="#c8ff00" opacity="0.85"/>
    <!-- Blade 2 — bottom-right -->
    <path d="M16,19 L20.5,21.7 A3.8,3.8 0 0,1 17.8,13.8 Z"
          fill="#c8ff00" opacity="0.85"
          transform="rotate(120 16 19)"/>
    <!-- Blade 3 — bottom-left -->
    <path d="M16,19 L20.5,21.7 A3.8,3.8 0 0,1 17.8,13.8 Z"
          fill="#c8ff00" opacity="0.85"
          transform="rotate(240 16 19)"/>
    <!-- Inner clear circle (punches out centre) -->
    <circle cx="16" cy="19" r="1.8" fill="#4a4a52"/>
    <!-- Outer ring -->
    <circle cx="16" cy="19" r="5.2" fill="none" stroke="#c8ff00" stroke-width="0.7" opacity="0.6"/>

    <!-- Status indicator light (top-right of lid) -->
    <circle cx="25" cy="9.5" r="1.4" fill="#39ff14" opacity="0.9"/>
    <circle cx="25" cy="9.5" r="0.7" fill="#ccffcc" opacity="0.8"/>

    <!-- Vent slots on left side of body -->
    <rect x="6" y="15.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>
    <rect x="6" y="17.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>
    <rect x="6" y="19.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>

    <!-- Vent slots on right side of body -->
    <rect x="23" y="15.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>
    <rect x="23" y="17.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>
    <rect x="23" y="19.5" width="3" height="0.8" rx="0.3" fill="#1a1a20" opacity="0.7"/>
  </svg>
</template>
