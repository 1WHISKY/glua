local json
local initialized = false
util = util or {}

local function init()
    if initialized then return json and true or false end

    json = include("libs/rxi_jsondotlua.lua")
    return json and true or false
end

local function fix_table(tbl, done, started)
    local new = {}
    done = done or {}
    started = started or {}

    if done[tbl] then return done[tbl] end
    started[tbl] = true

    local is_seq = true
    local i = 1

    for k,v in pairs(tbl) do
        if tbl[i] == nil then
            is_seq = false
            break
        end

        if isnumber(v) and (v != v or v == math.huge or v == -math.huge) then
            is_seq = false
            break
        end

        i = i + 1
    end

    for k,v in pairs(tbl) do
        local tk = type(k)
        if tk != "string" and tk != "number" and tk != "boolean" then continue end

        local tv = type(v)
        if tv != "string" and tv != "number" and tv != "boolean" and tv != "table" then continue end
        if tv == "number" and (v != v or v == math.huge or v == -math.huge) then continue end  // check nan and inf

        if tv == "table" then
            if tbl == v then error("attempt to serialize structure with cyclic reference") end

            if started[v] and !done[v] then
                error("attempt to serialize structure with cyclic reference")
            end

            if !done[v] then
                done[v] = fix_table(v, done, started)
            end
        end

        new[is_seq and k or tostring(k)] = tv == "table" and done[v] or v
    end

    return new
end


local function pretty_print(json)
    local indent = 0
    local indent_str = "    "
    local str = ""
    local in_quotes = false
    local last_char = ""

    for i = 1, string.len(json) do
        local char = string.sub(json, i, i)

        if !in_quotes then
            if last_char == ":" and char != " " then
                str = str .. " "
            end

            if last_char == "{" or last_char == "[" then
                str = str .. last_char
                indent = indent + 1

                if char == "}" or char == "]" then
                    indent = indent - 1
                    str = str .. char
                else
                    str = str .. "\n" .. string.rep(indent_str, indent)
                end
            end
        end

        if char == '"' and last_char != "\\" then
            in_quotes = !in_quotes
        end

        if !in_quotes then
            if char == '}' or char == ']' then
                if last_char != "{" and last_char != "[" then
                    indent = indent - 1
                    str = str .. "\n" .. string.rep(indent_str, indent) .. char
                end
            elseif char == '{' or char == '[' then
                // handled above
            elseif char == ',' then
                str = str .. char .. "\n" .. string.rep(indent_str, indent)
            else
                str = str .. char
            end

        else
            str = str .. char
        end

        last_char = char
    end

    return str
end

function util.TableToJSON(table, pretty)
    if !istable(table) then error("bad argument #1 to 'TableToJSON' (table expected, got " .. type(table) .. ")") end
    if !init() then return nil end

    local res = json.encode(fix_table(table))
    if pretty then res = pretty_print(res) end

    return res
end



local function decode_conversion(tbl, done, started)
    local new = {}
    done = done or {}

    if done[tbl] then return done[tbl] end

    for k,v in pairs(tbl) do
        if istable(v) and !done[v] then
            done[v] = decode_conversion(v, done, started)
        end

        new[tonumber(k) or k] = istable(v) and done[v] or v
    end

    return new
end

function util.JSONToTable(jsn, ignoreLimits, ignoreConversions)
    if !isstring(jsn) then error("bad argument #1 to 'JSONToTable' (string expected, got " .. type(jsn) .. ")") end
    if !init() then return nil end

    local ok, res = pcall(json.decode, jsn)
    if !ok then return nil, res end

    if !ignoreConversions then
        res = decode_conversion(res)
    end

    return res, nil
end

