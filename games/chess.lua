local game = {}

local garbochess = require("modules/garbochess")
local puzzle = require("modules/puzzle")
local tick = require("modules/tick")
local flux = require("modules/flux")
local lume = require("modules/lume")
local s = require("modules/say")

-- colors
--local color_fg = {63/255, 63/255, 63/255}  -- #3f3f3f
--local color_button_press = {155/255, 155/255, 154/255}  -- #9b9b9a
local color_select = {252/255, 234/255, 43/255, 0.5}  -- #ffdd67
local color_valid = {177/255, 204/255, 51/255, 0.5}  -- #4bd37b
local color_history = {179/255, 153/255, 200/255, 0.5}  -- #b399c8
local color_blue = {97/255, 178/255, 228/255}  -- #61b2e4
local color_red = {234/255, 90/255, 71/255}  -- #ea5a47

-- images
local image_square = love.graphics.newImage("images/square.png")
local image_black_bishop = love.graphics.newImage("images/black-bishop.png")
local image_black_king = love.graphics.newImage("images/black-king.png")
local image_black_knight = love.graphics.newImage("images/black-knight.png")
local image_black_pawn = love.graphics.newImage("images/black-pawn.png")
local image_black_queen = love.graphics.newImage("images/black-queen.png")
local image_black_rook = love.graphics.newImage("images/black-rook.png")
local image_white_bishop = love.graphics.newImage("images/white-bishop.png")
local image_white_king = love.graphics.newImage("images/white-king.png")
local image_white_knight = love.graphics.newImage("images/white-knight.png")
local image_white_pawn = love.graphics.newImage("images/white-pawn.png")
local image_white_queen = love.graphics.newImage("images/white-queen.png")
local image_white_rook = love.graphics.newImage("images/white-rook.png")
local image_hint = love.graphics.newImage("images/light-bulb.png")
local image_white_player = love.graphics.newImage("images/white_side.png")
local image_black_player = love.graphics.newImage("images/black_side.png")
local image_hand = love.graphics.newImage("images/hand_bottom.png")
local image_victory = love.graphics.newImage("images/hand_victory.png")
local image_man = love.graphics.newImage("images/man.png")
local image_bot = love.graphics.newImage("images/robot.png")
local image_puzzle = love.graphics.newImage("images/puzzle.png")
local image_back = love.graphics.newImage("images/back.png")
local image_menu = love.graphics.newImage("images/gear.png")
local image_lang = love.graphics.newImage("images/lang.png")
local image_fly = love.graphics.newImage("images/fly.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_restart = love.graphics.newImage("images/recycling.png")

-- calculate
local cell_size = 90
local board = {x=0, y=0, size=90*8}
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 30 )

-- game
local matrix = {}  -- chess board   cell -> { label="a8", color="white", piece={value="K", x=0, y=0} }
local board_labels = {[1]='a', [2]='b', [3]='c', [4]='d', [5]='e', [6]='f', [7]='g', [8]='h'}
local game_mode = 1  -- 1 -> chess, 2 -> puzzle
local player = 1  -- 1 or 2
local player_side = {"white", "black"}
local is_bot = true
local is_block = true
local is_show_menu = false
local is_show_info = false
local group = tick.group()
local tween = flux.group()
local is_flip = false
local bot_rotation = math.rad(0)
local valid_moves = {}  -- {"e2e4", ...}
local hint_move = {}  -- {"e2", "e4"}
local select_move = {}  -- {"e2", "e4"}
local history_move = {}  -- {"e2", "e4"}
local is_promotion = false
local promo_coord = {}
local promo_move = ""
local press_button = ""
local offset_anim = 0
local vector_anim = 1
local puzzle_moves = {}
local puzzle_turn = 1
local is_stop = false

-- thread
local is_thread = false
local thread -- Our thread object
local threadCode = [[
local garbochess = require("modules/garbochess")

local fen = ...

garbochess.InitializeEval()
garbochess.ResetGame()
garbochess.InitializeFromFen(fen)

local bestmove
bestmove = garbochess.Search(5)

love.thread.getChannel( "info" ):push( bestmove )
]]

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_move = love.audio.newSource("audio/move.ogg", "static")
local sound_error = love.audio.newSource("audio/error.ogg", "static")
local sound_gameover = love.audio.newSource("audio/gameover.ogg", "static")


local function stop_thread()
    if is_thread then
        is_thread = false
        if thread:isRunning( ) then
            thread:wait()  -- замораживает GUI
            love.thread.getChannel( "info" ):pop()
        end
    end
    is_stop = false
end


local function calculate_promo()
    --local W = love.graphics.getWidth()
    --local H = love.graphics.getHeight()
    
    if W > H then
        if player == 1 then
            promo_coord = {
                q = {x=cell_size * 0.25, y=H - cell_size * 1.75},
                r = {x=cell_size * 0.25, y=H - cell_size * 3.25},
                n = {x=cell_size * 0.25, y=H - cell_size * 4.75},
                b = {x=cell_size * 0.25, y=H - cell_size * 6.25}
            }
        else
            promo_coord = {
                q = {x=W - cell_size * 1.75, y=H - cell_size * 1.75},
                r = {x=W - cell_size * 1.75, y=H - cell_size * 3.25},
                n = {x=W - cell_size * 1.75, y=H - cell_size * 4.75},
                b = {x=W - cell_size * 1.75, y=H - cell_size * 6.25}
            }
        end
    else
        if player == 1 then
            promo_coord = {
                q = {x=cell_size * 0.25, y=H - cell_size * 1.75},
                r = {x=cell_size * 1.75, y=H - cell_size * 1.75},
                n = {x=cell_size * 3.25, y=H - cell_size * 1.75},
                b = {x=cell_size * 4.75, y=H - cell_size * 1.75}
            }
        else
            promo_coord = {
                q = {x=W - cell_size * 1.75, y=H - cell_size * 1.75},
                r = {x=W - cell_size * 3.25, y=H - cell_size * 1.75},
                n = {x=W - cell_size * 4.75, y=H - cell_size * 1.75},
                b = {x=W - cell_size * 6.25, y=H - cell_size * 1.75}
            }
        end
    end
