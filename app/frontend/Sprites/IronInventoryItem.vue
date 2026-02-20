<template>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="100%" height="100%">
    <!-- Shadow -->
    <ellipse cx="16" cy="28" rx="11" ry="2.5" fill="#0d0b08" opacity="0.5"/>

    <!-- Ingot body — trapezoid wider at bottom -->
    <polygon points="7,8 25,8 28,24 4,24" fill="#7a7a7a" stroke="#3a3a3a" stroke-width="1.2" stroke-linejoin="round"/>

    <!-- Ingot face highlight gradient simulation (lighter center band) -->
    <polygon points="10,9 22,9 24,15 8,15" fill="#b0b0b0" opacity="0.55"/>

    <!-- Mid tone -->
    <polygon points="8,15 24,15 26,22 6,22" fill="#909090" opacity="0.4"/>

    <!-- Left dark edge bevel -->
    <polygon points="4,24 7,8 9,9 6,22" fill="#4a4a4a" opacity="0.6"/>

    <!-- Right dark edge bevel -->
    <polygon points="25,8 28,24 26,22 23,9" fill="#4a4a4a" opacity="0.4"/>

    <!-- Top face (3D top surface) -->
    <polygon points="7,8 25,8 23,5 9,5" fill="#c0c0c0" stroke="#3a3a3a" stroke-width="0.8"/>
    <!-- Top face highlight -->
    <polygon points="10,6 22,6 21,5 11,5" fill="#e0e0e0" opacity="0.6"/>

    <!-- Specular glint on ingot face -->
    <line x1="10" y1="10" x2="9" y2="21" stroke="#d8d8d8" stroke-width="1.5" stroke-linecap="round" opacity="0.5"/>
  </svg>
</template>
