// PWA logic — port 1:1 từ lib/src/features/reminders/recurrence.dart (floor + grace/remindBefore).
const DAY = 86400000, KEY = 'habit_pwa_v1';
const $ = (s) => document.querySelector(s);

const TEMPLATES = [
  ['Dọn toilet','🚽',7,'Cọ bồn cầu, lavabo mỗi tuần.'],['Giặt ga giường','🛏️',14,'Tránh mạt bụi gây dị ứng.'],
  ['Lau nhà','🧹',3,'Quét + lau bếp, lối đi.'],['Giặt rèm cửa','👕',90,'Hút bụi thanh treo.'],
  ['Tẩy lồng giặt','🧺',30,'Chạy chế độ vệ sinh lồng.'],['Vệ sinh máy lạnh','🌬️',90,'Rửa lưới lọc.'],
  ['Thay bàn chải','🪥',90,'Tránh vi khuẩn tích tụ.'],['Thay lõi lọc nước','💧',180,'Theo khuyến cáo hãng.'],
  ['Cắt tóc','💇',30,'Tỉa định kỳ.'],['Tẩy giun','💊',180,'6 tháng/lần cả nhà.'],
  ['Khám răng','🦷',180,'Cạo vôi định kỳ.'],['Tưới cây','🌱',2,'Tưới sáng sớm.'],
  ['Dọn tủ lạnh','🧊',7,'Bỏ đồ hết hạn.'],['Thay nhớt xe','🛵',45,'Kiểm tra thắng, lốp.'],
  ['Vệ sinh nệm','🛋️',60,'Hút bụi, phơi nắng.'],
];
const uid = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
const load = () => { try { return JSON.parse(localStorage.getItem(KEY)) || { tasks: [] }; } catch { return { tasks: [] }; } };
const save = (d) => localStorage.setItem(KEY, JSON.stringify(d));

// --- recurrence (canonical: floor, giống Dart) ---
const nextDue = (last, cycle) => last + cycle * DAY;
function statusOf(t, now = Date.now()) {
  const eff = (t.snoozedUntil && t.snoozedUntil > now) ? t.snoozedUntil : t.nextDueAt;
  const diff = Math.floor((eff - now) / DAY);
  if (diff < -t.grace) return { s: 'overdue', diff, txt: `Quá hạn ${-diff} ngày` };
  if (diff < 0) return { s: 'dueGrace', diff, txt: `Trễ ${-diff} ngày` };
  if (diff === 0) return { s: 'dueToday', diff, txt: 'Đến hạn hôm nay' };
  if (diff <= t.remindBefore) return { s: 'upcoming', diff, txt: `Còn ${diff} ngày` };
  return { s: 'ok', diff, txt: `Còn ${diff} ngày` };
}
const colorOf = (s) => s === 'overdue' ? '#D64545' : (s === 'dueGrace' || s === 'dueToday') ? '#E86A2C' : (s === 'upcoming') ? '#E69F00' : '#2E9E5B';
function markDone(t, now = Date.now()) {
  const st = now < t.nextDueAt - DAY ? 'early' : now > t.nextDueAt ? 'late' : 'done';
  return { ...t, lastDoneAt: now, nextDueAt: nextDue(now, t.cycleDays), snoozedUntil: null, status: st };
}

