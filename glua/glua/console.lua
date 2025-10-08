console = console or {}
game = game or {}
local active = true

local commands = {}
local convars = {}
local alias = {}

function console.IsActive()
    return active
end

function AddConsoleCommand(name, helptext, flags)
    if !isstring(name) and !isnumber(name) then error("bad argument #1 to 'AddConsoleCommand' (string expected, got " .. type(name) .. ")") end
    if !isstring(name) then name = tostring(name) end
    name = string.lower(name)
    if !isstring(helptext) and !isnumber(helptext) and helptext != nil then error("bad argument #2 to 'AddConsoleCommand' (string expected, got " .. type(helptext) .. ")") end
    if isnumber(helptext) then helptext = tostring(helptext) end
    if !isnumber(flags) and !istable(flags) then flags = 0 end

    if commands[name] then return end

    commands[name] = {
        name = name,
        helptext = helptext,
        flags = flags
    }
end

include("../garrysmod/includes/modules/concommand.lua")   // have to re-run this now that we added our AddConsoleCommand

concommand.Add("help", function(ply, cmd, args, argstr)
    if #args != 1 then print("Usage:  help <cvarname>") return end

    local c = string.lower(args[1])
    if !commands[c] and !convars[c] then print("help:  no cvar or command named " .. args[1]) return end

    local cvar = convars[c]
    if cvar then
        local def = cvar.value != cvar.default and "( def. \"" .. cvar.default .."\" ) " or ""
        local min = cvar.min and "min. " .. cvar.min .. " " or ""
        local max = cvar.max and "max. " .. cvar.max .. " " or ""

        print("\"" .. c .. "\" = \"" .. cvar.value .. "\" " .. def .. min .. max)

        if cvar.helptext != "" then
            print(" - " .. cvar.helptext)
        end

        return
    end

    if commands[c] then
        print("\"" .. c .. "\"")

        if commands[c].helptext != "" then
            print(" - " .. commands[c].helptext)
        end

        return
    end

end, nil, "Find help about a convar/concommand.")

concommand.Add("find", function(ply, cmd, args, argstr)
    if #args < 1 then print("Usage:  find <string> [<string>...]") return end

    local cmds_found = {}

    for k, cmd in pairs(commands) do
        local found = true

        for _, str in pairs(args) do
            if !string.find(cmd.name, str) and !string.find(cmd.helptext, str) then
               found = false
               break
            end
        end

        if found then table.insert(cmds_found, cmd) end
    end

    for k, cmd in pairs(convars) do
        local found = true

        for _, str in pairs(args) do
            if !string.find(cmd.name, str) and !string.find(cmd.helptext, str) then
               found = false
               break
            end
        end

        if found then table.insert(cmds_found, cmd) end
    end

    table.SortByMember(cmds_found, "name", true)

    for k,v in pairs(cmds_found) do
        if !v.value then
            MsgN("\"", v.name, "\"")

            if v.helptext != "" then
                MsgN(" - ", v.helptext)
            end
        else
            local def = v.value != v.default and "( def. \"" .. v.default .."\" ) " or ""
            local min = v.min and "min. " .. v.min .. " "
            local max = v.max and "max. " .. v.max .. " "

            print("\"" .. v.name .. "\" = \"" .. v.value .. "\" " .. def .. min .. max)

            if v.helptext != "" then
                print(" - " .. v.helptext)
            end
        end
    end

end, nil, "Find concommands with the specified string in their name/help text.")

concommand.Add("alias", function(ply, cmd, args, argstr)
    if !args[1] then
        print("Current alias commands:")

        for k, v in pairs(alias) do
           MsgN(k, " : ", v)
        end
        return
    end

    local str = ""

    for i = 2, #args do
        if !args[i] then break end

        str = str .. " " .. args[i]
    end

    alias[args[1]] = str
end, nil, "Alias a command.")


local cm = {}   // convars mt
cm.__index = cm

function cm:GetFloat()
    return tonumber(self.value) or 0
end

function cm:GetInt()
    return math.floor(self:GetFloat())
end

function cm:GetBool()
    return self:GetInt() != 0
end

function cm:GetHelpText()
    return self.helptext
end

function cm:GetFlags()
    return self.flags
end

function cm:GetMax()
    return self.max
end

function cm:GetMin()
    return self.min
end

function cm:GetName()
    return self.name
end

function cm:GetDefault()
    return self.default
end

function cm:GetString()
    return self.value
end

