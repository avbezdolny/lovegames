local game = {}

local tick = require("modules/tick")
local flux = require("modules/flux")
local lume = require("modules/lume")
local s = require("modules/say")

-- colors
--local color_fg = {63/255, 63/255, 63/255}  -- #3f3f3f
--local color_button_press = {155/255, 155/255, 154/255}  -- #9b9b9a
local color_blue = {30/255, 80/255, 160/255}  -- #1e50a0
local color_red = {210/255, 47/255, 39/255}  -- #d22f27
local color_blue_ambar = {146/255, 211/255, 245/255, 0.5}  -- #92d3f5
local color_red_ambar = {234/255, 90/255, 71/255, 0.5}  -- #ea5a47
local color_cell = {155/255, 155/255, 154/255, 0.25}  -- #9b9b9a
local color_select = {177/255, 204/255, 51/255, 0.5}  -- #4bd37b
local color_press = {252/255, 234/255, 43/255, 0.5}  -- #ffdd67

-- images
local image_seed = love.graphics.newImage("images/seed.png")
local image_target = love.graphics.newImage("images/target.png")
local image_hand = love.graphics.newImage("images/hand_left.png")
local image_victory = love.graphics.newImage("images/hand_victory.png")
local image_menu = love.graphics.newImage("images/gear.png")
local image_help = love.graphics.newImage("images/help.png")
local image_back = love.graphics.newImage("images/back.png")
local image_bot = love.graphics.newImage("images/robot.png")
local image_human = love.graphics.newImage("images/man.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_anim = love.graphics.newImage("images/fly.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")
local image_lang = love.graphics.newImage("images/lang.png")

-- calculate
local cell_size = 120
local board = {x=0, y=0, w=120*8, h=120*4}
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 30 )
local button_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 40 )
local offset_info = 0
local coord = {
    menu = {x=0, y=0},
    help = {x=0, y=0},
    lang = {x=0, y=0},
    sound = {x=0, y=0},
    bot = {x=0, y=0},
    human = {x=0, y=0},
    about = {x=0, y=0},
    exit = {x=0, y=0},
    hand1 = {x=0, y=0},
    hand2 = {x=0, y=0}
}

-- game
local matrix = {}
local player = -1  -- 1 or 2, 0 if draw
local is_bot = true
local is_block = true
local is_stop = false
local is_first_turn = true
local is_show_menu = false
local is_show_info = false
local info_text = "Help text"
local group = tick.group()
local tween = flux.group()
local press_button = ""
local press_cell = {0, 0}
local target_cell = {0, 0}
local offset_anim = {x=0, y=0}
local vector_anim = {x=1, y=0}

-- save data
local save_matrix = { {0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0} }
local save_capture = false
local save_player = 1
local save_first_turn = true

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_capture = love.audio.newSource("audio/error.ogg", "static")
local sound_tween = love.audio.newSource("audio/tween.ogg", "static")
local sound_gameover = love.audio.newSource("audio/gameover.ogg", "static")


local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


local function get_rand_seed_pos(row, col)
    local hy = 1.75
    local ox = 0
    local oy = cell_size * 2
    if row == 2 then ox = cell_size end
    if (row == 1 and col == 1) or (row == 2 and col == 7) then
        hy = 2.75
        oy = cell_size
    end

    local rx = board.x + ox + cell_size * (col - 1) + love.math.random( math.ceil(cell_size * 0.25), math.floor(cell_size * 0.75) )
    local ry = board.y + oy * (row - 1) + love.math.random( math.ceil(cell_size * 0.25), math.floor(cell_size * hy) )
    local rr = love.math.random() * math.pi * 2

    return { x = rx, y = ry, rad = rr }
end


local function resize()
    --local W = love.graphics.getWidth()
    --local H = love.graphics.getHeight()

    cell_size = math.min(W / 9, H / 5)
    k_scale = cell_size / image_menu:getWidth()

    board.w = cell_size * 8
    board.h = cell_size * 4
    board.x = (W - board.w) * 0.5
    board.y = (H - board.h) * 0.5

    -- matrix seed's x and y
    for row=1,2 do
        for col=1,7 do
            local hy = 1.55
            local ox = 0
            local oy = cell_size * 2
            if row == 2 then ox = cell_size end
            if (row == 1 and col == 1) or (row == 2 and col == 7) then
                hy = 2.55
                oy = cell_size
            end
            for _k,v in pairs(matrix[row][col]) do
                tween:to(v, 0.6, get_rand_seed_pos(row, col))
            end
        end
    end

    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.25 )
    button_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size / 3 )
    game_font:setLineHeight( 0.7 )

    offset_anim = {x=0, y=0}
    
    coord = {
        menu = {x = board.x + board.w - cell_size, y = board.y},
        help = {x = board.x, y = board.y + cell_size * 3},
        lang = {x = board.x, y = board.y},
        sound = {x = board.x + board.w - cell_size, y = board.y + cell_size * 3},
        bot = {x = board.x + cell_size * 2, y = board.y},
        human = {x = board.x + cell_size * 2, y = board.y + cell_size},
        about = {x = board.x + cell_size * 2, y = board.y + cell_size * 2},
        exit = {x = board.x + cell_size * 2, y = board.y + cell_size * 3},
        hand1 = {x = board.x + cell_size * 0.1, y = board.y + cell_size * 0.5},
        hand2 = {x = board.x + board.w - cell_size * 0.1, y = board.y + cell_size * 2.5}
    }
