async = async or {}

local initialized = false
local init_successful = false
local loop
local dont_error_on_failure = false
local never_exit = false
local signal
local sl

function async.Init()
    if initialized then
        return init_successful
    end

    local s_ok, s = pcall(require, "cqueues.signal")

    if in_thread then s_ok = nil end

    if s_ok then
        signal = s
        sl = signal.listen(signal.SIGINT, 28)   //28 = SIGWINCH
        signal.block(signal.SIGINT, 28)
    end

    local ok, cqueues = pcall(require, "cqueues")
    if !ok then
        initialized = true
        init_successful = false
        ErrorNoHalt("async: failed to load cqueues module. you can still use non-async features\n")


        if !dont_error_on_failure then
            error(cqueues)
        end

        return false
    else
        initialized = true
        init_successful = true

        loop = cqueues.new()
        async.Sleep = cqueues.sleep

        if sl then
            loop:wrap(function()
                while console.IsActive() do
                    sl:wait()
                end
            end)
        end

        timer.Create("async_signal_timer", 0.05, 0, function()  // using signal listeners can cause the listener to not yield back to the main loop
            if !console.IsActive() then                         // this is why we disable them unless the console is active. We use a timer to force
                if signal then                                  // yielding out of the listener, but that is not free and also not optimal.
                    signal.unblock(signal.SIGINT, 28)
                    sl = nil
                end

                timer.Stop("async_signal_timer")
            end
        end)

        return true
    end
end

function async.DontErrorOnFailure(bool)
    local old = dont_error_on_failure
    dont_error_on_failure = bool
    return old
end

function async.NeverExit(bool)
    never_exit = bool
end

function async.Available()
    if initialized then return init_successful end

    local ok, cqueues = pcall(require, "cqueues")
    return ok
end

function async.Add(fun)
    if !async.Init() then return false end
    return loop:wrap(fun)
end

function async.Loop()
    if !async.Init() then return false end

    if never_exit then
        loop:wrap(function() async.Sleep(math.huge) end)
    end

    // kickstart drawing loops
    hook.Run("PreDrawHUD")
    hook.Run("HUDPaintBackground")
    hook.Run("HUDPaint")
    hook.Run("DrawOverlay")
    hook.Run("PostDrawHUD")

    while true do
        local signo = sl and sl:wait(0)

        if signo == 2 then  // 2 = SIGINT
            local res = hook.Run("Terminate")

            if res == nil then
                hook.Run("ShutDown")
                os.exit()
            else
                loop:pause(2)
                continue
            end
        end

        if signo == 28 then     // 28 = SIGWINCH
            hook.Run("TerminalResized")
            loop:pause(28)
            continue
        end

        local ok, err = loop:step()
        if !ok then error(err) end

        if loop:count() + thread.Count() <= (sl and 1 or 0) + (console and (console.IsActive() and 2 or 0) or 0) then   // only our listeners are left
           break
        end

        if sl and console.IsActive() then
            loop:pause(2)
        end

        if loop:empty() then    // all events are done, wait for threads
            async.Sleep(0.1)
        end

    end

    if console then console.Disable() end

    if true then    // terminate after main event loop is done. not sure if this is unintuitive
        hook.Run("ShutDown")
        os.exit()
    end
end

function async.Sleep(delay)
    if !async.Init() then return false end

    return async.Sleep(delay)   // replaced in async.Init
end
