<script setup>
// Full-screen preview: just the enlarged image/video on a dark backdrop.
// Click the dark area (or Esc, handled by the parent) to close. No prompt, no
// meta, no buttons — deliberately bare. Props beyond src/kind are accepted for
// call-site compatibility but intentionally not rendered.
import { ref, watch } from 'vue'

const props = defineProps({
  src: { type: String, required: true },     // resolved media URL
  kind: { type: String, default: 'image' },  // 'image' | 'video'
  prompt: { type: String, default: '' },
  meta: { type: String, default: '' },
  metaSub: { type: String, default: '' },
  downloadName: { type: String, default: '' },
})
const emit = defineEmits(['close'])

// Render the image as a CSS background (not <img>) so Edge/Bing shows no
// "visual search" hover icon. Load it to learn its aspect ratio, then size the
// div to fit the viewport while preserving ratio — mirrors object-contain.
const imgRatio = ref(1)
watch(() => props.src, (src) => {
  if (props.kind !== 'image' || !src) return
  const im = new Image()
  im.onload = () => { if (im.naturalHeight) imgRatio.value = im.naturalWidth / im.naturalHeight }
  im.src = src
}, { immediate: true })
</script>

<template>
  <!-- Teleport to <body> so the overlay escapes the layout's `main` (relative
       z-10) stacking context — otherwise the fixed z-index sits BELOW the
       root-level sidebar (z-30) and the logo pokes through the backdrop. -->
  <Teleport to="body">
  <transition name="lb-fade" appear>
    <div class="fixed inset-0 z-[100] bg-black/90 flex items-center justify-center p-4"
         @click.self="emit('close')">
      <video v-if="kind === 'video'" :src="src" controls autoplay
             class="max-h-[94vh] max-w-[96vw] rounded-lg"
             controlslist="nodownload noremoteplayback noplaybackrate"
             disablepictureinpicture disableremoteplayback></video>
      <div v-else
           :style="{ width: `min(96vw, calc(94vh * ${imgRatio}))`, aspectRatio: imgRatio, backgroundImage: `url(${src})` }"
           class="rounded-lg bg-contain bg-center bg-no-repeat"></div>
    </div>
  </transition>
  </Teleport>
</template>

<style scoped>
.lb-fade-enter-active, .lb-fade-leave-active { transition: opacity 0.18s ease; }
.lb-fade-enter-from, .lb-fade-leave-to { opacity: 0; }
</style>