end


local function resize()
    --local W = love.graphics.getWidth()
    --local H = love.graphics.getHeight()

    if W > H then
        cell_size = math.min(W / 14.5, H / 8.5)
    else
        cell_size = math.min(W / 8.5, H / 14.5)
    end

    k_scale = cell_size / image_square:getWidth()

    board.size = cell_size * 8
    board.x = (W - board.size) * 0.5
    board.y = (H - board.size) * 0.5

    for row = 1,8 do
        for col = 1,8 do
            if matrix[row][col].piece.value then
                matrix[row][col].piece.x = cell_size * (col - 1)
                matrix[row][col].piece.y = cell_size * (row - 1)
            end
        end
    end

    calculate_promo()
    
    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size / 3 )
    game_font:setLineHeight( 0.9 )
    love.graphics.setFont(game_font)
    
    offset_anim = 0
    vector_anim = 1
end


local function bot_move(fen)
    if is_stop then return end
    thread:start( fen )  -- start thread
    is_thread = true
end


local function get_piece_count()
    local piece_count = {}
    
    for row = 1,8 do
        for col = 1,8 do
            if matrix[row][col].piece.value then
                local p = string.lower(matrix[row][col].piece.value)
                if piece_count[p] then piece_count[p] = piece_count[p] + 1
                else piece_count[p] = 1 end
            end
        end
    end
    
    return piece_count
end


local function get_valid_moves()
    valid_moves = {}
    local vm = garbochess.GenerateValidMoves()
    for _k,v in pairs(vm) do
        table.insert(valid_moves, garbochess.FormatMove(v))
    end
end


