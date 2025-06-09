input = input or {}

local binds = {}

if !KEY_0 then
    include("enums/buttons.lua")
end

local keynames = {
    [KEY_0] = "0", [KEY_1] = "1", [KEY_2] = "2", [KEY_3] = "3", [KEY_4] = "4", [KEY_5] = "5",
    [KEY_6] = "6", [KEY_7] = "7", [KEY_8] = "8", [KEY_9] = "9",

    [KEY_A] = "A", [KEY_B] = "B", [KEY_C] = "C", [KEY_D] = "D", [KEY_E] = "E", [KEY_F] = "F", [KEY_G] = "G",
    [KEY_H] = "H", [KEY_I] = "I", [KEY_J] = "J", [KEY_K] = "K", [KEY_L] = "L", [KEY_M] = "M", [KEY_N] = "N",
    [KEY_O] = "O", [KEY_P] = "P", [KEY_Q] = "Q", [KEY_R] = "R", [KEY_S] = "S", [KEY_T] = "T", [KEY_U] = "U",
    [KEY_V] = "V", [KEY_W] = "W", [KEY_X] = "X", [KEY_Y] = "Y", [KEY_Z] = "Z",

    [KEY_F1] = "F1", [KEY_F2] = "F2", [KEY_F3] = "F3", [KEY_F4] = "F4", [KEY_F5] = "F5", [KEY_F6] = "F6", [KEY_F7] = "F7",
    [KEY_F8] = "F8", [KEY_F9] = "F9", [KEY_F10] = "F10", [KEY_F11] = "F11", [KEY_F12] = "F12",

    [KEY_PAD_0] = "KP_INS", [KEY_PAD_1] = "KP_END", [KEY_PAD_2] = "KP_DOWNARROW", [KEY_PAD_3] = "KP_PGDN", [KEY_PAD_4] = "KP_LEFTARROW",
    [KEY_PAD_5] = "KP_5", [KEY_PAD_6] = "KP_RIGHTARROW", [KEY_PAD_7] = "KP_HOME", [KEY_PAD_8] = "KP_UPARROW", [KEY_PAD_9] = "KP_PGUP",
    [KEY_PAD_DIVIDE] = "-", [KEY_PAD_MULTIPLY] = "KP_MULTIPLY", [KEY_PAD_MINUS] = "KP_MINUS", [KEY_PAD_PLUS] = "KP_PLUS",
    [KEY_PAD_ENTER] = "KP_ENTER", [KEY_PAD_DECIMAL] = "KP_DEL",

    [KEY_ENTER] = "ENTER", [KEY_SPACE] = "SPACE", [KEY_BACKSPACE] = "BACKSPACE", [KEY_TAB] = "TAB",
    [KEY_CAPSLOCK] = "CAPSLOCK", [KEY_NUMLOCK] = "NUMLOCK", [KEY_SCROLLLOCK] = "SCROLLLOCK", [KEY_SCROLLLOCKTOGGLE] = "SCROLLLOCKTOGGLE",
    [KEY_NUMLOCKTOGGLE] = "NUMLOCKTOGGLE",

    [KEY_ESCAPE] = "ESCAPE", [KEY_INSERT] = "INSERT", [KEY_DELETE] = "DELETE", [KEY_HOME] = "HOME", [KEY_END] = "END",
    [KEY_PAGEUP] = "PGUP", [KEY_PAGEDOWN] = "PGDN", [KEY_BREAK] = "NUMLOCK",

    [KEY_LSHIFT] = "SHIFT", [KEY_RSHIFT] = "RSHIFT", [KEY_LALT] = "ALT", [KEY_RALT] = "RALT", [KEY_LCONTROL] = "CTRL", [KEY_RCONTROL] = "RCTRL",
    [KEY_LWIN] = "LWIN", [KEY_RWIN] = "RWIN", [KEY_APP] = "RCTRL",

    [KEY_UP] = "UPARROW", [KEY_LEFT] = "LEFTARROW", [KEY_DOWN] = "DOWNARROW", [KEY_RIGHT] = "RIGHTARROW",
    [KEY_COMMA] = ",", [KEY_PERIOD] = ".", [KEY_MINUS] = "-", [KEY_BACKSLASH] = "\\", [KEY_LBRACKET] = "[", [KEY_RBRACKET] = "]",
    [KEY_SEMICOLON] = "SEMICOLON", [KEY_APOSTROPHE] = "'", [KEY_SLASH] = "/", [KEY_EQUAL] = "=",

    [MOUSE_LEFT] = "MOUSE1", [MOUSE_RIGHT] = "MOUSE2", [MOUSE_MIDDLE] = "MOUSE3", [MOUSE_4] = "MOUSE4", [MOUSE_5] = "MOUSE5",
    [MOUSE_WHEEL_UP] = "MWHEELUP", [MOUSE_WHEEL_DOWN] = "MWHEELDOWN"
}

