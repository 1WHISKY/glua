include("types.lua")

//FMT
local metatables = {}
local meta_id = 10

function RegisterMetaTable(metaName, metaTable)
    if !isstring(metaName)     then error("bad argument #1 to 'RegisterMetaTable' (string expected, got " .. type(metaName) .. ")") end
    if !istable(metaTable)     then error("bad argument #2 to 'RegisterMetaTable' (table expected, got " .. type(metaTable) .. ")") end
    if metatables[metaName] then return end

    metaTable.MetaID = meta_id
    meta_id = meta_id + 1
    metaTable.MetaName = metaName
    metatables[metaName] = metaTable
end

function FindMetaTable(metaName)
    if !isstring(metaName)     then error("bad argument #1 to 'FindMetaTable' (string expected, got " .. type(metaName) .. ")") end
    return metatables[metaName]
end

//unpack
unpack = unpack or table.unpack

//globals placeholders
include("enums/team.lua")
include("enums/type.lua")

file = file or {}
net = net or {}
game = game or {}
render = render or {}
ents = ents or {}
vgui = vgui or {}
player = player or {}

function game.MaxPlayers() return 1 end
function render.GetScreenEffectTexture() end
function LoadPresets() return {} end
function AddCSLuaFile() end

SENSORBONE = {}

//meta
local m = {}
RegisterMetaTable("Entity", m)
RegisterMetaTable("Vehicle", m)
RegisterMetaTable("Panel", m)
RegisterMetaTable("Player", m)

//bit
bit = bit or {}

bit.band = bit.band or load([[return function(num, ...)
    local a = tonumber(num or nil)
    if !a then error("bad argument #1 to 'band' (number expected, got " .. type(num) .. ")") end

    local len = select("#",...)
    for k = 1, len do   // we do it this way so we can get nil values and throw an error
        local v = select(k, ...)

        local b = tonumber(v)
        if !b then error("bad argument #" .. tostring(k + 1) .. " to 'band' (number expected, got " .. type(v) .. ")") end

        a = a & b
    end

    return a
end ]])()

bit.bor = bit.bor or load([[return function(num, ...)
    local a = tonumber(num or nil)
    if !a then error("bad argument #1 to 'bor' (number expected, got " .. type(num) .. ")") end

    local len = select("#",...)
    for k = 1, len do   // we do it this way so we can get nil values and throw an error
        local v = select(k, ...)

        local b = tonumber(v)
        if !b then error("bad argument #" .. tostring(k + 1) .. " to 'bor' (number expected, got " .. type(v) .. ")") end

        a = a | b
    end

    return a
end]])()

bit.bnot = bit.bnot or load([[return function(num)
    local a = tonumber(num or nil)
    if !a then error("bad argument #1 to 'bnot' (number expected, got " .. type(num) .. ")") end

    return ~a
end]])()

bit.bswap = bit.bswap or load([[return function(num)
    local a = tonumber(num or nil)
    if !a then error("bad argument #1 to 'bswap' (number expected, got " .. type(num) .. ")") end

    return ((a & 0xFF) << 24) | ((a & 0xFF00) << 8) | ((a & 0xFF0000) >> 8) | ((a & 0xFF000000) >> 24)
end]])()

bit.bxor = bit.bxor or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'bxor' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'bxor' (number expected, got " .. type(num_b) .. ")") end

    return a ~ b
end]])()

bit.lshift = bit.lshift or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'lshift' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'lshift' (number expected, got " .. type(num_b) .. ")") end

    return a << b
end]])()

bit.rshift = bit.rshift or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'rshift' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'rshift' (number expected, got " .. type(num_b) .. ")") end

    return a >> b
end]])()

bit.rol = bit.rol or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'rol' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'rol' (number expected, got " .. type(num_b) .. ")") end

    b = b % 32
    return ((a << b) | (a >> (32 - b))) & 0xFFFFFFFF
end]])()

bit.ror = bit.ror or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'ror' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'ror' (number expected, got " .. type(num_b) .. ")") end

    b = b % 32
    return ((a >> b) | (a << (32 - b))) & 0xFFFFFFFF
end]])()

bit.arshift = bit.arshift or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil)
    if !a then error("bad argument #1 to 'arshift' (number expected, got " .. type(num_a) .. ")") end
    if !b then error("bad argument #2 to 'arshift' (number expected, got " .. type(num_b) .. ")") end

    b = b % 32
    local shifted = a >> b

    if a & 0x80000000 ~= 0 then
        shifted = shifted | ((0xFFFFFFFF << (32 - b)) & 0xFFFFFFFF)
    end

    return shifted & 0xFFFFFFFF
end]])()

bit.tobit = bit.tobit or load([[return function(num)
    local a = tonumber(num or nil)
    if !a then error("bad argument #1 to 'tobit' (number expected, got " .. type(num) .. ")") end

    return a & 0xFFFFFFFF
end]])()

