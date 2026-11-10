local launcher = {}

local tick = require("modules/tick")
local s = require("modules/say")

-- images
local image_icon_bukva = love.graphics.newImage("images/bukva.png")
local image_icon_cube = love.graphics.newImage("images/cube.png")
local image_icon_chess = love.graphics.newImage("images/chess.png")
local image_icon_mancala = love.graphics.newImage("images/mancala.png")
local image_icon_mines = love.graphics.newImage("images/mines.png")
local image_icon_xo = love.graphics.newImage("images/xo.png")
local image_about = love.graphics.newImage("images/about.png")
local image_back = love.graphics.newImage("images/back.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_logo = love.graphics.newImage("images/logo.png")
local image_love = love.graphics.newImage("images/love.png")

-- calculate
--local W = 1280
--local H = 720
local cell_size = 240  -- 720 / 3
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 60 )
local totalTextHeight = 240

-- game
local press_button = ""
local group = tick.group()
local is_show_info = false

-- audio
sound_click = love.audio.newSource("audio/click.ogg", "static")


local function resize()
    --W = love.graphics.getWidth()
    --H = love.graphics.getHeight()
    
    cell_size = math.min(W / 6, H / 3)
    k_scale = cell_size / image_about:getWidth()
    
    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.18 )
    love.graphics.setFont(game_font)
    game_font:setLineHeight( 0.8 )
    
    local _, tlines = game_font:getWrap(s("Info text"), W - 2 * (cell_size * 0.5 + cell_size / 3))
    totalTextHeight = #tlines * game_font:getHeight() * 0.81
end


function launcher.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("Info text", [[LOVE GAMES
A collection of games for intellectual entertainment :)

* Bukva       *
* Cube        *
* Chess       *
* Mancala     *
* Mines       *
* Tic-Tac-Toe *

(c) 2026 Anton Bezdolny
avbezdolny.github.io]])

    -- RU
    s:set_namespace("ru")
    s:set("Info text", [[LOVE GAMES
Коллекция игр для интеллектуального развлечения :)

* Буква           *
* Куб             *
* Шахматы         *
* Манкала         *
* Мины            *
* Крестики-нолики *

(c) 2026 Антон Бездольный
avbezdolny.github.io]])

    s:set_namespace(game_lang)
    resize()
end


function launcher.update(dt)
    group:update(dt)
end


