#!/usr/bin/env python3
"""Comprobaciones del esqueleto de GoldPilot: compilación, TOC, idiomas, globales y pruebas Lua."""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = ROOT
LOCAL = os.path.join(ADDON, "Data", "Local")
# Solo estas carpetas forman el addon; tests/ y tools/ también tienen Lua o Python.
ADDON_DIRS = ("Core", "Data", "Engine", "Locales", "Media", "State", "Store", "UI")
ALLOWED = {"GoldPilot", "GoldPilotDB", "GoldPilotCharDB", "SLASH_GOLDPILOT1", "SLASH_GOLDPILOT2", "GoldPilotMainFrame"}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def toc_files():
    return [l.strip().replace("\\", "/") for l in read(os.path.join(ADDON, "GoldPilot.toc")).splitlines()
            if l.strip() and not l.startswith("#")]


def lua_files():
    # La semilla local se genera aparte y solo la carga el TOC de desarrollo.
    paths = [p for d in ADDON_DIRS for p in glob.glob(os.path.join(ADDON, d, "**", "*.lua"), recursive=True)]
    return sorted(p for p in paths if not os.path.abspath(p).startswith(LOCAL + os.sep))


def main():
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError:
        print("Falta lupa (Lua 5.1) para ejecutar las pruebas.", file=sys.stderr)
        return 1

    toc = read(os.path.join(ADDON, "GoldPilot.toc"))
    version = read(os.path.join(ROOT, "VERSION")).strip()
    if re.search(r"^## Version:\s*(.+)$", toc, re.M).group(1).strip() != version:
        print("VERSION no coincide con el TOC", file=sys.stderr)
        return 1

    lua = LuaRuntime(unpack_returned_tuples=True)
    for path in lua_files():
        lua.compile(read(path))
    listed = set(toc_files())
    for path in lua_files():
        rel = os.path.relpath(path, ADDON).replace("\\", "/")
        if rel not in listed:
            print("Archivo Lua fuera del TOC: " + rel, file=sys.stderr)
            return 1

    lua.execute("""
        function new_addon(files)
            local addon = {}
            for _, source in ipairs(files) do assert(loadstring(source))("GoldPilot", addon) end
            return addon
        end
        function global_names()
            local r = {}
            for k in pairs(_G) do r[k] = true end
            return r
        end
        function list_new(before)
            local r = {}
            for k in pairs(_G) do if not before[k] then r[#r + 1] = k end end
            table.sort(r)
            return table.concat(r, ",")
        end
        function key_list(t)
            local r = {}
            for k in pairs(t) do r[#r + 1] = k end
            table.sort(r)
            return table.concat(r, ",")
        end
    """)
    g = lua.globals()
    sources = [read(os.path.join(ADDON, rel)) for rel in toc_files()]
    mock = lua.execute(read(os.path.join(ROOT, "tests", "wowmock.lua")))
    before = g.global_names()

    addon = g.new_addon(lua.table_from(sources))
    if g.key_list(addon.LocaleStrings.enUS) != g.key_list(addon.LocaleStrings.esES):
        print("Claves enUS/esES diferentes", file=sys.stderr)
        return 1
    extra = {n for n in g.list_new(before).split(",") if n} - ALLOWED - {"SlashCmdList"}
    if extra:
        print("Globales no permitidos: " + ", ".join(sorted(extra)), file=sys.stderr)
        return 1

    failures = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "tests", "test_*.lua"))):
        for name, test in lua.execute(read(path)).items():
            mock = lua.execute(read(os.path.join(ROOT, "tests", "wowmock.lua")))
            g.GoldPilotDB = g.GoldPilotCharDB = None
            try:
                test(g.new_addon(lua.table_from(sources)), mock)
                print("ok   " + name)
            except Exception as err:
                failures += 1
                print("FALLA " + name + ": " + str(err), file=sys.stderr)
    if failures:
        return 1
    print("OK: Lua, TOC, idiomas, globales y pruebas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
