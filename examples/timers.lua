require("glua")

timer.Create("timer_1", 1,5,function() print(CurTime(), "Timer") end)
timer.Simple(2, function() print(CurTime(), "Simple timer") end)

print("Running timers...")
async.Loop()