function cm:IsFlagSet(flag)
    local flag = tonumber(flag or nil)
    if !flag then error("bad argument #1 to 'IsFlagSet' (number expected, got " .. type(flag) .. ")") end

    return bit.bor(self.flags, flag) == self.flags
end

local function change(cvar, value)
    if cvar.value == value then return end

    local old = cvar.value
    cvar.value = value

    hook.Run("server_cvar", {cvarname = cvar.name, cvarvalue = value})
    if cvars and cvars.OnConVarChanged then cvars.OnConVarChanged(cvar.name, old, value) end
end

function cm:SetString(value)
    if !isstring(value) and !isnumber(value) then error("bad argument #1 to 'SetString' (string expected, got " .. type(value) .. ")") end
    if !isstring(value) then value = tostring(value) end

    local num = tonumber(value)

    if self.min and self.min > 0 then
        if !num or num < self.min then
            change(self, tostring(self.min))
            return
        end

        if self.max and num > self.max then
           change(self, tostring(self.max))
           return
        end

        change(self, tostring(value))
    else
        if !num then    // source quirk: allow string values if min is <= 0
           change(self, value)
           return
        end

        if self.min and num < self.min then
            change(self, tostring(self.min))
            return
        end

        if self.max and num > self.max then
            change(self, tostring(self.max))
            return
        end

        change(self, tostring(value))
    end
end

function cm:Revert()
    self:SetString(self.default)
end

function cm:SetBool(bool)
    self:SetString(bool and "1" or "0")
end

function cm:SetFloat(value)
    local num = tonumber(value or nil)
    if !num then error("bad argument #1 to 'SetFloat' (number expected, got " .. type(value) .. ")") end
    self:SetString(tostring(num))
end

function cm:SetInt(value)
    local num = tonumber(value or nil)
    if !num then error("bad argument #1 to 'SetInt' (number expected, got " .. type(value) .. ")") end
    self:SetString(tostring(math.floor(num)))
end

function cm:__tostring()
    return "ConVar [" .. self.name .. "]"
end


function CreateConVar(name, value, flags, helptext, min, max)
    if !isstring(name) and !isnumber(name) then error("bad argument #1 to 'CreateConVar' (string expected, got " .. type(name) .. ")") end
    if !isstring(name) then name = tostring(name) end
    name = string.lower(name)

    if !isstring(value) and !isnumber(value) then error("bad argument #2 to 'CreateConVar' (string expected, got " .. type(value) .. ")") end
    if !isstring(value) then value = tostring(value) end
    value = string.lower(value)

    if !isnumber(flags) then flags = 0 end

    if !isstring(helptext) then
        if helptext != nil then
            ErrorNoHaltWithStack("bad argument #4 to CreateConVar (string expected, got " .. type(helptext) .. ")")
        end
        helptext = ""
    end

    if !isnumber(min) then
        if min != nil then
            ErrorNoHaltWithStack("bad argument #5 to CreateConVar (number expected, got " .. type(min) .. ")")
        end

        min = nil
    end

    if !isnumber(max) then
        if max != nil then
            ErrorNoHaltWithStack("bad argument #6 to CreateConVar (number expected, got " .. type(max) .. ")")
        end

        max = nil
    end

    if commands[name] then
        error("CreateConVar: Cannot override an existing console command! (" .. name .. ")")
        return
    end

    if convars[name] then
        return convars[name]
    end

    local cvar = {
        name = name,
        default = value,
        value = value,
        flags = flags,
        helptext = helptext,
        min = min,
        max = max
    }

    setmetatable(cvar, cm)
    convars[name] = cvar

    return cvar
end

function GetConVar_Internal(name)
    if !isstring(name) and !isnumber(name) then error("bad argument #1 to 'GetConVar_Internal' (string expected, got " .. type(name) .. ")") end
    if !isstring(name) then name = tostring(name) end
    name = string.lower(name)

    return convars[name]
end

function console.Disable()   // replaced below
    active = false
end

local function parse_args(cmd)
    if cmd == "" then return {} end
    local args = {}
    local ret = {}

    local quote = false
    local cur = {}
    for i = 1, string.len(cmd) do
        local char = string.sub(cmd, i, i)

        if char == "\"" then
            quote = !quote
            table.insert(args, table.concat(cur))
            cur = {}
            continue
        end

        if char == " " and !quote then
            table.insert(args, table.concat(cur))
            cur = {}
            continue
        end

        table.insert(cur, char)
    end

    table.insert(args, table.concat(cur))

    for k,v in pairs(args) do
        if v == "" then continue end
        table.insert(ret, v)
    end

    return ret
end

