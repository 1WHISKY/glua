http = http or {}

local initialized = false
local init_success = false
local http_request
local http_cookie


local zlib_initialized = false
local zlib

local http_server
local http_headers

local ws
local ws_initialized = false

local ws_server
local ws_server_initialized = false

local server_initialized
local http_tls, openssl_pkey, openssl_x509, openssl_x509_chain

local headers_as_tables = false

local empty_tbl = {}
local empty_fun = function() end
local empty_fun_true = function() return true end
local empty_str = ""

local ua


// websocket meta
local wm = {}
wm.__index = wm

function wm:IsClosed()
    if self.closed or self.ws.readyState > 1 then return true end
    return false
end

function wm:IsConnected()
    return self.connected and !self:IsClosed() and self.ws.readyState == 1
end

function wm:Close(code, reason)
    if code != nil and !isnumber(code) then error("bad argument #1 to 'Close' (number expected, got " .. type(code) .. ")") end
    if reason != nil and !isstring(reason) then error("bad argument #2 to 'Close' (string expected, got " .. type(reason) .. ")") end
    if !self:IsConnected() then return false, "socket is not connected" end

    self.closed = true

    return pcall( function() self.ws:close(code, reason) end)
end

function wm:Send(msg, type1)
    if !isstring(msg) then error("bad argument #1 to 'Send' (string expected, got " .. type(msg) .. ")") end
    if type1 != nil and !isstring(type1) then error("bad argument #2 to 'Send' (string expected, got " .. type(type1) .. ")") end
    if !self:IsConnected() then return false, "socket is not connected" end

    return self.ws:send(msg, type1)
end



function HTTP(params)
    if !istable(params) then error("bad argument #1 to 'HTTP' (table expected, got " .. type(params) .. ")") end


    if !initialized then
        local ok, res = pcall(require, "http.request")

        if ok then
            init_success = true
            http_request = res
        else
            init_success = false
            ErrorNoHalt("http: failed to load http.request module. all http calls will fail! error: ", res, "\n")
        end

        initialized = true
    end

    local params_failed = params.failed
    local params_success = params.success
    local params_url = params.url
    local params_headers = params.headers
    local params_type = params.type
    local params_method = params.method
    local params_timeout = params.timeout

    if !isfunction(params.failed) then params_failed = empty_fun end
    if !isfunction(params.success) then params_success = empty_fun end
    if !isstring(params.method) then params_method = "GET" end
    if !isstring(params.url) then params_url = empty_str end
    if !istable(params.headers) then params_headers = empty_tbl end
    if !isstring(params.type) then params_type = nil end
    if !isnumber(params.timeout) then params_timeout = nil end


    if !init_success then
        params_failed("Error initializing http module")
        return true // return true here so http.Fetch doesnt call the fail function again
    end

    if params.sync != true and !async.Init() then
        params_failed("Error during async initialization")
        return true
    end



    local do_request = function()
        if !isstring(params.body) and params.parameters and istable(params.parameters) then
            if string.lower(params_method) == "post" then
                params.body = ""
                for k,v in pairs(params.parameters) do
                    if !isstring(k) or !isstring(v) then continue end
                    params.body = params.body .. k .. "=" .. v .. "&"
                end

                params_type = "application/x-www-form-urlencoded"
            else
                params_url = params_url .. "?"
                for k,v in pairs(params.parameters) do
                    if !isstring(k) or !isstring(v) then continue end
                    params_url = params_url .. k .. "=" .. v .. "&"
                end

                params_url = string.sub(params_url, 1, -2) // remove last &
           end
        end


        local ok, request = pcall(http_request.new_from_uri, params_url)

        if !ok then
            params_failed("Error: " .. tostring(request))
            return
        end



        for k,v in pairs(params_headers) do
            if !isstring(k) then continue end
            k = string.lower(k)

            if headers_as_tables then
                if !istable(v) and !isstring(v) then continue end

                if isstring(v) then
                    request.headers:upsert(k, v)
                    continue
                end

                for a, b in pairs(v) do
                    request.headers:append(k, b)
                end

            else
                if !isstring(v) then continue end
                request.headers:upsert(k, v)
            end
        end

        if isstring(params.body) then request:set_body(params.body) end
        if ua then request.headers:upsert("user-agent", ua) end
        if params.dont_follow then request.follow_redirects = false end
        request.headers:upsert(":method", params_method and string.upper(params_method) or "GET")
        request.headers:upsert("content-type", params_type or params_headers["Content-Type"] or params_headers["content-type"] or "text/plain; charset=utf-8")
        request.cookie_store = params.jar or nil

        local ok, ret_headers, stream = pcall(function() return request:go(params_timeout or 60) end)

        if !ok then
            params_failed(ret_headers)
            return
        end

        if !ret_headers then
            params_failed(stream)
            return
        end

        local decompress = false

        local h = {}
        for name, value in ret_headers:each() do
            if string.sub(name, 1, 1) == ":" then continue end
            if (params.decompress or params.decompress == nil) and string.lower(name) == "content-encoding" then    // decompress by default if the response is compressed
                // only gzip deflate is supported, raw deflate is not, but we cant tell the difference so we just attempt it anyways
                if string.find(value, "gzip") or string.find(value, "deflate") then
                    decompress = true
                end
            end

            if headers_as_tables then
                h[name] = h[name] or {}
                table.insert(h[name], value)
            else
                h[name] = value
            end

        end

        local body, err = stream:get_body_as_string()
        if !body then
            params_failed(err)
            return
        end

        if decompress then
            if !zlib_initialized then
                local ok, lib = pcall(require, "http.zlib")
                if ok then
                   zlib = lib
                else
                    print("http: warning: failed to load http.zlib module: " .. lib)
                end

                zlib_initialized = true
            end

            if !zlib then
                params_failed("decompression was requested but loading the http.zlib module failed. try passing decompress = false.")
                return
            end

            local inflate = zlib.inflate()
            local ok, b = pcall(inflate, body, true)

            if ok then
                body = b
            else
                params_failed("decompression error: " .. b)
                return
            end

        end

        params_success(tonumber(ret_headers:get(":status")), body, h)
        return
    end


    if params.sync then
        local ok, err = pcall(do_request)
        if !ok then
            params_failed(err)
        end
    else
        async.Add(function()
            local ok, err = pcall(do_request)
            if !ok then
                params_failed(err)
            end
        end)
    end

    return true
