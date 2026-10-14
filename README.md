# BLISS FARM — YBA (Your Bizarre Adventure) Auto Farm

Скрипт автофарма для Roblox YBA с поддержкой сбора предметов, продажи торговцу, покупки Lucky Arrow и Server Hop.

## 🚀 Запуск скрипта через Roblox Executor
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/main.lua"))()
```

## ✨ Функционал
- **Auto Farm Loot**: сканирование спавна предметов (`Item_Spawns/Items`) и сбор через `fireproximityprompt`
- **Smart Stacking**: отслеживание лимитов стаков и редких предметов
- **Auto Sell**: автоматический диалог с торговцем (Merchant) и продажа лишнего
- **Auto Buy Lucky Arrow**: покупка лаки стрел при достижении нужного баланса
- **Anti-Cheat Bypass**: хук `__namecall` для обхода детектов телепортации
- **Anti-Fall**: защита от падения в бездну
- **Server Hop**: смена сервера при засухе спавна или по таймеру
- **Компактный GUI**: статус работы, кнопка паузы/возобновления, счетчики
