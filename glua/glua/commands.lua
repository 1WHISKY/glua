local function exit()
    console.Disable()
    hook.Run("Terminate")
    hook.Run("ShutDown")
    os.exit()
end

concommand.Add("exit", exit, nil, "Exit the engine.")
concommand.Add("quit", exit, nil, "Exit the engine.")


local function lua_run(ply, cmd, args, argstr)
    RunString(argstr, "LuaCmd")
end

concommand.Add( "lua_run", lua_run, nil, "Run a Lua command" )
concommand.Add( "lua_run_cl", lua_run, nil, "Run a Lua command" )

concommand.Add( "echo", function(ply, cmd, args, argstr)
    local str = ""

    for k,v in pairs(args) do
        str = str .. v .. " "
    end

    MsgN(str)
end, nil, "Echo text to console." )
