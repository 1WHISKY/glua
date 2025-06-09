require("glua")

for i = 1, 5 do
    local t = thread.New(function(id)
        local count = 1000000000 -- may need adjustment depending on you cpu

        for x = 1, count do
            if x % (count / 5) == 0 then
                local pct = ((x / count) * 100)
                if pct != 100 then
                    print("Thread " .. id .. ": " .. pct .. "%")
                end
            end
        end

        print("Thread " .. id .. " is done!")
    end, i)


    if !t then
        print("Threading is not supported!")
        os.exit()
    end
end

async.Loop() -- this also waits for all threads to be done
