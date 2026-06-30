<script setup>
// App shell is layout-driven: each top-level route renders its own layout
// (PublicLayout for /, /user; AdminLayout for /admin/*). The login modal is
// mounted here so it can overlay any page instead of being a separate route.
import { onMounted, watch } from 'vue'
import LoginModal from './components/LoginModal.vue'
import AnnouncementModal from './components/AnnouncementModal.vue'
import PaymentModal from './components/PaymentModal.vue'
import { auth, refreshMe, openRegister } from './auth'
import { loadAnnouncement } from './announcement'

// Pull the 公告 whenever a user is (or becomes) logged in — at first paint AND
// after a fresh login. It pops up only if this user hasn't seen the latest one.
watch(() => auth.user?.id, (id) => { if (id) loadAnnouncement() }, { immediate: true })

onMounted(async () => {
  // Validate the stored session on every page load / refresh — even on public
  // pages where the router guard doesn't. This populates auth.user, which fires
  // the watch above → the 公告 check runs on a plain refresh (no re-login).
  if (auth.token && !auth.ready) await refreshMe()

  // An invite link (/?ref=CODE) should drop a guest straight into registration
  // with the code attached. Logged-in users just ignore the ref.
  const code = new URLSearchParams(location.search).get('ref')
  if (!code) return
  if (!auth.ready) await refreshMe()
  if (!auth.token || !auth.user) openRegister(code)
})
</script>

<template>
  <router-view />
  <LoginModal />
  <AnnouncementModal />
  <PaymentModal />
</template>
