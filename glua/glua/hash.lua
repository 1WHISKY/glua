local sha = include("libs/egor-skriptunoff_pure_lua_sha.lua")
util = util or {}

function util.MD5(str)
    if !isstring(str) then error("bad argument #1 to 'MD5' (string expected, got " .. type(str) .. ")") end
    if !sha then return nil end

    return sha.md5(str)
end

function util.SHA1(str)
    if !isstring(str) then error("bad argument #1 to 'SHA1' (string expected, got " .. type(str) .. ")") end
    if !sha then return nil end

    return sha.sha1(str)
end

function util.SHA256(str)
    if !isstring(str) then error("bad argument #1 to 'SHA256' (string expected, got " .. type(str) .. ")") end
    if !sha then return nil end

    return sha.sha256(str)
end

function util.SHA512(str)
    if !isstring(str) then error("bad argument #1 to 'SHA512' (string expected, got " .. type(str) .. ")") end
    if !sha then return nil end

    return sha.sha512(str)
end

