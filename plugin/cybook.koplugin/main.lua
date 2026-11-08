-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Cybook plugin: Home-button Quick Menu and Home-as-Back in reader mode,
-- USB mass storage, ADB, stock reader, and performance tuning. The
-- /mnt/app/boordr shim reads /tmp/cybook-mode after KOReader exits.

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

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

local function home_menu_enabled()
    local v = G_reader_settings:readSetting("cybook_home_quickmenu")
    return v == nil or v == true
end

local CybookFrontLightWidget

local function clamp(value, min_value, max_value)
    if value < min_value then return min_value end
    if value > max_value then return max_value end
    return value
end

local function get_frontlight_widget_class()
    if CybookFrontLightWidget then return CybookFrontLightWidget end

    local Base = require("ui/widget/frontlightwidget")
    local FL = Base:extend{}

    function FL:level_to_intensity(level)
        local span = self.fl.max - self.fl.min
        return math.floor(self.fl.min + span * level / 10)
    end

    function FL:intensity_to_level(value)
        local span = self.fl.max - self.fl.min
        if span <= 0 or value <= self.fl.min then return 0 end
        return clamp(math.floor((value - self.fl.min) * 10 / span + 0.5), 1, 10)
    end

    function FL:refresh_state()
        self.powerd:updateResumeFrontlightState()
        self.fl.cur = self.powerd:frontlightIntensity()
        self:updateBrightnessWidgets()
        self:update()
    end

    function FL:set_level(level)
        level = clamp(level, 1, 10)
        self.powerd:setIntensity(self:level_to_intensity(level))
        self:refresh_state()
    end

    function FL:set_minimum()
        self.powerd:setIntensity(self.fl.min + 1)
        self:refresh_state()
    end

    function FL:toggle_off_on()
        if self.powerd:isFrontlightOn() then
            self.powerd:turnOffFrontlight()
        else
            if not self.powerd:turnOnFrontlight() then
                self.powerd:setIntensity(self:level_to_intensity(1))
            end
        end
        self:refresh_state()
    end

    function FL:change_level(delta)
        local cur = self.powerd:frontlightIntensity()
        if cur <= self.fl.min then
            if delta > 0 then self:set_level(1) end
            return
        end
        if cur <= self.fl.min + 1 then
            if delta > 0 then self:set_level(1) end
            return
        end
        local level = self:intensity_to_level(cur)
        if delta < 0 and level <= 1 then
            self:set_minimum()
        else
            self:set_level(level + delta)
        end
    end

    function FL:setFrontLightIntensity(intensity)
        if intensity <= self.fl.min then
            if self.powerd:isFrontlightOn() then
                self.powerd:turnOffFrontlight()
            end
        else
            local span = self.fl.max - self.fl.min
            local level = clamp(math.floor((intensity - self.fl.min) * 10 / span + 0.5), 1, 10)
            self.powerd:setIntensity(self:level_to_intensity(level))
        end
        self.powerd:updateResumeFrontlightState()
        self.fl.cur = self.powerd:frontlightIntensity()
    end

    function FL:updateBrightnessWidgets()
        Base.updateBrightnessWidgets(self)
        local cur = self.powerd:frontlightIntensity()
        local label
        if cur <= self.fl.min then
            label = _("Off")
        elseif cur <= self.fl.min + 1 then
            label = _("Min")
        else
            label = T(_("%1/10"), self:intensity_to_level(cur))
        end
        self.fl_level:setText(label)
        if cur <= self.fl.min + 1 then
            self.fl_minus:disable()
        else
            self.fl_minus:enable()
        end
        local toggle = self.layout[2] and self.layout[2][2]
        if toggle then
            toggle:setText(cur > self.fl.min and _("Off") or _("On"), toggle.width)
        end
    end

    function FL:setup_cybook_controls()
        -- FocusManager drops the default Home binding on devices without a D-pad.
        self.key_events.Home = { { "Home" } }
        self.key_events.BrightnessDown = { { Device.input.group.PgBack } }
        self.key_events.BrightnessUp = { { Device.input.group.PgFwd } }

        local span = self.fl.max - self.fl.min
        local ticks = {}
        for i = 1, 9 do
            ticks[i] = math.floor(self.fl.min + span * i / 10)
        end
        self.fl_progress.ticks = ticks

        local fl_buttons = self.layout[1]
        if fl_buttons then
            fl_buttons[1].callback = function() self:change_level(-1) end
            fl_buttons[2].callback = function() self:change_level(1) end
        end
        local extrema = self.layout[2]
        if extrema then
            extrema[1].callback = function() self:set_minimum() end
            extrema[2].callback = function() self:toggle_off_on() end
            extrema[3].callback = function() self:set_level(10) end
        end

        self:updateBrightnessWidgets()
    end

    function FL:init()
        Base.init(self)
        self:setup_cybook_controls()
    end

    function FL:onHome()
        self:onClose()
        return true
    end

    function FL:onBrightnessDown()
        self:change_level(-1)
        return true
    end

    function FL:onBrightnessUp()
        self:change_level(1)
        return true
    end

    function FL:onClose()
        if self.cybook_on_close then
            self.cybook_on_close()
        end
        return Base.onClose(self)
    end

    CybookFrontLightWidget = FL
    return FL
