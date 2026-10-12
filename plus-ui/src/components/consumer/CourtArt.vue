<template>
  <svg class="court-art" viewBox="0 0 520 320" aria-hidden="true">
    <defs>
      <pattern :id="gridId" width="35" height="35" patternUnits="userSpaceOnUse">
        <path d="M0 35V0h35" fill="none" stroke="#ceddc7" stroke-width=".6" />
      </pattern>
    </defs>
    <rect width="520" height="320" :fill="`url(#${gridId})`" />
    <ellipse cx="280" cy="272" rx="167" ry="20" fill="#b5ceb0" opacity=".35" />
    <g transform="translate(70 53) skewY(-8)">
      <path d="M40 210 125 43h265l-85 167Z" fill="#467959" />
      <path d="m62 195 69-137h234l-69 137Z" fill="none" stroke="#dce8d2" stroke-width="2" />
      <path d="m97 127 235 0m-153-69-70 137m210-137-70 137m-94-68-34 68" fill="none" stroke="#dce8d2" stroke-width="1.4" />
      <path d="m99 117 225 0M97 99v49m229-49v49" fill="none" stroke="#f1f1d8" stroke-width="2" />
      <path d="m102 103 221 0m-224 7h225m-221 9h214" stroke="#d8dfc3" stroke-width=".7" />
    </g>
    <g transform="translate(345 39) rotate(23)">
      <ellipse cx="32" cy="49" rx="29" ry="41" fill="#edf0d7" stroke="#d47a42" stroke-width="6" />
      <path d="M7 30h48M4 42h55M5 55h53M10 69h44M20 12v74m12-78v81m12-76v69" stroke="#bbccb0" stroke-width="1" />
      <path d="M32 90v65" stroke="#d47a42" stroke-width="7" />
      <path d="M32 137v27" stroke="#f2c299" stroke-width="9" />
    </g>
    <g transform="translate(326 204) rotate(-25)">
      <path d="m0 0-29-50 13-6 15 6 13-6 13 6-20 50Z" fill="#fcfcf3" stroke="#c2d0b4" />
      <path d="M-16-54 3-4M2-51 3-3M17-54 3-2" stroke="#c2d0b4" />
      <ellipse cx="3" cy="3" rx="10" ry="8" fill="#d58b54" />
    </g>
    <circle cx="140" cy="42" r="6" fill="#da8751" />
    <path d="M117 36h13m-6-6v12" stroke="#dfb881" stroke-width="2" />
  </svg>
</template>

<script lang="ts">
let serial = 0;
</script>

<script setup lang="ts">
const gridId = `court-grid-${++serial}`;
</script>
