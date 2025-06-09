surface = surface or {}
gui = gui or {}
draw = draw or {}
input = input or {}

local sdl
local sdl_ok = false
local sdl_initialized = false

local sdl_mixer
local audio_ok = false
local audio_initialized = false
local last_error
local sounds = {}
local channels_num = 256

local gui_ok = false
local gui_initialized = false
local win
local rdr
local drawing = false
local target_frametime = 1/60 // 60 fps max
local win_width = 1280
local win_height = 720
local exit_on_close = true
local fullscreen = false

local ttf
local ttf_initialized = false
local ttf_ok = false
local fonts = {}
local font_default = "Roboto-Regular.ttf"
local font_size_default = 13

local font_active = "Default"
local font_color = { r = 255, g = 255, b = 255, a = 255}
local text_x = 0
local text_y = 0

local sdl_image
local image_initialized = false
local image_ok = false
local materials = {}
local material_active

local mousewheel_moved
local mouse_moved
local mousebutton_pressed
local key_pressed
local mouse_x = 0
local mouse_y = 0
local keys_map = {}
local buttons_state = {}
local cmd = {}
local ply = {}
local trapping = false
local trapped = nil



function gui.ExitOnClose(exit)
    exit_on_close = exit and true or false
end

function gui.SetWidth(width)
    if !isnumber(width) then error("bad argument #1 to 'SetWidth' (number expected, got " .. type(width) .. ")") end

    win_width = width

    if win then
        win:setSize(win_width, win_height)
    end
end

function gui.SetHeight(height)
    if !isnumber(height) then error("bad argument #1 to 'SetHeight' (number expected, got " .. type(height) .. ")") end

    win_height = height

    if win then
        win:setSize(win_width, win_height)
    end
end

function gui.SetFullscreen(fs)
    fullscreen = fs and true or false

    if win then
        win:setFullscreen(fullscreen and sdl.window.Fullscreen or 0)
    end
end

function gui.SetMaxFPS(fps)
    if !isnumber(fps) then error("bad argument #1 to 'SetMaxFPS' (number expected, got " .. type(fps) .. ")") end
    target_frametime = 1 / fps
end

function ScrW()
    if !win then return 0 end
    return win_width
end

function ScrH()
    if !win then return 0 end
    return win_height
end

ScreenWidth = ScrW
ScreenHeight = ScrH



local function gui_handle_events()
    for e in sdl.pollEvent() do

        if e.type == sdl.event.Quit then
            if exit_on_close then
                local res = hook.Run("Terminate")

                if res == nil then
                    hook.Run("ShutDown")
                    os.exit()
                end
            else
                win:hide()
                rdr = nil
                win = nil
            end

        elseif e.type == sdl.event.WindowEvent and e.event == sdl.eventWindow.Resized or e.event == sdl.eventWindow.SizeChanged then
            win_width =  e.data1
            win_height = e.data2
        elseif e.type == sdl.event.KeyDown and !e["repeat"] then
            //print(string.format("key down: %d -> %s", e.keysym.sym, sdl.getKeyName(e.keysym.sym)))
            key_pressed(true, e.keysym.sym)
        elseif e.type == sdl.event.KeyUp and !e["repeat"] then
            key_pressed(false, e.keysym.sym)
        elseif e.type == sdl.event.MouseWheel then
            //print(string.format("mouse wheel: %d, x=%d, y=%d", e.which, e.x, e.y))
            mousewheel_moved(e.x, e.y)
        elseif e.type == sdl.event.MouseButtonDown then
            //print(string.format("mouse button down: %d, x=%d, y=%d", e.button, e.x, e.y))
            mousebutton_pressed(true, e.button)
        elseif e.type == sdl.event.MouseButtonUp then
            mousebutton_pressed(false, e.button)
        elseif e.type == sdl.event.MouseMotion then
            //print(string.format("mouse motion: x=%d, y=%d", e.x, e.y))
            mouse_moved(e.x, e.y)
        end
    end

end

local function render_loop()
    local frames = 0
    local last = CurTime()

    while rdr do
        local frame_start = CurTime()
        frames = frames + 1

        gui_handle_events()

        rdr:setDrawColor(0x00000000)
        rdr:clear()

        drawing = true

        hook.Run("PreDrawHUD")
        hook.Run("HUDPaintBackground")
        hook.Run("HUDPaint")
        hook.Run("DrawOverlay")
        hook.Run("PostDrawHUD")

        rdr:present()

        drawing = false

        local frametime = CurTime() - frame_start
        local wait = target_frametime - frametime
        if wait < 0 then wait = 0 end

        if CurTime() - last >= 1 then
            //print("FPS: ", frames, wait)
            frames = 0
            last = CurTime()
        end

        async.Sleep(wait)
    end
end

local function init_sdl()
    if sdl_initialized then return sdl_ok end
    sdl_initialized = true

    local ok, s = pcall(require, "SDL")

    if !ok then
        last_error = s
        return false
    end

    sdl = s

    sdl_ok = true
    return true
end


local function init_audio()
    if audio_initialized then return audio_ok end
    audio_initialized = true

    if !init_sdl() then return false end

    local ok, m = pcall(require, "SDL.mixer")

    if !ok then
        last_error = m
        return false
    end

    sdl_mixer = m

    local ok, err = sdl.init({sdl.flags.Audio})
    if !ok then
        last_error = err
        return false
    end

    local ok, err = sdl_mixer.openAudio(44100, sdl.audioFormat.S16, 2, 1024)
    if !ok then
        last_error = err
        return false
    end

    sdl_mixer.allocateChannels(channels_num)

    audio_ok = true
    return true
end

