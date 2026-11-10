-- Глобальная переменная для хранения текущего активного состояния (лаунчера или игры)
current_state = nil

-- global settings
is_anim = true
is_sound = true
is_msg = false
game_lang = "ru"  -- "en" or "ru"
color_fg = {63/255, 63/255, 63/255}  -- #3f3f3f
color_button_press = {155/255, 155/255, 154/255, 0.5}  -- #9b9b9a
W = 1280
H = 720

-- local settings
local lume = require("modules/lume")
local tick = require("modules/tick")
local group = tick.group()
local color_bg = {238/255, 236/255, 237/255}  -- #eeeced
local image_paper = love.graphics.newImage("images/paper.png")
local particles = {}
local cell = 240
local msg_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 30 )
local msg_text = "info"



function draw_button(bx, by, bwidth, bheight, bcolor, bcolor2)  -- global
    local color_border = bcolor2 or color_fg
    local rad = math.min(bwidth, bheight) * 0.08
    love.graphics.setColor(bcolor)
    love.graphics.rectangle("fill", bx, by, bwidth, bheight, rad, rad)
    love.graphics.setColor(color_border)
    love.graphics.setLineWidth(rad * 0.4)
    love.graphics.rectangle("line", bx, by, bwidth, bheight, rad, rad)
end


function msg(info)
    msg_text = info or "info"
    is_msg = true
end


local function resize()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    cell = math.min(W / 6, H / 3)
    msg_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell * 0.18 )
    
    local particles_colors = { {177/255, 204/255, 51/255}, {146/255, 211/255, 245/255}, {241/255, 179/255, 28/255}, {234/255, 90/255, 71/255}, {179/255, 153/255, 200/255}, {252/255, 234/255, 43/255} }
    local particles_alpha = {0.3, 0.6}
    local dir = { {0, 1}, {0, -1}, {1, 0}, {-1, 0} }
    for p=1,#particles do
        particles[p].size = love.math.random( math.floor(cell/30), math.ceil(cell/15) )
        particles[p].x = love.math.random( 0, W - particles[p].size )
        particles[p].y = love.math.random( 0, H - particles[p].size )
        local c = love.math.random( 1, 6 )
        local a = love.math.random( 1, 2 )
        local pc = particles_colors[c]
        pc[4] = particles_alpha[a]
        particles[p].color = pc
        local d = love.math.random( 1, 4 )
        particles[p].dir = dir[d]
    end
end


local function save_game()
    local data = {}
    data.is_anim = is_anim
    data.is_sound = is_sound
    data.game_lang = game_lang

    local serialized = lume.serialize(data)
    love.filesystem.write("global", serialized)
end


function love.load()
    -- default particles
    for _p=1,90 do
        table.insert( particles, { x=0, y=0, size=10, color=color_bg, dir={0, 1} } )
    end
    
    -- load save data
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("global") then
            local file = love.filesystem.read("global")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local ok, msg = pcall( function()
            if not (data.is_anim == true or data.is_anim == false) then error("Incorrect saved data!")
            else is_anim = data.is_anim end
            
            if not (data.is_sound == true or data.is_sound == false) then error("Incorrect saved data!")
            else is_sound = data.is_sound end
            
            if not (data.game_lang == "en" or data.game_lang == "ru") then error("Incorrect save data!")
            else game_lang = data.game_lang end
        end )

        if not ok then  -- защищенный код вызвал ошибку
            --love.window.showMessageBox("ERROR", "Not read saved data! " .. (msg or "..."), "error")
            msg("Not read saved data! " .. (msg or "..."))
            is_anim = true
            is_sound = true
            game_lang = "ru"
        end
    else
        --love.window.showMessageBox("INFO", "Saved data was not found! " .. (err or "..."), "info")
        is_anim = true
        is_sound = true
        game_lang = "ru"
    end
    
    love.graphics.setBackgroundColor(color_bg)
    resize()
    
    -- Загружаем лаунчер как начальное состояние
    launcher = require("launcher")  -- глобальная переменная
    current_state = launcher
    current_state.load()
end