end


local function human(h_matrix)
    local max_ambar = 0
    local moves = {}
    
    for col=1,7 do
        if h_matrix[2][col] > 0 and col ~= 7 then
            table.insert(moves, col)
        end
    end
    
    if #moves > 0 then
        for _k,v in pairs(moves) do
            local human_matrix = deepcopy(h_matrix)
            local index_row = 2
            local index_col = v
            local len = human_matrix[2][v]
            human_matrix[2][v] = 0

            while len > 0 do
                if index_row == 1 then
                    index_col = index_col - 1
                    if index_col == 1 then
                        index_row = 2
                    end
                else
                    index_col = index_col + 1
                    if index_col == 8 then
                        index_row = 1
                        index_col = 7
                    end
                end

                human_matrix[index_row][index_col] = human_matrix[index_row][index_col] + 1
                len = len - 1
            end
            
            -- Проверка на бонусный ход, захват и конец игры!
            if index_row == 2 and index_col == 7 then  -- bonus turn
                local max_value = human(human_matrix)
                if max_value > max_ambar then max_ambar = max_value end
                
            else
            
                if human_matrix[index_row][index_col] == 1 and index_row == 2 and human_matrix[1][index_col + 1] > 0 then  -- capture
                    human_matrix[2][7] = human_matrix[2][7] + human_matrix[index_row][index_col] + human_matrix[1][index_col + 1]
                    human_matrix[index_row][index_col] = 0
                    human_matrix[1][index_col + 1] = 0
                end
                
                local count_1 = human_matrix[1][2] + human_matrix[1][3] + human_matrix[1][4] + human_matrix[1][5] + human_matrix[1][6] + human_matrix[1][7]
                local count_2 = human_matrix[2][1] + human_matrix[2][2] + human_matrix[2][3] + human_matrix[2][4] + human_matrix[2][5] + human_matrix[2][6]
                
                if human_matrix[1][1] > 36 or human_matrix[2][7] > 36 or count_1 == 0 or count_2 == 0 then  -- game over
                    human_matrix[2][7] = human_matrix[2][7] + human_matrix[2][1] + human_matrix[2][2] + human_matrix[2][3] + human_matrix[2][4] + human_matrix[2][5] + human_matrix[2][6]
                end
                    
                if human_matrix[2][7] > max_ambar then max_ambar = human_matrix[2][7] end
            
            end
            
        end
        
    end
    
    return max_ambar
end