local function run_command(cmd)
    local cmds = {}
    local quote = false

    local cur = ""
    for i = 1, string.len(cmd) do
        local char = string.sub(cmd, i, i)

        if char == "\"" then quote = !quote end

        if char == ";" and !quote then
            table.insert(cmds, cur)
            cur = ""
            continue
        end

        cur = cur .. char
    end
    table.insert(cmds, cur)

    for k, v in pairs(cmds) do
        v = string.Trim(v)
        if v == "" then continue end

        local command_o = v
        local command = string.lower(v)
        local args
        local args_start = string.find(v, " ", 1, true)
        local argstr = ""

        if args_start then
            argstr = string.Trim(string.sub(v, args_start))
            command_o = string.sub(v, 1, args_start - 1)
            command = string.lower(command_o)
        end

        if alias[command] then
            run_command(alias[command])
            continue
        end

        if convars[command] then
            if argstr == "" then
                if concommand and concommand.Run then concommand.Run({}, "help", {command}, command) end
                continue
            end

            argstr = string.Trim(argstr)

            if string.sub(argstr, 1, 1) == "\"" then    // this is how source seems to do it
                argstr = string.sub(argstr, 2)

                if string.sub(argstr, -1, -1) == "\"" then
                    argstr = string.sub(argstr, 1, -2)
                end
            end

            convars[command]:SetString(argstr)
            continue
        end

        if commands[command] then
            args = parse_args(argstr)
            if concommand and concommand.Run then concommand.Run({}, command, args, argstr) end
            continue
        end

        MsgN("Unknown command: ", command_o)
    end
end

function game.ConsoleCommand(cmd)
    if !isstring(cmd) then error("bad argument #1 to 'ConsoleCommand' (string expected, got " .. type(cmd) .. ")") end

    if !string.find(cmd, "\n") then
        ErrorNoHalt("Error, bad server command " .. cmd)
        return
    end

    local cmds = string.Split(cmd, "\n")
    for k,v in pairs(cmds) do
       run_command(v)
    end
end