local function next_move(change_player)
    if is_stop then return end
    if change_player then
        if player == 1 then player = 2 else player = 1 end
    end
    valid_moves = {}
    
    if game_mode == 1 then  -- chess
        -- проверка на недостаток материала
        local pc = get_piece_count()
        local pc_len = 0
        for k,v in pairs(pc) do
            pc_len = pc_len + 1
        end
        
        if ( pc_len == 1 and pc["k"] == 2 ) or ( pc_len == 2 and pc["k"] == 2 and pc["n"] == 1 ) or ( pc_len == 2 and pc["k"] == 2 and pc["b"] == 1 ) then
            if change_player then
                if is_sound then sound_gameover:play() end
                love.system.vibrate(0.150)
                msg(s("GAME DRAW") .. "\n" .. s("Lack of material!"))  -- НИЧЬЯ Недостаток материала!
            end
        else
            get_valid_moves()
            
            if #valid_moves == 0 then
                if garbochess.g_inCheck then
                    if change_player then
                        if is_sound then sound_gameover:play() end
                        love.system.vibrate(0.150)
                        local win_player = player_side[1]
                        if player == 1 then win_player = player_side[2] end
                        msg(s("CHECK AND MATE") .. "\n" .. s("Win ") .. s(win_player) .. "!")  -- ШАХ И МАТ Победа белых/черных!
                    end
                else
                    if change_player then
                        if is_sound then sound_gameover:play() end
                        love.system.vibrate(0.150)
                        msg(s("GAME DRAW") .. "\n" .. s("Slatemate, no available moves!"))  -- НИЧЬЯ Пат, нет доступных ходов!
                    end
                end
            else  -- next move
                local fen = garbochess.GetFen()
                
                if player == 1 or not is_bot then
                    is_block = false
                else
                    if fen == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -" and not change_player then  -- рандомный первый ход бота для разнообразия
                        local rand_move = love.math.random( 1, #valid_moves )
                        group:delay(function() player_move( valid_moves[rand_move] ) end, 0.300)
                    else
                        bot_move(fen)
                    end
                end
            end
        end
    
    elseif game_mode == 2 then  -- puzzle
        if change_player then
            puzzle_turn = puzzle_turn + 1
        end
        
        if puzzle_turn > #puzzle_moves then  -- задача решена
            if change_player then
                if is_sound then sound_gameover:play() end
                love.system.vibrate(0.150)
                msg(s("COMPLETED") .. "\n" .. s("The puzzle is solved!"))
            end
        
        else
            get_valid_moves()
            
            if player == 1 then
                is_block = false
            else
                group:delay(function() player_move( puzzle_moves[puzzle_turn] ) end, 0.300)
            end
        end
    end
end


local function get_side(fen)
    local s = string.find( fen, " " )
    local side = string.sub( fen, s+1, s+1)
    if side == "w" then return "white"
    elseif side == "b" then return "black"
    else return side end
end


local function update_matrix_from_fen(fen, isNext, history, isAnim)
    if is_stop then return end
    local is_next = isNext or false
    history_move = history or {}
    anim = isAnim or false
    
    local s = 0
    local pieces = ""
    local c = " "
    local row = 1
    local col = 1

    s = string.find( fen, " " )
    pieces = string.sub( fen, 1, s-1)

    for i=0, string.len(pieces), 1 do
        c = string.sub(pieces, i+1, i+1 )

        if (c == '/') or i == string.len(pieces) then
            row = row + 1
            col = 1
        else
            if ( c >= '1' and c <= '8' ) then
                for j=1, tonumber(c), 1 do
                    matrix[row][col].piece = {}
                    col = col + 1
                end
            else
                if anim then
                    matrix[row][col].piece = { value = c, x = 0, y = 0 }
                    tween:to( matrix[row][col].piece, 0.300, { x = cell_size * (col - 1), y = cell_size * (row - 1) } )
                else
                    matrix[row][col].piece = { value = c, x = cell_size * (col - 1), y = cell_size * (row - 1) }
                end
                col = col + 1
            end
        end
    end
    
    select_move = {}
    if is_next then group:delay(function() next_move(true) end, 0.150) end
end


local function after_promotion_move(i_start, j_start, i_end, j_end)
    local p = matrix[i_start][j_start].piece.value
    matrix[i_end][j_end].piece = { value = p, x = cell_size * (j_end - 1), y = cell_size * (i_end - 1) }
    matrix[i_start][j_start].piece = {}
    
    calculate_promo()
    is_promotion = true
end


local function after_puzzle_error()
    if is_sound then sound_error:play() end
    love.system.vibrate(0.150)
    msg(s("INCORRECT") .. "\n" .. s("Find the best move!"))
    
    local fen = garbochess.GetFen()
    update_matrix_from_fen(fen, false, history_move)
    select_move = {}
    is_block = false
end


local function puzzle_error(i_start, j_start, i_end, j_end)
    if i_start and j_start and i_end and j_end then
        local p = matrix[i_start][j_start].piece.value
        matrix[i_end][j_end].piece = { value = p, x = cell_size * (j_end - 1), y = cell_size * (i_end - 1) }
        matrix[i_start][j_start].piece = {}
    end
    group:delay(function() after_puzzle_error() end, 0.150)
end


local function reset_board()
    is_block = true
    hint_move = {}
    select_move = {}
    history_move = {}
    is_promotion = false
    
    for row = 1,8 do
        for col = 1,8 do
            if matrix[row][col].piece.value then
                tween:to( matrix[row][col].piece, 0.300, { x = 0, y = 0 } )
            end
        end
    end
end


local function new_game()
    is_stop = false

    -- очистка
    for row = 1,8 do
        for col = 1,8 do
            matrix[row][col].piece = {}
        end
    end

    -- CHESS
    if game_mode == 1 then
        -- для тестирования продвижения, мата и пата  "q7/1P6/8/8/8/6KB/8/6k1 w - - 0 1"
        local fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        update_matrix_from_fen(fen, false, nil, true)
        
        garbochess.InitializeEval()
        garbochess.ResetGame()
        garbochess.InitializeFromFen(fen)
        
        if player_side[1] == "black" then is_flip = true else is_flip = false end
        
        next_move(false)
    
    -- PUZZLE
    elseif game_mode == 2 then
        local rand_puzzle = love.math.random( 1, #puzzle )
        local fen = puzzle[rand_puzzle][1]
        update_matrix_from_fen(fen, false, nil, true)
        
        garbochess.InitializeEval()
        garbochess.ResetGame()
        garbochess.InitializeFromFen(fen)
        
        puzzle_moves = puzzle[rand_puzzle][2]
        puzzle_turn = 1
        
        player_side[2] = get_side(fen)
        if player_side[2] == "white" then player_side[1] = "black" else player_side[1] = "white" end
        if player_side[1] == "black" then is_flip = true else is_flip = false end
        
        next_move(false)
    end
end


function player_move(chess_move)  -- global
    if is_stop then return end
    local cell_start = string.sub( chess_move, 1, 2)
    local cell_end = string.sub( chess_move, 3, 4)
    
    local i_start = 1
    local j_start = 1
    local i_end = 1
    local j_end = 1
    
    for row = 1,8 do
        for col = 1,8 do
            if cell_start == matrix[row][col].label then
                i_start = row
                j_start = col
            end
            if cell_end == matrix[row][col].label then
                i_end = row
                j_end = col
            end
        end
    end
    
    tween:to( matrix[i_start][j_start].piece, 0.300, { x = cell_size * (j_end - 1), y = cell_size * (i_end - 1) } )
    if is_sound then sound_move:play() end
    
    -- превращение пешки
    if string.lower( matrix[i_start][j_start].piece.value ) == "p" and ( i_end == 1 or i_end == 8 ) and ( player == 1 or not is_bot ) then
        promo_move = chess_move
        group:delay(function() after_promotion_move(i_start, j_start, i_end, j_end) end, 0.325)
    else
        if game_mode == 1 or ( game_mode == 2 and chess_move == puzzle_moves[puzzle_turn] ) then
            local is_move = true
            local ok, msg = pcall( function() is_move = garbochess.MakeMove( garbochess.GetMoveFromString(chess_move) ) end )
            
            if ok and is_move then  -- при выполнении защищенного кода ошибок нет
                local history = {cell_start, cell_end}
                local fen = garbochess.GetFen()
                group:delay(function() update_matrix_from_fen(fen, true, history) end, 0.325)
            
            else  -- защищенный код вызвал ошибку
                if is_sound then sound_error:play() end
                love.system.vibrate(0.150)
                msg(s("ERROR") .. "\n" .. s("Unexpected error!"))  -- Непредвиденная ошибка!
                group:delay(function() new_game() end, 0.300)
            end
        else
            group:delay(function() puzzle_error(i_start, j_start, i_end, j_end) end, 0.325)
        end
    end
end


local function after_bot_analyze(bestmove)
    if is_stop then return end
    if player == 1 or not is_bot then  -- подсказка (подсветка)
        hint_move = { string.sub( bestmove, 1, 2), string.sub( bestmove, 3, 4) }
        is_block = false
    else  -- ход бота
        player_move(bestmove)
    end
end


local function after_promotion(p)
    is_promotion = false
    promo_move = promo_move .. p
    
    if game_mode == 1 or ( game_mode == 2 and promo_move == puzzle_moves[puzzle_turn] ) then
        local is_move = true
        local ok, msg = pcall( function() is_move = garbochess.MakeMove( garbochess.GetMoveFromString(promo_move) ) end )
        
        if ok and is_move then  -- при выполнении защищенного кода ошибок нет
            local history = { string.sub( promo_move, 1, 2), string.sub( promo_move, 3, 4) }
            local fen = garbochess.GetFen()
            group:delay(function() update_matrix_from_fen(fen, true, history) end, 0.150)
        
        else  -- защищенный код вызвал ошибку
            if is_sound then sound_error:play() end
            love.system.vibrate(0.150)
            msg(s("ERROR") .. "\n" .. s("Unexpected error!"))  -- Непредвиденная ошибка!
            group:delay(function() new_game() end, 0.150)
        end
    else
        group:delay(function() puzzle_error() end, 0.150)
    end
end


local function save_game()
    local data = {}
    data.fen = garbochess.GetFen()
    data.game_mode = game_mode
    data.player_side = player_side
    data.is_bot = is_bot
    data.puzzle_moves = puzzle_moves
    data.puzzle_turn = puzzle_turn
    data.history_move = history_move

    local serialized = lume.serialize(data)
    love.filesystem.write("chess", serialized)
end


function game.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("GAME DRAW", "GAME DRAW")
    s:set("Lack of material!", "Lack of material!")
    s:set("CHECK AND MATE", "CHECK AND MATE")
    s:set("Win ", "Win ")
    s:set("white", "white")
    s:set("black", "black")
    s:set("Slatemate, no available moves!", "Slatemate, no available moves!")
    s:set("COMPLETED", "COMPLETED")
    s:set("The puzzle is solved!", "The puzzle is solved!")
    s:set("INCORRECT", "INCORRECT")
    s:set("Find the best move!", "Find the best move!")
    s:set("ERROR", "ERROR")
    s:set("Unexpected error!", "Unexpected error!")
    s:set("Don't find bestmove!", "Don't find bestmove!")
    s:set("About text", [[ABOUT GAME

GarboChess engine
Gary Linscott and Chessforeva
chessforeva.gitlab.io

Lichess open database
database.lichess.org

Images OpenMoji
openmoji.org

The Programming Language Lua
lua.org

LÖVE Free 2D Game Engine
love2d.org

(c) 2026 Anton Bezdolny
avbezdolny.github.io]])

    -- RU
    s:set_namespace("ru")
    s:set("GAME DRAW", "НИЧЬЯ")
    s:set("Lack of material!", "Недостаток материала!")
    s:set("CHECK AND MATE", "ШАХ И МАТ")
    s:set("Win ", "Победа ")
    s:set("white", "белых")
    s:set("black", "черных")
    s:set("Slatemate, no available moves!", "Пат, нет доступных ходов!")
    s:set("COMPLETED", "ЗАВЕРШЕНО")
    s:set("The puzzle is solved!", "Задача решена!")
    s:set("INCORRECT", "НЕВЕРНО")
    s:set("Find the best move!", "Найдите лучший ход!")
    s:set("ERROR", "ОШИБКА")
    s:set("Unexpected error!", "Непредвиденная ошибка!")
    s:set("Don't find bestmove!", "Не найден лучший ход!")
    s:set("About text", [[ОБ ИГРЕ

GarboChess движок
Gary Linscott и Chessforeva
chessforeva.gitlab.io

Lichess база данных
database.lichess.org

Изображения OpenMoji
openmoji.org

Язык Программирования Lua
lua.org

LÖVE Свободный 2D Игровой Движок
love2d.org

(c) 2026 Антон Бездольный
avbezdolny.github.io]])

    s:set_namespace(game_lang)

    -- default matrix
    local cell = "white"
    for row = 1,8 do
        table.insert(matrix, {})
        for col = 1,8 do
            table.insert(matrix[row], { label=board_labels[col] .. tostring(9-row), color=cell, piece={} })
            if col < 8 then
                if cell == "white" then cell = "black" else cell = "white" end
            end
        end
    end

    thread = love.thread.newThread( threadCode )
    resize()
    
    -- load saved data
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("chess") then
            local file = love.filesystem.read("chess")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local ok, msg = pcall( function()
            local fen = ""
            
            if not ( type(data.fen) == 'string' ) then error("Incorrect saved data!")
            else fen = data.fen end
            
            if not ( type(data.player_side) == 'table' and ( (data.player_side[1] == "white" and data.player_side[2] == "black") or (data.player_side[1] == "black" and data.player_side[2] == "white") ) ) then error("Incorrect saved data!")
            else player_side = data.player_side end
            
            if not ( type(data.history_move) == 'table' and (#data.history_move == 0 or #data.history_move == 2) ) then error("Incorrect saved data!")
            else history_move = data.history_move end
            
            if not ( type(data.puzzle_moves) == 'table' ) then error("Incorrect saved data!")
            else puzzle_moves = data.puzzle_moves end
            
            if not (data.puzzle_turn >= 1 and data.puzzle_turn <= #puzzle_moves + 1) then error("Incorrect saved data!")
            else puzzle_turn = data.puzzle_turn end
            
            if not (data.game_mode == 1 or data.game_mode == 2) then error("Incorrect saved data!")
            else game_mode = data.game_mode end
            
            if not (data.is_bot == true or data.is_bot == false) then error("Incorrect saved data!")
            else is_bot = data.is_bot end
        
            if player_side[1] == get_side(fen) then
                player = 1
            elseif player_side[2] == get_side(fen) then
                player = 2
            else
                error("Incorrect saved data!")
            end
            
            update_matrix_from_fen(fen, false, history_move, true)
            garbochess.InitializeEval()
            garbochess.ResetGame()
            garbochess.InitializeFromFen(fen)
            if player_side[1] == "black" then is_flip = true else is_flip = false end
        
        end )

        if ok then  -- при выполнении защищенного кода ошибок нет
            next_move(false)
        
        else  -- защищенный код вызвал ошибку
            msg("Not read saved data! " .. (msg or "..."))
            game_mode = 1
            is_bot = true
            player = 1
            player_side = {"white", "black"}
            reset_board()
            group:delay(function() new_game() end, 0.350)
        end
    else
        --love.window.showMessageBox("INFO", "Saved data was not found! " .. (err or "..."), "info")
        game_mode = 1
        is_bot = true
        player = 1
        player_side = {"white", "black"}
        reset_board()
        group:delay(function() new_game() end, 0.350)
    end
end


function game.update(dt)
    group:update(dt)
    tween:update(dt)

    if is_anim then
        -- hand
        offset_anim = offset_anim + cell_size * dt * vector_anim * 0.25
        if math.abs(offset_anim) >= cell_size * 0.25 then offset_anim = 0 end  -- для исправления скачков анимации при паузах
        if offset_anim >= cell_size * 0.125 then
            vector_anim = -1
        elseif offset_anim <= 0 then
            vector_anim = 1
        end
    end

    if is_thread then
        bot_rotation = bot_rotation + dt * 6
        if math.abs(bot_rotation) >= 2 * math.pi then bot_rotation = math.rad(0) end
        
        if not thread:isRunning( ) then  -- finish thread
            is_thread = false

            local bestmove = love.thread.getChannel( "info" ):pop()
            if bestmove then
                after_bot_analyze(bestmove)
            else
                if is_sound then sound_error:play() end
                love.system.vibrate(0.150)
                msg(s("ERROR") .. "\n" .. s("Don't find bestmove!"))
            end
        end
    end
end


local function draw_board()
    local i_row
    local i_col
    
    -- board cell's
    for row = 1,8 do
        for col = 1,8 do
            i_row = row
            i_col = col
            if is_flip then
                i_row = 9 - row
                i_col = 9 - col
            end
            
            local is_valid = false
            if #select_move == 1 then
                for _k,v in pairs(valid_moves) do
                    local cell_start = string.sub( v, 1, 2)
                    local cell_end = string.sub( v, 3, 4)
                    if select_move[1] == cell_start then
                        if matrix[row][col].label == cell_end then
                            is_valid = true
                        end
                    end
                end
            end
            
            if matrix[row][col].color == "white" then
                love.graphics.setColor(1, 1, 1, 0)
                if is_valid then love.graphics.setColor(color_valid) end
                if select_move[1] == matrix[row][col].label or select_move[2] == matrix[row][col].label then love.graphics.setColor(color_select) end
                love.graphics.rectangle("fill", board.x + cell_size * (i_col - 1), board.y + cell_size * (i_row - 1), cell_size, cell_size)
            else
                love.graphics.setColor(1, 1, 1, 0.5)
                if is_valid then love.graphics.setColor(color_valid) end
                if select_move[1] == matrix[row][col].label or select_move[2] == matrix[row][col].label then love.graphics.setColor(color_select) end
                love.graphics.draw(image_square, board.x + cell_size * (i_col - 1), board.y + cell_size * (i_row - 1), 0, k_scale, k_scale)
            end
            
            if garbochess.g_inCheck and matrix[row][col].piece.value and player_side[player] == get_side(garbochess.GetFen()) then
                if ( player_side[player] == "white" and matrix[row][col].piece.value == "K" ) or ( player_side[player] == "black" and matrix[row][col].piece.value == "k" ) then
                    love.graphics.setColor(234/255, 90/255, 71/255, 0.5)
                    love.graphics.setLineWidth(cell_size * 0.1)
                    love.graphics.rectangle("line", board.x + cell_size * (i_col - 1), board.y + cell_size * (i_row - 1), cell_size, cell_size)
                end
            end
            
            if history_move[1] == matrix[row][col].label or history_move[2] == matrix[row][col].label then
                love.graphics.setColor(color_history)
                love.graphics.setLineWidth(cell_size * 0.1)
                love.graphics.rectangle("line", board.x + cell_size * (i_col - 1), board.y + cell_size * (i_row - 1), cell_size, cell_size)
            end
            
            if hint_move[1] == matrix[row][col].label or hint_move[2] == matrix[row][col].label then
                love.graphics.setColor(color_select)
                love.graphics.setLineWidth(cell_size * 0.1)
                love.graphics.rectangle("line", board.x + cell_size * (i_col - 1), board.y + cell_size * (i_row - 1), cell_size, cell_size)
            end
        end
    end
    
    -- board label's
    local cl = color_red
    if is_flip then cl = color_blue end
    for i = 1,8 do
        i_col = i
        if is_flip then i_col = 9 - i end
        love.graphics.setColor(cl)
        love.graphics.printf(board_labels[i], board.x + cell_size * (i_col - 1) + cell_size * 0.01, board.y + cell_size * 8 - cell_size * 0.35, cell_size, "left")
        love.graphics.printf(tostring(9-i), board.x + cell_size * 8 - cell_size * 0.2, board.y + cell_size * (i_col - 1) - cell_size * 0.0625, cell_size, "left")
        if cl == color_red then cl = color_blue else cl = color_red end
    end
    
    -- board piece's
    love.graphics.setColor(1, 1, 1, 1)
    for row = 1,8 do
        for col = 1,8 do
            if matrix[row][col].piece.value then
                local img = image_white_pawn

                -- PRNBQK prnbqk
                if matrix[row][col].piece.value == 'P' then img = image_white_pawn
                elseif matrix[row][col].piece.value == 'R' then img = image_white_rook
                elseif matrix[row][col].piece.value == 'N' then img = image_white_knight
                elseif matrix[row][col].piece.value == 'B' then img = image_white_bishop
                elseif matrix[row][col].piece.value == 'Q' then img = image_white_queen
                elseif matrix[row][col].piece.value == 'K' then img = image_white_king
                elseif matrix[row][col].piece.value == 'p' then img = image_black_pawn
                elseif matrix[row][col].piece.value == 'r' then img = image_black_rook
                elseif matrix[row][col].piece.value == 'n' then img = image_black_knight
                elseif matrix[row][col].piece.value == 'b' then img = image_black_bishop
                elseif matrix[row][col].piece.value == 'q' then img = image_black_queen
                elseif matrix[row][col].piece.value == 'k' then img = image_black_king
                end

                if is_flip then
                    love.graphics.draw(img, board.x + board.size - matrix[row][col].piece.x - cell_size, board.y + board.size - matrix[row][col].piece.y - cell_size, 0, k_scale, k_scale)
                else
                    love.graphics.draw(img, board.x + matrix[row][col].piece.x, board.y + matrix[row][col].piece.y, 0, k_scale, k_scale)
                end
            end
        end
    end

    -- bot analyze
    if is_thread then
        love.graphics.draw(image_bot, cell_size, cell_size, bot_rotation, k_scale * 1.5, k_scale * 1.5, image_bot:getWidth() * 0.5, image_bot:getHeight() * 0.5)
    end

    -- pawn promotion
    if is_promotion then
        local bcolor = {1, 1, 1, 0.5}
        if press_button == "promo_q" then bcolor = color_button_press end
        draw_button(promo_coord.q.x + cell_size * 0.048, promo_coord.q.y + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.096, cell_size * 1.5 - cell_size * 0.096, bcolor)
        
        if press_button == "promo_r" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(promo_coord.r.x + cell_size * 0.048, promo_coord.r.y + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.096, cell_size * 1.5 - cell_size * 0.096, bcolor)
        
        if press_button == "promo_n" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(promo_coord.n.x + cell_size * 0.048, promo_coord.n.y + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.096, cell_size * 1.5 - cell_size * 0.096, bcolor)
        
        if press_button == "promo_b" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(promo_coord.b.x + cell_size * 0.048, promo_coord.b.y + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.096, cell_size * 1.5 - cell_size * 0.096, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        if player_side[player] == "white" then
            love.graphics.draw(image_white_queen, promo_coord.q.x + cell_size * 0.25, promo_coord.q.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_white_rook, promo_coord.r.x + cell_size * 0.25, promo_coord.r.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_white_knight, promo_coord.n.x + cell_size * 0.25, promo_coord.n.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_white_bishop, promo_coord.b.x + cell_size * 0.25, promo_coord.b.y + cell_size * 0.25, 0, k_scale, k_scale)
        else
            love.graphics.draw(image_black_queen, promo_coord.q.x + cell_size * 0.25, promo_coord.q.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_black_rook, promo_coord.r.x + cell_size * 0.25, promo_coord.r.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_black_knight, promo_coord.n.x + cell_size * 0.25, promo_coord.n.y + cell_size * 0.25, 0, k_scale, k_scale)
            love.graphics.draw(image_black_bishop, promo_coord.b.x + cell_size * 0.25, promo_coord.b.y + cell_size * 0.25, 0, k_scale, k_scale)
        end
    end
    
    -- УКАЗАТЕЛИ
    love.graphics.setColor(1, 1, 1, 1)
    
    -- side
    local p1 = image_white_player
    local p2 = image_black_player
    if player_side[1] ~= "white" then
        p1 = image_black_player
        p2 = image_white_player
    end
    if not (player == 1 and is_promotion) then love.graphics.draw(p1, cell_size * 0.25, H - cell_size * 1.75, 0, k_scale * 1.5, k_scale * 1.5) end
    if not (player == 2 and is_promotion) then love.graphics.draw(p2, W - cell_size * 1.75, H - cell_size * 1.75, 0, k_scale * 1.5, k_scale * 1.5) end
    
    -- hand
    if #valid_moves > 0 then
        if player == 1 and not is_promotion then love.graphics.draw(image_hand, cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, k_scale * 1.5, k_scale * 1.5)
        elseif player == 2 and not is_promotion then love.graphics.draw(image_hand, W - cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, -k_scale * 1.5, k_scale * 1.5) end
    
    elseif game_mode == 1 and (player == 1 or player == 2) then
        if garbochess.g_inCheck then  -- mate
            local win_player = 1
            if player == 1 then win_player = 2 end
            if win_player == 1 then love.graphics.draw(image_victory, cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, k_scale * 1.5, k_scale * 1.5)
            elseif win_player == 2 then love.graphics.draw(image_victory, W - cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, -k_scale * 1.5, k_scale * 1.5) end
        else  -- draw, slatemate
            love.graphics.draw(image_victory, cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, k_scale * 1.5, k_scale * 1.5)
            love.graphics.draw(image_victory, W - cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, -k_scale * 1.5, k_scale * 1.5)
        end
    
    elseif game_mode == 2 then
        love.graphics.draw(image_victory, cell_size * 0.25, H - cell_size * 3.25 + offset_anim + cell_size * 0.1, 0, k_scale * 1.5, k_scale * 1.5)
    end
end


local function draw_menu()
    local bcolor = {1, 1, 1, 0.5}
    if press_button == "bbot" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 2 + cell_size * 0.064, board.y + cell_size * 2 + cell_size * 0.064, cell_size * 2 - cell_size * 0.128, cell_size * 2 - cell_size * 0.128, bcolor)
    
    if press_button == "wbot" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(board.x + cell_size * 4 + cell_size * 0.064, board.y + cell_size * 2 + cell_size * 0.064, cell_size * 2 - cell_size * 0.128, cell_size * 2 - cell_size * 0.128, bcolor)
    
    if press_button == "human" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(board.x + cell_size * 2 + cell_size * 0.064, board.y + cell_size * 4 + cell_size * 0.064, cell_size * 2 - cell_size * 0.128, cell_size * 2 - cell_size * 0.128, bcolor)
    
    if press_button == "puzzle" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(board.x + cell_size * 4 + cell_size * 0.064, board.y + cell_size * 4 + cell_size * 0.064, cell_size * 2 - cell_size * 0.128, cell_size * 2 - cell_size * 0.128, bcolor)
    
    if press_button == "anim" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(cell_size * 0.25 + cell_size * 0.048, H - cell_size * 3.25 + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.096, bcolor)
    
    if press_button == "sound" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(cell_size * 0.25 + cell_size * 0.048, H - cell_size * 1.75 + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.096, bcolor)
    
    if press_button == "about" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(W - cell_size * 1.75 + cell_size * 0.048, H - cell_size * 3.25 + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.096, bcolor)
    
    if press_button == "exit" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(W - cell_size * 1.75 + cell_size * 0.048, H - cell_size * 1.75 + cell_size * 0.048, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.096, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.draw(image_man, board.x + cell_size * 2, board.y + cell_size * 2, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_bot, board.x + cell_size * 2.75, board.y + cell_size * 2, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_white_player, board.x + cell_size * 2, board.y + cell_size * 2.75, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_black_player, board.x + cell_size * 2.75, board.y + cell_size * 2.75, 0, k_scale * 1.25, k_scale * 1.25)
    
    love.graphics.draw(image_man, board.x + cell_size * 4, board.y + cell_size * 2, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_bot, board.x + cell_size * 4.75, board.y + cell_size * 2, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_black_player, board.x + cell_size * 4, board.y + cell_size * 2.75, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_white_player, board.x + cell_size * 4.75, board.y + cell_size * 2.75, 0, k_scale * 1.25, k_scale * 1.25)
    
    love.graphics.draw(image_man, board.x + cell_size * 2, board.y + cell_size * 4, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_man, board.x + cell_size * 2.75, board.y + cell_size * 4, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_white_player, board.x + cell_size * 2, board.y + cell_size * 4.75, 0, k_scale * 1.25, k_scale * 1.25)
    love.graphics.draw(image_black_player, board.x + cell_size * 2.75, board.y + cell_size * 4.75, 0, k_scale * 1.25, k_scale * 1.25)
    
    love.graphics.draw(image_puzzle, board.x + cell_size * 4, board.y + cell_size * 4, 0, k_scale * 2, k_scale * 2)
    
    if is_anim then love.graphics.draw(image_fly, cell_size * 0.25, H - cell_size * 3.25, 0, k_scale * 1.5, k_scale * 1.5) else love.graphics.draw(image_stop, cell_size * 0.25, H - cell_size * 3.25, 0, k_scale * 1.5, k_scale * 1.5) end
    
    if is_sound then love.graphics.draw(image_sound, cell_size * 0.25, H - cell_size * 1.75, 0, k_scale * 1.5, k_scale * 1.5) else love.graphics.draw(image_mute, cell_size * 0.25, H - cell_size * 1.75, 0, k_scale * 1.5, k_scale * 1.5) end
    
    love.graphics.draw(image_about, W - cell_size * 1.75, H - cell_size * 3.25, 0, k_scale * 1.5, k_scale * 1.5)
    
    love.graphics.draw(image_exit, W - cell_size * 1.75, H - cell_size * 1.75, 0, k_scale * 1.5, k_scale * 1.5)
end


function game.draw()
    love.graphics.setFont(game_font)
    
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        draw_board()
    end

    -- КНОПКИ ОСНОВНЫЕ
    local bcolor = {1, 1, 1, 0.5}
    if press_button == "hint" then bcolor = color_button_press end
    -- рисуем кнопку внутри условий, чтобы скрыть её при вычислениях
    if not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves > 0 and not is_stop and (player == 1 or not is_bot) then
        draw_button(cell_size * 0.25 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.064, bcolor)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_hint, cell_size * 0.25, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
    elseif not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves == 0 and not is_stop and is_block then
        draw_button(cell_size * 0.25 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.064, bcolor)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_restart, cell_size * 0.25, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
    elseif is_show_menu or is_show_info then
        draw_button(cell_size * 0.25 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.064, bcolor)
        if is_show_menu then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image_lang, cell_size * 0.25, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
            love.graphics.setColor(color_fg)
            love.graphics.printf(game_lang, cell_size * 0.37, cell_size * 1.27, cell_size * 1.5)
        elseif is_show_info then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image_back, cell_size * 0.25, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
        end
    end
    
    if press_button == "menu" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(W - cell_size * 1.75 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size * 1.5 - cell_size * 0.064, cell_size * 1.5 - cell_size * 0.064, bcolor)
    love.graphics.setColor(1, 1, 1, 1)
    if is_show_menu then
        love.graphics.draw(image_back, W - cell_size * 1.75, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
    else
        love.graphics.draw(image_menu, W - cell_size * 1.75, cell_size * 0.25, 0, k_scale * 1.5, k_scale * 1.5)
    end
    
    -- КНОПКИ МЕНЮ
    if is_show_menu then
        draw_menu()
    end

    -- ИНФО
    if is_show_info then
        love.graphics.setColor(color_fg)
        love.graphics.printf(s("About text"), board.x, board.y, cell_size * 8, "center")
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
        if not is_block and is_collide(x, y, board.x, board.y, board.size, board.size) then
            for row = 1,8 do
                for col = 1,8 do
                    local i = col
                    local j = row
                    if is_flip then
                        i = 9 - i
                        j = 9 - j
                    end
                    
                    if is_collide(x, y, board.x + cell_size * (i - 1), board.y + cell_size * (j - 1), cell_size, cell_size) then
                        if #select_move == 0 then
                            if is_sound then sound_click:play() end
                            table.insert(select_move, matrix[row][col].label)
                        elseif #select_move == 1 then
                            if select_move[1] == matrix[row][col].label then
                                if is_sound then sound_click:play() end
                                select_move = {}
                            else
                                table.insert(select_move, matrix[row][col].label)
                                
                                -- проверка на валидность
                                local is_move = false
                                for _k,v in pairs(valid_moves) do
                                    local cell_start = string.sub( v, 1, 2)
                                    local cell_end = string.sub( v, 3, 4)
                                    if select_move[1] == cell_start and select_move[2] == cell_end then
                                        is_move = true
                                    end
                                end
                                
                                if is_move then
                                    is_block = true
                                    hint_move = {}
                                    player_move(select_move[1] .. select_move[2])
                                else
                                    if is_sound then sound_click:play() end
                                    select_move = {matrix[row][col].label, }
                                end
                            end
                        else  -- обработка для непредвиденной ситуации
                            if is_sound then sound_click:play() end
                            select_move = {}
                        end
                    end
                end
            end
        end
    
        -- pawn promotion
        if is_promotion then
            if is_collide(x, y, promo_coord.q.x, promo_coord.q.y, cell_size * 1.5, cell_size * 1.5) then
                press_button = "promo_q"
            elseif is_collide(x, y, promo_coord.r.x, promo_coord.r.y, cell_size * 1.5, cell_size * 1.5) then
                press_button = "promo_r"
            elseif is_collide(x, y, promo_coord.n.x, promo_coord.n.y, cell_size * 1.5, cell_size * 1.5) then
                press_button = "promo_n"
            elseif is_collide(x, y, promo_coord.b.x, promo_coord.b.y, cell_size * 1.5, cell_size * 1.5) then
                press_button = "promo_b"
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, cell_size * 0.25, cell_size * 0.25, cell_size * 1.5, cell_size * 1.5) then
        if (not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves > 0 and not is_stop and (player == 1 or not is_bot)) or is_show_menu or is_show_info or (not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves == 0 and not is_stop and is_block) then
            press_button = "hint"
        end
    elseif is_collide(x, y, W - cell_size * 1.75, cell_size * 0.25, cell_size * 1.5, cell_size * 1.5) then
        press_button = "menu"
    end
    
    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, board.x + cell_size * 2, board.y + cell_size * 2, cell_size * 2, cell_size * 2) then
            press_button = "bbot"
        
        elseif is_collide(x, y, board.x + cell_size * 4, board.y + cell_size * 2, cell_size * 2, cell_size * 2) then
            press_button = "wbot"
        
        elseif is_collide(x, y, board.x + cell_size * 2, board.y + cell_size * 4, cell_size * 2, cell_size * 2) then
            press_button = "human"
        
        elseif is_collide(x, y, board.x + cell_size * 4, board.y + cell_size * 4, cell_size * 2, cell_size * 2) then
            press_button = "puzzle"
        
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 3.25, cell_size * 1.5, cell_size * 1.5) then
            press_button = "anim"
        
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 1.75, cell_size * 1.5, cell_size * 1.5) then
            press_button = "sound"
        
        elseif is_collide(x, y, W - cell_size * 1.75, H - cell_size * 3.25, cell_size * 1.5, cell_size * 1.5) then
            press_button = "about"
        
        elseif is_collide(x, y, W - cell_size * 1.75, H - cell_size * 1.75, cell_size * 1.5, cell_size * 1.5) then
            press_button = "exit"
        end
    end
end


function game.mousereleased( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        -- pawn promotion
        if is_promotion then
            if is_collide(x, y, promo_coord.q.x, promo_coord.q.y, cell_size * 1.5, cell_size * 1.5) and press_button == "promo_q" then
                if is_sound then sound_click:play() end
                after_promotion("q")
            elseif is_collide(x, y, promo_coord.r.x, promo_coord.r.y, cell_size * 1.5, cell_size * 1.5) and press_button == "promo_r" then
                if is_sound then sound_click:play() end
                after_promotion("r")
            elseif is_collide(x, y, promo_coord.n.x, promo_coord.n.y, cell_size * 1.5, cell_size * 1.5) and press_button == "promo_n" then
                if is_sound then sound_click:play() end
                after_promotion("n")
            elseif is_collide(x, y, promo_coord.b.x, promo_coord.b.y, cell_size * 1.5, cell_size * 1.5) and press_button == "promo_b" then
                if is_sound then sound_click:play() end
                after_promotion("b")
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, cell_size * 0.25, cell_size * 0.25, cell_size * 1.5, cell_size * 1.5) and press_button == "hint" then
        if not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves > 0 and not is_stop and (player == 1 or not is_bot) then  -- нажатие кнопки-подсказки
            if is_sound then sound_click:play() end
            select_move = {}
            if game_mode == 1 then
                is_block = true
                local fen = garbochess.GetFen()
                bot_move(fen)
            elseif game_mode == 2 then
                hint_move = { string.sub( puzzle_moves[puzzle_turn], 1, 2), string.sub( puzzle_moves[puzzle_turn], 3, 4) }
            end
        elseif not is_show_menu and not is_show_info and not is_thread and not is_promotion and #valid_moves == 0 and not is_stop and is_block then  -- рестарт
            if is_sound then sound_click:play() end
            is_stop = true
            reset_board()
            group:delay(function() new_game() end, 0.350)
        elseif is_show_menu then  -- переводчик
            if is_sound then sound_click:play() end
            if game_lang == "en" then game_lang = "ru" else game_lang = "en" end
            s:set_namespace(game_lang)
        elseif is_show_info then  -- назад
            if is_sound then sound_click:play() end
            is_show_info = false
        end
    elseif is_collide(x, y, W - cell_size * 1.75, cell_size * 0.25, cell_size * 1.5, cell_size * 1.5) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, board.x + cell_size * 2, board.y + cell_size * 2, cell_size * 2, cell_size * 2) and press_button == "bbot" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            game_mode = 1
            is_bot = true
            player = 1
            player_side = {"white", "black"}
            reset_board()
            is_show_menu = false
            group:delay(function() new_game() end, 0.350)
        
        elseif is_collide(x, y, board.x + cell_size * 4, board.y + cell_size * 2, cell_size * 2, cell_size * 2) and press_button == "wbot" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            game_mode = 1
            is_bot = true
            player = 2
            player_side = {"black", "white"}
            reset_board()
            is_show_menu = false
            group:delay(function() new_game() end, 0.350)
        
        elseif is_collide(x, y, board.x + cell_size * 2, board.y + cell_size * 4, cell_size * 2, cell_size * 2) and press_button == "human" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            game_mode = 1
            is_bot = false
            player = 1
            player_side = {"white", "black"}
            reset_board()
            is_show_menu = false
            group:delay(function() new_game() end, 0.350)
        
        elseif is_collide(x, y, board.x + cell_size * 4, board.y + cell_size * 4, cell_size * 2, cell_size * 2) and press_button == "puzzle" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            game_mode = 2
            is_bot = true
            player = 2
            reset_board()
            is_show_menu = false
            group:delay(function() new_game() end, 0.350)
        
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 3.25, cell_size * 1.5, cell_size * 1.5) and press_button == "anim" then
            if is_sound then sound_click:play() end
            is_anim = not is_anim
            offset_anim = 0
            vector_anim = 1
        
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 1.75, cell_size * 1.5, cell_size * 1.5) and press_button == "sound" then
            is_sound = not is_sound
            if is_sound then sound_click:play() end
        
        elseif is_collide(x, y, W - cell_size * 1.75, H - cell_size * 3.25, cell_size * 1.5, cell_size * 1.5) and press_button == "about" then
            if is_sound then sound_click:play() end
            is_show_menu = false
            is_show_info = true
        
        elseif is_collide(x, y, W - cell_size * 1.75, H - cell_size * 1.75, cell_size * 1.5, cell_size * 1.5) and press_button == "exit" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            --group:delay(function() love.event.quit(0) end, 0.150)
            
            -- Возврат в лаунчер
            save_game()
            is_show_menu = false
            current_state = launcher
            current_state.load()
        end
    end

    press_button = ""
end


function game.threaderror(thread, errorstr)  -- If not overwritten this callback will raise an error!
  if is_sound then sound_error:play() end
  love.system.vibrate(0.150)
  msg("Thread error! " .. (errorstr or "..."))
  -- thread:getError() will return the same error string now.
end


function game.resize(w, h)
    --print(("Window resized to width: %d and height: %d."):format(w, h))
    group:delay(function() resize() end, 0.150)
end


function game.focus(f)
    if not f then  -- Window is not focused
        save_game()
    end
end


function game.quit()
    is_stop = true  -- дублируем stop для случая закрытия окна крестиком
    stop_thread()
    save_game()
    return false
end


return game
