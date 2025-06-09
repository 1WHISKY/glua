file = file or {}

local home = GLUA_HOME or os.getenv("GLUA_HOME") or os.getenv("HOME") or os.getenv("LOCALAPPDATA") or "~"
local storage = "/.glua"
local gamepath_default = "DATA"
local restrict_write = true // restrict write operations to DATA and ROOT paths

local lfs
local lfs_init = false
local initialized = {}

local ffi
local ffi_structs = {}



local paths = {
    GAME = home .. storage .. "/",
    GARRYSMOD = home .. storage .. "/",
    MOD = home .. storage .. "/",
    BASE_PATH = home .. storage .. "/",
    MOD_WRITE = home .. storage .. "/",
    GAME_WRITE = home .. storage .. "/",
    DEFAULT_WRITE_PATH = home .. storage .. "/",

    EXECUTABLE_PATH = home .. storage .. "/bin/",
    GAMEBIN = home .. storage .. "/bin/",
    WORKSHOP = home .. storage .. "/workshop/",
    THIRDPARTY = home .. storage .. "/workshop/",
    BSP = home .. storage .. "/bsp/",

    DATA = home .. storage .. "/data/",
    DOWNLOAD = home .. storage .. "/lua/download/",

    LUA = home .. storage .. "/lua/",
    LCL = home .. storage .. "/lua/",
    LSV = home .. storage .. "/lua/",
    LUAMENU = home .. storage .. "/lua/",

    ROOT = ""
}


local function exists_raw(path)
    if lfs then
        local attr = lfs.attributes(path, "size")
        return attr != nil
    else
        local ok, err, num = os.rename(path, path)

        if system.IsWindows() and num == 13 then return true end
        return ok and true or false
    end
end

local function dir_raw(path)
    if lfs then
        local mode = lfs.attributes(path, "mode")
        if !mode then return false end
        return mode == "directory"
    else
        if !exists_raw(path) then return false end

        local ok, err, num = io.open(path .. "/")
        if ok then
            ok:close()
            return true
        end

        if system.IsWindows() and num == 13 then return true end // may also be access denied, but cant tell the difference
        return false
    end
end

local windows_illegal = {"/", "\\", "\"", ":", "*", "?", "<", ">", "|"}
local function mkdir(path)
    if lfs then
        return lfs.mkdir(path) and true or false
    else
        if system.IsWindows() then
            local p = path
            for k,v in pairs(windows_illegal) do
               p = string.Replace(p, v, "")
            end

            return os.execute("mkdir \"" .. p .. "\"") == 0
        else
            -- sanitize " and \ and ignore stderr/out
            return os.execute("mkdir \"" .. string.Replace(string.Replace(path, "\\", "\\\\"), "\"", "\\\"") .. "\" > /dev/null 2>&1") == 0
        end
    end
end

local function initialize(gamepath)
    if !lfs_init then
        local ok, l = pcall(require, "lfs")
        if ok then lfs = l end

        local ok2, f = pcall(require, "ffi")

        if ok2 then
            ffi = f
            ffi_structs["double"] = ffi.new("union { double v; uint8_t b[8]; }")
            ffi_structs["float"]  = ffi.new("union { float v; uint8_t b[4]; }")
            ffi_structs["long"]  = ffi.new("union { int32_t v; uint8_t b[4]; }")
            ffi_structs["short"]  = ffi.new("union { int16_t v; uint8_t b[2]; }")
            ffi_structs["uint64"]  = ffi.new("union { uint64_t v; uint8_t b[8]; }")
            ffi_structs["ulong"]  = ffi.new("union { uint32_t v; uint8_t b[4]; }")
            ffi_structs["ushort"]  = ffi.new("union { uint16_t v; uint8_t b[2]; }")
        end

        lfs_init = true
    end

    if !isstring(gamepath) then return false end

    gamepath = string.upper(gamepath)
    if initialized[paths[gamepath]] then return true end
    if !paths[gamepath] then return false end

    if gamepath == "ROOT" then return true end

    // create missing dirs
    local path = string.Split(paths[gamepath], "/")
    local _, home_sub = string.gsub(home, "/", "")

    local cur = ""
    for k, v in pairs(path) do
        if k == 1 then continue end

        cur = cur .. "/" .. v
        if k <= home_sub + 1 then continue end

        if !dir_raw(cur) then
            local ok = mkdir(cur)
            if !ok then return false end
        end
    end

    initialized[paths[gamepath]] = true
    return true
