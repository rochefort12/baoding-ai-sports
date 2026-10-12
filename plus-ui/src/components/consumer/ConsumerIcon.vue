<template>
  <svg
    class="consumer-icon"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.7"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path :d="paths[name] || paths.arrow" />
  </svg>
</template>
<script setup lang="ts">
defineProps<{ name: string }>();
const paths: Record<string, string> = {
  home: 'm3 10 9-7 9 7v10h-6v-6H9v6H3z',
  events: 'M4 5h16v5a2 2 0 0 0 0 4v5H4v-5a2 2 0 0 0 0-4V5Zm11 0v14',
  user: 'M20 21v-3a5 5 0 0 0-5-5H9a5 5 0 0 0-5 5v3M16 6a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  calendar: 'M5 5h14v16H5zM8 3v5m8-5v5M5 11h14',
  pin: 'M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0Zm-7-2v4',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  back: 'M19 12H5m6-6-6 6 6 6',
  chevron: 'm9 5 7 7-7 7',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
  team: 'M16 21v-3a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v3M13 6a4 4 0 1 1-8 0 4 4 0 0 1 8 0m5 8a4 4 0 0 1 4 4v3m-5-19a4 4 0 0 1 0 8',
  award: 'M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0M8 10l-3 12 7-4 7 4-3-12',
  file: 'M5 2h9l5 5v15H5zM14 2v6h5M8 12h8m-8 4h8',
  clock: 'M12 8v5l3 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0',
  check: 'm5 12 4 4L19 6',
  search: 'M16 10a6 6 0 1 1-12 0 6 6 0 0 1 12 0m-1 5 6 6',
  venue: 'M3 21V8l9-5 9 5v13H3Zm5 0V11h8v10M8 15h8',
  life: 'M4 13 9 3l4 9h7l-5 9-4-8H4',
  shield: 'M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6l-8-3Zm-4 9 3 3 5-6'
};
</script>
