-- Speshell's login screen: a bare Hyprland that runs greeter.qml and exits with it,
-- once it has started the session. speshell-greeter starts it for greetd.
--
-- The keyboard follows localectl's X11 layout, so passwords type as in the session.
-- /etc/speshell/greeter.lua, when present, runs last: monitors, input, or any other
-- Hyprland setting for the login screen.
local app = os.getenv("SPESHELL_QML_DIR") or "/usr/share/speshell"

local keyboard = {}
local file = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf")
if file then
    for line in file:lines() do
        local key, value = line:match('Option%s+"Xkb(%a+)"%s+"([^"]*)"')
        if key then
            keyboard[key] = value
        end
    end
    file:close()
end

hl.config({
    input = {
        kb_layout = keyboard.Layout or "us",
        kb_variant = keyboard.Variant or "",
        kb_model = keyboard.Model or "",
        kb_options = keyboard.Options or "",
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

local overrides = io.open("/etc/speshell/greeter.lua")
if overrides then
    overrides:close()
    dofile("/etc/speshell/greeter.lua")
end

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p '" .. app .. "/greeter.qml'; hyprctl dispatch 'hl.dsp.exit()'")
end)
