-- Plugin-local translations from l10n/<lang>/cwngsync.po are merged into
-- KOReader's gettext tables, so the existing _() and N_() calls pick them up.

package.path = table.concat({
    "./?.lua",
    "../?.lua",
    package.path,
}, ";")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nexpected: %s\nactual: %s",
            message, tostring(expected), tostring(actual)), 2)
    end
end

-- Just enough of KOReader's frontend/gettext.lua: plain strings live in
-- translation[msgid], plural forms in translation[msgid][0..n].
local function fakeGetText(lang)
    local G = {
        translation = { Cancel = "core translation" },
        context = {},
        current_lang = lang,
    }
    G.getPlural = function(n)
        if n == 1 then return 0 elseif n >= 2 and n <= 4 then return 1 end
        return 2
    end
    G.ngettext = function(msgid, msgid_plural, n)
        local t = G.translation[msgid]
        if t then return t[G.getPlural(n)] end
        return n == 1 and msgid or msgid_plural
    end
    return setmetatable(G, { __call = function(g, msgid)
        local t = g.translation[msgid]
        if type(t) == "table" then return t[0] end
        return t or msgid
    end })
end

local function load(lang)
    local G = fakeGetText(lang)
    package.loaded["gettext"] = G
    package.loaded["cwng_l10n"] = nil
    local L10n = require("cwng_l10n")
    return G, L10n
end

do
    local G = load("sk")
    assertEqual(G("Sync now"), "Synchronizovať teraz", "Slovak string is translated")
    assertEqual(G("Cancel"), "core translation", "KOReader's own translation wins")
    assertEqual(G.ngettext("1 book", "%1 books", 1), "%1 kniha", "Slovak plural, one")
    assertEqual(G.ngettext("1 book", "%1 books", 3), "%1 knihy", "Slovak plural, few")
    assertEqual(G.ngettext("1 book", "%1 books", 8), "%1 kníh", "Slovak plural, many")
    assertEqual(G("Downloading %1…"), "Sťahujem %1…", "UTF-8 survives")
    assertEqual(G("Could not download %1.\n\n%2"), "%1 sa nepodarilo stiahnuť.\n\n%2",
        "escaped newlines are unescaped")
end

do
    local G = load("cs_CZ")
    assertEqual(G("Sync now"), "Synchronizovat nyní", "region falls back to the base language")
end

do
    local G, L10n = load("de")
    assertEqual(G("Sync now"), "Sync now", "missing language stays English")
    assertEqual(L10n.install(), false, "nothing to install for a missing language")
end

do
    local G, L10n = load("sk")
    assertEqual(L10n.install(), false, "installing twice is a no-op")
end

do
    package.loaded["gettext"] = function(text) return text end
    package.loaded["cwng_l10n"] = nil
    local L10n = require("cwng_l10n")
    assertEqual(L10n.install(), false, "a stubbed gettext is left alone")
end

-- Every translation keeps the msgid's %1/%2 placeholders.
local function placeholders(s)
    local seen = {}
    for p in s:gmatch("%%%d") do seen[p] = true end
    local list = {}
    for p in pairs(seen) do table.insert(list, p) end
    table.sort(list)
    return table.concat(list, ",")
end

local L10n = require("cwng_l10n")
for _, lang in ipairs({ "sk", "cs" }) do
    local f = assert(io.open("../l10n/" .. lang .. "/cwngsync.po", "r")
        or io.open("l10n/" .. lang .. "/cwngsync.po", "r"))
    local entries = L10n.parse(f:read("*a"))
    f:close()
    for _, e in ipairs(entries) do
        if e.id_plural then
            for i = 0, 2 do
                assertEqual(placeholders(e.strs[i] or ""), placeholders(e.id_plural),
                    lang .. " plural form " .. i .. " of " .. e.id)
            end
        else
            assertEqual(placeholders(e.str or ""), placeholders(e.id), lang .. ": " .. e.id)
        end
    end
end

print("cwng_l10n_test: ok")
