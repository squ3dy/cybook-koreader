-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Cybook menu: USB mass storage, ADB, stock reader, and performance tuning.
-- The /mnt/app/boordr shim reads /tmp/cybook-mode after KOReader exits.

local ConfirmBox = require("ui/widget/confirmbox")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local CPU_GOV = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
local CPU_AVAIL = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"
local CPU_CUR = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
local CPU_MIN = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
local CPU_MAX = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"

local Cybook = WidgetContainer:extend{
    name = "cybook",
    is_doc_only = false,
}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function first_line(path)
    local s = read_file(path)
    if not s then return nil end
    return s:match("^([^\r\n]*)")
end

local function write_file(path, value)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(value)
    f:close()
    return true
end

local function words(path)
    local out = {}
    local s = first_line(path)
    if not s then return out end
    for w in s:gmatch("%S+") do
        table.insert(out, w)
    end
    return out
end

local function nand_paths(suffix)
    local out = {}
    local p = io.popen([[for f in /sys/block/nand*/queue/]] .. suffix .. [[; do [ -e "$f" ] && echo "$f"; done 2>/dev/null]])
    if not p then return out end
    for line in p:lines() do
        if line ~= "" then table.insert(out, line) end
    end
    p:close()
    return out
end

local function current_scheduler()
    local paths = nand_paths("scheduler")
    if #paths == 0 then return nil end
    local s = first_line(paths[1])
    if not s then return nil end
    return s:match("%[([^%]]+)%]") or s:match("^(%S+)")
end

local function available_schedulers()
    local paths = nand_paths("scheduler")
    if #paths == 0 then return {} end
    local s = first_line(paths[1])
    if not s then return {} end
    local out = {}
    for w in s:gmatch("%S+") do
        w = w:gsub("[%[%]]", "")
        table.insert(out, w)
    end
    return out
end

local function current_read_ahead()
    local paths = nand_paths("read_ahead_kb")
    if #paths == 0 then return nil end
    return tonumber(first_line(paths[1]))
end

local function coverbrowser_disabled()
    local pd = G_reader_settings:readSetting("plugins_disabled")
    if type(pd) ~= "table" then return false end
    return pd["coverbrowser"] == true
end

local function set_coverbrowser(disabled)
    local pd = G_reader_settings:readSetting("plugins_disabled")
    if type(pd) ~= "table" then pd = {} end
    if disabled then
        pd["coverbrowser"] = true
    else
        pd["coverbrowser"] = nil
    end
    G_reader_settings:saveSetting("plugins_disabled", pd)
end

function Cybook:apply_saved_performance()
    local gov = G_reader_settings:readSetting("cybook_cpu_governor")
    if gov and read_file(CPU_GOV) ~= gov then
        write_file(CPU_GOV, gov)
    end

    local sched = G_reader_settings:readSetting("cybook_io_scheduler")
    if sched then
        for _, p in ipairs(nand_paths("scheduler")) do
            write_file(p, sched)
        end
    end

    local ra = G_reader_settings:readSetting("cybook_read_ahead_kb")
    if ra then
        for _, p in ipairs(nand_paths("read_ahead_kb")) do
            write_file(p, tostring(ra))
        end
    end
end

function Cybook:init()
    self.ui.menu:registerToMainMenu(self)
    self:apply_saved_performance()
end

local function request(mode, warning)
    UIManager:show(ConfirmBox:new{
        text = warning,
        ok_text = _("Continue"),
        ok_callback = function()
            local f = io.open("/tmp/cybook-mode", "w")
            if not f then
                UIManager:show(InfoMessage:new{ text = _("Could not write /tmp/cybook-mode.") })
                return
            end
            f:write(mode)
            f:close()
            UIManager:scheduleIn(4, function() UIManager:broadcastEvent(Event:new("Exit")) end)
        end,
    })
end

function Cybook:status_text()
    local lines = {}

    local gov = first_line(CPU_GOV) or "not available"
    local cur = tonumber(first_line(CPU_CUR))
    local min = tonumber(first_line(CPU_MIN))
    local max = tonumber(first_line(CPU_MAX))
    local freq = cur and string.format("%.0f MHz", cur / 1000) or "?"
    local range = (min and max) and string.format("%.0f–%.0f MHz", min / 1000, max / 1000) or "?"
    table.insert(lines, string.format("CPU: %s, %s (%s)", gov, freq, range))

    local sched = current_scheduler() or "not available"
    local ra = current_read_ahead()
    table.insert(lines, string.format("I/O: %s, read-ahead %s KB", sched, ra and tostring(ra) or "?"))

    local mem = read_file("/proc/meminfo") or ""
    local function mb(key)
        local kb = tonumber(mem:match(key .. ":%s*(%d+)"))
        return kb and string.format("%.0f MB", kb / 1024) or "?"
    end
    table.insert(lines, string.format("RAM: free %s of %s, cached %s",
        mb("MemFree"), mb("MemTotal"), mb("Cached")))
    local swap = tonumber(mem:match("SwapTotal:%s*(%d+)")) or 0
    table.insert(lines, "Swap: " .. (swap > 0 and mb("SwapTotal") or "none"))

    local zram = io.popen("ls /sys/block 2>/dev/null | grep '^zram' | tr '\\n' ' '")
    local z = zram and zram:read("*a") or ""
    if zram then zram:close() end
    table.insert(lines, "zram: " .. (z ~= "" and z:gsub("%s+$", "") or "none"))

    table.insert(lines, "Cover browser: " .. (coverbrowser_disabled() and "disabled" or "enabled"))
    table.insert(lines, "KOReader: " .. (first_line("/mnt/fat/koreader/git-rev") or "unknown"))
    table.insert(lines, "Load: " .. (first_line("/proc/loadavg") or "?"))

    return table.concat(lines, "\n")
