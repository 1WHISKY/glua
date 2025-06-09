
// include files relative to current path
function include(path)
    if type(path) != "string" then error("bad argument #1 to 'include' (string expected, got " .. type(path) .. ")") end

    local f

    if file and file.GetPath then    // prioritize files in LUA dir
        local base = file.GetPath("LUA")

        if base and !string.find(path, "..", 1, true) and file.Exists(path, "LUA") and !file.IsDir(path, "LUA") then
            f = base .. path
        end
    end

    if !f then
        if string.sub(path, 1, 1) == "/" then
            f = path
        else
            local here = debug.getinfo(2, "S").source:sub(2):match("(.*/)") or ""
            f = here .. path
        end
    end

    local res = { pcall(dofile, f) }
    local ok = res[1]

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


local blacklist = { "drive" }

function include(path)
    for k, v in pairs(blacklist) do
        if string.find(path, v) then return end
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
end

include("glua/postinit.lua")
