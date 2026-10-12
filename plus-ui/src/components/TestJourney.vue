<template>
  <el-card shadow="never" class="mb-4">
    <template #header>测试时按这个顺序走</template>
    <p>这些按钮是为了把整条流程摊开。上线时会换成正式界面。</p>
    <ol class="journey">
      <li v-for="step in steps" :key="step.to">
        <router-link :to="step.to">{{ step.label }}</router-link>
        <span> — {{ step.hint }}</span>
      </li>
    </ol>
  </el-card>
</template>

<script setup lang="ts">
defineProps<{ steps: { to: string; label: string; hint: string }[] }>();
</script>

<style scoped>
.journey {
  margin: 0;
  padding-left: 1.2em;
  line-height: 1.8;
}
</style>
