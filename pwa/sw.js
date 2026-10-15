/* Service Worker — App shell cache-first, versioned. */
const CACHE = 'nhac-viec-v10';
const SHELL = ['./', './index.html', './styles.css', './app.js', './assets.js', './manifest.webmanifest', './icon.svg',
  './assets/air-filter.svg', './assets/bed.svg', './assets/toothbrush.svg', './assets/water-filter.svg',
  './assets/smoke-alarm.svg', './assets/pillow.svg', './assets/sponge.svg', './assets/toilet.svg',
  './assets/broom.svg', './assets/curtain.svg', './assets/washer.svg', './assets/ac.svg', './assets/scissors.svg',
  './assets/pill.svg', './assets/tooth.svg', './assets/plant.svg', './assets/fridge.svg', './assets/scooter.svg',
  './assets/mattress.svg', './assets/bell.svg', './assets/user.svg', './assets/default.svg'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request).then((hit) => hit || fetch(e.request).then((res) => {
    const copy = res.clone();
    caches.open(CACHE).then((c) => c.put(e.request, copy));
    return res;
  }).catch(() => caches.match('./index.html'))));
});
// Web Push từ backend (/api/cron lúc 7h sáng). Payload: {title, body}.
self.addEventListener('push', (e) => {
  let data = { title: 'Nhắc việc', body: 'Có việc đến hạn.' };
  try { if (e.data) data = { ...data, ...e.data.json() }; } catch {}
  e.waitUntil(self.registration.showNotification(data.title, {
    body: data.body, icon: './icon.svg', badge: './icon.svg', tag: 'nhac-viec-digest',
  }));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(clients.matchAll({ type: 'window' }).then((list) => {
    for (const c of list) { c.focus(); return; }
    return clients.openWindow('./index.html');
  }));
});