// stuff required for stdin console, everything below may not run
async.Add(function()
    if !active then return end

    local ok, sys = pcall(require, "system")
    if !ok then
    active = false
    return
    end

    if !sys.isatty(io.stdin) or !sys.isatty(io.stdout) then
        active = false
    return
    end


    local rows, cols

    local function terminal_size()
        local r, c = sys.termsize()
        if !isnumber(r) or !isnumber(c) then return end

        return r, c
    end

    local prompt = "> "
    local prompt_len = 0
    local prompt_printed = false
    local str = ""
    local pos = 0 // how far to move the cursor to the left
    local dont_clear = false

    local print_o = print
    local iow = io.write

    local function cleanup()
        local len = utf8.len(str)
        local len_up = len + prompt_len - pos

        if  pos == 0 and (len + prompt_len) % cols == 0 then
            len_up = len_up - 1
        end

        local up = len_up / cols

        for i = 1, up do
            iow("\27[1A")   // go up 1 line
        end

        iow("\r")
        for i = 1, len  + prompt_len do
            iow(" ")
        end
        iow("\r")

        up = ( len + prompt_len - 1 ) / cols

        for i = 1, up do
            iow("\27[1A")
        end

    end

    local function print_function(fun, ...)
            if !dont_clear then
                cleanup()
            end

            local len = utf8.len(str)
            local res = fun(...)

            if !dont_clear then
                // print input
                iow("\r", prompt, str)
                prompt_printed = true
            end

            // position cursor
            local last = (len + prompt_len) % cols     // chars on last line
            local up_extra = pos % cols > last and last > 0 and 1 or 0

            up = pos / cols
            if (pos % cols) == 0 and (len + prompt_len) % cols == 0 then
                up = up - 1
            end

            for i = 1, up + up_extra do
                iow("\27[1A")
            end

            iow("\r")
            local right = ((len + prompt_len - pos) % cols)
            if pos == 0 and right == 0 then right = cols end

            if !dont_clear then
                for i = 1, right do
                    iow("\27\91\67")
                end
            end

            dont_clear = false
            io.flush()
            return res
    end

    local buf = {}
    local history = {}
    local history_pos = 1
    local str_o
    local special_characters = "!\"§$%&/()=?`'{[]}\\#*~+-_.:,;°^<>|@€"
    local whitespace_characters = " \t"

    local control = {
        "\27\91\65",
        "\27\91\66",
        "\27\91\67",
        "\27\91\68",
        "\27\91\51\126",
        "\27\91\70",
        "\27\91\72",
        "\27\91\49\59\51\68",
        "\27\91\49\59\53\68",
        "\27\91\49\59\53\67",
        "\27\91\49\59\51\67",
        "\27\127"
    }



    prompt_len = utf8.len(prompt)

    sys.autotermrestore()

    sys.setconsoleflags(io.stdout, sys.getconsoleflags(io.stdout) + sys.COF_VIRTUAL_TERMINAL_PROCESSING)
    sys.setconsoleflags(io.stdin, sys.getconsoleflags(io.stdin) + sys.CIF_VIRTUAL_TERMINAL_INPUT)

    local of_attr = sys.tcgetattr(io.stdin)

    sys.setnonblock(io.stdin, true)
    sys.tcsetattr(io.stdin, sys.TCSANOW, {
        lflag = of_attr.lflag - sys.L_ICANON - sys.L_ECHO,
    })

    rows, cols = terminal_size()
    if !rows or !cols then active = false return end

    local ok, socket = pcall(require, "cqueues.socket")
    if !ok then active = false return end

    local stdin = socket.fdopen(0, "r")
    if !stdin then active = false return end

    function print(...)
        return print_function(print_o, ...)
    end

    function io.write(...)
        local args = {...}
        if string.sub(args[#args], -1, -1) != "\n" then
            dont_clear = true
            return iow(...)
        end

        return print_function(iow, ...)
    end



    hook.Add("TerminalResized", "console_resize", function()
        if !active then return end

        rows, cols = terminal_size()
        if !rows or !cols then active = false return end
    end)

    hook.Add("Terminate", "console_cleanup", function()
        if str != "" then
            cleanup()
            iow(prompt, str, "^C\n", prompt)
            io.flush()

            str = ""
            pos = 0
            history_pos = #history + 1
            return false
        end

        cleanup()
    end)

    function console.Disable()
        if !active then return end
        active = false

        hook.Remove("TerminalResized", "console_resize")
        hook.Remove("Terminate", "console_cleanup")

        if prompt_printed then
            cleanup()
            io.flush()
        end

        print = print_o
        io.write = iow
    end


    if !prompt_printed then
        iow(prompt, str)
        io.flush()
        prompt_printed = true
    end

    while active do
        // parsing
        local inp = stdin:read(1)
        async.Sleep(0)

        if !active then break end   // has been disabled while we were waiting for input

        table.insert(buf, inp)
        local char = table.concat(buf)
        //print("input: ", string.byte(inp)," ", inp)

        if #buf > 6 then // failsafe in case of unknown control sequence
           buf = {}
           continue
        end

        if !utf8.len(char) or (buf[1] == "\27" and !table.HasValue(control, char)) then
            continue // wait for the full sequence
        else
            buf = {}
        end

        if char == "\t" then
            if pos != 0 then continue end
            if str == "" then continue end
            if string.find(str, " ") then continue end
            char = ""

            local found = false
            for k, v in pairs(commands) do
                if string.StartsWith(k, str) then
                   str = k .. " "
                   found = true
                   break
                end
            end

            if !found then
                for k, v in pairs(convars) do
                    if string.StartsWith(k, str) then
                        str = k  .. " "
                        break
                    end
                end
            end
        end

        if char == "\4" then    // ctrl + d
            if str != "" then continue end

            print("^D")
            run_command("exit")
            return
        end

        // modifications
        local len = utf8.len(str)
        local pos_o = pos

        if char == control[4] then      // left
            pos = pos + 1
            if pos > len then pos = len end
        elseif char == control[3] then      // right
            pos = pos - 1
            if pos < 0 then pos = 0 end
        elseif char == control[1] then      // up
            if #history == 0 then continue end

            if history_pos > #history then
                str_o = str
            end

            history_pos = history_pos - 1
            if history_pos < 1 then history_pos = 1 end



            str = history[history_pos]
            pos = 0
        elseif char == control[2] then      // down
            if #history == 0 then continue end

            history_pos = history_pos + 1
            if history_pos > #history + 1 then history_pos = #history + 1 end

            str = history[history_pos] or str_o or ""
            pos = 0
        elseif char == control[6] then      // end
             pos = 0
        elseif char == control[7] then      // pos1
             pos = len
        elseif char == control[5] then      // del
            if pos < 1 then continue end
            str = utf8.sub(str, 1, len - pos) .. utf8.sub(str, len - pos + prompt_len)

            pos = pos - 1
            if pos < 0 then pos = 0 end
        elseif char == control[12] then     // alt+backspace
            if pos == len then continue end

            local starting_whitespaces = true
            local starting_special = true
            local to = 0

            for i = len - pos, 1, -1 do
                local ch = utf8.GetChar(str, i)

                if starting_special and string.find(special_characters, ch, 1, true) then
                    starting_special = false

                    if pos == len - 1 then
                        to = len
                    else
                        to = len - i
                    end

                    continue
                end

                if !starting_special and !starting_whitespaces and !string.find(whitespace_characters, ch, 1, true) then
                    to = len - i  - 1
                    break
                end

                if starting_whitespaces and string.find(whitespace_characters, ch, 1, true) then
                    continue
                end

                starting_whitespaces = false


                if string.find(whitespace_characters, ch, 1, true) or string.find(special_characters, ch, 1, true) then
                    to = len - i
                    break
                end

                to = len
            end

            str = utf8.sub(str, 1, len - to) .. utf8.sub(str, len - pos + 1)
        elseif char == control[8] or char == control[9] then    // ctrl or alt left
            if pos == len then continue end

            local starting_whitespaces = true
            local starting_special = true

            for i = len - pos, 1, -1 do
                local ch = utf8.GetChar(str, i)

                if starting_special and string.find(special_characters, ch, 1, true) then
                    starting_special = false

                    if pos == len - 1 then
                        pos = len
                    else
                        pos = len - i
                    end

                    continue
                end

                if !starting_special and !starting_whitespaces and !string.find(whitespace_characters, ch, 1, true) then
                    pos = len - i  - 1
                    break
                end

                if starting_whitespaces and string.find(whitespace_characters, ch, 1, true) then
                    continue
                end

                starting_whitespaces = false


                if string.find(whitespace_characters, ch, 1, true) or string.find(special_characters, ch, 1, true) then
                    pos = len - i
                    break
                end

                pos = len
            end

        elseif char == control[10] or char == control[11] then    // ctrl or alt right
            if pos == 0 then continue end

            local starting_whitespaces = true
            local starting_special = true

            for i = len - pos + 1, len do
                local ch = utf8.GetChar(str, i)

                if starting_special and string.find(special_characters, ch, 1, true) then
                    starting_special = false

                    if pos == 1 then
                        pos = 0
                    end

                    continue
                end

                starting_special = false


                if starting_whitespaces and string.find(whitespace_characters, ch, 1, true) then
                    continue
                end

                starting_whitespaces = false


                if string.find(whitespace_characters, ch, 1, true) or string.find(special_characters, ch, 1, true) then
                    pos = len - i + 1
                    break
                end

                pos = 0
            end
        elseif char == "\n" then

            if str != "" and str != history[#history] then
                table.insert(history, str)
            end

            history_pos = #history + 1

            cleanup()
            iow("] ", str, "\n")

            run_command(str)

            str = ""
            pos = 0
        elseif char == "\127" or char == "\8" then      // backspace or ctrl+backspace
            if pos == len then continue end

            str = utf8.sub(str, 1, len - pos - 1) .. utf8.sub(str, len - pos + 1)
        else    // append character
            history_pos = #history + 1
            str_o = str

            if pos == 0 then
                str = str .. char   // much cheaper
            else
                str = utf8.sub(str, 1, len - pos) .. char .. utf8.sub(str, len - pos + 1)
            end
        end

        local len_o = len
        len = utf8.len(str)

        // clearing
        local len_up = len_o + prompt_len - pos_o
        local right = ((len_o + prompt_len - pos_o) % cols)
        if (len != len_o and (right != 0 or pos == 0)) or (len == len_o and pos_o == 0 and (len + prompt_len) % cols == 0 ) then
            len_up = len_up - 1
        end

        local up = len_up / cols

        for i = 1, up do
            iow("\27[1A")   // go up 1 line
        end

        iow("\r")
        for i = 1, len_o  + prompt_len do
            iow(" ")
        end

        up = ( len_o + prompt_len - 1 ) / cols

        for i = 1, up do
            iow("\27[1A")
        end

        // print input
        iow("\r", prompt, str)

        // position cursor
        local last = (len + prompt_len) % cols     // chars on last line
        local up_extra = pos % cols > last and last > 0 and 1 or 0

        up = pos / cols
        if (pos % cols) == 0 and (len + prompt_len) % cols == 0 then
            up = up - 1
        end

        for i = 1, up + up_extra do
            iow("\27[1A")
        end

        iow("\r")
        local right = ((len + prompt_len - pos) % cols)
        if pos == 0 and right == 0 then right = cols end

        for i = 1, right do
            iow("\27\91\67")
        end

        io.flush()
    end

end)

