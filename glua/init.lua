// debug include timings
local measure_include = false
local depth = 0
local time

if measure_include then
    local cq = require("cqueues")
    time = cq.monotime
end


// include files relative to current path
function include(path)
    local times

    if measure_include then
       times = {}
       times[1] = time()
       depth = depth + 1
    end

    if type(path) != "string" then error("bad argument #1 to 'include' (string expected, got " .. type(path) .. ")") end

    local f

    if file and file.GetPath then    // prioritize files in LUA dir
        local base = file.GetPath("LUA")

        if base and !string.find(path, "..", 1, true) and file.Exists(path, "LUA") and !file.IsDir(path, "LUA") then
            f = base .. path
        end
    end

    if measure_include then times[2] = time() end

    if !f then
        if string.sub(path, 1, 1) == "/" then
            f = path
        else
            local here = debug.getinfo(2, "S").source:sub(2):match("(.*/)") or ""
            f = here .. path
        end
    end

    if measure_include then times[3] = time() end

    local res = { pcall(dofile, f) }
    local ok = res[1]

    if measure_include then times[4] = time() end

    if !ok then
       if ErrorNoHaltWithStack then
           ErrorNoHaltWithStack(res[2] or "")
           return
        else
           print(res[2])
           return
        end
    end

    table.remove(res, 1)

    if measure_include then
        depth = depth - 1
        local now = time()
        local total = (now - times[1]) * 1000
        local times_str = {}

        for k, v in pairs(times) do
            if k == 1 then continue end
            times_str[k] = (v - times[k - 1]) * 1000
        end

        times_str[1] = total

        for k, v in pairs(times_str) do
            local col = "\x1b[0m"

            if v > 0.1 then col = "\x1b[36m" end
            if v > 0.5 then col = "\x1b[33m" end
            if v > 1.0 then col = "\x1b[31m" end

            v = col .. string.format("%.4f", v) .. "\x1b[0m"
            times_str[k] = v
        end

        local depth_str = "└"

        if depth > 0 then
           depth_str = "├" .. string.rep("─", depth - 1)
        end

        print("ms check_file_lua:", times_str[2], "check_file_rel:", times_str[3], "exec:", times_str[4], "total:", times_str[1], depth_str .. path)
    end

    return (unpack or table.unpack)(res)
end

include("glua/init.lua")


// stuff required for gmod lua
CLIENT = true
local reg = debug.getregistry
local require_o = require
local jit_o = jit
local sql_Query_o = sql.Query
local include_o = include
local material_o = Material
jit = jit or {}


local blacklist = {
    "drive", // these are at the wrong location

    // these technically work fine but add nothing of value for us
    "extensions/client/panel.lua",
    "extensions/entity.lua",
    "util/worldpicker.lua",
    "extensions/player.lua",
    "util/workshop_files.lua",
    "util/client.lua",
    "modules/construct.lua",
    "modules/constraint.lua",
    "modules/duplicator.lua",
    "modules/undo.lua",
    "modules/team.lua",
    "modules/numpad.lua",
    "modules/player_manager.lua",
    "modules/saverestore.lua",
}

function include(path)
    for k, v in pairs(blacklist) do
        if string.find(path, v) then
            //print("skipped", path)
            return
        end
    end

    return include_o(path)
end

function require(mod)
    return include("modules/" .. mod .. ".lua") -- we don't have these modules, just include the lua
end

function sql.Query()
    return true
end

function Material(...)
    //print("Material called", ...)
end



include("garrysmod/includes/init.lua")


CLIENT = nil
debug.getregistry = reg     // undo gmod fix from includes/util.lua
require = require_o
jit = jit_o
sql.Query = sql_Query_o
include = include_o
Material = material_o

if _G["math.ease"] then
    math.ease = _G["math.ease"]
    _G["math.ease"] = nil
end

include("glua/postinit.lua")
