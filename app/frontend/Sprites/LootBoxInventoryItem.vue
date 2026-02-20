<template>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="100%" height="100%">
    <!-- Shadow -->
    <ellipse cx="16" cy="30" rx="12" ry="2" fill="#0d0b08" opacity="0.5"/>

    <!-- Crate body -->
    <rect x="3" y="13" width="26" height="16" rx="1" fill="#7a4e1e" stroke="#3d2510" stroke-width="1.2"/>
    <!-- Crate body highlight (top edge) -->
    <rect x="4" y="14" width="24" height="2.5" rx="0.5" fill="#a06830" opacity="0.45"/>

    <!-- Crate lid -->
    <rect x="3" y="7" width="26" height="7" rx="1" fill="#9a6228" stroke="#3d2510" stroke-width="1.2"/>
    <!-- Lid highlight -->
    <rect x="4" y="8" width="24" height="2.5" rx="0.5" fill="#c48040" opacity="0.45"/>

    <!-- Lid/body divider band -->
    <rect x="3" y="13" width="26" height="2" fill="#3d2510" opacity="0.5"/>

    <!-- Vertical slat lines on body -->
    <line x1="9"  y1="15" x2="9"  y2="28" stroke="#3d2510" stroke-width="1" opacity="0.55"/>
    <line x1="16" y1="15" x2="16" y2="28" stroke="#3d2510" stroke-width="1" opacity="0.55"/>
    <line x1="23" y1="15" x2="23" y2="28" stroke="#3d2510" stroke-width="1" opacity="0.55"/>

    <!-- Vertical slat lines on lid -->
    <line x1="9"  y1="8" x2="9"  y2="13" stroke="#3d2510" stroke-width="1" opacity="0.45"/>
    <line x1="16" y1="8" x2="16" y2="13" stroke="#3d2510" stroke-width="1" opacity="0.45"/>
    <line x1="23" y1="8" x2="23" y2="13" stroke="#3d2510" stroke-width="1" opacity="0.45"/>

    <!-- Horizontal reinforcement band on body -->
    <rect x="3" y="20" width="26" height="2.5" fill="#3d2510" opacity="0.35"/>

    <!-- Clasp base (orange metal bracket) -->
    <rect x="12" y="10" width="8" height="6" rx="1" fill="#c07800" stroke="#7a4a00" stroke-width="1"/>
    <!-- Clasp highlight -->
    <rect x="13" y="11" width="6" height="1.5" rx="0.5" fill="#ffb234" opacity="0.6"/>
    <!-- Clasp keyhole -->
    <circle cx="16" cy="14" r="1.2" fill="#3d2510"/>

    <!-- Question mark on front face -->
    <text
      x="16"
      y="26"
      text-anchor="middle"
      font-family="'Arial Narrow', Arial, sans-serif"
      font-weight="900"
      font-size="9"
      fill="#e8a020"
      opacity="0.9"
    >?</text>
  </svg>
</template>