function love.update(dt)
    -- Защита от «скачка смерти» при переносе окна
    if dt > 0.25 then
        dt = 0.25
    end
    
    group:update(dt)
    
    if is_anim then
        -- particles
        for p=1,#particles do
            particles[p].x = particles[p].x + particles[p].size * dt * 6 * particles[p].dir[1]
            particles[p].y = particles[p].y + particles[p].size * dt * 6 * particles[p].dir[2]
            if (particles[p].x > W) or (particles[p].x + particles[p].size < 0) or (particles[p].y > H) or (particles[p].y + particles[p].size < 0) then
                local particles_colors = { {177/255, 204/255, 51/255}, {146/255, 211/255, 245/255}, {241/255, 179/255, 28/255}, {234/255, 90/255, 71/255}, {179/255, 153/255, 200/255}, {252/255, 234/255, 43/255} }
                local particles_alpha = {0.3, 0.6}
                local dir = { {0, 1}, {0, -1}, {1, 0}, {-1, 0} }
                particles[p].size = love.math.random( math.floor(cell/30), math.ceil(cell/15) )
                local c = love.math.random( 1, 6 )
                local a = love.math.random( 1, 2 )
                local pc = particles_colors[c]
                pc[4] = particles_alpha[a]
                particles[p].color = pc
                local d = love.math.random( 1, 4 )
                particles[p].dir = dir[d]
                if dir[d][1] == 0 then
                    particles[p].x = love.math.random( 0, W - particles[p].size )
                    if dir[d][2] > 0 then particles[p].y = -particles[p].size else particles[p].y = H end
                else
                    particles[p].y = love.math.random( 0, H - particles[p].size )
                    if dir[d][1] > 0 then particles[p].x = -particles[p].size else particles[p].x = W end
                end
            end
        end
    end
    
    if current_state and current_state.update then
        current_state.update(dt)
    end
end


function love.draw()
    -- background image
    love.graphics.setColor(1, 1, 1, 1)
    for y = 0, H, 800 do
        for x = 0, W, 800 do
            love.graphics.draw(image_paper, x, y)
        end
    end

    -- particles
    for p=1,#particles do
        love.graphics.setColor(particles[p].color)
        love.graphics.rectangle("fill", particles[p].x, particles[p].y, particles[p].size, particles[p].size)
    end

    if current_state and current_state.draw then
        current_state.draw()
    end
    
    if is_msg then
        draw_button(W * 0.5 - cell + cell * 0.025, H * 0.5 - cell * 0.5 + cell * 0.025, cell * 2, cell, {0, 0, 0, 0.25}, {0, 0, 0, 0})
        draw_button(W * 0.5 - cell, H * 0.5 - cell * 0.5, cell * 2, cell, {252/255, 234/255, 43/255})
        local _, tlines = msg_font:getWrap(msg_text, cell * 2)
        local totalTextHeight = #tlines * msg_font:getHeight()
        love.graphics.setColor(color_fg)
        love.graphics.setFont(msg_font)
        love.graphics.printf(msg_text, W * 0.5 - cell, H * 0.5 - totalTextHeight * 0.5, cell * 2, "center")
    end
end


function love.keypressed(key)
    if current_state and current_state.keypressed then
        current_state.keypressed(key)
    end
end


function love.mousepressed( x, y, button, istouch, presses )
    if is_msg then
        is_msg = false
    elseif current_state and current_state.mousepressed then
        current_state.mousepressed( x, y, button, istouch, presses )
    end
end


function love.mousereleased( x, y, button, istouch, presses )
    if current_state and current_state.mousereleased then
        current_state.mousereleased( x, y, button, istouch, presses )
    end
end


function love.mousemoved( x, y, dx, dy, istouch )
    if current_state and current_state.mousemoved then
        current_state.mousemoved( x, y, dx, dy, istouch )
    end
end


function love.wheelmoved( x, y )
    if current_state and current_state.wheelmoved then
        current_state.wheelmoved( x, y )
    end
end


function love.threaderror(thread, errorstr)  -- If not overwritten this callback will raise an error!
    if current_state and current_state.threaderror then
        current_state.threaderror( thread, errorstr )
    end
end


function love.resize(w, h)
    group:delay(function() resize() end, 0.050)
    
    if current_state and current_state.resize then
        current_state.resize(w, h)
    end
end


function love.focus(f)
    if not f then  -- Window is not focused
        save_game()
    end
    
    if current_state and current_state.focus then
        current_state.focus(f)
    end
end


function love.quit()
    save_game()
    
    if current_state and current_state.quit then
        current_state.quit()
    end
    
    return false
end