end


function http.SetUserAgent(agent)
    if !isstring(agent) and agent != nil then error("bad argument #1 to 'SetUserAgent' (string expected, got " .. type(agent) .. ")") end
    ua = agent
end


function http.FetchSync(...)
    return call_sync(http.Fetch, ...)
end

function http.PostSync(...)
    return call_sync(http.Post, ...)
end

function http.HeadersAsTables(enable)
    if !isbool(enable) then error("bad argument #1 to 'HeadersAsTables' (boolean expected, got " .. type(enable) .. ")") end
    headers_as_tables = enable
end



local function fetch(url, onsuccess, onfailure, header, method, params, sync, cookies)
    local b, c, h

    local req = {
        url         = url,
        method      = method or "get",
        headers     = header or {},
        parameters  = params,
        sync = sync,
        jar = cookies,

        success = function(code, body, headers)
            b = body
            c = code
            h = headers

            if !onsuccess then return end
            onsuccess(body, body:len(), headers, code)
        end,

        failed = function(err)
            if !onfailure then return end
            onfailure(err)
        end
    }

    local success = HTTP(req)
    if !success and onfailure then onfailure("HTTP failed") end

    return b, c, h  // in case its sync
end

function http.FetchSync(url, onsuccess, onfailure, header)
    return fetch(url, onsuccess, onfailure, header, "get", nil, true)
end

function http.PostSync(url, params, onsuccess, onfailure, header)
    return fetch(url, onsuccess, onfailure, header, "post", params, true)
end

function http.CookieJar()
    if !http_cookie then
        http_cookie = require("http.cookie")
    end

    local jar = http_cookie.new_store()

    // for some reason automatically storing cookies is broken in lua-http (or im using it wrong)
    local mt = getmetatable(jar)
    local store = mt.__index.store
    mt.__index.store = function(self, req_domain, req_path, req_is_http, req_is_secure, req_site_for_cookies, name, value, params)
                   return store(self, req_domain, req_path, req_is_http, req_is_secure, req_domain          , name, value, params)    // see lua-http/cookie.lua:444
    end

    return jar
end