end

local function validate(name, gamepath)
    if !isstring(name) then return false end
    gamepath = string.upper(gamepath)

    if gamepath == "ROOT" then return true end

    local first = string.sub(name, 1, 1)
    if first == "/" or first == "\\" then return false end
    if string.find(name, "..", 1, true) then return false end

    return true
end



function file.GetPath(gamepath)
    if !isstring(gamepath) then error("bad argument #1 to 'GetPath' (string expected, got " .. type(gamepath) .. ")") return nil end
    if !initialize(gamepath) then return nil end

    return paths[string.upper(gamepath)]
end

function file.Exists(name, gamepath)
    if !isstring(name) then error("bad argument #1 to 'Exists' (string expected, got " .. type(name) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'Exists' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return false end
    if !validate(name, gamepath) then return false end

    return exists_raw( paths[gamepath] .. name)
end

function file.IsDir(name, gamepath)
    if !isstring(name) then error("bad argument #1 to 'IsDir' (string expected, got " .. type(name) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'IsDir' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return false end
    if !validate(name, gamepath) then return false end

    return dir_raw( paths[gamepath] .. name)
end

function file.Delete(name, gamepath)
    if !isstring(name) then error("bad argument #1 to 'Delete' (string expected, got " .. type(name) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'Delete' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return false end
    if !validate(name, gamepath) then return false end
    if name == "" then return false end

    if restrict_write and (gamepath != "DATA" and gamepath != "ROOT") then
        return false
    end

    local file = paths[gamepath] .. name
    if lfs and system.IsWindows() and dir_raw(file) then
        return lfs.rmdir(file) and true or false
    end

    return os.remove( paths[gamepath] .. name) and true or false
end

function file.CreateDir(name, gamepath)
    if !isstring(name) then error("bad argument #1 to 'CreateDir' (string expected, got " .. type(name) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'CreateDir' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return false end
    if !validate(name, gamepath) then return false end

    if restrict_write and (gamepath != "DATA" and gamepath != "ROOT") then
        return false
    end

    local path_full = string.Split( string.Replace(name, "\\", "/"), "/")
    local path = paths[gamepath]

    for k,v in pairs(path_full) do
        path = path .. v .. "/"
        mkdir(path)
    end

    return true
end

function file.Rename(name, newname, gamepath)
    if !isstring(name) then error("bad argument #1 to 'Rename' (string expected, got " .. type(name) .. ")") end
    if !isstring(newname) then error("bad argument #2 to 'Rename' (string expected, got " .. type(newname) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #3 to 'Rename' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return false end
    if !validate(name, gamepath) then return false end
    if !validate(newname, gamepath) then return false end

    if name == "" then return false end
    if exists_raw(paths[gamepath] .. newname) then return false end

    if restrict_write and (gamepath != "DATA" and gamepath != "ROOT") then
        return false
    end

    newname = string.Replace(newname, "\\", "/")
    if string.sub(newname, -1) == "/" then return false end

    file.CreateDir(string.match(newname, ".*/") or "", gamepath)
    return os.rename( paths[gamepath] .. name, paths[gamepath] .. newname) and true or false
end

local fm = {}
fm.__index = fm
RegisterMetaTable("File", fm)

function fm:Close()
    self.closed = self.file:close()
    return self.closed and true or false
end

function fm:Flush()
    if self.closed then return end
    return self.file:flush() and true or false
end

function fm:Tell()
    if self.closed then return end
    return self.file:seek()
end

function fm:Seek(num)
    if self.closed then return end
    return self.file:seek("set", num)
end

function fm:Skip(num)
    if self.closed then return end
    return self.file:seek("cur", num)
end

function fm:EndOfFile(num)
    if self.closed then return end
    return self.file:seek() >= self:Size()
end

function fm:Size()
    if self.closed then return end

    local current = self.file:seek()
    local size = self.file:seek("end")
    self.file:seek("set", current)
    return size
end

function fm:Read(num)
    if self.closed then return end
    if !isnumber(num) and num != nil then error("bad argument #1 to 'Read' (number expected, got " .. type(num) .. ")") end
    num = num or "*all"
    return self.file:read(num)
end

function fm:Write(str)
    if self.closed then return end
    if !isstring(str) then return false end
    return self.file:write(str) and true or false
end

function fm:ReadLine()
    if self.closed then return end
    local chars = {}

    for i = 1, 8191 do
        local char = self.file:read(1)

        if char == nil then break end

        table.insert(chars, char)

        if char == "\n" then break end
    end

    if #chars == 0 then return nil end
    return table.concat(chars)
end

function fm:WriteBool(bool)
    if self.closed then return end

    if bool then
        return self.file:write("\x01") and true or false
    else
        return self.file:write("\x00") and true or false
    end
end

function fm:ReadBool()
    if self.closed then return end

    local res = self:Read(1)
    if !res then return nil end

    return res != "\x00"
end

function fm:WriteByte(byte)
    if self.closed then return end
    if !isnumber(byte) and byte != nil then error("bad argument #1 to 'WriteByte' (number expected, got " .. type(byte) .. ")") end

    return self:Write(string.char(byte % 256))
end

function fm:ReadByte()
    if self.closed then return end

    local res = self:Read(1)
    if !res then return nil end

    return string.byte(res)
end

local pack = {
    double = "<d",
    float = "<f",
    long = "<i4",
    short = "<i2",
    uint64 = "<I8",
    ulong = "<I4",
    ushort = "<I2",
}

local function write_size(f, num, size, type)
    if f.closed then return end

    if !isnumber(num) then
        f:WriteByte(0)
        return true
    end

    if string.pack then
        return f:Write(string.pack(pack[type], num))
    end

    local s = ffi_structs[type]
    if s then
        s.v = num

        local str = {}
        for i = 0, size - 1 do
            table.insert(str, string.char(s.b[i]))
        end

        return f:Write(table.concat(str))
    end

    return false
end

local function read_size(f, size, type)
    if f.closed then return end

    local res = f:Read(size)
    if !res then return nil end

    if string.unpack then
        while string.len(res) < size do
            res = res .. "\x00"
        end

        local r = string.unpack(pack[type], res)
        return r
    end

    local s = ffi_structs[type]
    if s then
        for i = 1, size do
            s.b[i - 1] = string.byte(res, i, i) or 0
        end

        return s.v
    end

    return nil
end

function fm:WriteDouble(num)
    return write_size(self, num, 8, "double")
end

function fm:ReadDouble()
    return read_size(self, 8, "double")
end

function fm:WriteFloat(num)
    return write_size(self, num, 4, "float")
end

function fm:ReadFloat()
    return read_size(self, 4, "float")
end

function fm:WriteLong(num)
    return write_size(self, num, 4, "long")
end

function fm:ReadLong()
    return read_size(self, 4, "long")
end

function fm:WriteShort(num)
    return write_size(self, num, 2, "short")
end

function fm:ReadShort()
    return read_size(self, 2, "short")
end

function fm:WriteUInt64(num)
    return write_size(self, num, 8, "uint64")
end

function fm:ReadUInt64()
    return read_size(self, 8, "uint64")
end

function fm:WriteULong(num)
    return write_size(self, num, 4, "ulong")
end

function fm:ReadULong()
    return read_size(self, 4, "ulong")
end

function fm:WriteUShort(num)
    return write_size(self, num, 2, "ushort")
end

function fm:ReadUShort()
    return read_size(self, 2, "ushort")
end

local mode_allowed = {"r", "w", "a", "rb", "wb", "ab"}

function file.Open(name, mode, gamepath)
    if !isstring(name) then error("bad argument #1 to 'Open' (string expected, got " .. type(name) .. ")") end
    if !isstring(mode) then error("bad argument #2 to 'Open' (string expected, got " .. type(mode) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #3 to 'Open' (string expected, got " .. type(gamepath) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return nil end
    if !validate(name, gamepath) then return nil end

    if name == "" then return nil end
    if !table.HasValue(mode_allowed, mode) then error("Invalid read mode '" .. mode .. "'!") end

    if restrict_write and (gamepath != "DATA" and gamepath != "ROOT") and string.find(string.lower(mode), "w") then
        return nil
    end

    if dir_raw(paths[gamepath] .. name) then
        return nil
    end

    local file = io.open(paths[gamepath] .. name, mode)
    if !file then return nil end

    local f = { file = file}
    setmetatable(f, fm)

    return f
end

function file.Append(name, content, path)
	local f = file.Open( name, "ab", path or "DATA" )
	if !f then return false end

	f:Write(content)
	f:Close()

	return true
end


function file.Read(name, path)
    if path == true then path = "GAME" end
    if path == nil or path == false then path = "DATA" end

    local f = file.Open(name, "rb", path)
    if !f then return end

    local str = f:Read()
    f:Close()

    return str or ""
end

function file.Write(name, content, path)
    local f = file.Open(name, "wb", path or "DATA")
    if !f then return false end

    f:Write(content)
    f:Close()

    return true
end

function file.Size(name, path)
    local f = file.Open(name, "rb", path)
    if !f then return -1 end

    local size = f:Size()
    f:Close()

    return size
end

function file.Time(filename, path)
    if !initialize(path) then return end
    if !lfs then return end
    if !file.Exists(filename, path) then return 0 end

    return lfs.attributes(paths[path] .. filename, "modification")
end

local function match(pattern, str)
    local patterns = string.Split(pattern, "*")
    local cur = 0

    for k,v in pairs(patterns) do
        local start, ends = string.find(str, v, cur, true)
        if !start or start < cur then return false end

        // start and end have to match exactly unless there is a wildcard
        if k == 1 and start != 1 then return false end
        if k == #patterns and v != "" and ends != string.len(str) then return false end

        if ends > cur then
           cur = ends
        end
    end

    return true
end

local find_sortings = {"nameasc", "namedesc", "dateasc", "datedesc"}

function file.Find(name, gamepath, sorting)
    if !isstring(name) then error("bad argument #1 to 'Find' (string expected, got " .. type(name) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'Find' (string expected, got " .. type(gamepath) .. ")") end
    if !isstring(sorting) and sorting != nil then error("bad argument #3 to 'Find' (string expected, got " .. type(sorting) .. ")") end

    gamepath = gamepath and string.upper(gamepath) or gamepath_default
    if !initialize(gamepath) then return {}, {} end
    if !validate(name, gamepath) then return end

    if !lfs then return end

    local sort = "nameasc"
    if table.HasValue(find_sortings, sorting) then sort = sorting end
    local sort_name = string.find(sort, "name")
    local sort_asc = string.find(sort, "asc")

    local dirs = {}
    local files = {}

    local p1 = string.match(name, ".*/")    // part before last /
    local p2 = string.sub(name, string.len(p1 or "") + 1)   // part after last /
    local dir = paths[gamepath] .. (p1 or ".")

    if !dir_raw(dir) then return dirs, files end

    local list = {}

    for file in lfs.dir(dir) do
        if file == "." or file == ".." then continue end

        if !match(p2, file) then continue end

        local f = dir .. "/" .. file
        local attr = lfs.attributes (f)

        if attr.mode != "directory" and attr.mode != "file" then continue end

        table.insert(list, {
            file = file,
            dir = attr.mode == "directory",
            date = attr.modification
        })
    end

    table.SortByMember(list, sort_name and "file" or "date", sort_asc and true or false)

    for k,v in pairs(list) do
        if v.dir then
            table.insert(dirs, v.file)
        else
            table.insert(files, v.file)
        end
    end

    return files, dirs
end


FSASYNC_ERR_FAILURE     = -5
FSASYNC_ERR_NOMEMORY    = -3
FSASYNC_ERR_FILEOPEN    = -1
FSASYNC_OK              = 0

function file.AsyncRead(filename, gamepath, callback, sync)
    if !isstring(filename) then error("bad argument #1 to 'AsyncRead' (string expected, got " .. type(filename) .. ")") end
    if !isstring(gamepath) and gamepath != nil then error("bad argument #2 to 'AsyncRead' (string expected, got " .. type(gamepath) .. ")") end
    if !isfunction(callback) then error("bad argument #3 to 'AsyncRead' (function expected, got " .. type(callback) .. ")") end
    if !isbool(sync) and sync != nil then error("bad argument #4 to 'AsyncRead' (bool expected, got " .. type(sync) .. ")") end

    gamepath = gamepath or gamepath_default

    if !async.Init() then
        callback(filename, gamepath, -5, "")
        return -5
    end

    local f = file.Open(filename, "rb", gamepath)
    if !f then
        callback(filename, gamepath, -1, "")
        return 0
    end

    async.Add(function()
        local file_content = {}

        while true do
            local chunk = f:Read(8192)
            if not chunk then break end
            table.insert(file_content, chunk)

            if !sync then
                async.Sleep(0) // yield control back to the event loop
            end
        end

        f:Close()

        local str = ""
        local ok, err = pcall(function()
            str = table.concat(file_content)
        end)

        local e = err == "not enough memory" and -3 or -5

        callback(filename, gamepath, err and e or 0, str)
    end)

    return 0
end


