require("glua")

function callback(req)
    print("got request:")
    PrintTable(req)

    local body = "method: " .. req.method .. "\npath: " .. req.path .. "\nbody: " .. req.body .. "\n"
    return { status = 200, body = body }
end

function err(e)
    print("error:")
    PrintTable(e)
end

http.Server({
    host = "0.0.0.0",
    port = 80,
    onrequest = callback,
    onerror = err
})

async.Loop()
