thread = thread or {}

local initialized = false
local effil
local g
local threads = {}

local function init()
    if initialized then
        return effil and true or false
    end

    local ok, e = pcall(require, "effil")

    if ok then
       effil = e
       initialized = true
       g = effil.G
       return true
    else
        initialized = true
        return false
    end
end

function thread.New(fun, data)
    if !isfunction(fun)    then error("bad argument #1 to 'New' (function expected, got " .. type(fun) .. ")") end

    if !init() then return nil end

    local thread = effil.thread(function(d)
        in_thread = true
        require("glua")
        in_thread = nil

        console.Disable()

        local ok ,err = pcall(fun, d)
        if err then
            ErrorNoHaltWithStack(err)
            os.exit()
        end

        async.Loop()
    end
    )(data)

    if thread then
       table.insert(threads, thread)
    end

    return thread
end

function thread.Data()
    init()
    return g
end


function thread.Count()
    if !effil then return 0 end

    local count = 0

    for k,v in pairs(threads) do
        if !v then continue end

        if v:status() != "running" then
            threads[k] = nil
        else
            count = count + 1
        end
    end

    return count
end
