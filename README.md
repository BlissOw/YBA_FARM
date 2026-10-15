# ⚡ BLISS FARM • YBA (Your Bizarre Adventure)
> **The Ultimate God-Collector Auto Farm Script for Roblox YBA**  
> *Developed by BlissOw*

---

## 🚀 Быстрый запуск (Loadstring)

Запустите в вашем эксплоите (Delta, Hydrogen, Codex, Wave, Fluxus, Solara):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/main.lua?t=" .. tostring(tick())))()
```

---

## 💎 Уникальный функционал

### 1. 🏆 Трёхэтапный цикл «God Account»
* **Фаза 1 (Охота на Lucky Arrow):** сбор лута, продажа торговцу пачками по 8 шт., моментальная авто-покупка 10x Lucky Arrow в магазине при накоплении $75,000.
* **Фаза 2 (Накопление $1,000,000):** стрелы не покупаются, деньги копятся до максимального внутриигрового капа $1,000,000.
* **Фаза 3 (Full Collector):** торговец полностью отключается! Скрипт добивает стаки абсолютно всех 16 предметов из `BaseMaxAmounts` до 100%.

### 2. 🔥 Умный расчёт ценности (Value-Priority)
* Lucky Arrow и Lucky Stone Mask имеют абсолютный высший приоритет (скрипт бросает всё и летит к ним).
* Дорогие предметы (`Pure Rokakaka` $1500, `Rib Cage` $1200) берутся первыми вместо дешёвых монет.

### 3. 🛡️ Stealth Anti-Kick
* Позиционирование исключительно внутри `RunService.Heartbeat`.
* Отсутствие палевных внутренних методов.
* Живые «human-like» рандомизированные задержки (Jitter), имитирующие человеческий пинг.

### 4. 📢 Discord Webhook (Оповещения в карман)
* 🏹 Уведомления о получении Lucky Arrow (с пингом `@everyone`).
* 🍀 Уведомления о поднятых редких предметах.
* 💰 Оповещение о достижении $1,000,000.
* 🏆 Финальный победный рапорт при 100% готовности God Account.
* 📊 Периодический отчёт о прибыли каждые 15 минут.

---

## ⚙️ Как подключить Discord Webhook

### Вариант 1: Через конфигурационный файл (Рекомендуется)
Создайте в папке `workspace` вашего эксплоита файл `BlissFarm_Config.json`:

```json
{
  "WebhookUrl": "https://discord.com/api/webhooks/ВАШ_ВЕБХУК",
  "WebhookEnabled": true,
  "WebhookPingOnLucky": true,
  "WebhookReportInterval": 15
}
```

### Вариант 2: В коде скрипта
Откройте [`main.lua`](file:///d:/Projects/YBA_Farm/main.lua) и вставьте ссылку в строку 57:
```lua
WebhookUrl = "https://discord.com/api/webhooks/ВАШ_ВЕБХУК",
```