bit.tohex = bit.tohex or load([[return function(num_a, num_b)
    local a = tonumber(num_a or nil)
    local b = tonumber(num_b or nil) or 8
    if !a then error("bad argument #1 to 'tohex' (number expected, got " .. type(num_a) .. ")") end

    return string.format("%0" .. tostring(b) .. "x", a & 0xFFFFFFFF)
end]])()

//Msg
function Msg(...)
    local str = {}

    for i = 1,select("#",...) do
        table.insert(str, tostring(select(i,...)))
    end

    io.write(unpack(str))
    io.flush()
end

function MsgN(...)
    local args = {...}
    table.insert(args, "\n")
    Msg(unpack(args))
end

function MsgC(...)  // maybe add support for colors?
    local str = {}

    for i = 1,select("#",...) do
        local e = select(i,...)
        if IsColor(e) then continue end
        table.insert(str, tostring(e))
    end

    io.write(unpack(str))
    io.flush()
end

//CurTime
local curtime_warned = false
local ost_start = os.time()
local mt_start
local mt

function CurTime()
    if mt_start then
        return mt() - mt_start
    end

    if package.loaded.cqueues and package.loaded.cqueues.monotime then
        mt = package.loaded.cqueues.monotime
        mt_start = mt() - (os.time() - ost_start)

        return mt() - mt_start
    end

    if !curtime_warned then
        print("warning: CurTime sub-second precision may not be available. Use async.Init() to load the required modules")
        curtime_warned = true
    end

    return os.time() - ost_start
end

SysTime = CurTime
RealTime = CurTime

//module
module = module or function(name, ...)
    local ns = _G[name] or {}
    _G[name] = ns
    package.loaded[name] = ns

    for _, f in ipairs({...}) do
        f(ns)
    end

    local env = setmetatable({}, {
        __newindex = ns,
        __index = function(_, k) return ns[k] or _G[k] end,
    })

    local function set_env(level)
        local info = debug.getinfo(level + 1, "f")
        local func = info.func
        local i = 1
        while true do
            local name = debug.getupvalue(func, i)
            if !name then break end
            if name == "_ENV" then
                debug.upvaluejoin(func, i, (function() return env end), 1)
            end
            i = i + 1
        end
    end

    set_env(2)

    return ns
end

//lua execution
function RunString(code, identifier, handle)
    if !isstring(code) then error("bad argument #1 to 'RunString' (string expected, got " .. type(code) .. ")") end
    if !isstring(identifier) and identifier != nil then error("bad argument #2 to 'RunString' (string expected, got " .. type(identifier) .. ")") end

    if handle == nil then handle = true end
    if !identifier then identifier = "RunString(Ex)" end

    local fun, res = load(code, "t")
    local ok = false

    if fun then
        ok, res = pcall(fun)
    end

    if !ok then
        if handle then
            ErrorNoHaltWithStack(identifier .. ": " .. res)
        else
            return identifier .. ": " .. res
        end
    end
end

RunStringEx = RunString

function CompileString(code, identifier, handle)
    if !isstring(code) then error("bad argument #1 to 'CompileString' (string expected, got " .. type(code) .. ")") end
    if !isstring(identifier) and identifier != nil then error("bad argument #2 to 'CompileString' (string expected, got " .. type(identifier) .. ")") end

    if handle == nil then handle = true end
    if !identifier then identifier = "CompileString" end

    local fun, res = load(code, "t")

    if !fun then
        if handle then
            ErrorNoHaltWithStack(identifier .. ": " .. res)
        else
            return identifier .. ": " .. res
        end
    end

    return fun
end

function CompileFile(path, handle)
    if !isstring(path) then error("bad argument #1 to 'CompileFile' (string expected, got " .. type(path) .. ")") end

    if handle == nil then handle = true end

    if string.GetExtensionFromFilename(path) != "lua" then
        if handle then
            ErrorNoHaltWithStack("Couldn't include file '" .. path .. "' - Not a .lua file!")
        end
        return
    end

    if string.find(path, "..", 1, true) then
        if handle then
            ErrorNoHaltWithStack("Couldn't include file '" .. path .. "' - File not found or is empty")
        end
        return
    end

    local base = file.GetPath("LUA")

    if !base then
        if handle then
            ErrorNoHaltWithStack("Couldn't include file '" .. path .. "' - File not found or is empty")
        end
        return
    end

    if !file.Exists(path, "LUA") then
        if handle then
            ErrorNoHaltWithStack("Couldn't include file '" .. path .. "' - File not found or is empty")
        end
        return
    end

    local fun, res = loadfile( base .. path, "t")

    if !fun and handle then
        ErrorNoHaltWithStack(res)
    end

    return fun
end

// error
function ErrorNoHaltWithStack(...)
    MsgN("[ERROR] ", ...)
    print(debug.traceback())
end

ErrorNoHalt = Msg
Error = ErrorNoHalt