let filter = 'all';
function sorted() {
  const { tasks } = load();
  return tasks.filter((t) => t.isActive !== false).sort((a, b) => a.nextDueAt - b.nextDueAt);
}
function render() {
  const h = location.hash || '#/';
  const v = $('#view');
  if (h.startsWith('#/detail/')) return renderDetail(v, decodeURIComponent(h.slice(9)));
  if (h.startsWith('#/form')) return renderForm(v, new URLSearchParams(h.split('?')[1] || '').get('edit'));
  return renderHome(v);
}
function renderHome(v) {
  const tasks = sorted(), now = Date.now();
  const sts = tasks.map((t) => statusOf(t, now));
  const over = sts.filter((s) => s.s === 'overdue' || s.s === 'dueGrace').length;
  const up = sts.filter((s) => s.s === 'upcoming' || s.s === 'dueToday').length;
  const list = tasks.filter((t, i) => {
    const s = sts[i].s;
    return filter === 'all' || (filter === 'over' && (s === 'overdue' || s === 'dueGrace')) || (filter === 'up' && (s === 'upcoming' || s.s === 'dueToday')) || (filter === 'ok' && s.s === 'ok');
  });
  v.innerHTML = `<header class="hero"><h1>Việc nhà định kỳ</h1><p>${tasks.length ? `${over} quá hạn, ${up} sắp tới` : 'Chưa có việc nào — thêm việc đầu tiên!'}</p>
    <div class="pills"><span class="pill">Tổng ${tasks.length}</span><span class="pill">Quá hạn ${over}</span><span class="pill">Sắp tới ${up}</span></div></header>
    <main><div class="filters">${[['all','Tất cả'],['over','Quá hạn'],['up','Sắp tới'],['ok','An toàn']].map(([k,l]) => `<button class="chip${filter===k?' on':''}" data-f="${k}">${l}</button>`).join('')}</div>
    <div><button class="chip" id="notif">🔔 Bật nhắc việc</button> <small class="mut">PWA: nhắc khi mở app + notification</small></div>
    <div id="list">${list.length ? '' : `<div class="empty"><div style="font-size:48px">🏡</div><p>Chưa có việc nào.<br>Chọn mẫu bên dưới hoặc bấm + .</p></div>`}</div>
    <h3>Mẫu có sẵn (1 chạm)</h3><div>${TEMPLATES.map((t,i)=>`<div class="tpl" data-t="${i}"><span style="font-size:22px">${t[1]}</span><div><b>${t[0]}</b> · ${t[2]} ngày<br><small class="mut">${t[3]}</small></div></div>`).join('')}</div></main>
    <button class="fab" id="add">+ Thêm việc</button>`;
  v.querySelectorAll('[data-f]').forEach((b) => b.onclick = () => { filter = b.dataset.f; render(); });
  $('#add').onclick = () => location.hash = '#/form';
  $('#notif').onclick = enableNotif;
  v.querySelectorAll('[data-t]').forEach((el) => el.onclick = () => addFromTemplate(+el.dataset.t));
  const box = v.querySelector('#list');
  list.forEach((t) => box.appendChild(card(t, now)));
}
function card(t, now) {
  const st = statusOf(t, now), c = colorOf(st.s);
  const donePct = st.diff < 0 ? 1 : Math.min(1, Math.max(0, (t.cycleDays - st.diff) / t.cycleDays));
  const d = document.createElement('div');
  d.className = 'card';
  d.innerHTML = `<div class="icon" style="background:linear-gradient(135deg,${c},${c}88)">${t.icon}</div>
    <div class="body"><div class="title">${esc(t.title)}</div>
    <span class="badge" style="color:${c};border-color:${c}55;background:${c}22"><span class="dot" style="background:${c}"></span>${st.txt}</span>
    <div class="prog"><i style="width:${Math.round(donePct*100)}%;background:${c}"></i></div>
    <div class="cap">Hạn ${fmt(t.nextDueAt)} · chu kỳ ${t.cycleDays} ngày</div></div>
    <button class="donebtn" title="Đánh dấu xong">✅</button>`;
  d.onclick = (e) => { if (!e.target.closest('.donebtn')) location.hash = '#/detail/' + encodeURIComponent(t.id); };
  d.querySelector('.donebtn').onclick = () => doDone(t.id);
  return d;
}
function renderDetail(v, id) {
  const d = load(), t = d.tasks.find((x) => x.id === id);
  if (!t) { v.innerHTML = `<main><div class="empty"><p>Không tìm thấy.</p><a href="#/">Về trang chủ</a></div></main>`; return; }
  const st = statusOf(t), c = colorOf(st.s);
  v.innerHTML = `<main><p><a href="#/">← Trang chủ</a></p><div class="card"><div class="icon" style="background:linear-gradient(135deg,${c},${c}88)">${t.icon}</div>
    <div class="body"><div class="title">${esc(t.title)}</div><div class="cap">Lần cuối: ${t.lastDoneAt ? fmt(t.lastDoneAt) : 'chưa ghi'} · Hạn ${fmt(t.nextDueAt)}</div></div></div>
    <div class="card"><div class="body">Trạng thái: <b style="color:${c}">${st.txt}</b><br><small class="mut">Nhắc trước ${t.remindBefore} ngày · grace ${t.grace} ngày</small></div></div>
    <div class="row"><button class="cta" id="done">Đánh dấu đã xong</button><button class="chip" id="snz">Hoãn 1 ngày</button></div>
    <div class="row" style="margin-top:8px"><button class="chip" id="edit">Sửa</button><button class="chip" id="del">Xóa</button></div></main>`;
  $('#done').onclick = () => doDone(id, true);
  $('#snz').onclick = () => { d.tasks = d.tasks.map((x) => x.id === id ? { ...x, snoozedUntil: Date.now() + DAY } : x); save(d); location.hash = '#/'; };
  $('#edit').onclick = () => location.hash = '#/form?edit=' + encodeURIComponent(id);
  $('#del').onclick = () => { if (confirm('Xóa việc này?')) { d.tasks = d.tasks.filter((x) => x.id !== id); save(d); location.hash = '#/'; } };
}
function renderForm(v, editId) {
  const d = load(), t = editId ? d.tasks.find((x) => x.id === editId) : null;
  v.innerHTML = `<main><p><a href="#/">← Trang chủ</a></p><h2>${t ? 'Sửa việc' : 'Thêm việc'}</h2>
    <form class="card" id="f"><input id="title" required maxlength="60" placeholder="VD: Dọn toilet" value="${esc(t?.title || '')}">
    <div class="row"><select id="icon">${['🧹','🚽','🛏️','🪥','💧','🌱','🧊','🛵','💊','🦷'].map((e)=>`<option ${t?.icon===e?'selected':''}>${e}</option>`).join('')}</select>
    <input id="cycle" type="number" min="1" max="730" value="${t?.cycleDays || 7}" title="Chu kỳ (ngày)"></div>
    <div class="row"><input id="last" type="date" value="${t?.lastDoneAt ? iso(t.lastDoneAt) : iso(Date.now())}" title="Lần cuối"><input id="rb" type="number" min="0" max="30" value="${t?.remindBefore ?? 2}" title="Nhắc trước (ngày)"></div>
    <button class="cta" type="submit">Lưu</button></form></main>`;
  $('#f').onsubmit = (e) => {
    e.preventDefault();
    const title = $('#title').value.trim(); if (!title) return;
    const cycle = Math.max(1, +$('#cycle').value || 7);
    const last = new Date($('#last').value + 'T08:00:00').getTime() || Date.now();
    if (t) d.tasks = d.tasks.map((x) => x.id === t.id ? { ...x, title, icon: $('#icon').value, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: +$('#rb').value || 0, snoozedUntil: null } : x);
    else d.tasks.push({ id: uid(), title, icon: $('#icon').value, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: +$('#rb').value || 0, grace: 0, snoozedUntil: null, isActive: true });
    save(d); location.hash = '#/'; checkDue();
  };
}
function addFromTemplate(i) {
  const [title, icon, cycle] = TEMPLATES[i], d = load(), now = Date.now();
  d.tasks.push({ id: uid(), title, icon, cycleDays: cycle, lastDoneAt: now, nextDueAt: nextDue(now, cycle), remindBefore: Math.min(7, Math.max(1, Math.floor(cycle / 4))), grace: 0, snoozedUntil: null, isActive: true });
  save(d); render(); checkDue();
}
function doDone(id, goHome) {
  const d = load();
  d.tasks = d.tasks.map((x) => x.id === id ? markDone(x) : x);
  save(d); if (goHome) location.hash = '#/'; else render(); checkDue();
}
async function enableNotif() {
  if (!('Notification' in window)) return alert('Trình duyệt không hỗ trợ notification.');
  const p = await Notification.requestPermission();
  alert(p === 'granted' ? 'Đã bật nhắc việc! Mở app mỗi ngày để nhận nhắc.' : 'Chưa cấp quyền: ' + p);
  checkDue();
}
function checkDue() {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  const now = Date.now();
  sorted().slice(0, 3).forEach((t) => {
    const st = statusOf(t, now);
    if (st.s === 'dueToday' || st.s === 'overdue') { try { new Notification(st.s === 'overdue' ? `Quá hạn: ${t.title}` : `Đến hạn: ${t.title}`, { body: st.txt, icon: './icon.svg' }); } catch {} }
  });
}
const esc = (s) => String(s || '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fmt = (ms) => { const d = new Date(ms); return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`; };
const iso = (ms) => { const d = new Date(ms); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
window.addEventListener('hashchange', render);
// Seed lần đầu: 3 mẫu để có aha-moment 30s
if (!localStorage.getItem(KEY)) {
  const now = Date.now();
  const mk = (ti, ago) => { const [title, icon, cycle] = TEMPLATES[ti], last = now - ago * DAY; return { id: uid(), title, icon, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: 2, grace: 0, snoozedUntil: null, isActive: true }; };
  save({ tasks: [mk(0, 6), mk(6, 45), mk(1, 12)] });
}
render(); checkDue();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js');
