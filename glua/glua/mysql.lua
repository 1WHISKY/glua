mysql = mysql or {}

local initialized = false
local success = false
local driver
local env
local con

local function init()
    if initialized then return success end
    initialized = true
    success = true

    local ok, d = pcall(require, "luasql.mysql")
    if !ok then success = false return false end

    driver = d
    env = driver.mysql()
    if !env then success = false return false end

    return success
end

function mysql.Connect(db, user, pw, host, port, socket, client_flag)
    if !init() then return false, "error while initializing mysql library" end

    local c, err = env:connect(db or "", user, pw, host, port, socket, client_flag)
    if !c then return false, err end

    con = c
    return true
end

function mysql.Query(query)
    if !isstring(query) then error("bad argument #1 to 'Query' (string expected, got " .. type(query) .. ")") end

    local ok, err
    if !con then ok, err = mysql.Connect() end
    if !con then mysql.m_strError = err return false end

    local cur, err = con:execute(query)
    if !cur then mysql.m_strError = err return false end
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

--------

function mysql.DatabaseExists(db)
    local r = mysql.Query("SELECT 1 FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME=" .. SQLStr(db) .. ";")
    return r and true or false
end

function mysql.TableExists(db, table)
    local r = mysql.Query("SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=" .. SQLStr(db) .. " AND TABLE_NAME=" .. SQLStr(table) .. ";")
    return r and true or false
end


function mysql.IndexExists(db, table, index)
    local r = mysql.Query("SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=" .. SQLStr(db) .. " AND TABLE_NAME=" .. SQLStr(table) .. " AND INDEX_NAME=" .. SQLStr(index) .. ";")
    return r and true or false
end

function mysql.QueryRow(query, row)
    row = row or 1
    local r = mysql.Query(query)

    if (r) then return r[row] end
    return r
end

function mysql.QueryValue(query)
    local r = mysql.QueryRow(query)

    if (r) then
        for k, v in pairs(r) do return v end
    end

    return r
end

function mysql.Begin()
    mysql.Query("BEGIN;")
end

function mysql.Commit()
    mysql.Query("COMMIT;")
end

function mysql.LastError()
    return mysql.m_strError
end