end

function Cybook:close_home_menu()
    local qm = self.home_menu
    self.home_menu = nil
    if qm and UIManager:isWidgetShown(qm) then
        UIManager:close(qm)
    end
end

function Cybook:close_brightness_menu()
    local bm = self.brightness_menu
    self.brightness_menu = nil
    if bm and UIManager:isWidgetShown(bm) then
        UIManager:close(bm)
    end
end

function Cybook:run_action(key)
    self:close_home_menu()
    self:close_brightness_menu()
    local ok, err = pcall(function()
        Dispatcher:init()
        Dispatcher:execute({ [key] = true })
    end)
    if not ok then
        logger.warn("cybook: quick menu action failed", key, err)
    end
end

function Cybook:show_brightness_menu()
    self:close_home_menu()
    self:close_brightness_menu()

    local FL = get_frontlight_widget_class()
    local widget = FL:new{
        cybook_on_close = function()
            self.brightness_menu = nil
        end,
    }
    self.brightness_menu = widget
    UIManager:show(widget)
end

function Cybook:show_home_quickmenu(readerui)
    self:close_home_menu()
    self:close_brightness_menu()
    local buttons = {
        {
            {
                text = _("Frontlight"),
                callback = function()
                    self:show_brightness_menu()
                end,
            },
            {
                text = _("Night mode"),
                callback = function() self:run_action("night_mode") end,
            },
        },
        {
            {
                text = _("Table of contents"),
                callback = function() self:run_action("toc") end,
            },
            {
                text = _("Rotate"),
                callback = function() self:run_action("toggle_rotation") end,
            },
        },
        {
            {
                text = _("Full refresh"),
                callback = function() self:run_action("full_refresh") end,
            },
            {
                text = _("Dictionary"),
                callback = function() self:run_action("dictionary_lookup") end,
            },
        },
        {
            {
                text = _("File browser"),
                callback = function()
                    self:close_home_menu()
                    local ReaderUI = require("apps/reader/readerui")
                    local orig = ReaderUI._cybook_original_on_home
                    if orig and readerui then
                        orig(readerui)
                    else
                        UIManager:show(InfoMessage:new{ text = _("File browser is unavailable.") })
                    end
                end,
            },
        },
    }

    local qm
    qm = ButtonDialog:new{
        title = _("Quick Menu"),
        buttons = buttons,
        width_factor = 0.85,
        shrink_unneeded_width = true,
        use_info_style = false,
        tap_close_callback = function() self.home_menu = nil end,
    }
    -- FocusManager drops the default Home binding on devices without a D-pad.
    qm.key_events.Home = { { "Home" } }
    qm.onHome = function()
        self.home_menu = nil
        UIManager:close(qm)
        return true
    end
    self.home_menu = qm
    UIManager:show(qm)
end

function Cybook:on_home(readerui)
    if not home_menu_enabled() then return false end
    if not readerui or not readerui.document or readerui.tearing_down then return false end
    if self.home_menu and UIManager:isWidgetShown(self.home_menu) then
        self:close_home_menu()
        return true
    end
    if self.brightness_menu and UIManager:isWidgetShown(self.brightness_menu) then
        self:close_brightness_menu()
        return true
    end
    self:show_home_quickmenu(readerui)
    return true
end