function http.Session()
    local ret = {}
    ret.jar = http.CookieJar()

    ret.Fetch = function(url, onsuccess, onfailure, header)
        return fetch(url, onsuccess, onfailure, header, "get", nil, false, ret.jar)
    end

    ret.FetchSync = function(url, onsuccess, onfailure, header)
        return fetch(url, onsuccess, onfailure, header, "get", nil, true, ret.jar)
    end

    ret.Post = function(url, params, onsuccess, onfailure, header)
        return fetch(url, onsuccess, onfailure, header, "post", params, false, ret.jar)
    end

    ret.PostSync = function(url, params, onsuccess, onfailure, header)
        return fetch(url, onsuccess, onfailure, header, "post", params, true, ret.jar)
    end

    return ret
end

---------- server

local function isLocalAddress(ip)
    if !isstring(ip) then return false end

    local split4 = string.Split(ip, ".")
    if #split4 == 4 then
        for k,v in pairs(split4) do // valid ip?
            local num = tonumber(v)
            if !num or num < 0 or num > 255 then return false end

            split4[k] = num
        end

        if split4[1] == 10 then return true end
        if split4[1] == 127 then return true end
        if split4[1] == 172 and split4[2] >= 16 and split4[2] <= 31 then return true end
        if split4[1] == 192 and split4[2] == 168 then return true end
        return false
    end

    local split6 = string.Split(ip, ":")
    if #split6 > 8 or #split6 < 3 then return false end

    for k,v in pairs(split6) do // valid ip?
        local num = tonumber(v, 16)
        if v == "" then num = 0 end

        if !num or num < 0 or num > 0xffff then return false end
        split6[k] = num
    end

    if split6[1] == 0xfe80 then return true end
    if split6[1] >= 0xfc00 and split6[1] <= 0xfdff then return true end

    for k,v in pairs(split6) do //::1 or 0:0:0::1
        if k != #split6 and v != 0 then break end
        if k == #split6 and v == 1 then return true end
    end

    return false
end

