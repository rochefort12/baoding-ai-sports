<template><div class="assistant-markdown" v-html="html" /></template>
<script setup lang="ts">
import { computed } from 'vue';
import { renderAssistantMarkdown } from '@/utils/assistantMarkdown';
import '@/assets/styles/assistant-markdown.scss';
const props = defineProps<{ text: string }>();
const html = computed(() => renderAssistantMarkdown(props.text));
</script>
