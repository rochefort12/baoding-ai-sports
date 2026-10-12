<template>
  <router-view v-slot="{ Component }">
    <Transition name="sport-route" mode="out-in">
      <component :is="Component" />
    </Transition>
  </router-view>
</template>