end

function Cybook:set_governor(gov)
    local function apply()
        if write_file(CPU_GOV, gov) then
            G_reader_settings:saveSetting("cybook_cpu_governor", gov)
            UIManager:show(InfoMessage:new{ text = string.format(_("CPU governor set to %s."), gov) })
        else
            UIManager:show(InfoMessage:new{ text = _("Could not write the CPU governor.") })
        end
    end
    if gov == "performance" then
        UIManager:show(ConfirmBox:new{
            text = _("Keep the CPU at maximum frequency? This makes the UI snappier but increases battery drain and heat."),
            ok_text = _("Use performance"),
            ok_callback = apply,
        })
    else
        apply()
    end
end

function Cybook:set_scheduler(sched)
    local paths = nand_paths("scheduler")
    local ok = false
    for _, p in ipairs(paths) do
        if write_file(p, sched) then ok = true end
    end
    if ok then
        G_reader_settings:saveSetting("cybook_io_scheduler", sched)
        UIManager:show(InfoMessage:new{ text = string.format(_("I/O scheduler set to %s."), sched) })
    else
        UIManager:show(InfoMessage:new{ text = _("Could not write the I/O scheduler.") })
    end
end

function Cybook:set_read_ahead(kb)
    local paths = nand_paths("read_ahead_kb")
    local ok = false
    for _, p in ipairs(paths) do
        if write_file(p, tostring(kb)) then ok = true end
    end
    if ok then
        G_reader_settings:saveSetting("cybook_read_ahead_kb", kb)
        UIManager:show(InfoMessage:new{ text = string.format(_("Read-ahead set to %s KB."), tostring(kb)) })
    else
        UIManager:show(InfoMessage:new{ text = _("Could not write the read-ahead setting.") })
    end
end

function Cybook:add_performance_menu(menu_items)
    local items = {
        {
            text = _("Performance status"),
            callback = function()
                UIManager:show(InfoMessage:new{ text = self:status_text() })
            end,
        },
    }

    local governors = words(CPU_AVAIL)
    if #governors > 0 then
        local sub = {}
        for _, gov in ipairs(governors) do
            table.insert(sub, {
                text = gov,
                checked_func = function() return first_line(CPU_GOV) == gov end,
                callback = function() self:set_governor(gov) end,
            })
        end
        table.insert(items, { text = _("CPU governor"), sub_item_table = sub })
    end

    local scheds = available_schedulers()
    if #scheds > 0 then
        local sub = {}
        for _, sched in ipairs(scheds) do
            table.insert(sub, {
                text = sched,
                checked_func = function() return current_scheduler() == sched end,
                callback = function() self:set_scheduler(sched) end,
            })
        end
        table.insert(items, { text = _("I/O scheduler (NAND)"), sub_item_table = sub })
    end

    if #nand_paths("read_ahead_kb") > 0 then
        local sub = {}
        for _, kb in ipairs({ 128, 256, 512, 1024 }) do
            table.insert(sub, {
                text = string.format("%d KB", kb),
                checked_func = function() return current_read_ahead() == kb end,
                callback = function() self:set_read_ahead(kb) end,
            })
        end
        table.insert(items, { text = _("Read-ahead (NAND)"), sub_item_table = sub })
    end

    table.insert(items, {
        text_func = function()
            return coverbrowser_disabled() and _("Enable Cover Browser (slower)") or _("Disable Cover Browser (faster)")
        end,
        callback = function()
            if coverbrowser_disabled() then
                set_coverbrowser(false)
                UIManager:show(InfoMessage:new{ text = _("Cover Browser enabled. Restart KOReader to apply.") })
            else
                UIManager:show(ConfirmBox:new{
                    text = _("Disable Cover Browser? Covers disappear from the file browser, but it uses less RAM and CPU on this device."),
                    ok_text = _("Disable"),
                    ok_callback = function()
                        set_coverbrowser(true)
                        UIManager:show(InfoMessage:new{ text = _("Cover Browser disabled. Restart KOReader to apply.") })
                    end,
                })
            end
        end,
    })

    table.insert(items, {
        text = _("Apply fast UI profile"),
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Apply the fast UI profile? It enables smaller panning, avoids UI flashes, disables swipe animations, and starts with the last book."),
                ok_text = _("Apply"),
                ok_callback = function()
                    G_reader_settings:saveSetting("low_pan_rate", true)
                    G_reader_settings:saveSetting("avoid_flashing_ui", true)
                    G_reader_settings:saveSetting("swipe_animations", false)
                    G_reader_settings:saveSetting("start_with", "last")
                    UIManager:show(InfoMessage:new{ text = _("Fast UI profile applied. Restart KOReader to apply the panning change.") })
                end,
            })
        end,
    })

    menu_items.cybook_perf = {
        text = _("Cybook: performance"),
        sorting_hint = "more_tools",
        sub_item_table = items,
    }
end

function Cybook:addToMainMenu(menu_items)
    menu_items.cybook = {
        text = _("Cybook: USB, ADB, stock reader"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("USB mode (mass storage)"),
                callback = function()
                    request("usb", _("KOReader will close and the reader becomes a USB drive. Connect the cable; when you eject it from the PC and unplug it, KOReader comes back. Eject from the PC first. Continue?"))
                end,
            },
            {
                text = _("Enable ADB"),
                callback = function()
                    request("adb", _("KOReader will close and ADB is enabled. When you unplug the cable, KOReader comes back. Continue?"))
                end,
            },
            {
                text = _("Back to the stock reader"),
                callback = function()
                    request("stock", _("KOReader will close and the stock reader takes over. KOReader stays disabled until you delete koreader/.disabled. Continue?"))
                end,
            },
        },
    }
    self:add_performance_menu(menu_items)
end

return Cybook
