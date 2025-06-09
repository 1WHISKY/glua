## glua
glua adds functionality provided by [Garry's Mod](https://wiki.facepunch.com/gmod/) into plain lua.  
Syntax changes like `!=` are implemented by patching the lua source.  
Functions are implemented using lua code or by using existing lua modules (installed with luarocks).  
  
glua is modular and does not strictly require any module to function.  
If you don't need HTTP functionality you can comment out the `luarocks install http` line in the Dockerfile.  

## Getting started
1. Clone the repo
```bash
git clone https://github.com/1WHISKY/glua.git
cd glua
```

2. Build the image
```bash
docker build . -t glua
docker build . -f Dockerfile.full -t glua:full    # if you need gui functionality
```

3. Run your lua script
```bash
docker run --rm -it -v $PWD:/app:ro -w /app glua examples/timers.lua
```

## Documentation
See the [wiki](../../wiki) for details about ported functions and added functionality, aswell as how to use each function.

## Examples
For more examples see the [examples/](examples) folder

Timers
```lua
require("glua")

timer.Create("timer_1", 1, 5, function()
  print(CurTime(), "Timer")
end)

timer.Simple(2, function()
  print(CurTime(), "Simple timer")
end)

print("Running timers...")
async.Loop()
```

```
Running timers...
1.0038908909992 Timer
2.0038770259998 Simple timer
2.0038975559983 Timer
3.003874140999  Timer
4.0038734689988 Timer
5.0038706269988 Timer
```
  
Echo Webserver
```lua
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
```
