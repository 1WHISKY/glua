require("glua")

http.Fetch("https://example.com",
    function(body, size, headers, code) --onSuccess
        print("Success:")
        print("Code: " .. code)
        print("Size: " .. size)
        print("Headers:")
        PrintTable(headers)
        print("Body: ")
        print(body)
    end,

    function(err) --onFailure
        print("Error:")
        print(err)
    end,

    { --headers to send
        ["accept-language"] = "en"
    }
)

async.Loop()
