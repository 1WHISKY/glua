util = util or {}

local last = 0
function util.TimerCycle()
    local time = CurTime() - last
    last = CurTime()

    return time * 1000
end