local BACK_METHODS = {
    "onCloseDialog",
    "onCloseWithKey",
    "onCloseWithKeys",
    "onBack",
    "onClose",
    "onAnyKeyPressed",
}

local function find_back_target(widget, depth)
    if not widget or type(widget) ~= "table" or depth > 5 then return nil end
    for _, method in ipairs(BACK_METHODS) do
        if type(widget[method]) == "function" then return widget end
    end
    for i = 1, #widget do
        local found = find_back_target(widget[i], depth + 1)
        if found then return found end
    end
    return nil
end

local function get_back_window()
    if not UIManager.getTopmostVisibleWidget then return nil end
    local top = UIManager:getTopmostVisibleWidget()
    if not top or not top.toast then return top end
    if UIManager._window_stack then
        for i = #UIManager._window_stack, 1, -1 do
            local widget = UIManager._window_stack[i].widget
            if not widget.invisible and not widget.toast then
                return widget
            end
        end
    end
    return nil
end

function Cybook:back_out_widget(top)
    local target = find_back_target(top, 0) or top
    if target.name == "ScreenSaver" or target.name == "ScreenSaverLock" then
        return false
    end

    for _, method in ipairs(BACK_METHODS) do
        if type(target[method]) == "function" then
            local ok, err = pcall(target[method], target)
            if ok then return true end
            logger.warn("cybook: Home back failed", method, err)
        end
    end

    local ok, err = pcall(UIManager.close, UIManager, top)
    if not ok then
        logger.warn("cybook: Home close failed", err)
    end
    return true
end

function Cybook:handle_home_key()
    local top = get_back_window()
    if not top or top == self.ui then return false end
    return self:back_out_widget(top)
end

function Cybook:install_home_back_hook()
    if UIManager._cybook_home_back_hooked then return end
    if not UIManager.handleInputEvent then return end
    UIManager._cybook_home_back_hooked = true
    local original_handle_input = UIManager.handleInputEvent
    function UIManager:handleInputEvent(input_event)
        if input_event and input_event.handler == "onKeyPress"
                and input_event.args and input_event.args[1] then
            local key = input_event.args[1]
            if type(key) == "table" and key.key == "Home" then
                -- Use the require cache to avoid loading the file manager from
                -- inside its own plugin init.
                local ReaderUI = package.loaded["apps/reader/readerui"]
                local ui = ReaderUI and ReaderUI.instance
                if not ui or ui.tearing_down then
                    local FileManager = package.loaded["apps/filemanager/filemanager"]
                    ui = FileManager and FileManager.instance
                end
                local plugin = ui and ui.cybook_plugin
                if plugin then
                    local ok, handled = pcall(plugin.handle_home_key, plugin)
                    if ok and handled then return end
                    if not ok then
                        logger.warn("cybook: Home back hook failed", handled)
                    end
                end
            end
        end
        return original_handle_input(self, input_event)
    end
end

function Cybook:install_home_hook()
    local ReaderUI = require("apps/reader/readerui")
    if ReaderUI._cybook_home_hooked then return end
    ReaderUI._cybook_original_on_home = ReaderUI.onHome
    ReaderUI._cybook_home_hooked = true
    function ReaderUI:onHome()
        local plugin = self.cybook_plugin
        if plugin then
            local ok, handled = pcall(plugin.on_home, plugin, self)
            if ok and handled then return true end
            if not ok then
                logger.warn("cybook: Home Quick Menu failed", handled)
            end
        end
        return ReaderUI._cybook_original_on_home(self)
    end
end

function Cybook:init()
    self.ui.cybook_plugin = self
    self.ui.menu:registerToMainMenu(self)
    self:apply_saved_performance()
    self:install_home_hook()
    self:install_home_back_hook()
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

function Cybook:add_home_menu(menu_items)
    menu_items.cybook_home = {
        text = _("Cybook: Home button"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Home opens Quick Menu"),
                checked_func = home_menu_enabled,
                callback = function()
                    G_reader_settings:saveSetting("cybook_home_quickmenu", not home_menu_enabled())
                end,
            },
            {
                text = _("Preview Quick Menu"),
                callback = function()
                    if self.ui.document then
                        self:show_home_quickmenu(self.ui)
                    else
                        UIManager:show(InfoMessage:new{ text = _("Open a book first.") })
                    end
                end,
            },
        },
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
    self:add_home_menu(menu_items)
end

return Cybook