local function bot(bot_matrix)
    local max_matrix = {}  -- { {human_ambar, index_move, bot_ambar}, ... }
    local moves = {}
    
    for col=1,7 do
        if bot_matrix[1][col] > 0 and col ~= 1 and not (is_first_turn and col == 7) then
            table.insert(moves, col)
        end
    end
    
    if #moves > 0 then
        for _k,v in pairs(moves) do
            local human_matrix = deepcopy(bot_matrix)
            local index_row = 1
            local index_col = v
            local len = human_matrix[1][v]
            human_matrix[1][v] = 0

            while len > 0 do
                if index_row == 1 then
                    index_col = index_col - 1
                    if index_col == 0 then
                        index_col = 1
                        index_row = 2
                    end
                else
                    index_col = index_col + 1
                    if index_col == 7 then
                        index_row = 1
                    end
                end

                human_matrix[index_row][index_col] = human_matrix[index_row][index_col] + 1
                len = len - 1
            end
            
            -- Проверка на бонусный ход, захват и конец игры!
            if index_row == 1 and index_col == 1 then  -- bonus turn
                local temp_matrix = bot(human_matrix)
                local max_value = 0
                local bot_ambar = 0
                for _kk,vv in pairs(temp_matrix) do
                    if vv[1] > max_value then
                        max_value = vv[1]
                        bot_ambar = vv[3]
                    end
                end
                table.insert(max_matrix, {max_value, v, bot_ambar})
                
            else
            
                if human_matrix[index_row][index_col] == 1 and index_row == 1 and human_matrix[2][index_col - 1] > 0 then  -- capture
                    human_matrix[1][1] = human_matrix[1][1] + human_matrix[index_row][index_col] + human_matrix[2][index_col - 1]
                    human_matrix[index_row][index_col] = 0
                    human_matrix[2][index_col - 1] = 0
                end
                
                local count_1 = human_matrix[1][2] + human_matrix[1][3] + human_matrix[1][4] + human_matrix[1][5] + human_matrix[1][6] + human_matrix[1][7]
                local count_2 = human_matrix[2][1] + human_matrix[2][2] + human_matrix[2][3] + human_matrix[2][4] + human_matrix[2][5] + human_matrix[2][6]
                
                if human_matrix[1][1] > 36 or human_matrix[2][7] > 36 or count_1 == 0 or count_2 == 0 then  -- game over
                    human_matrix[1][1] = human_matrix[1][1] + human_matrix[1][2] + human_matrix[1][3] + human_matrix[1][4] + human_matrix[1][5] + human_matrix[1][6] + human_matrix[1][7]
                    human_matrix[2][7] = human_matrix[2][7] + human_matrix[2][1] + human_matrix[2][2] + human_matrix[2][3] + human_matrix[2][4] + human_matrix[2][5] + human_matrix[2][6]
                    table.insert(max_matrix, {human_matrix[2][7], v, human_matrix[1][1]})
                    
                else
                    
                    local max_human = human(human_matrix)
                    table.insert(max_matrix, {max_human, v, human_matrix[1][1]})
                    
                end
            
            end
            
        end
        
    end
    
    return max_matrix
end