function http.Server(settings)
    if !istable(settings) then error("bad argument #1 to 'Server' (table expected, got " .. type(settings) .. ")") end

    local host =        isstring(settings.host)         and settings.host       or "127.0.0.1"
    local port =        isnumber(settings.port)         and settings.port       or 0
    local path =        isstring(settings.path)         and settings.path       or nil
    local onrequest =   isfunction(settings.onrequest)  and settings.onrequest  or empty_fun
    local onerror =     isfunction(settings.onerror)    and settings.onerror    or nil

    local proxyheader = isstring(settings.proxyheader) and string.lower(settings.proxyheader)    or nil
    local trustedproxies = istable(settings.trustedproxies) and settings.trustedproxies or empty_tbl
    local trustlocalproxies = settings.trustlocalproxies or settings.trustlocalproxies == nil

    local wants_ws = istable(settings.websocket) and true or false
    local ws = istable(settings.websocket) and settings.websocket or empty_tbl
    local ws_onclose = isfunction(ws.onclose) and ws.onclose or empty_fun
    local ws_onerror = isfunction(ws.onerror) and ws.onerror or empty_fun
    local ws_onmessage = isfunction(ws.onmessage) and ws.onmessage or empty_fun
    local ws_onconnect = isfunction(ws.onconnect) and ws.onconnect or empty_fun
    local ws_onrequest = isfunction(ws.onrequest) and ws.onrequest or empty_fun_true
    local ws_path = isstring(ws.path) and ws.path or nil


    if !async.Init() then
        ErrorNoHalt("http_server: error initializing the async system", "\n")
        return
    end

    if !server_initialized then
        local ok, server = pcall(require, "http.server")
        local ok2, headers = pcall(require, "http.headers")

        if !ok then
            ErrorNoHalt("http_server: failed to load http.server module: ", server, "\n")
            return
        end

        if !ok2 then
            ErrorNoHalt("http_server: failed to load http.headers module: ", headers, "\n")
            return
        end

        http_server = server
        http_headers = headers

        server_initialized = true
    end


    local reply = function(srv, stream)
        local req = {}
        local h = stream:get_headers()

        if !h then return end

        stream.req = req    // add as much info to the stream for error handling
        req.headers = {}

        local h_host = h:get(":authority")
        if h_host then h:upsert("host", h_host) end

        for k,v in h:each() do
            if string.sub(k, 1, 1) == ":" then continue end
            k = string.lower(k)

            if headers_as_tables then
                req.headers[k] = req.headers[k] or {}
                table.insert(req.headers[k], v)
            else
                req.headers[k] = v
            end

        end

        local _, src_ip, src_port = stream.connection:peername()
        req.src_ip = src_ip
        req.src_port = src_port
        req.method = h:get(":method")
        req.useragent = h:get("user-agent")
        req.path = h:get(":path")
        req.scheme = h:get(":scheme")
        req.body = stream:get_body_as_string()
        req.version = stream.connection.version
        req.referer = h:get("referer")
        req.host = h_host

        // check if this comes from a reverse proxy
        if proxyheader and ((trustlocalproxies and isLocalAddress(src_ip)) or (trustedproxies != empty_tbl and table.HasValue(trustedproxies, src_ip))) then
            local real_ip = h:get(proxyheader)
            req.src_ip = real_ip or src_ip
        end

        // handle ws
        if wants_ws and (ws_path == nil or string.Trim(ws_path, "/") == string.Trim(req.path, "/")) then

            if !ws_server_initialized then
                ws_server_initialized = true

                local ok, res = pcall(require, "http.websocket")

                if !ok then
                    ErrorNoHalt("http_server: error loading websocket module: ", res, "\n")
                else
                    ws_server = res
                end
            end

            if !ws_server then
               return
            end

            local function onerror(...)
                pcall(ws_onerror, ...)
            end

            local function onrequest(req)
                local ok, res1, res2 = pcall(ws_onrequest, req)

                if !ok then
                    local e = {}
                    e.error = res1
                    e.error_function = "onrequest"
                    e.server = srv
                    e.request = req
                    e.stream = stream

                    onerror(e)
                    return false
                end

                return res1, res2
            end

            local allow, headers = onrequest(req)
            if !istable(headers) then headers = empty_tbl end

            if !allow then
                if stream.state == "idle" then
                    return
                end

                local res_headers = http_headers.new()
                res_headers:upsert(":status", "403")
                stream:write_headers(res_headers, true)

                return
            end

            local ws = ws_server.new_from_stream(stream, h)

            if ws then
                local res_headers = http_headers.new()

                for k,v in pairs(headers) do
                    if !isstring(k) then continue end
                    k = string.lower(k)

                    if headers_as_tables then
                        if !istable(v) and !isstring(v) then continue end

                        if isstring(v) then
                            res_headers:append(k, v)
                            continue
                        end

                        for a, b in pairs(v) do
                            res_headers:append(k, b)
                        end

                    else
                        if !isstring(v) then continue end
                        res_headers:append(k, v)
                    end
                end

                local t = {}
                setmetatable(t, wm)
                t.ws = ws
                t.request = req

                local function onclose(t, ...)
                    local ok, err = pcall(ws_onclose, t, ...)

                    if !ok then
                        local e = {}
                        e.error = err
                        e.error_function = "onclose"
                        e.server = srv
                        e.request = {t, ...}
                        e.stream = stream

                        onerror(e)
                    end
                end

                local function onmessage(t, ...)
                    local ok, err = pcall(ws_onmessage, t, ...)

                    if !ok then
                        local e = {}
                        e.error = err
                        e.error_function = "onmessage"
                        e.server = srv
                        e.request = {t, ...}
                        e.stream = stream

                        onerror(e)
                    end
                end

                local function onconnect(t, ...)
                    local ok, err = pcall(ws_onconnect, t, ...)

                    if !ok then
                        local e = {}
                        e.error = err
                        e.error_function = "onconnect"
                        e.server = srv
                        e.request = {t, ...}
                        e.stream = stream

                        onerror(e)
                    end
                end

                local ok, msg, code = ws:accept({headers = res_headers})

                if !ok then
                    local e = {}
                    e.error = msg
                    e.code = code
                    e.error_function = "http.websocket:accept"
                    e.server = srv
                    e.request = {t, res_headers}
                    e.stream = stream

                    onerror(e)
                    onclose(t)
                    return
                end

                t.connected = true
                onconnect(t, req)

                //async.Add(function()
                    while true do
                        local data, msg, code = ws:receive()

                        if !data then
                            pcall(function() t.ws:close() end)
                            onclose(t, code, msg)
                            t.closed = true
                            break
                        end

                        onmessage(t, data, msg) //msg = type (text or binary)
                    end
                //end)

                return  // this request has been handled, no need to send a normal response
            end
        end


        // this is not a ws endpoint (or request), handle normal request
        local res = onrequest(req)

        if stream.state == "idle" then
            return
        end

        local status = tostring(res.status or 200)
        local headers = res.headers

        if !istable(res.headers)    then headers = empty_tbl end
        if !isnumber(res.status)    then status = "200" end

        local res_headers = http_headers.new()
        res_headers:upsert(":status", status)

        for k,v in pairs(headers) do
            if !isstring(k) then continue end
            k = string.lower(k)

            if headers_as_tables then
                if !istable(v) and !isstring(v) then continue end

                if isstring(v) then
                    res_headers:append(k, v)
                    continue
                end

                for a, b in pairs(v) do
                    res_headers:append(k, b)
                end

            else
                if !isstring(v) then continue end
                res_headers:append(k, v)
            end
        end

        res_headers:upsert("content-type", res.contenttype or "text/html")

        stream:write_headers(res_headers, !isstring(res.body))
        if isstring(res.body) then
            stream:write_chunk(res.body, true)
        end
    end

    local onerr = function(srv, stream, errorfun, errorstr)
        if errorfun == "accept" then
            error("accept: " .. tostring(errorstr))  // if we dont error out here the server will call the onerror function in a infinite loop
        end

        if onerror == nil then return end

        local params = {
            error = errorstr,
            error_function = errorfun,
            request = istable(stream) and stream.req or nil,
            server = srv,
            stream = stream
        }

        if istable(stream) then
            stream.req = nil    // we added that one during the request
        end

        local ok ,err = pcall(onerror, params)

        if !ok then
           print("error during http.Server onerror callback for server " .. tostring(srv) .. ": " .. err)
        end
    end

    //tls
    local ctx
    if istable(settings.tls) and isstring(settings.tls.key_file) and isstring(settings.tls.cert_file) then
        if !http_tls then
            local ok1, r1 = pcall(require, "http.tls")
            local ok2, r2 = pcall(require, "openssl.pkey")
            local ok3, r3 = pcall(require, "openssl.x509")
            local ok4, r4 = pcall(require, "openssl.x509.chain")

            if !ok1 or !ok2 or !ok3 or !ok4 then
                ErrorNoHalt("error importing tls module: ", ((!ok1 and r1) or (!ok2 and r2) or (!ok3 and r3) or (!ok4 and r4)), "\n" )
                return
            end

            http_tls = r1
            openssl_pkey = r2
            openssl_x509 = r3
            openssl_x509_chain = r4
        end

        local pkey = file.Read(settings.tls.key_file, "MOD")

        if !pkey then
            ErrorNoHalt("Error loading tls private key file \"", settings.tls.key_file, "\".\n")
            return
        end

        local cert = file.Read(settings.tls.cert_file, "MOD")

        if !cert then
            ErrorNoHalt("Error loading tls cert file \"", settings.tls.cert_file, "\".\n")
            return
        end

        ctx = http_tls.new_server_context()
        local key = openssl_pkey.new(pkey)
        local chain = openssl_x509_chain.new()

        local certs = string.Split(cert, "-----END CERTIFICATE-----")

        for k,v in pairs(certs) do
            if string.len(v) < 54 then  // length of start certificate + end certificate
                certs[k] = nil
                break
            end

            certs[k] = openssl_x509.new(v .. "-----END CERTIFICATE-----")
            chain:add(certs[k])
        end

        local ok, err = ctx:setPrivateKey(key)

        if !ok then
            ErrorNoHalt("TLS error: ctx:setPrivateKey: ", err, "\n")
            return
        end

        local ok, err = ctx:setCertificate(certs[1])

        if !ok then
            ErrorNoHalt("TLS error: ctx:setCertificate: ", err, "\n")
            return
        end

        if #certs > 1 then
            local ok, err = ctx:setCertificateChain(chain)

            if !ok then
                ErrorNoHalt("TLS error: ctx:setCertificateChain: ", err, "\n")
                return
            end
        end
    end

    local srv = http_server.listen({
        host = host,
        port = port,
        path = path,
        onstream = reply,
        onerror = onerr,
        tls = settings.tls and true or false,
        ctx = ctx
    })

    srv:listen()

    async.Add(function()
        local ok, err = srv:loop()

        if !ok then
           onerr(srv, nil, "loop", err)
        end
    end)

    return srv
