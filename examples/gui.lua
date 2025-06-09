require("glua")

-- We call this function here just to check if the gui system can be successfully initialzed
local ok, err = surface.SetDrawColor(255,255,255,255)

if !ok then
    print("Error initializing the GUI system, check the wiki for more info!")
    print(err)
end

gui.SetMaxFPS(144)


local w = 100
local h = 100
local x = (ScrW() / 2) - (w / 2)
local y = (ScrH() / 2) - (h / 2)

local grabbed = false
local grabbed_x = 0
local grabbed_y = 0
local m1_last = false

hook.Add("HUDPaint", "GUI", function()
    if input.IsKeyDown(KEY_ESCAPE) then
       os.exit()
    end

    local m1 = input.IsMouseDown(MOUSE_LEFT)
    local mx = gui.MouseX()
    local my = gui.MouseY()
    local in_box = mx < x + w and mx >= x and my < y + h and my >= y

    if !m1 then
        grabbed = false
    end

    if !grabbed and m1 and !m1_last and in_box then
        grabbed = true
        grabbed_x = mx - x
        grabbed_y = my - y
    end

    if grabbed then
        x = mx - grabbed_x
        y = my - grabbed_y
    end

    surface.SetDrawColor(255,255,255,255)
    surface.DrawRect(x, y, w, h)

    surface.SetFont("Default")
    surface.SetTextColor(255, 60, 60)
    surface.SetTextPos(100, 30)
    surface.DrawText("Drag the box!")

    m1_last = m1
end)

async.Loop()