local function bot_move()
    if not is_stop then
        local bot_matrix = { {0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0} }
        local moves = {}  -- для случайного хода
        
        for row=1,2 do
            for col=1,7 do
                bot_matrix[row][col] = #matrix[row][col]
                if row == 1 and #matrix[row][col] > 0 and col ~= 1 and not (is_first_turn and col == 7) then
                    table.insert(moves, col)
                end
            end
        end
        
        if #moves > 0 then
            local max_matrix = bot(bot_matrix)
            local min_human_ambar = 72
            local max_bot_ambar = 0
            
            for _k,v in pairs(max_matrix) do
                if v[1] < min_human_ambar then min_human_ambar = v[1] end
                if v[3] > max_bot_ambar then max_bot_ambar = v[3] end
            end
            
            min_moves = {}
            max_moves = {}
            
            for _kk,vv in pairs(max_matrix) do
                if vv[1] == min_human_ambar then table.insert(min_moves, vv[2]) end
                if vv[3] == max_bot_ambar then
                    if (vv[3] - bot_matrix[1][1]) >= (vv[1] - bot_matrix[2][7]) then table.insert(max_moves, vv[2]) end
                end
            end       
            
            local press_index = 0
            local rand_move = love.math.random( 1, 100 )
            if rand_move > 90 then press_index = moves[ love.math.random( 1, #moves ) ]  -- random 10% chance
            elseif #max_moves ~= 0 then press_index = max_moves[ love.math.random( 1, #max_moves ) ]  -- maxmax
            else press_index = min_moves[ love.math.random( 1, #min_moves ) ]  -- minmax
            end
            
            is_first_turn = false
            press_cell = {1, press_index}
            group:delay(function() press_field(1, press_index) end, 0.3)
        
        else
            msg("ERROR Bot no moves!")
        end
    end
end


local function after_game_over()
    if not is_stop then
        if #matrix[1][1] > 36 then
            player = 1
        elseif #matrix[2][7] > 36 then
            player = 2
        elseif #matrix[1][1] == 36 and #matrix[2][7] == 36 then
            player = 0
        end
        
        offset_anim = {x=0, y=0}
        vector_anim = {x=0, y=1}
        if is_sound then sound_gameover:play() end
    end
end


local function after_analyze(is_capture) -- call from load function
    if not is_stop then
        target_cell = {0, 0}
        local capture = is_capture or false
        local count_1 = #matrix[1][2] + #matrix[1][3] + #matrix[1][4] + #matrix[1][5] + #matrix[1][6] + #matrix[1][7]
        local count_2 = #matrix[2][1] + #matrix[2][2] + #matrix[2][3] + #matrix[2][4] + #matrix[2][5] + #matrix[2][6]
        
        if #matrix[1][1] > 36 or #matrix[2][7] > 36 or count_1 == 0 or count_2 == 0 then  -- game over
            love.system.vibrate(0.150)
            
            for row=1,2 do
                for col=1,6 do
                    local icol = col
                    local ambar = 7
                    
                    if row == 1 then
                        icol = col + 1
                        ambar = 1
                    end                
                    
                    if #matrix[row][icol] > 0 then
                        local len = #matrix[row][icol]
                        while len > 0 do
                            seed = table.remove(matrix[row][icol], len)
                            table.insert(matrix[row][ambar], seed)
                            local i = #matrix[row][ambar]
                            tween:to(matrix[row][ambar][i], 0.6, get_rand_seed_pos(row, ambar))
                            len = len - 1
                        end
                    end
                end
            end
            
            if is_sound then sound_tween:play() end
            group:delay(function() after_game_over() end, 0.6)
        
        else    
            if capture then -- next player for capture
                if player == 1 then player = 2 else player = 1 end
            end
            
            if player == 2 or not is_bot then
                is_block = false
            else
                bot_move()
            end
        end
    end
end


local function analyze(index_row, index_col)
    if not is_stop then
        local row = index_row or 1
        local col = index_col or 1
        local is_capture = false
        local dt = 0.0
        
        if is_first_turn then
            local turn = love.math.random( 1, 100 )
            if turn <= 50 then player = 1 else player = 2 end
        else
            if (row == 1 and col == 1 and player == 1) or (row == 2 and col == 7 and player == 2) then  -- bonus turn
                player = player
            
            elseif #matrix[row][col] == 1 and player == row then  -- capture
                local other_row = 1
                local other_col = 1
                if player == 1 then
                    other_row = 2
                    other_col = col - 1
                elseif player == 2 then
                    other_col = col + 1
                end
                
                if #matrix[other_row][other_col] > 0 then
                    love.system.vibrate(0.150)
                    if is_sound then sound_capture:play() end
                    
                    target_cell = {other_row, other_col}
                    is_capture = true
                    dt = 0.6
                    
                    local ambar = 1
                    if player == 2 then ambar = 7 end
                    
                    local seed = table.remove(matrix[row][col], 1)
                    table.insert(matrix[player][ambar], seed)
                    local i = #matrix[player][ambar]
                    tween:to(matrix[player][ambar][i], 0.6, get_rand_seed_pos(player, ambar))
                    
                    local len = #matrix[other_row][other_col]
                    while len > 0 do
                        seed = table.remove(matrix[other_row][other_col], len)
                        table.insert(matrix[player][ambar], seed)
                        local i = #matrix[player][ambar]
                        tween:to(matrix[player][ambar][i], 0.6, get_rand_seed_pos(player, ambar))
                        len = len - 1
                    end
                    if is_sound then sound_tween:play() end
                else  -- next player
                    if player == 1 then player = 2 else player = 1 end
                end
            
            else  -- next player
                if player == 1 then player = 2 else player = 1 end
            end
        end
        
        -- save data
        for row=1,2 do
            for col=1,7 do
                save_matrix[row][col] = #matrix[row][col]
            end
        end
        save_capture = is_capture
        save_player = player
        save_first_turn = is_first_turn
        
        group:delay(function() after_analyze(is_capture) end, dt)
    end
end


local function new_game()
    is_block = true
    is_first_turn = true

    -- очистка
    local new_matrix = {}
    for row=1,2 do
        table.insert(new_matrix, {})
        for col=1,7 do
            table.insert(new_matrix[row], {})
            if not ((row == 1 and col == 1) or (row == 2 and col == 7)) then
                for s=1,6 do
                    table.insert(new_matrix[row][col], {x=0, y=0, rad=0})
                end
            end
        end
    end
    
    matrix = new_matrix    
    resize()
    if is_sound then sound_tween:play() end
    
    vector_anim = {x=1, y=0}
    is_stop = false
    
    group:delay(function() analyze() end, 0.6)
end


local function save_game()
    local data = {}
    data.player = save_player
    data.matrix = deepcopy(save_matrix)
    data.capture = save_capture
    data.first_turn = save_first_turn
    data.is_bot = is_bot

    local serialized = lume.serialize(data)
    love.filesystem.write("mancala", serialized)
end


function game.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("Game vs Bot", "Game vs Bot")
    s:set("Game vs Human", "Game vs Human")
    s:set("About game", "About game")
    s:set("Exit game", "Exit game")
    s:set("Help text", [[MANCALA (Kalah, Bantumi)
The game has 12 fields (6 grains each) in two rows and two barns on the sides. Players take turns taking grains from their field and distribute them one by one counterclockwise to each of the following fields and their barn, skipping the opponent's barn. If the last grain is placed in the barn, the player goes again. If the last grain is placed in their empty field and the opponent's opposite field is not empty, the player transfers all these grains to the barn. The first move from the first field is prohibited. When one of the players has all the fields empty or more than half of all the grains in the barn, the remaining grains are transferred to the barn. The player with the most grains wins!]])
    s:set("About text", [[ABOUT GAME

Images: OpenMoji
openmoji.org

The Programming Language Lua
lua.org

LÖVE Free 2D Game Engine
love2d.org

(c) 2026 Anton Bezdolny
avbezdolny.github.io]])

    -- RU
    s:set_namespace("ru")
    s:set("Game vs Bot", "Игра с ботом")
    s:set("Game vs Human", "Игра с другом")
    s:set("About game", "Об игре")
    s:set("Exit game", "Выход")
    s:set("Help text", [[МАНКАЛА (Калах, Бантуми)
В игре 12 полей (по 6 зерен) в два ряда и два амбара по сторонам. Игроки по очереди берут зерна из своего поля и распределяют их по одному против часовой стрелки в каждое из следующих полей и свой амбар, пропуская амбар соперника. Если последнее зерно попало в амбар, то игрок ходит снова. Если последнее зерно попало в своё пустое поле и противоположное поле соперника не пустое, то все эти зерна игрок переносит в амбар. Запрещен первый ход из первого поля. Когда у одного из игроков все поля пустые или в амбаре больше половины всех зерен, оставшиеся зерна игроки переносят в амбар. Побеждает игрок, набравший больше зерен!]])
    s:set("About text", [[ОБ ИГРЕ

Изображения: OpenMoji
openmoji.org

Язык Программирования Lua
lua.org

LÖVE Свободный 2D Игровой Движок
love2d.org

(c) 2026 Антон Бездольный
avbezdolny.github.io]])

    s:set_namespace(game_lang)

    -- default matrix
    for row=1,2 do
        table.insert(matrix, {})
        for col=1,7 do
            table.insert(matrix[row], {})
            if not ((row == 1 and col == 1) or (row == 2 and col == 7)) then
                for s=1,6 do
                    table.insert(matrix[row][col], {x=0, y=0, rad=0})
                end
            end
        end
    end

    -- load save data
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("mancala") then
            local file = love.filesystem.read("mancala")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local is_capture = false
        
        local ok, msg = pcall( function()
            
            if not (data.player == 1 or data.player == 2) then error("Incorrect save data!")
            else player = data.player end
            
            if not (data.capture == true or data.capture == false) then error("Incorrect save data!")
            else is_capture = data.capture end
            
            if not (data.first_turn == true or data.first_turn == false) then error("Incorrect save data!")
            else is_first_turn = data.first_turn end
            
            if not (data.is_bot == true or data.is_bot == false) then error("Incorrect save data!")
            else is_bot = data.is_bot end

            local temp_matrix = {}
            
            for row=1,2 do
                table.insert(temp_matrix, {})
                for col=1,7 do
                    table.insert(temp_matrix[row], {})
                    if data.matrix[row][col] >= 0 and data.matrix[row][col] <= 72 then
                        if data.matrix[row][col] > 0 then
                            for s=1,data.matrix[row][col] do
                                table.insert(temp_matrix[row][col], {x=0, y=0, rad=0})
                            end
                        end
                    else error("Incorrect save data!") end
                end
            end
            
            matrix = temp_matrix    
            resize()
            if is_sound then sound_tween:play() end
            
            save_matrix = data.matrix
            save_capture = is_capture
            save_player = player
            save_first_turn = is_first_turn
            
        end )

        if ok then  -- при выполнении защищенного кода ошибок нет
            group:delay(function() after_analyze(is_capture) end, 0.6)
        
        else  -- защищенный код вызвал ошибку
            msg("ERROR reading saved data! " .. (msg or "..."))
            new_game()
        end
    else
        --love.window.showMessageBox("Message", "Saved data was not found!\n" .. (err or "..."), "info")
        new_game()
    end
end


function game.update(dt)
    group:update(dt)
    tween:update(dt)

    if is_anim then
        -- hand
        offset_anim = {x = offset_anim.x + dt * vector_anim.x * cell_size * 0.1, y = offset_anim.y + dt * vector_anim.y * cell_size * 0.1}
        
        if math.abs(offset_anim.x) >= cell_size * 0.1 then offset_anim.x = 0 end  -- для исправления скачков анимации при паузах
        if math.abs(offset_anim.y) >= cell_size * 0.1 then offset_anim.y = 0 end  -- для исправления скачков анимации при паузах
        
        if offset_anim.x >= cell_size * 0.05 then
            vector_anim.x = -1
        elseif offset_anim.x < 0 then
            vector_anim.x = 1
        elseif offset_anim.y >= cell_size * 0.05 then
            vector_anim.y = -1
        elseif offset_anim.y < 0 then
            vector_anim.y = 1
        end
    end
end


function game.draw()
    local bcolor = {1, 1, 1, 0.5}
    
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        --love.graphics.rectangle("fill", board.x, board.y, board.w, board.h)
        love.graphics.setFont(game_font)

        for row=1,2 do
            local ty = - cell_size * 0.4
            if row == 2 then ty = cell_size * 4.075 end
            for col=1,7 do
                local img = "field"
                local ox = 0
                local oy = cell_size * 2
                if row == 2 then ox = cell_size end
                if (row == 1 and col == 1) or (row == 2 and col == 7) then
                    img = "ambar"
                    oy = cell_size
                end

                bcolor = color_cell
                if not is_block and row == player and #matrix[row][col] > 0 and not ((row == 1 and col == 1) or (row == 2 and col == 7)) and not (is_first_turn and ((row == 1 and col == 7) or (row == 2 and col == 1))) then
                    bcolor = color_select
                end
                if row == press_cell[1] and col == press_cell[2] then bcolor = color_press end
                if row == 1 and col == 1 then bcolor = color_red_ambar end
                if row == 2 and col == 7 then bcolor = color_blue_ambar end
                
                if img == "field" then
                    draw_button(board.x + ox + cell_size * (col - 1) + cell_size * 0.032, board.y + oy * (row - 1) + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor, {1, 1, 1, 0})
                elseif img == "ambar" then
                    draw_button(board.x + ox + cell_size * (col - 1) + cell_size * 0.032, board.y + oy * (row - 1) + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size * 3 - cell_size * 0.064, bcolor, {1, 1, 1, 0})
                end

                love.graphics.setColor(1, 1, 1, 1)
                for _k,v in pairs(matrix[row][col]) do
                    love.graphics.draw(image_seed, v.x, v.y, v.rad, k_scale * 0.4, k_scale * 0.4, image_seed:getWidth() * 0.5, image_seed:getHeight() * 0.5)
                end

                if row == target_cell[1] and col == target_cell[2] then love.graphics.draw(image_target, board.x + ox + cell_size * (col - 1), board.y + oy * (row - 1) + cell_size * 0.5, 0, k_scale, k_scale) end
                
                if (row == 1 and col == 1) then love.graphics.setColor(color_red) elseif (row == 2 and col == 7) then love.graphics.setColor(color_blue) else love.graphics.setColor(color_fg) end
                love.graphics.printf(#matrix[row][col], board.x + ox + cell_size * (col - 1), board.y + ty, cell_size, "center")
            end
        end
    
        -- hand
        love.graphics.setColor(1, 1, 1, 1)
        if not (#matrix[1][1] > 36 or #matrix[2][7] > 36 or (#matrix[1][1] == 36 and #matrix[2][7] == 36)) then
            if player == 1 then
                love.graphics.draw(image_hand, coord.hand1.x - offset_anim.x, coord.hand1.y - offset_anim.y, 0, -k_scale, k_scale)
            end
            if player == 2 then
                love.graphics.draw(image_hand, coord.hand2.x + offset_anim.x, coord.hand2.y - offset_anim.y, 0, k_scale, k_scale)
            end
        else  -- game over
            if player == 1 or player == 0 then
                love.graphics.draw(image_victory, coord.hand1.x - offset_anim.x, coord.hand1.y - offset_anim.y, 0, -k_scale, k_scale)
            end
            if player == 2 or player == 0 then
                love.graphics.draw(image_victory, coord.hand2.x + offset_anim.x, coord.hand2.y - offset_anim.y, 0, k_scale, k_scale)
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if press_button == "menu" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(coord.menu.x + cell_size * 0.032, coord.menu.y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    if press_button == "info" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(coord.help.x + cell_size * 0.032, coord.help.y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    if is_show_menu then love.graphics.draw(image_back, coord.menu.x, coord.menu.y, 0, k_scale, k_scale)
    else love.graphics.draw(image_menu, coord.menu.x, coord.menu.y, 0, k_scale, k_scale) end
    
    if is_show_menu then
        if is_anim then love.graphics.draw(image_anim, coord.help.x, coord.help.y, 0, k_scale, k_scale)
        else love.graphics.draw(image_stop, coord.help.x, coord.help.y, 0, k_scale, k_scale) end
    elseif is_show_info then love.graphics.draw(image_back, coord.help.x, coord.help.y, 0, k_scale, k_scale)
    else love.graphics.draw(image_help, coord.help.x, coord.help.y, 0, k_scale, k_scale) end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if press_button == "lang" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.lang.x + cell_size * 0.032, coord.lang.y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "sound" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.sound.x + cell_size * 0.032, coord.sound.y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "bot" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.bot.x + cell_size * 0.032, coord.bot.y + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "human" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.human.x + cell_size * 0.032, coord.human.y + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "about" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.about.x + cell_size * 0.032, coord.about.y + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "exit" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.exit.x + cell_size * 0.032, coord.exit.y + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_lang, coord.lang.x, coord.lang.y, 0, k_scale, k_scale)
        if is_sound then love.graphics.draw(image_sound, coord.sound.x, coord.sound.y, 0, k_scale, k_scale) else love.graphics.draw(image_mute, coord.sound.x, coord.sound.y, 0, k_scale, k_scale) end
        love.graphics.draw(image_bot, coord.bot.x, coord.bot.y, 0, k_scale, k_scale)
        love.graphics.draw(image_human, coord.human.x, coord.human.y, 0, k_scale, k_scale)
        love.graphics.draw(image_about, coord.about.x, coord.about.y, 0, k_scale, k_scale)
        love.graphics.draw(image_exit, coord.exit.x, coord.exit.y, 0, k_scale, k_scale)
        
        love.graphics.setColor(color_fg)
        love.graphics.setFont(button_font)
        love.graphics.printf(s("Game vs Bot"), coord.bot.x + cell_size * 0.5, coord.bot.y + cell_size * 0.25, cell_size * 3.5, "center")
        love.graphics.printf(s("Game vs Human"), coord.human.x + cell_size * 0.5, coord.human.y + cell_size * 0.25, cell_size * 3.5, "center")
        love.graphics.printf(s("About game"), coord.about.x + cell_size * 0.5, coord.about.y + cell_size * 0.25, cell_size * 3.5, "center")
        love.graphics.printf(s("Exit game"), coord.exit.x + cell_size * 0.5, coord.exit.y + cell_size * 0.25, cell_size * 3.5, "center")
    end

    -- ИНФО
    if is_show_info then
        love.graphics.setColor(color_fg)
        love.graphics.setFont(game_font)
        love.graphics.printf(s(info_text), board.x + cell_size * 1.05, offset_info, cell_size * 5.9, "center")
    end

end


local function calculate_offset_info()
    local _w, t = game_font:getWrap(s(info_text), cell_size * 5.9)
    offset_info = ( H - #t * cell_size * 0.25 * 0.95 ) / 2
end


local function after_press(row, col)
    if not is_stop then
        local index_row = row
        local index_col = col
        local len = #matrix[row][col]

        while len > 0 do
            if index_row == 1 then
                index_col = index_col - 1
                if player == 1 and index_col == 0 then
                    index_col = 1
                    index_row = 2
                elseif player == 2 and index_col == 1 then
                    index_row = 2
                end
            else
                index_col = index_col + 1
                if player == 1 and index_col == 7 then
                    index_row = 1
                elseif player == 2 and index_col == 8 then
                    index_col = 7
                    index_row = 1
                end
            end

            local seed = table.remove(matrix[row][col], len)
            table.insert(matrix[index_row][index_col], seed)
            local i = #matrix[index_row][index_col]
            tween:to(matrix[index_row][index_col][i], 0.6, get_rand_seed_pos(index_row, index_col))
            len = len - 1
        end
        
        if is_sound then sound_tween:play() end
        group:delay(function() analyze(index_row, index_col) end, 0.6)
    end
end


function press_field(row, col)  -- global
    if not is_stop then
        if is_sound then sound_click:play() end
        
        for _k,v in pairs(matrix[row][col]) do
            local sy = board.y - cell_size * 0.25
            if row == 2 then sy = board.y + board.h + cell_size * 0.25 end
            tween:to(v, 0.3, { y = sy })
        end
        
        press_cell = {0, 0}  -- for bot
        group:delay(function() after_press(row, col) end, 0.3)
    end
end


local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)  -- пересечение точки с прямоугольником
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


function game.keypressed(key, scancode, isrepeat)  -- love.keyreleased( key, scancode )
    if key == "escape" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    end
end


function game.mousepressed( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        if not is_block and is_collide(x, y, board.x, board.y, board.w, board.h) then
            for row=1,2 do
                for col=1,7 do
                    local ox = 0
                    local oy = cell_size * 2
                    if row == 2 then ox = cell_size end
                    if (row == 1 and col == 1) or (row == 2 and col == 7) then oy = cell_size end

                    if row == player and #matrix[row][col] > 0 and not ((row == 1 and col == 1) or (row == 2 and col == 7)) and not (is_first_turn and ((row == 1 and col == 7) or (row == 2 and col == 1))) then
                        if is_collide(x, y, board.x + ox + cell_size * (col - 1), board.y + oy * (row - 1), cell_size, cell_size * 2) then
                            press_cell = {row, col}
                        end
                    end
                    
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, coord.help.x, coord.help.y, cell_size, cell_size) then
        press_button = "info"
    elseif is_collide(x, y, coord.menu.x, coord.menu.y, cell_size, cell_size) then
        press_button = "menu"
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, coord.lang.x, coord.lang.y, cell_size, cell_size) then
            press_button = "lang"
        elseif is_collide(x, y, coord.sound.x, coord.sound.y, cell_size, cell_size) then
            press_button = "sound"
        elseif is_collide(x, y, coord.bot.x, coord.bot.y, cell_size * 4, cell_size) then
            press_button = "bot"
        elseif is_collide(x, y, coord.human.x, coord.human.y, cell_size * 4, cell_size) then
            press_button = "human"
        elseif is_collide(x, y, coord.about.x, coord.about.y, cell_size * 4, cell_size) then
            press_button = "about"
        elseif is_collide(x, y, coord.exit.x, coord.exit.y, cell_size * 4, cell_size) then
            press_button = "exit"
        end
    end
end


function game.mousereleased( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        if not is_block and is_collide(x, y, board.x, board.y, board.w, board.h) then
            for row=1,2 do
                for col=1,7 do
                    local ox = 0
                    local oy = cell_size * 2
                    if row == 2 then ox = cell_size end
                    if (row == 1 and col == 1) or (row == 2 and col == 7) then oy = cell_size end

                    if row == player and #matrix[row][col] > 0 and not ((row == 1 and col == 1) or (row == 2 and col == 7)) and not (is_first_turn and ((row == 1 and col == 7) or (row == 2 and col == 1))) then
                        if is_collide(x, y, board.x + ox + cell_size * (col - 1), board.y + oy * (row - 1), cell_size, cell_size * 2) and row == press_cell[1] and col == press_cell[2] then
                            is_block = true
                            is_first_turn = false
                            press_field(row, col)
                        end
                    end
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, coord.help.x, coord.help.y, cell_size, cell_size) and press_button == "info" then
        if is_sound then sound_click:play() end
        if is_show_menu then
            is_anim = not is_anim
            offset_anim = {x=0, y=0}
        elseif is_show_info then
            is_show_info = false
        else
            info_text = "Help text"
            calculate_offset_info()
            is_show_info = true
        end
    elseif is_collide(x, y, coord.menu.x, coord.menu.y, cell_size, cell_size) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, coord.lang.x, coord.lang.y, cell_size, cell_size) and press_button == "lang" then
            if is_sound then sound_click:play() end
            if game_lang == "en" then game_lang = "ru" else game_lang = "en" end
            s:set_namespace(game_lang)
        
        elseif is_collide(x, y, coord.sound.x, coord.sound.y, cell_size, cell_size) and press_button == "sound" then
            if is_sound then sound_click:play() end
            is_sound = not is_sound
        
        elseif is_collide(x, y, coord.bot.x, coord.bot.y, cell_size * 4, cell_size) and press_button == "bot" then
            if is_sound then sound_click:play() end
            is_stop = true
            is_block = true
            player = -1
            is_show_menu = false
            
            for row=1,2 do
                for col=1,7 do
                    for _k,v in pairs(matrix[row][col]) do
                        tween:to(v, 0.6, {x=0, y=0})
                    end
                end
            end
            
            if is_sound then sound_tween:play() end
            
            is_bot = true
            group:delay(function() new_game() end, 0.600)
        
        elseif is_collide(x, y, coord.human.x, coord.human.y, cell_size * 4, cell_size) and press_button == "human" then
            if is_sound then sound_click:play() end
            is_stop = true
            is_block = true
            player = -1
            is_show_menu = false
            
            for row=1,2 do
                for col=1,7 do
                    for _k,v in pairs(matrix[row][col]) do
                        tween:to(v, 0.6, {x=0, y=0})
                    end
                end
            end
            
            if is_sound then sound_tween:play() end
            
            is_bot = false
            group:delay(function() new_game() end, 0.600)
        
        elseif is_collide(x, y, coord.about.x, coord.about.y, cell_size * 4, cell_size) and press_button == "about" then
            if is_sound then sound_click:play() end
            info_text = "About text"
            calculate_offset_info()
            is_show_menu = false
            is_show_info = true
        
        elseif is_collide(x, y, coord.exit.x, coord.exit.y, cell_size * 4, cell_size) and press_button == "exit" then
            if is_sound then sound_click:play() end
            --group:delay(function() love.event.quit(0) end, 0.300)
            
            -- Возврат в лаунчер
            save_game()
            is_show_menu = false
            current_state = launcher
            current_state.load()
        end
    end

    press_button = ""
    press_cell = {0, 0}
end


function game.resize(w, h)
    --print(("Window resized to width: %d and height: %d."):format(w, h))
    group:delay(function() resize() end, 0.150)
         :after(function() calculate_offset_info() end, 0.150)
end

function game.focus(f)
  if not f then  -- Window is not focused
    save_game()
  end
end


function game.quit()
    save_game()
    return false
end


return game
