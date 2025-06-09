require("glua")

local ws = http.WebSocket("wss://echo.websocket.org/", {
    onerror = function(err)
        print("Error: ")
        PrintTable(err)
    end,

    onclose = function(ws, code, message)
        print("Closed: ", code, message)
    end,

    onmessage = function(ws, msg, type)
        print("Received: \"" .. msg .. "\" type: " .. type) -- type is "text" or "binary"
    end,

    onconnect = function(ws, headers, status)
        print("Connected: ", status)

        ws:Send("Hello!")
    end,
})

timer.Simple(2, function()
    ws:Send("Goodbye!")
    ws:Close()
end)

async.Loop()
