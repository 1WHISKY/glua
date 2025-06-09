system = system or {}

function system.IsLinux()
    if jit and jit.os then return jit.os == "Linux" end
    return string.sub(package.cpath, -2) == "so"
end

function system.IsWindows()
    if jit and jit.os then return jit.os == "Windows" end
    return string.sub(package.config, 1, 1) == "\\"
end

function system.IsOSX()
    if jit and jit.os then return jit.os == "OSX" end
    return string.sub(package.cpath, -5) == "dylib"
end


system.AppTime = CurTime
system.SteamTime = os.clock
