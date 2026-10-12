<template>
  <SportHeader :title="title" :description="description"
    ><template v-if="$slots.default || backTo" #default
      ><router-link v-if="backTo" class="btn" :to="backTo"><ConsumerIcon name="back" />{{ backLabel || '返回上一层' }}</router-link
      ><slot /></template
  ></SportHeader>
</template>
<script setup lang="ts">
import ConsumerIcon from './ConsumerIcon.vue';
import SportHeader from '@/components/sport-ui/SportHeader.vue';
defineProps<{ title: string; eyebrow?: string; description?: string; backTo?: string; backLabel?: string }>();
</script>