local function init_gui()
    if gui_initialized then return gui_ok end
    gui_initialized = true

    if !init_sdl() then return false end

    if !async.Init() then
        last_error = "failed to initialize the async system."
        return false
    end

    local ok, err = sdl.init({sdl.flags.Video})
    if !ok then
        last_error = err
        return false
    end

    if sdl.getCurrentVideoDriver() == "offscreen" then
        last_error = "video driver is \"offscreen\""
        return false
    end

    local w, err = sdl.createWindow({
        title   = "glua",
        width   = win_width,
        height  = win_height,
        flags   = { sdl.window.Resizable, }
    })

    if !w then
        last_error = err
        return false
    end

    win = w

    timer.Simple(0.01, function()
        win:setFullscreen(fullscreen and sdl.window.Fullscreen or 0)
    end)

    local r, err
    r = sdl.createRenderer(win, -1, sdl.rendererFlags.Accelerated)
    if !r then
        r, err = sdl.createRenderer(win, -1)  // retry without acceleration

        if !r then
            last_error = err
            return false
        end
    end

    rdr = r
    rdr:setDrawBlendMode(sdl.blendMode.Blend)

    local m, err = sdl.createRGBSurface(1, 1)

    if m then
        m:fillRect({x = 0, y = 0, w = 1, h = 1}, 0xFFFFFFFF)

        local mat = {}
        mat.img = m
        mat.path = "vgui/white"
        mat.w = 1
        mat.h = 1
        materials[0] = mat
    end

    include("../garrysmod/includes/modules/draw.lua") //reload so it can see the materials we added
    // you have to manually load the materials you need from draw.lua before your first draw call by doing e.g. Material("gui/corner8.png"). Make sure the file exists first.

    async.Add(render_loop)

    gui_ok = true
    return true
end

local function init_ttf()
    if ttf_initialized then return ttf_ok end
    ttf_initialized = true

    if !init_sdl() then return false end

    local ok, t = pcall(require, "SDL.ttf")

    if !ok then
        last_error = t
        return false
    end

    ttf = t

    local ok, err = ttf.init()

    if !ok then
       last_error = err
       return false
    end


    local base = file.GetPath("MOD")
    if !base then return false, "filesystem init error" end

    local font, err = ttf.open(base .. "resource/fonts/" .. font_default, font_size_default / 1.2)

    if !font then
        last_error = err
        return false, err
    end

    local default_fonts = {
        "BudgetLabel", "CenterPrintText", "ChatFont", "CloseCaption_Bold",
        "CloseCaption_BoldItalic", "CloseCaption_Italic", "CloseCaption_Normal",
        "CreditsOutroText", "CreditsText", "DebugFixed", "DebugFixedSmall",
        "DebugOverlay", "Default", "DefaultFixed", "DefaultFixedDropShadow",
        "DefaultSmall", "DefaultUnderline", "DefaultVerySmall", "HudDefault",
        "HudHintTextLarge", "HudHintTextSmall", "HudSelectionNumbers", "HudSelectionText",
        "TargetID", "TargetIDSmall", "Trebuchet18", "Trebuchet24", "ClientTitleFont",
        "CreditsLogo", "CreditsOutroLogos", "Crosshairs", "HDRDemoText",
        "HudNumbers", "HudNumbersGlow", "HudNumbersSmall", "Marlett", "QuickInfo",
        "WeaponIcons", "WeaponIconsSelected", "WeaponIconsSmall", "HL2MPTypeDeath",
        "DermaDefault", "DermaDefaultBold", "DermaLarge"
    }

    local default = {font = font, data = {size = font_size_default / 1.2, name = font_default, antialias = true, additive = false}}

    for k,v in pairs(default_fonts) do
        fonts[v] = default
    end

    ttf_ok = true
    return true
end

local function init_image()
    if image_initialized then return image_ok end
    image_initialized = true

    if !init_sdl() then return false end

    local ok, i = pcall(require, "SDL.image")

    if !ok then
        last_error = i
        return false
    end

    sdl_image = i

    local flags, ok, err = sdl_image.init({sdl_image.flags.JPG, sdl_image.flags.PNG })

    if !ok then
        last_error = err
        return false
    end

    image_ok = true
    return true
end

function surface.PlaySound(filename)
    if !isstring(filename) then error("bad argument #1 to 'PlaySound' (string expected, got " .. type(filename) .. ")") end
    if !init_audio() then return false, last_error end

    if string.find(filename, "..", 1, true) then return false, "invalid file name" end

    local base = file.GetPath("MOD")
    if !base then return false, "filesystem init error" end

    if !file.Exists("sound/" .. filename, "MOD") then return false, "file not found" end

    if !sounds[filename] then
        sounds[filename] = sdl_mixer.loadWAV(base .. "sound/" .. filename)
    end

    local sound = sounds[filename]
    if !sound then return false, "error loading soundfile" end

    return sound:playChannel(-1, 0)
end

