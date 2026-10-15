// Registry asset minh họa: key -> file SVG trong thư mục assets/.
// Mỗi việc lưu `icon` = key (vd 'air-filter'), dùng lại được cho item tự tạo.
const ART = {
  'air-filter': 'air-filter',
  bed: 'bed',
  toothbrush: 'toothbrush',
  'water-filter': 'water-filter',
  'smoke-alarm': 'smoke-alarm',
  pillow: 'pillow',
  sponge: 'sponge',
  toilet: 'toilet',
  broom: 'broom',
  curtain: 'curtain',
  washer: 'washer',
  ac: 'ac',
  scissors: 'scissors',
  pill: 'pill',
  tooth: 'tooth',
  plant: 'plant',
  fridge: 'fridge',
  scooter: 'scooter',
  mattress: 'mattress',
  bell: 'bell',
  user: 'user',
  default: 'default',
};
const ART_KEYS = Object.keys(ART).filter((k) => k !== 'default');

// src() chịu cả key mới lẫn emoji cũ để dữ liệu đã lưu vẫn hiển thị đúng.
function artSrc(icon) {
  const key = String(icon || '').trim();
  if (ART[key]) return `./assets/${ART[key]}.svg`;
  return './assets/default.svg';
}
function artImg(icon, cls, alt) {
  return `<img class="${cls}" src="${artSrc(icon)}" alt="${alt ? esc(alt) : ''}" loading="lazy" decoding="async">`;
}