function input.LookupKeyBinding(key)
    if !isnumber(key) then error("bad argument #1 to 'LookupKeyBinding' (number expected, got " .. type(key) .. ")") end

    return binds[key]
end

concommand.Add("bind", function(ply, cmd, args)
    local key = args[1]

    if !key or #args > 2 then
        print("bind <key> [command] : attach a command to a key")
        return
    end

    local keys = {} // we do it this way because multiple keys may map to one bind (e.g. "-")

    for k,v in pairs(keynames) do
        if v == string.upper(key) then
            table.insert(keys, k)
        end
    end

    local key_valid = #keys > 0

    if !key_valid then
        print("\"" .. key .. "\" isn't a valid key")
        return
    end

    if !args[2] then
        local bind

        for k,v in pairs(keys) do
            if binds[v] then
               bind = binds[v]
               break
            end
        end

        if !bind then
            print("\"" .. key .. "\" is not bound")
            return
        end

        print("\"" .. key .. "\" = \"" .. bind .. "\"")
        return
    end

    for k,v in pairs(keys) do
        binds[v] = args[2]
    end
end, nil, "Bind a key.")

concommand.Add("unbind", function(ply, cmd, args)
    local key = args[1]

    if !key or #args > 1 then
        print("unbind <key> : remove commands from a key")
        return
    end

    local keys = {}

    for k,v in pairs(keynames) do
        if v == string.upper(key) then
            table.insert(keys, k)
        end
    end

    local key_valid = #keys > 0

    if !key_valid then
        print("\"" .. key .. "\" isn't a valid key")
        return
    end

    for k,v in pairs(keys) do
        binds[v] = ""
    end
end, nil, "Unbind a key.")

concommand.Add("unbindall", function(ply, cmd, args)
    for k, v in pairs(binds) do
       binds[k] = ""
    end
end, nil, "Unbind all keys.")


hook.Add( "PlayerButtonDown", "binds_button_down", function(ply, button)
    local bind = binds[button]
    if !bind then return end

    game.ConsoleCommand(bind .. "\n")
end)

hook.Add( "PlayerButtonUp", "binds_button_up", function(ply, button)
    local bind = binds[button]
    if !bind then return end
    if string.sub(bind, 1, 1) != "+" then return end

    game.ConsoleCommand("-" .. string.sub(bind, 2) .. "\n")
end)

concommand.Add("host_writeconfig", function(ply, cmd, args)
    if #args > 1 then
        print("Usage:  writeconfig <filename.cfg>")
        return
    end

    local base = file.GetPath("MOD")
    if !base then
       print("Host_WriteConfiguration: filesystem error")
       return
    end

    file.CreateDir(base .. "cfg", "ROOT")

    if !file.IsDir("cfg", "MOD") then
       print("Host_WriteConfiguration: filesystem error")
       return
    end

    local f = args[1]
    if !f then f = "config.cfg" end

    if string.find(f, "..", 1, true) then
        f = string.Replace(f, ".", "")
    end

    f = string.Replace(f, "/", "")
    f = string.Replace(f, "\\", "")

    if string.sub(f, -4) != ".cfg" then
       f = f .. ".cfg"
    end

    local b = {}
    for k, v in pairs(binds) do // de-dupe first
        local key = keynames[k]
        if !key then continue end

        b[key] = v
    end

    local bindsstr = ""
    for k, v in pairs(b) do
       bindsstr = bindsstr .. "bind \"" .. string.lower(k) .. "\" \"" .. v .. "\"\n"
    end

    file.Write(base .. "cfg/" .. f, bindsstr, "ROOT")
    print("Host_WriteConfiguration: Wrote cfg/" .. f)

end, nil, "Store current settings to config.cfg (or specified .cfg file).")

// load config.cfg
local cfg = file.Read("cfg/config.cfg", "MOD")

if cfg and game and game.ConsoleCommand then
    game.ConsoleCommand(cfg)
end