function launcher.draw()
    local bcolor = {1, 1, 1, 0.5}
    
    if is_show_info then
        bcolor = {1, 1, 1, 0.5}
        if press_button == "about" then bcolor = color_button_press end
        draw_button(cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "exit" then bcolor = color_button_press end
        draw_button(W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_back, cell_size / 6, H * 0.5 - cell_size * 0.25, 0, k_scale * 0.5, k_scale * 0.5)
        love.graphics.draw(image_love, W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, 0, k_scale * 0.5, k_scale * 0.5)
        
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.draw(image_logo, W * 0.5 - cell_size, H * 0.5 - cell_size, 0, k_scale * 2, k_scale * 2)
        
        love.graphics.setColor(color_fg)
        love.graphics.setFont(game_font)
        love.graphics.printf(s("Info text"), cell_size * 0.5 + cell_size / 3, H * 0.5 - totalTextHeight * 0.5, W - 2 * (cell_size * 0.5 + cell_size / 3), "center")
    
    else
        bcolor = {1, 1, 1, 0.5}
        if press_button == "bukva" then bcolor = color_button_press end
        draw_button(W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "cube" then bcolor = color_button_press end
        draw_button(W * 0.5 - cell_size * 0.5, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "chess" then bcolor = color_button_press end
        draw_button(W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "mancala" then bcolor = color_button_press end
        draw_button(W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "mines" then bcolor = color_button_press end
        draw_button(W * 0.5 - cell_size * 0.5, H * 0.5 + cell_size / 6, cell_size, cell_size, bcolor)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "xo" then bcolor = color_button_press end
        draw_button(W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_icon_bukva, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 - cell_size - cell_size / 6, 0, k_scale, k_scale)
        love.graphics.draw(image_icon_cube, W * 0.5 - cell_size * 0.5, H * 0.5 - cell_size - cell_size / 6, 0, k_scale, k_scale)
        love.graphics.draw(image_icon_chess, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 - cell_size - cell_size / 6, 0, k_scale, k_scale)
        love.graphics.draw(image_icon_mancala, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 + cell_size / 6, 0, k_scale, k_scale)
        love.graphics.draw(image_icon_mines, W * 0.5 - cell_size * 0.5, H * 0.5 + cell_size / 6, 0, k_scale, k_scale)
        love.graphics.draw(image_icon_xo, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 + cell_size / 6, 0, k_scale, k_scale)
        
        bcolor = {1, 1, 1, 0.5}
        if press_button == "about" then bcolor = color_button_press end
        draw_button(cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5, bcolor)
        bcolor = {1, 1, 1, 0.5}
        if press_button == "exit" then bcolor = color_button_press end
        draw_button(W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_about, cell_size / 6, H * 0.5 - cell_size * 0.25, 0, k_scale * 0.5, k_scale * 0.5)
        love.graphics.draw(image_exit, W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, 0, k_scale * 0.5, k_scale * 0.5)
    end
end


local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)  -- пересечение точки с прямоугольником
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


function launcher.keypressed(key, scancode, isrepeat)  -- love.keyreleased( key, scancode )
    if key == "escape" then
        if is_sound then sound_click:play() end
        if is_show_info then is_show_info = false
        else group:delay(function() love.event.quit(0) end, 0.150) end
    end
end


function launcher.mousepressed( x, y, button, istouch, presses )
    if not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) then
        press_button = "bukva"
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 0.5, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) then
        press_button = "cube"
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) then
        press_button = "chess"
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size) then
        press_button = "mancala"
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 0.5, H * 0.5 + cell_size / 6, cell_size, cell_size) then
        press_button = "mines"
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size) then
        press_button = "xo"
    
    elseif is_collide(x, y, cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5) then
        press_button = "about"
    
    elseif is_collide(x, y, W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5) then
        press_button = "exit"
    end
end


function launcher.mousereleased( x, y, button, istouch, presses )
    if not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) and press_button == "bukva" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.bukva")  -- Динамически загружаем выбранную игру
        if chosen_game.load then chosen_game.load() end  -- Сбрасываем её состояние перед запуском
        current_state = chosen_game  -- Переключаем глобальное состояние на эту игру
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 0.5, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) and press_button == "cube" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.cube")
        if chosen_game.load then chosen_game.load() end
        current_state = chosen_game
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 - cell_size - cell_size / 6, cell_size, cell_size) and press_button == "chess" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.chess")
        if chosen_game.load then chosen_game.load() end
        current_state = chosen_game
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 1.5 - cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size) and press_button == "mancala" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.mancala")
        if chosen_game.load then chosen_game.load() end
        current_state = chosen_game
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 - cell_size * 0.5, H * 0.5 + cell_size / 6, cell_size, cell_size) and press_button == "mines" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.mines")
        if chosen_game.load then chosen_game.load() end
        current_state = chosen_game
    
    elseif not is_show_info and is_collide(x, y, W * 0.5 + cell_size * 0.5 + cell_size / 3, H * 0.5 + cell_size / 6, cell_size, cell_size) and press_button == "xo" then
        if is_sound then sound_click:play() end
        local chosen_game = require("games.xo")
        if chosen_game.load then chosen_game.load() end
        current_state = chosen_game
    
    elseif is_collide(x, y, cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5) and press_button == "about" then
        if is_sound then sound_click:play() end
        is_show_info = not is_show_info
    
    elseif is_collide(x, y, W - cell_size * 0.5 - cell_size / 6, H * 0.5 - cell_size * 0.25, cell_size * 0.5, cell_size * 0.5) and press_button == "exit" then
        if is_sound then sound_click:play() end
        if is_show_info then
            love.system.openURL("https://github.com/avbezdolny/lovegames")
        else
            group:delay(function() love.event.quit(0) end, 0.150)
        end
    end

    press_button = ""
end


function launcher.resize(w, h)
    group:delay(function() resize() end, 0.150)
end


return launcher
