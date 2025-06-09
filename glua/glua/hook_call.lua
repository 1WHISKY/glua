local call = hook and hook.Call
if !call then return end

// this makes sure that errors in hooks dont halt everything
function hook.Call(...)
    local ok, a, b, c, d, e, f = pcall(call, ...)
    if !ok then ErrorNoHaltWithStack(a) return end

    return a, b, c, d, e, f
end
