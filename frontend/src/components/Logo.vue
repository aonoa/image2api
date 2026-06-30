<script setup>
defineProps({ size: { type: [Number, String], default: 40 } })
</script>

<template>
  <img
    src="/purefox_1_eye_192.png"
    alt="ManyToken"
    :width="size"
    :height="size"
    class="shrink-0 object-cover"
    draggable="false"
  />
</template>
