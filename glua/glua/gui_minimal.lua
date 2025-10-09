surface = surface or {}
gui = gui or {}
draw = draw or {}
input = input or {}
system = system or {}

TEXT_ALIGN_LEFT = 0
TEXT_ALIGN_CENTER = 1
TEXT_ALIGN_RIGHT = 2
TEXT_ALIGN_TOP = 3
TEXT_ALIGN_BOTTOM = 4

if !KEY_0 then
    include("enums/buttons.lua")
end


local funcs = {
    "gui.ExitOnClose",
    "gui.SetWidth",
    "gui.SetHeight",
    "gui.SetFullscreen",
    "gui.SetMaxFPS",
    "ScrW",
    "ScrH",
    "ScreenWidth",
    "ScreenHeight",
    "surface.PlaySound",
    "surface.DrawLine",
    "surface.SetDrawColor",
    "surface.GetDrawColor",
    "surface.DrawCircle",
    "surface.DrawRect",
    "surface.DrawOutlinedRect",
    "surface.DrawPoly",
    "surface.CreateFont",
    "surface.SetFont",
    "surface.SetTextColor",
    "surface.SetTextPos",
    "surface.DrawText",
    "surface.GetTextSize",
    "Material",
    "surface.SetMaterial",
    "surface.GetTextureID",
    "surface.GetTextureNameByID",
    "surface.SetTexture",
    "surface.DrawTexturedRect",
    "surface.DrawTexturedRectRotated",
    "surface.DrawTexturedRectUV",
    "input.IsButtonDown",
    "input.IsKeyDown",
    "input.IsMouseDown",
    "gui.MouseX",
    "gui.MouseY",
    "input.GetCursorPos",
    "gui.MousePos",
    "input.StartKeyTrapping",
    "input.CheckKeyTrapping",
    "input.IsKeyTrapping",
    "input.GetKeyName",
    "input.GetKeyCode",
    "input.IsShiftDown",
    "input.IsControlDown",
    "system.BatteryPower",
}

for k, v in pairs(funcs) do
    local dot = string.find(v, ".", 1, true)

    if !dot then
        _G[v] = function() return false, "please use glua:full" end
    else
        local left = string.sub(v, 1, dot - 1)
        local right = string.sub(v, dot + 1)
        _G[left][right] = function() return false, "please use glua:full" end
     end
 end