local drawline = {}
function surface.DrawLine(x1, y1, x2, y2)
    if !isnumber(x1) then error("bad argument #1 to 'DrawLine' (number expected, got " .. type(x1) .. ")") end
    if !isnumber(y1) then error("bad argument #2 to 'DrawLine' (number expected, got " .. type(y1) .. ")") end
    if !isnumber(x2) then error("bad argument #3 to 'DrawLine' (number expected, got " .. type(x2) .. ")") end
    if !isnumber(y2) then error("bad argument #4 to 'DrawLine' (number expected, got " .. type(y2) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    drawline.x1 = x1
    drawline.y1 = y1
    drawline.x2 = x2
    drawline.y2 = y2

    return rdr:drawLine(drawline)
end

local drawcolor = {}
function surface.SetDrawColor(r, g, b, a )
    local is_color_tbl = true

    if !IsColor(r) then
        is_color_tbl = false
        if !isnumber(r) then error("bad argument #1 to 'SetDrawColor' (number expected, got " .. type(r) .. ")") end
        if !isnumber(g) then error("bad argument #2 to 'SetDrawColor' (number expected, got " .. type(g) .. ")") end
        if !isnumber(b) then error("bad argument #3 to 'SetDrawColor' (number expected, got " .. type(b) .. ")") end
        if !isnumber(a) then a = 255 end
    end

    if !init_gui() then return false, last_error end
    if !rdr then return false, "rederer is closed" end

    if is_color_tbl then
        drawcolor.r = r.r
        drawcolor.g = r.g
        drawcolor.b = r.b
        drawcolor.a = r.a
    else
        drawcolor.r = r
        drawcolor.g = g
        drawcolor.b = b
        drawcolor.a = a
    end

    return rdr:setDrawColor(drawcolor)
end

local current_color
function surface.GetDrawColor()
    current_color = current_color or Color(0,0,0,0)

    if !rdr then return current_color end
    local _, col = rdr:getDrawColor()

    current_color.r = col.r
    current_color.g = col.g
    current_color.b = col.b
    current_color.a = col.a

    return current_color
end

local p = {}
function surface.DrawCircle(x, y, radius, r, g, b, a)
    if !isnumber(x) then error("bad argument #1 to 'DrawCircle' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawCircle' (number expected, got " .. type(y) .. ")") end
    if !isnumber(radius) then error("bad argument #3 to 'DrawCircle' (number expected, got " .. type(radius) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end

    if !rdr then return false, "rederer is closed" end

    if r then
        surface.SetDrawColor(r, g, b, a )
    end

    local offsetx = 0
    local offsety = radius
    local d = radius - 1

    while (offsety >= offsetx) do
        p.x = x + offsetx   p.y = y + offsety   rdr:drawPoint(p)
        p.x = x + offsety   p.y = y + offsetx   rdr:drawPoint(p)
        p.x = x - offsetx   p.y = y + offsety   rdr:drawPoint(p)
        p.x = x - offsety   p.y = y + offsetx   rdr:drawPoint(p)
        p.x = x + offsetx   p.y = y - offsety   rdr:drawPoint(p)
        p.x = x + offsety   p.y = y - offsetx   rdr:drawPoint(p)
        p.x = x - offsetx   p.y = y - offsety   rdr:drawPoint(p)
        p.x = x - offsety   p.y = y - offsetx   rdr:drawPoint(p)

        if d >= 2 * offsetx then
            d = d - 2 * offsetx + 1
            offsetx = offsetx + 1
        elseif d < 2 * (radius - offsety) then
            d = d + 2 * offsety - 1
            offsety = offsety - 1
        else
            d = d + 2 * (offsety - offsetx - 1)
            offsety = offsety - 1
            offsetx = offsetx + 1
        end
    end
end

local rect = {}
function surface.DrawRect(x, y, w, h)
    if !isnumber(x) then error("bad argument #1 to 'DrawRect' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawRect' (number expected, got " .. type(y) .. ")") end
    if !isnumber(w) then error("bad argument #3 to 'DrawRect' (number expected, got " .. type(w) .. ")") end
    if !isnumber(h) then error("bad argument #4 to 'DrawRect' (number expected, got " .. type(h) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    rect.x = x
    rect.y = y
    rect.w = w
    rect.h = h

    return rdr:fillRect(rect)
end

function surface.DrawOutlinedRect(x, y, w, h, thickness)
    if !isnumber(x) then error("bad argument #1 to 'DrawOutlinedRect' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawOutlinedRect' (number expected, got " .. type(y) .. ")") end
    if !isnumber(w) then error("bad argument #3 to 'DrawOutlinedRect' (number expected, got " .. type(w) .. ")") end
    if !isnumber(h) then error("bad argument #4 to 'DrawOutlinedRect' (number expected, got " .. type(h) .. ")") end
    if !isnumber(thickness) then thickness = 1 end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    for i = 0, thickness - 1 do
        rect.x = x + i
        rect.y = y + i
        rect.w = w - i - i
        rect.h = h - i - i

        rdr:drawRect(rect)
    end
end

local line = {}
local color_poly
local texture_poly
local width_poly
local height_poly

local function DrawFilledTriangle(p1, p2, p3)
    if !istable(p1) or !istable(p2) or !istable(p3) then return end

    local temp  // sort points
    if (p2.y or 0) < (p1.y or 0) then temp = p1     p1 = p2     p2 = temp end
    if (p3.y or 0) < (p1.y or 0) then temp = p1     p1 = p3     p3 = temp end
    if (p3.y or 0) < (p2.y or 0) then temp = p2     p2 = p3     p3 = temp end

    local p1x = math.floor(p1.x or 0)
    local p1y = math.floor(p1.y or 0)
    local p2x = math.floor(p2.x or 0)
    local p2y = math.floor(p2.y or 0)
    local p3x = math.floor(p3.x or 0)
    local p3y = math.floor(p3.y or 0)

    for y = p1y, p3y - 1 do
        local x_start, x_end

        if y < p2y then
            x_start = p1x + (p2x - p1x) * (y - p1y) / (p2y - p1y)
            x_end = p1x + (p3x - p1x) * (y - p1y) / (p3y - p1y)
        else
            x_start = p2x + (p3x - p2x) * (y - p2y) / (p3y - p2y)
            x_end = p1x + (p3x - p1x) * (y - p1y) / (p3y - p1y)
        end

        line.x1 = x_start
        line.y1 = y
        line.x2 = x_end
        line.y2 = y

        rdr:drawLine(line)
    end
end

function surface.DrawPoly(points)
    if !istable(points) then error("bad argument #1 to 'DrawPoly' (table expected, got " .. type(points) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    if drawcolor.a != 255 then
        color_poly = color_poly or Color(0,0,0,0)

        color_poly.r = drawcolor.r or 0
        color_poly.g = drawcolor.g or 0
        color_poly.b = drawcolor.b or 0
        color_poly.a = 255

        if !texture_poly or width_poly != win_width or height_poly != win_height then
            width_poly = win_width
            height_poly = win_height

            local tex, err = rdr:createTexture(sdl.pixelFormat.RGBA8888, sdl.textureAccess.Target, width_poly, height_poly)
            if !tex then return false, err end

            texture_poly = tex
            texture_poly:setBlendMode(sdl.blendMode.Blend)
            texture_poly:setAlphaMod(drawcolor.a)
        end



        rdr:setTarget(texture_poly)
        rdr:setDrawColor(0x00000000)
        rdr:clear()
        rdr:setDrawColor(color_poly)
    end

    for i = 2, #points - 1 do
       DrawFilledTriangle(points[1], points[i], points[i + 1])
    end

    if drawcolor.a != 255 then
        rdr:setTarget()
        rdr:copy(texture_poly)
        rdr:setDrawColor(drawcolor)
    end
end

function surface.CreateFont(name, data)
    if !isstring(name) then error("bad argument #1 to 'CreateFont' (string expected, got " .. type(name) .. ")") end
    if !istable(data) then error("bad argument #2 to 'CreateFont' (table expected, got " .. type(data) .. ")") end

    if !init_ttf() then return false, last_error end

    local size = isnumber(data.size) and data.size or font_size_default
    local fontname = font_default

    if isstring(data.font) and !string.find(data.font, "..", 1, true) then
        fontname = data.font
    end

    local base = file.GetPath("MOD")
    if !base then return false, "filesystem init error" end

    if !file.Exists("resource/fonts/" .. fontname, "MOD") then
        Error("Couldn't find/load font '" .. fontname .. "', falling back to '" .. font_default .. "'..\n")
        fontname = font_default
    end

    local font, err = ttf.open(base .. "resource/fonts/" .. fontname, math.ceil(size / 1.2))

    if !font then
        last_error = err
        return false, err
    end

    //todo: styles and other options

    local style = 0

    bit.bor(style, data.underline and ttf.style.Underline or 0)
    style = bit.bor(style, data.underline and ttf.style.Underline or 0)
    style = bit.bor(style, data.italic and ttf.style.Italic or 0)
    style = bit.bor(style, data.strikeout and ttf.style.StrikeThrough or 0)
    style = bit.bor(style, data.rotary and ttf.style.StrikeThrough or 0)
    style = bit.bor(style, (data.weight or 500) >= 700 and ttf.style.Bold or 0)

    font:setStyle(style)

    //todo: blursize

    local aa = data.antialias
    if aa == nil then aa = true end

    fonts[name] = {
        font = font,
        data = {
            size = size,
            font = fontname,
            additive = data.additive and true or false,
            antialias = aa and true or false,
        }
    }

end

function surface.SetFont(name)
    if !isstring(name) then error("bad argument #1 to 'SetFont' (string expected, got " .. type(name) .. ")") end

    if !init_ttf() then return false, last_error end
    if !fonts[name] then error("'" .. name .. "' isn't a valid font") end

    font_active = name
    return true
end

function surface.SetTextColor(r, g, b, a)
    local is_color_tbl = true

    if !IsColor(r) then
        is_color_tbl = false
        if !isnumber(r) then error("bad argument #1 to 'SetTextColor' (number expected, got " .. type(r) .. ")") end
        if !isnumber(g) then error("bad argument #2 to 'SetTextColor' (number expected, got " .. type(g) .. ")") end
        if !isnumber(b) then error("bad argument #3 to 'SetTextColor' (number expected, got " .. type(b) .. ")") end
        if !isnumber(a) then a = 255 end
    end

    if is_color_tbl then
        font_color.r = r.r
        font_color.g = r.g
        font_color.b = r.b
        font_color.a = r.a
    else
        font_color.r = r
        font_color.g = g
        font_color.b = b
        font_color.a = a
    end

    return true
end

function surface.SetTextPos(x, y)
    if !isnumber(x) then error("bad argument #1 to 'SetTextPos' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'SetTextPos' (number expected, got " .. type(y) .. ")") end

    text_x = x
    text_y = y

    return true
end

local textpos = {}
function surface.DrawText(text, additive)
    if !isstring(text) then error("bad argument #1 to 'DrawText' (string expected, got " .. type(text) .. ")") end

    if !init_ttf() or !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    local f = fonts[font_active].font
    local data = fonts[font_active].data

    local surf, err = f:renderUtf8(string.Replace(text, "\n", "  "), data.antialias and "blended" or "solid", font_color)

    if !surf then
        return false, err
    end

    local w, h = surf:getSize()


    local texture, err = rdr:createTextureFromSurface(surf)

    if !texture then
        return false, err
    end

    textpos.x = text_x
    textpos.y = text_y
    textpos.w = w
    textpos.h = h

    local add = data.additive
    if additive then add = true end
    if additive == false then add = false end

    texture:setBlendMode(add and sdl.blendMode.Add or sdl.blendMode.Blend)
    rdr:copy(texture, nil, textpos)
    text_x = text_x + w

    return true
end

TEXT_ALIGN_LEFT = 0
TEXT_ALIGN_CENTER = 1
TEXT_ALIGN_RIGHT = 2
TEXT_ALIGN_TOP = 3
TEXT_ALIGN_BOTTOM = 4

function surface.GetTextSize(text)
    if !isstring(text) then error("bad argument #1 to 'GetTextSize' (string expected, got " .. type(text) .. ")") end

    if !init_ttf() then return false, last_error end

    local f = fonts[font_active].font
    local w, h, err = f:sizeUtf8(string.Replace(text, "\n", "  "))

    if !w then
        return false, err
    end

    return w, h
end

local error_surf

local function create_error_surface()
    if error_surf or !init_sdl() then return end

    local m, err = sdl.createRGBSurface(32, 32)
    if !m then return end

    local black = true
    for i = 0, 63 do
        black = !black
        m:fillRect({x = (i % 8) * 4, y = math.floor(i / 8) * 4, w = 4, h = 4}, black and 0xFF000000 or 0xFFFF0CFE)

        if (i + 1)  % 8 == 0 then black = !black end
    end

    error_surf = m
end

local mm = {}
mm.__index = mm
RegisterMetaTable("IMaterial", mm)

function mm:IsError()
    return self.error != nil
end

function mm:GetName()
    if self.error then return "___error" end
    return (self.flags or "") .. self.path
end

function mm:__tostring()
    return "Material [" .. self:GetName() .. "]"
end

function mm:Height()
    return self.h or 0
end

function mm:Width()
    return self.w or 0
end

function mm:GetColor(x, y)
    if !isnumber(x) then error("bad argument #1 to 'GetColor' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'GetColor' (number expected, got " .. type(y) .. ")") end
    if self.error or !self.img then return Color(0,0,0,255) end

    return Color(string.byte(self.img:getRawPixel(x % self.w, y % self.h), 1, 4))
end

// placeholders
function mm:GetKeyValues()
    return {}
end

function mm:GetTexture()
    return {}
end

function mm:GetShader()
    return "UnlitGeneric"
end

function mm:GetFloat() end
function mm:GetInt() end
function mm:GetMatrix() end
function mm:GetString() end
function mm:GetVector() end
function mm:GetVector4D() end
function mm:GetVectorLinear() end
function mm:Recompute() end
function mm:SetFloat() end
function mm:SetInt() end
function mm:SetMatrix() end
function mm:SetShader() end
function mm:SetString() end
function mm:SetTexture() end
function mm:SetUndefined() end
function mm:SetVector() end
function mm:SetVector4D() end

function Material(path, flags)
    if !isstring(path) then error("bad argument #1 to 'Material' (string expected, got " .. type(path) .. ")") end

    local start = CurTime()
    local mat = {}
    setmetatable(mat, mm)

    create_error_surface()
    mat.path = string.StripExtension and string.StripExtension(path) or path
    mat.flags = isstring(flags) and flags or ""
    mat.img = error_surf
    mat.w = 32  //size of error texture
    mat.h = 32

    if !init_image() then
        mat.error = last_error
        return mat, CurTime() - start
    end



    if string.find(path, "..", 1, true) then
        mat.error = "invalid path"
        return mat, CurTime() - start
    end

    local base = file.GetPath("MOD")
    if !base then
        mat.error = "filesystem init error"
        return mat, CurTime() - start
    end

    local in_materials = true

    if !file.Exists("materials/" .. path, "MOD") then
        in_materials = false

        if !file.Exists(path, "MOD") then   // allow loading files in e.g. data/
            mat.error = "file not found"
            return mat, CurTime() - start
        end
    end

    local img, err = sdl_image.load(base .. (in_materials and "materials/" or "") .. path)

    if !img then
        mat.error = err
        return mat, CurTime() - start
    end

    local w, h = img:getSize()

    mat.img = img
    mat.w = w
    mat.h = h

    local found = false
    for k,v in pairs(materials) do
        if v.path == string.StripExtension(path) then
           found = true
           break
        end
    end

    if !found then
        table.insert(materials, mat) // this is just for surface.SetMaterial
    end

    if rdr then
       mat.texture = rdr:createTextureFromSurface(img)
    end

    return mat, CurTime() - start
end

function surface.SetMaterial(mat)
    if !istable(mat) then error("bad argument #1 to 'SetMaterial' (IMaterial expected, got " .. type(mat) .. ")") end
    if getmetatable(mat) != mm then error("bad argument #1 to 'SetMaterial' (IMaterial expected, got " .. type(mat) .. ")") end


    material_active = mat
end


local missing_ignore = {
    "gui/corner8",
    "gui/corner16",
    "gui/corner32",
    "gui/corner64",
    "gui/corner512",
}
function surface.GetTextureID(name)
    if !isstring(name) then error("bad argument #1 to 'GetTextureID' (string expected, got " .. type(name) .. ")") end
    if !sdl then return 0 end

    for k,v in pairs(materials) do
        if v.path == name then
            return k
        end
    end

    if table.HasValue(missing_ignore, name) then
        return 0
    end

    MsgN("--- Missing Vgui material ", name)
    return 0
end

function surface.GetTextureNameByID(id)
    if !isnumber(id) then error("bad argument #1 to 'GetTextureNameByID' (number expected, got " .. type(id) .. ")") end

    local mat = materials[id]
    if !mat then return "" end

    return mat.path or ""
end

function surface.SetTexture(id)
    if !isnumber(id) then error("bad argument #1 to 'SetTexture' (number expected, got " .. type(id) .. ")") end

    material_active = materials[id]
end

function surface.DrawTexturedRect(x, y, w, h)
    if !isnumber(x) then error("bad argument #1 to 'DrawTexturedRect' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawTexturedRect' (number expected, got " .. type(y) .. ")") end
    if !isnumber(w) then error("bad argument #3 to 'DrawTexturedRect' (number expected, got " .. type(w) .. ")") end
    if !isnumber(h) then error("bad argument #4 to 'DrawTexturedRect' (number expected, got " .. type(h) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    local mat = material_active

    if !mat then return false, "invalid material" end
    if !mat.img then return false, "material error" end

    if !mat.texture then
        mat.texture = rdr:createTextureFromSurface(mat.img)
        if !mat.texture then return false, "error converting material to texture" end
    end

    rect.x = x
    rect.y = y
    rect.w = w
    rect.h = h

    mat.texture:setBlendMode(sdl.blendMode.Blend)
    mat.texture:setColorMod(drawcolor)
    mat.texture:setAlphaMod(drawcolor.a or 255)
    return rdr:copy(mat.texture, nil, rect)
end

local copyex = {}
function surface.DrawTexturedRectRotated(x, y, w, h, rotation)
    if !isnumber(x) then error("bad argument #1 to 'DrawTexturedRectRotated' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawTexturedRectRotated' (number expected, got " .. type(y) .. ")") end
    if !isnumber(w) then error("bad argument #3 to 'DrawTexturedRectRotated' (number expected, got " .. type(w) .. ")") end
    if !isnumber(h) then error("bad argument #4 to 'DrawTexturedRectRotated' (number expected, got " .. type(h) .. ")") end
    if !isnumber(rotation) then error("bad argument #4 to 'DrawTexturedRectRotated' (number expected, got " .. type(rotation) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    local mat = material_active

    if !mat then return false, "invalid material" end
    if !mat.img then return false, "material error" end

    if !mat.texture then
        mat.texture = rdr:createTextureFromSurface(mat.img)
        if !mat.texture then return false, "error converting material to texture" end
    end

    rect.x = x - (w / 2)
    rect.y = y - (h / 2)
    rect.w = w
    rect.h = h

    mat.texture:setBlendMode(sdl.blendMode.Blend)
    mat.texture:setColorMod(drawcolor)
    mat.texture:setAlphaMod(drawcolor.a or 255)

    copyex.texture = mat.texture
    copyex.destination = rect
    copyex.angle = -rotation

    return rdr:copyEx(copyex)
end

local copyex2 = {}
local src = {}
local dst = {}
function surface.DrawTexturedRectUV(x, y, w, h, startu, startv, endu, endv)
    if !isnumber(x) then error("bad argument #1 to 'DrawTexturedRectUV' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'DrawTexturedRectUV' (number expected, got " .. type(y) .. ")") end
    if !isnumber(w) then error("bad argument #3 to 'DrawTexturedRectUV' (number expected, got " .. type(w) .. ")") end
    if !isnumber(h) then error("bad argument #4 to 'DrawTexturedRectUV' (number expected, got " .. type(h) .. ")") end
    if !isnumber(startu) then error("bad argument #5 to 'DrawTexturedRectUV' (number expected, got " .. type(startu) .. ")") end
    if !isnumber(startv) then error("bad argument #6 to 'DrawTexturedRectUV' (number expected, got " .. type(startv) .. ")") end
    if !isnumber(endu) then error("bad argument #7 to 'DrawTexturedRectUV' (number expected, got " .. type(endu) .. ")") end
    if !isnumber(endv) then error("bad argument #8 to 'DrawTexturedRectUV' (number expected, got " .. type(endv) .. ")") end

    if !init_gui() then return false, last_error end
    if !drawing then return false, "not in 2d rendering context" end
    if !rdr then return false, "rederer is closed" end

    local mat = material_active

    if !mat then return false, "invalid material" end
    if !mat.img then return false, "material error" end

    if !mat.texture then
        mat.texture = rdr:createTextureFromSurface(mat.img)
        if !mat.texture then return false, "error converting material to texture" end
    end


    mat.texture:setBlendMode(sdl.blendMode.Blend)
    mat.texture:setColorMod(drawcolor)
    mat.texture:setAlphaMod(drawcolor.a or 255)


    local clamp = true
    if isstring(mat.flags) then clamp = string.sub(mat.flags,5,5) != "1" end

    local range_u = math.abs(endu - startu)
    local range_v = math.abs(endv - startv)
    local flip = 0

    local tex, err = rdr:createTexture(sdl.pixelFormat.RGBA8888, sdl.textureAccess.Target, (range_u + 1) * mat.w, (range_v + 1) * mat.h)
    if !tex then return false, err end

    tex:setBlendMode(sdl.blendMode.Blend)
    tex:setAlphaMod(drawcolor.a)

    rdr:setTarget(tex)
    rdr:setDrawColor(0x00000000)
    rdr:clear()

    if startu > endu then
       flip = bit.bor(flip, sdl.rendererFlip.Horizontal)
    end

    if startv > endv then
       flip = bit.bor(flip, sdl.rendererFlip.Vertical)
    end

    local cur_y = 0
    for k = 0, range_v do
        local cur_x = 0

        for i = 0, range_u do
            dst.x = cur_x
            dst.y = cur_y
            dst.w = mat.w
            dst.h = mat.h

            src.x = 0
            src.y = 0
            src.w = mat.w
            src.h = mat.h

            copyex2.texture = mat.texture
            copyex2.destination = dst
            copyex2.source = src
            copyex2.flip = flip

            rdr:copyEx(copyex2)
            if clamp then break end

            cur_x = cur_x + mat.w
        end

        if clamp then break end

        cur_y = cur_y + mat.h
    end

    rdr:setTarget()
    rdr:setDrawColor(drawcolor)

    dst.x = x
    dst.y = y
    dst.w = w
    dst.h = h

    src.x = (startu % 1) * mat.w
    src.y = (startv % 1) * mat.h
    src.w = (range_u) * mat.w
    src.h = (range_v) * mat.h

    rdr:copy(tex, src, dst)
    return true
end

// input
if !KEY_0 then
    include("enums/buttons.lua")
end

keys_map = {
    [1] = MOUSE_LEFT, [2] = MOUSE_MIDDLE, [3] = MOUSE_RIGHT, [4] = MOUSE_4, [5] = MOUSE_5,

    [48] = KEY_0, [49] = KEY_1, [50] = KEY_2, [51] = KEY_3, [52] = KEY_4, [53] = KEY_5, [54] = KEY_6, [55] = KEY_7, [56] = KEY_8, [57] = KEY_9,
    [97] = KEY_A,  [98] = KEY_B,  [99] = KEY_C,  [100] = KEY_D, [101] = KEY_E, [102] = KEY_F, [103] = KEY_G, [104] = KEY_H, [105] = KEY_I,
    [106] = KEY_J, [107] = KEY_K, [108] = KEY_L, [109] = KEY_M, [110] = KEY_N, [111] = KEY_O, [112] = KEY_P, [113] = KEY_Q, [114] = KEY_R,
    [115] = KEY_S, [116] = KEY_T, [117] = KEY_U, [118] = KEY_V, [119] = KEY_W, [120] = KEY_X, [121] = KEY_Y, [122] = KEY_Z,

    [1073741922] = KEY_PAD_0, [1073741913] = KEY_PAD_1, [1073741914] = KEY_PAD_2, [1073741915] = KEY_PAD_3, [1073741916] = KEY_PAD_4,
    [1073741917] = KEY_PAD_5, [1073741918] = KEY_PAD_6, [1073741919] = KEY_PAD_7, [1073741920] = KEY_PAD_8, [1073741921] = KEY_PAD_9,
    [1073741908] = KEY_PAD_DIVIDE, [1073741909] = KEY_PAD_MULTIPLY, [1073741910] = KEY_PAD_MINUS, [1073741911] = KEY_PAD_PLUS, [1073741912] = KEY_PAD_ENTER, [1073741923] = KEY_PAD_DECIMAL,

    [91] = KEY_LBRACKET, [93] = KEY_RBRACKET, [59] = KEY_SEMICOLON, [39] = KEY_APOSTROPHE, [96] = KEY_BACKQUOTE, [44] = KEY_COMMA, [46] = KEY_PERIOD,
    [47] = KEY_SLASH, [92] = KEY_BACKSLASH, [45] = KEY_MINUS, [61] = KEY_EQUAL, [13] = KEY_ENTER, [32] = KEY_SPACE, [8] = KEY_BACKSPACE, [9] = KEY_TAB,
    [1073741881] = KEY_CAPSLOCK, [1073741907] = KEY_NUMLOCK, [27] = KEY_ESCAPE, [1073741895] = KEY_SCROLLLOCK, [1073741897] = KEY_INSERT, [127] = KEY_DELETE,
    [1073741898] = KEY_HOME, [1073741901] = KEY_END, [1073741899] = KEY_PAGEUP, [1073741902] = KEY_PAGEDOWN, [1073741896] = KEY_BREAK, [1073742049] = KEY_LSHIFT,
    [1073742053] = KEY_RSHIFT, [1073742050] = KEY_LALT, [1073742054] = KEY_RALT, [1073742048] = KEY_LCONTROL, [1073742052] = KEY_RCONTROL, [1073742051] = KEY_LWIN,
    [1073742055] = KEY_RWIN, [1073741925] = KEY_APP, [1073741906] = KEY_UP, [1073741904] = KEY_LEFT, [1073741905] = KEY_DOWN, [1073741903] = KEY_RIGHT,
    [1073741882] = KEY_F1, [1073741883] = KEY_F2, [1073741884] = KEY_F3, [1073741885] = KEY_F4, [1073741886] = KEY_F5, [1073741887] = KEY_F6, [1073741888] = KEY_F7,
    [1073741889] = KEY_F8, [1073741890] = KEY_F9, [1073741891] = KEY_F10, [1073741892] = KEY_F11, [1073741893] = KEY_F12, [1073741881] = KEY_CAPSLOCKTOGGLE, [1073741907] = KEY_NUMLOCKTOGGLE,

    [223] = KEY_LBRACKET, [1073741824] = KEY_RBRACKET, [252] = KEY_SEMICOLON, [43] = KEY_EQUAL, [246] = KEY_SEMICOLON, [228] = KEY_APOSTROPHE,
    [35] = KEY_SLASH, [1073741824] = KEY_BACKSLASH, [60] = KEY_EQUAL
}

mouse_moved = function(x, y)
    mouse_x = x
    mouse_y = y
end

mousewheel_moved = function(x, y)
    if y > 0 then
        hook.Run("PlayerButtonDown", ply, MOUSE_WHEEL_UP)
        hook.Run("PlayerButtonUp", ply, MOUSE_WHEEL_UP)
    else
        hook.Run("PlayerButtonDown", ply, MOUSE_WHEEL_DOWN)
        hook.Run("PlayerButtonUp", ply, MOUSE_WHEEL_DOWN)
    end

    if trapping then
        if y > 0 then
            trapped = MOUSE_WHEEL_UP
        else
            trapped = MOUSE_WHEEL_DOWN
        end

        trapping = false
        return
    end
end

mousebutton_pressed = function(down, button)
    local btn = keys_map[button]
    if !btn then return end

    if down then
        hook.Run("PlayerButtonDown", ply, btn)

        if trapping then
            trapped = btn
            trapping = false
            return
        end
    else
        hook.Run("PlayerButtonUp", ply, btn)
    end

    buttons_state[btn] = down
end

key_pressed = function(down, keycode)
    local btn = keys_map[keycode]
    if !btn then return end

    if down then
        hook.Run("PlayerButtonDown", ply, btn)

        if trapping then
            trapped = btn
            trapping = false
            return
        end
    else
        hook.Run("PlayerButtonUp", ply, btn)
    end

    buttons_state[btn] = down
end

function input.IsButtonDown(key)
    if !isnumber(key) then error("bad argument #1 to 'IsButtonDown' (number expected, got " .. type(key) .. ")") end
    return buttons_state[key] or false
end

function input.IsKeyDown(key)
    if !isnumber(key) then error("bad argument #1 to 'IsKeyDown' (number expected, got " .. type(key) .. ")") end

    if key < KEY_FIRST or key > KEY_LAST then return false end
    return buttons_state[key] or false
end

function input.IsMouseDown(key)
    if !isnumber(key) then error("bad argument #1 to 'IsMouseDown' (number expected, got " .. type(key) .. ")") end

    if key < MOUSE_FIRST or key > MOUSE_LAST then return false end
    return buttons_state[key] or false
end

function gui.MouseX()
    return mouse_x
end

function gui.MouseY()
    return mouse_y
end

function input.GetCursorPos()
    return mouse_x, mouse_y
end

gui.MousePos = input.GetCursorPos

function input.StartKeyTrapping()
    trapping = true
end

function input.CheckKeyTrapping()
    local k = trapped
    if !k then return end

    trapped = nil
    return k
end

function input.IsKeyTrapping()
    return trapping
end

local keynames = {
    [KEY_PAD_5] = "NUMPAD 5", [KEY_PAD_6] = "NUMPAD 6", [KEY_PAD_7] = "NUMPAD 7", [KEY_PAD_8] = "NUMPAD 8", [KEY_PAD_9] = "NUMPAD 9",
    [KEY_PAD_DIVIDE] = "NUMPAD DIVIDE", [KEY_PAD_MULTIPLY] = "NUMPAD MULTIPLY", [KEY_PAD_MINUS] = "NUMPAD MINUS", [KEY_PAD_PLUS] = "NUMPAD PLUS",
    [KEY_PAD_ENTER] = "NUMPAD ENTER", [KEY_PAD_DECIMAL] = "NUMPAD DECIMAL", [KEY_LBRACKET] = "LBRACKET", [KEY_RBRACKET] = "RBRACKET",
    [KEY_SEMICOLON] = "SEMICOLON", [KEY_APOSTROPHE] = "APOSTROPHE", [KEY_BACKQUOTE] = "BACKQUOTE", [KEY_COMMA] = "COMMA",
    [KEY_PERIOD] = "PERIOD", [KEY_SLASH] = "SLASH", [KEY_BACKSLASH] = "BACKSLASH", [KEY_MINUS] = "MINUS", [KEY_EQUAL] = "EQUAL",
    [KEY_ENTER] = "ENTER", [KEY_SPACE] = "SPACE", [KEY_BACKSPACE] = "BACKSPACE", [KEY_TAB] = "TAB", [KEY_CAPSLOCK] = "CAPSLOCK",
    [KEY_NUMLOCK] = "NUMLOCK", [KEY_ESCAPE] = "ESCAPE", [KEY_SCROLLLOCK] = "SCROLLLOCK", [KEY_INSERT] = "INSERT", [KEY_DELETE] = "DELETE",
    [KEY_HOME] = "HOME", [KEY_END] = "END", [KEY_PAGEUP] = "PAGEUP", [KEY_PAGEDOWN] = "PAGEDOWN", [KEY_BREAK] = "BREAK", [KEY_LSHIFT] = "LSHIFT",
    [KEY_RSHIFT] = "RSHIFT", [KEY_LALT] = "LALT", [KEY_RALT] = "RALT", [KEY_LCONTROL] = "LCONTROL", [KEY_RCONTROL] = "RCONTROL",
    [KEY_LWIN] = "LWIN", [KEY_RWIN] = "RWIN", [KEY_APP] = "APP", [KEY_UP] = "UP", [KEY_LEFT] = "LEFT", [KEY_DOWN] = "DOWN", [KEY_RIGHT] = "RIGHT",
    [KEY_F1] = "F1", [KEY_F2] = "F2", [KEY_F3] = "F3", [KEY_F4] = "F4", [KEY_F5] = "F5", [KEY_F6] = "F6", [KEY_F7] = "F7", [KEY_F8] = "F8",
    [KEY_F9] = "F9", [KEY_F10] = "F10", [KEY_F11] = "F11", [KEY_F12] = "F12", [KEY_CAPSLOCKTOGGLE] = "CAPSLOCKTOGGLE", [KEY_NUMLOCKTOGGLE] = "NUMLOCKTOGGLE",
    [KEY_NONE] = "NONE", [KEY_SCROLLLOCKTOGGLE] = "SCROLLLOCKTOGGLE", [MOUSE_LEFT] = "MOUSE1", [MOUSE_RIGHT] = "MOUSE2",
    [MOUSE_MIDDLE] = "MOUSE3", [MOUSE_4] = "MOUSE4", [MOUSE_5] = "MOUSE5", [MOUSE_WHEEL_DOWN] = "MOUSEWHEEL DOWN", [MOUSE_WHEEL_UP] = "MOUSEWHEEL UP",
    [KEY_XBUTTON_A] = "CONTROLLER A", [KEY_XBUTTON_B] = "CONTROLLER B", [KEY_XBUTTON_X] = "CONTROLLER X", [KEY_XBUTTON_Y] = "CONTROLLER Y",
    [KEY_XBUTTON_LEFT_SHOULDER] = "CONTROLLER LEFTSHOULDER", [KEY_XBUTTON_RIGHT_SHOULDER] = "CONTROLLER RIGHTSHOULDER", [KEY_XBUTTON_BACK] = "CONTROLLER BACK",
    [KEY_XBUTTON_START] = "CONTROLLER START", [KEY_XBUTTON_STICK1] = "CONTROLLER STICK1", [KEY_XBUTTON_STICK2] = "CONTROLLER STICK2", [KEY_F] = "F",
    [KEY_XBUTTON_RIGHT] = "CONTROLLER RIGHT", [KEY_XBUTTON_DOWN] = "CONTROLLER DOWN", [KEY_XBUTTON_LEFT] = "CONTROLLER LEFT",
    [KEY_XSTICK1_RIGHT] = "CONTROLLER STICK1RIGHT", [KEY_XSTICK1_LEFT] = "CONTROLLER STICK1LEFT", [KEY_XSTICK1_DOWN] = "CONTROLLER STICK1DOWN",
    [KEY_XSTICK1_UP] = "CONTROLLER STICK1UP", [KEY_XBUTTON_LTRIGGER] = "CONTROLLER LTRIGGER", [KEY_XBUTTON_RTRIGGER] = "CONTROLLER RTRIGGER",
    [KEY_XSTICK2_RIGHT] = "CONTROLLER STICK2RIGHT", [KEY_XSTICK2_LEFT] = "CONTROLLER STICK2LEFT", [KEY_XSTICK2_DOWN] = "CONTROLLER STICK2DOWN",
    [KEY_XSTICK2_UP] = "CONTROLLER STICK2UP", [KEY_XBUTTON_UP] = "CONTROLLER UP", [KEY_0] = "0", [KEY_1] = "1", [KEY_2] = "2", [KEY_3] = "3", [KEY_4] = "4", [KEY_5] = "5",
    [KEY_6] = "6", [KEY_7] = "7", [KEY_8] = "8", [KEY_9] = "9", [KEY_A] = "A", [KEY_B] = "B", [KEY_C] = "C", [KEY_D] = "D", [KEY_E] = "E", [KEY_G] = "G",
    [KEY_H] = "H", [KEY_I] = "I", [KEY_J] = "J", [KEY_K] = "K", [KEY_L] = "L", [KEY_M] = "M", [KEY_N] = "N", [KEY_O] = "O", [KEY_P] = "P", [KEY_Q] = "Q",
    [KEY_R] = "R", [KEY_S] = "S", [KEY_T] = "T", [KEY_U] = "U", [KEY_V] = "V", [KEY_W] = "W", [KEY_X] = "X", [KEY_Y] = "Y", [KEY_Z] = "Z", [KEY_PAD_0] = "NUMPAD 0",
    [KEY_PAD_1] = "NUMPAD 1", [KEY_PAD_2] = "NUMPAD 2", [KEY_PAD_3] = "NUMPAD 3", [KEY_PAD_4] = "NUMPAD 4"
}

function input.GetKeyName(key)
    if !isnumber(key) then error("bad argument #1 to 'GetKeyName' (number expected, got " .. type(key) .. ")") end

    local name = keynames[key]
    if !name then return "NONE" end

    return name
end

function input.GetKeyCode(name)
    if !isstring(name) then error("bad argument #1 to 'GetKeyCode' (string expected, got " .. type(name) .. ")") end

    for k,v in pairs(keynames) do
        if string.lower(v) == string.lower(name) then
           return k
        end
    end

    return -1
end

function input.IsShiftDown()
    return buttons_state[KEY_LSHIFT] or buttons_state[KEY_RSHIFT] or false
end

function input.IsControlDown()
    return buttons_state[KEY_LCONTROL] or buttons_state[KEY_RCONTROL] or false
end

system = system or {}
function system.BatteryPower()
    if !init_sdl() then return 255 end

    local state, secs, pct = sdl.getPowerInfo()
    if pct == -1 then return 255 end

    return pct
end