end

function http.CloseServer(srv)
    return srv:close()
end


--- ws
function http.WebSocket(host, cb, headers, cookiejar)
    if !isstring(host) then error("bad argument #1 to 'WebSocket' (string expected, got " .. type(host) .. ")") end
    if cb != nil and !istable(cb) then error("bad argument #2 to 'WebSocket' (table expected, got " .. type(cb) .. ")") end
    if headers != nil and !istable(headers) then error("bad argument #3 to 'WebSocket' (table expected, got " .. type(headers) .. ")") end
    if cookiejar != nil and !istable(cookiejar) then error("bad argument #4 to 'WebSocket' (table expected, got " .. type(cookiejar) .. ")") end

    if !ws_initialized then
        ws_initialized = true

        local ok, res = pcall(require, "http.websocket")
        local ok2, res2 = pcall(require, "http.headers")

        if !async.Init() then
           ok = false
           res = "error initializing async system"
        end

        if !ok2 then
            ws_initialized = res2
        else
            http_headers = res2
        end

        if !ok then
            ws_initialized = res
        else
            ws = res
        end

        if !ok2 then
           ws = nil
        end
    end

    local ws_onclose = istable(cb) and isfunction(cb.onclose) and cb.onclose or empty_fun
    local ws_onerror = istable(cb) and isfunction(cb.onerror) and cb.onerror or empty_fun
    local ws_onmessage = istable(cb) and isfunction(cb.onmessage) and cb.onmessage or empty_fun
    local ws_onconnect = istable(cb) and isfunction(cb.onconnect) and cb.onconnect or empty_fun

    local function onerror(...)
        pcall(ws_onerror, ...)
    end

    local function onclose(t, ...)
        local ok, err = pcall(ws_onclose, t, ...)

        if !ok then
            local e = {}
            e.error = err
            e.error_function = "onclose"
            e.server = t
            e.request = {t, ...}
            e.stream = t.ws.socket

            onerror(e)
        end
    end

    local function onmessage(t, ...)
        local ok, err = pcall(ws_onmessage, t, ...)

        if !ok then
            local e = {}
            e.error = err
            e.error_function = "onmessage"
            e.server = t
            e.request = {t, ...}
            e.stream = t.ws.socket

            onerror(e)
        end
    end

    local function onconnect(t, ...)
        local ok, err = pcall(ws_onconnect, t, ...)

        if !ok then
            local e = {}
            e.error = err
            e.error_function = "onconnect"
            e.server = t
            e.request = {t, ...}
            e.stream = t.ws.socket

            onerror(e)
        end
    end

    local t = {}
    t.ws = {}
    t.host = host
    setmetatable(t, wm)

    if !ws then
        local e = {}
        e.error = "error loading websocket modules: " .. ws_initialized
        e.error_function = "http.WebSocket"
        e.server = t

        onerror(e)
        onclose(t)
        return
    end


    async.Add(function()
        local ok, res = pcall(ws.new_from_uri, host)

        if !ok then
            local e = {}
            e.error = res
            e.error_function = "http.websocket.new_from_uri"
            e.server = t
            e.stream = t.ws.socket

            onerror(e)
            onclose(t)
            return
        end

        t.ws = res

        if headers then
            for k,v in pairs(headers) do
                if !isstring(k) then continue end
                k = string.lower(k)

                if headers_as_tables then
                    if !istable(v) and !isstring(v) then continue end

                    if isstring(v) then
                        t.ws.request.headers:upsert(k, v)
                        continue
                    end

                    for a, b in pairs(v) do
                        t.ws.request.headers:append(k, b)
                    end

                else
                    if !isstring(v) then continue end
                    t.ws.request.headers:upsert(k, v)
                end
            end
        end

        if ua then t.ws.request.headers:upsert("user-agent", ua) end
        t.ws.request.cookie_store = cookiejar

        local ok, msg, code = t.ws:connect()

        if !ok then
            t.closed = true

            local e = {}
            e.error = msg
            e.code = code
            e.error_function = "http.websocket:connect"
            e.server = t
            e.request = t.ws.request
            e.stream = t.ws.socket

            onerror(e)
            onclose(t)
            return
        end

        t.connected = true

        local h = {}
        for name, value in t.ws.headers:each() do
            if string.sub(name, 1, 1) == ":" then continue end

            if headers_as_tables then
                h[name] = h[name] or {}
                table.insert(h[name], value)
            else
                h[name] = value
            end

        end

        onconnect(t, h, tonumber(t.ws.headers:get(":status")))

        while true do
            local data, msg, code = t.ws:receive()

            if !data then
                pcall(function() t.ws:close() end)  // just to make sure
                onclose(t, code, msg)
                t.closed = true
                break
            end

            onmessage(t, data, msg) //msg = type (text or binary)
        end

    end )

    return t
end

