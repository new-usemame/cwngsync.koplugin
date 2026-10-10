--[[
Plugin-local translations.

KOReader's gettext only knows the strings in its own catalog, so this plugin's
strings stay in English whatever the UI language. This module reads
l10n/<lang>/cwngsync.po from the plugin folder and adds its entries to
KOReader's gettext tables, so every existing _() and N_() call picks them up.
Strings KOReader already translates are left alone.

Load it before any module evaluates _() at load time (_meta.lua, main.lua).
Loading it again is a no-op.
--]]

local GetText = require("gettext")

local M = {}

local loaded_lang

local function pluginDir()
    local source = debug.getinfo(1, "S").source or ""
    return source:match("^@(.*/)") or "./"
end

local function unescape(s)
    return (s:gsub("\\(.)", function(c)
        if c == "n" then return "\n" end
        if c == "t" then return "\t" end
        return c
    end))
end

-- Returns a list of entries { ctxt=, id=, id_plural=, str=, strs={[0]=..} }.
function M.parse(text)
    local entries = {}
    local entry, field, index

    local function flush()
        if entry and entry.id and entry.id ~= "" then
            table.insert(entries, entry)
        end
        entry, field, index = nil, nil, nil
    end

    local function append(value)
        if not entry or not field then return end
        if field == "strs" then
            entry.strs[index] = (entry.strs[index] or "") .. value
        else
            entry[field] = (entry[field] or "") .. value
        end
    end

    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local key, rest = line:match('^(msg%S+)%s+"(.*)"%s*$')
        if key then
            if key == "msgctxt" or (key == "msgid" and entry and (entry.str or next(entry.strs))) then
                flush()
            end
            entry = entry or { strs = {} }
            local n = key:match("^msgstr%[(%d+)%]$")
            if n then
                field, index = "strs", tonumber(n)
            elseif key == "msgctxt" then
                field = "ctxt"
            elseif key == "msgid" then
                field = "id"
            elseif key == "msgid_plural" then
                field = "id_plural"
            elseif key == "msgstr" then
                field = "str"
            else
                field = nil
            end
            append(unescape(rest))
        else
            local cont = line:match('^%s*"(.*)"%s*$')
            if cont then
                append(unescape(cont))
            elseif line:match("^%s*$") then
                flush()
            end
        end
    end
    flush()
    return entries
end

local function languageCandidates(lang)
    local list = { lang }
    local base = lang:match("^(%a+)[_%-]")
    if base then table.insert(list, base) end
    return list
end

local function readCatalog(lang)
    local dir = pluginDir()
    for _, code in ipairs(languageCandidates(lang)) do
        local f = io.open(dir .. "l10n/" .. code .. "/cwngsync.po", "r")
        if f then
            local text = f:read("*a")
            f:close()
            return text
        end
    end
end

function M.install()
    if type(GetText) ~= "table" or type(GetText.translation) ~= "table" then
        return false
    end
    local lang = GetText.current_lang
    if not lang or lang == "C" or lang == loaded_lang then
        return false
    end
    local text = readCatalog(lang)
    if not text then return false end

    local translation = GetText.translation
    GetText.context = GetText.context or {}
    for _, e in ipairs(M.parse(text)) do
        if e.id_plural then
            if next(e.strs) and (e.strs[0] or "") ~= "" and translation[e.id] == nil then
                translation[e.id] = e.strs
            end
        elseif e.str and e.str ~= "" then
            if e.ctxt then
                GetText.context[e.ctxt] = GetText.context[e.ctxt] or {}
                if GetText.context[e.ctxt][e.id] == nil then
                    GetText.context[e.ctxt][e.id] = e.str
                end
            elseif translation[e.id] == nil then
                translation[e.id] = e.str
            end
        end
    end
    loaded_lang = lang
    return true
end

pcall(M.install)

return M
