<template>
  <svg class="sport-court-scene" viewBox="0 0 600 540" fill="none" role="img" aria-label="羽毛球场与球拍线稿">
    <defs>
      <linearGradient :id="id + 'floor'" x1="50" y1="10" x2="550" y2="540" gradientUnits="userSpaceOnUse">
        <stop stop-color="#267c69" />
        <stop offset="1" stop-color="#0d403b" />
      </linearGradient>
      <radialGradient :id="id + 'halo'">
        <stop stop-color="#d9ee9e" stop-opacity=".3" />
        <stop offset="1" stop-color="#d9ee9e" stop-opacity="0" />
      </radialGradient>
    </defs>
    <circle cx="350" cy="225" r="210" :fill="'url(#' + id + 'halo)'" />
    <g transform="translate(78 68) rotate(-15 220 220)">
      <rect x="26" y="33" width="404" height="401" rx="18" fill="#07362f" opacity=".2" />
      <rect x="16" y="19" width="404" height="401" rx="14" :fill="'url(#' + id + 'floor)'" />
      <rect x="37" y="42" width="362" height="355" stroke="#b5d6b1" stroke-opacity=".75" stroke-width="2" />
      <path d="M76 42v355m284-355v355M37 135h362M37 302h362M37 219h362M218 42v177m0 83v95" stroke="#b5d6b1" stroke-opacity=".65" stroke-width="1.5" />
      <path d="M24 217h388" stroke="#eef3cd" stroke-width="3" />
      <path d="M27 225h382" stroke="#eef3cd" stroke-opacity=".2" stroke-width="8" />
      <circle cx="300" cy="95" r="5" fill="#d8ee88" />
      <circle cx="109" cy="342" r="4" fill="#d8ee88" />
    </g>
    <g transform="translate(342 296) rotate(23)">
      <path d="m0 42 0 105" stroke="#d5e0ca" stroke-width="8" stroke-linecap="round" />
      <path d="M0 84v25" stroke="#d3ee72" stroke-width="12" stroke-linecap="round" />
      <ellipse cy="-11" rx="44" ry="58" fill="#143f37" stroke="#d3ee72" stroke-width="5" />
      <g stroke="#d8e8bb" stroke-width="1" opacity=".55">
        <path d="M-31-45v68m15-85v98M0-69v116m16-108v98m15-80v59M-39-31h77m-82 16h87m-86 17h86m-80 17h76m-61 16h52" />
      </g>
    </g>
    <path d="M178 120c-14 73 58 67 73 123" stroke="#d7ec9d" stroke-opacity=".75" stroke-width="2" stroke-dasharray="5 9" />
    <g transform="translate(239 221) rotate(-24)">
      <path d="m-12 0-7-28 9 3 10-10 10 10 9-3-7 28Z" fill="#e5edca" />
      <path d="M-12 0h24v10c0 10-24 10-24 0Z" fill="#d3ee72" />
      <path d="m-10-26 4 24M0-32v30m10-24L6-2" stroke="#729e72" />
    </g>
  </svg>
</template>
<script setup lang="ts">
import { useId } from 'vue';
const id = 'court-' + useId().replace(/[^a-zA-Z0-9_-]/g, '');
</script>
