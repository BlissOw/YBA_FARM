# -*- coding: utf-8 -*-
"""
BLISS SHIELD • Local Offline Lua Obfuscator
Encrypts strings, strips comments, and generates a protected distribution build
"""

import re
import os
import random

SOURCE_FILE = "main_dev.lua"
OUTPUT_FILE = "main.lua"

def obfuscate_lua(content):
    # 1. Удаление комментариев (кроме специальных)
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    
    lines = []
    for line in content.splitlines():
        # Убираем строчные комментарии
        cleaned = re.sub(r'--.*$', '', line)
        if cleaned.strip():
            lines.append(cleaned)
    clean_code = "\n".join(lines)

    # 2. Сбор и шифрование всех строковых литералов
    # Регулярка для строк в двойных кавычках
    string_table = []
    string_map = {}

    def replace_string(match):
        raw_str = match.group(1)
        # Если строка пустая или слишком короткая
        if not raw_str:
            return '""'
        
        # Если строка уже закодирована
        if raw_str in string_map:
            idx = string_map[raw_str]
        else:
            string_table.append(raw_str)
            idx = len(string_table)
            string_map[raw_str] = idx
        
        return f"_BLISS_STR[{idx}]"

    # Экранирование строк с безопасным поиском
    # Заменяем только двойные кавычки без переносов строк внутри
    pattern = r'"((?:[^"\\]|\\.)*)"'
    obfuscated_code = re.sub(pattern, replace_string, clean_code)

    # Генерация зашифрованной таблицы строк (в виде байт-последовательностей)
    encoded_entries = []
    xor_key = random.randint(35, 120)

    for s in string_table:
        # Шифруем каждый байт с помощью XOR
        # Для безопасности в Lua экранируем через string.char
        encoded_bytes = []
        for ch in s.encode('utf-8', errors='ignore'):
            encoded_bytes.append(str(ch ^ xor_key))
        joined = ",".join(encoded_bytes)
        encoded_entries.append(f"{{{joined}}}")

    all_table_lines = ",\n    ".join(encoded_entries)

    # Обертка-дешифратор (быстрая, без задержек в игре)
    runtime_wrapper = f"""-- ═════════════════════════════════════════════════════════════════════════
-- ⚡ BLISS FARM • ULTIMATE EDITION (PROTECTED BUILD)
-- [ BLISS SHIELD v1.0 • OBFUSCATED & COMPILED FOR PRODUCTION ]
-- ═════════════════════════════════════════════════════════════════════════

local _BXOR_KEY = {xor_key}
local _RAW_DATA = {{
    {all_table_lines}
}}

local _BLISS_STR = {{}}
local _char = string.char
local _bxor = bit32 and bit32.bxor or function(a, b)
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra ~= rb then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    if a < b then a = b end
    while a > 0 do
        local ra = a % 2
        if ra > 0 then c = c + p end
        a, p = (a - ra) / 2, p * 2
    end
    return c
end

for _i = 1, #_RAW_DATA do
    local _b = _RAW_DATA[_i]
    local _t = {{}}
    for _j = 1, #_b do
        _t[_j] = _char(_bxor(_b[_j], _BXOR_KEY))
    end
    _BLISS_STR[_i] = table.concat(_t)
end

-- Основной код
{obfuscated_code}
"""
    return runtime_wrapper

if __name__ == "__main__":
    if not os.path.exists(SOURCE_FILE):
        print(f"Error: {SOURCE_FILE} not found!")
    else:
        with open(SOURCE_FILE, "r", encoding="utf-8") as f:
            src = f.read()
        
        print(f"Reading {SOURCE_FILE} ({len(src)} bytes)...")
        obf = obfuscate_lua(src)
        
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            f.write(obf)
        
        print(f"SUCCESS: Generated protected {OUTPUT_FILE} ({len(obf)} bytes)!")
