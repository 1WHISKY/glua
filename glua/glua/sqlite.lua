sql = sql or {}

local initialized = false
local success = false
local driver
local env
local con

local function init()
    if initialized then return success end
    initialized = true
    success = true

    local ok, d = pcall(require, "luasql.sqlite3")
    if !ok then success = false return false end

    driver = d
    env = driver.sqlite3()
    if !env then success = false return false end

    local path = file.GetPath("GAME")
    if !path then success = false return false end


    con = env:connect(path .. "sv.db")
    if !con then success = false return false end

    return success
end

function sql.Query(query)
    if !isstring(query) then error("bad argument #1 to 'Query' (string expected, got " .. type(query) .. ")") end

    if !init() then return nil end

    local cur, err = con:execute(query)
    if !cur then sql.m_strError = err return false end
    if isnumber(cur) then return end

    local row = cur:fetch({}, "a")
    if !row then return nil end

    local res = {}

    while row do
        table.insert(res,row)
        row = cur:fetch({}, "a")
    end

    return res
end
