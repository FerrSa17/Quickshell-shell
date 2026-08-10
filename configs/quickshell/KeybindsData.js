.pragma library

// Static keybind cheatsheet (Hyprland + Quickshell). Keep in sync with hypr/modules/binds.lua.
var sections = [
  {
    id: "shell",
    en: "Quickshell",
    ru: "Quickshell",
    binds: [
      { keys: "Super + A", en: "Toggle dashboard", ru: "Панель слева" },
      { keys: "Super + W", en: "App launcher", ru: "Лаунчер приложений" },
      { keys: "Super + P", en: "Power menu", ru: "Меню питания" },
      { keys: "Super + Shift + A", en: "System monitor", ru: "Монитор системы" },
      { keys: "Super + S", en: "Screenshot (area)", ru: "Скриншот области" }
    ]
  },
  {
    id: "windows",
    en: "Windows",
    ru: "Окна",
    binds: [
      { keys: "Super + Return", en: "Terminal", ru: "Терминал" },
      { keys: "Super + E", en: "File manager", ru: "Файловый менеджер" },
      { keys: "Super + Q", en: "Close window", ru: "Закрыть окно" },
      { keys: "Super + V", en: "Toggle floating", ru: "Плавающее окно" },
      { keys: "Super + J", en: "Toggle split", ru: "Сменить сплит" },
      { keys: "Super + Shift + P", en: "Pseudo tiling", ru: "Псевдотайлинг" },
      { keys: "Super + Arrows", en: "Focus window", ru: "Фокус окна" },
      { keys: "Super + Shift + Arrows", en: "Move window", ru: "Переместить окно" },
      { keys: "Super + LMB drag", en: "Drag window", ru: "Перетащить окно" },
      { keys: "Super + RMB drag", en: "Resize window", ru: "Изменить размер" }
    ]
  },
  {
    id: "workspaces",
    en: "Workspaces",
    ru: "Рабочие столы",
    binds: [
      { keys: "Super + 1…0", en: "Switch workspace", ru: "Переключить стол" },
      { keys: "Super + Shift + 1…0", en: "Move to workspace", ru: "Окно на стол" },
      { keys: "Super + Shift + S", en: "Special workspace", ru: "Специальный стол" },
      { keys: "Super + Scroll", en: "Cycle workspaces", ru: "Листать столы" }
    ]
  },
  {
    id: "media",
    en: "Media & brightness",
    ru: "Медиа и яркость",
    binds: [
      { keys: "Vol Up / Down", en: "Volume", ru: "Громкость" },
      { keys: "Mute", en: "Mute output", ru: "Без звука" },
      { keys: "Mic Mute", en: "Mute microphone", ru: "Выкл. микрофон" },
      { keys: "Brightness ±", en: "Brightness", ru: "Яркость" },
      { keys: "Play / Pause", en: "Media play/pause", ru: "Плей/пауза" },
      { keys: "Next / Prev", en: "Media next/prev", ru: "След./пред." }
    ]
  }
];

function sectionTitle(sec, lang) {
  if (!sec) return "";
  return lang === "ru" ? (sec.ru || sec.en) : (sec.en || sec.ru);
}

function bindLabel(b, lang) {
  if (!b) return "";
  return lang === "ru" ? (b.ru || b.en) : (b.en || b.ru);
}
