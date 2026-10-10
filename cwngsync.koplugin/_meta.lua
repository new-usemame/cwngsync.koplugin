-- Renamed from the legacy cwasync.koplugin bundled by Calibre-Web NextGen.

-- Plugin translations must be in place before fullname/description below.
pcall(function()
    local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
    package.loaded["cwng_l10n"] = package.loaded["cwng_l10n"] or dofile(dir .. "cwng_l10n.lua")
end)

local _ = require("gettext")
return {
    name = "cwngsync",
    fullname = _("NextGen Progress Sync"),
    description = _([[Synchronizes your reading progress to Calibre-Web NextGen and across your KOReader devices.]]),
    version = "4.1.46",  -- Updates Manager reads this; keep in lockstep with main.lua and the CWNG release tag
}
