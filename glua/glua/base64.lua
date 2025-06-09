local b64 = include("libs/iskolbin_lbase64.lua")
util = util or {}

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

function util.Base64Decode(str)
    if !isstring(str) then error("bad argument #1 to 'Base64Decode' (string expected, got " .. type(str) .. ")") end
    if !b64 then return nil end

    local ok, res = pcall(b64.decode, str)
    if ok then return res end

    // there is probably a issue with the input, search for invalid characters
    local last_good = string.len(str)

    for i = 1, last_good do
        local char = string.sub(str, i, i)

        if !string.find(chars, char, 1, true) then
            last_good = i - 1
            break
        end
    end

    str = string.sub(str, 1, last_good) .. "="

    local ok, res = pcall(b64.decode, str)
    if ok then return res end

    return ""
end

function util.Base64Encode(str, inline)
    if !isstring(str) then error("bad argument #1 to 'Base64Encode' (string expected, got " .. type(str) .. ")") end
    if !b64 then return nil end

    local encoded = b64.encode(str)
    if inline then return encoded end

    local len = string.len(encoded)
    if len < 73 then return encoded end

    local res = ""

    for i = 1, len, 72 do
        res = res .. string.sub(encoded, i, i + 71)

        if len - i > 71 then
            res = res .. "\n"
        end
    end

    return res
end
