local game = {}

local tick = require("modules/tick")
local lume = require("modules/lume")
local s = require("modules/say")

-- colors
--local color_fg = {63/255, 63/255, 63/255}  -- #3f3f3f
--local color_button_press = {155/255, 155/255, 154/255}  -- #9b9b9a
local color_empty_cell = {155/255, 155/255, 154/255, 0.25}  -- #9b9b9a
local color_select_cell = {177/255, 204/255, 51/255, 0.5}  -- #4bd37b
local color_press_cell = {252/255, 234/255, 43/255, 0.5}  -- #ffdd67
local color_blue = {146/255, 211/255, 245/255}  -- #15a1ea
local color_red = {234/255, 90/255, 71/255}  -- #e5516d

-- images
local image_cross = love.graphics.newImage("images/cross.png")
local image_zero = love.graphics.newImage("images/zero.png")
local image_x = love.graphics.newImage("images/x.png")
local image_o = love.graphics.newImage("images/o.png")
local image_hand = love.graphics.newImage("images/hand_bottom.png")
local image_win = love.graphics.newImage("images/hand_victory.png")
local image_info = love.graphics.newImage("images/help.png")
local image_menu = love.graphics.newImage("images/gear.png")
local image_lang = love.graphics.newImage("images/lang.png")
local image_back = love.graphics.newImage("images/back.png")
local image_bot = love.graphics.newImage("images/robot.png")
local image_human = love.graphics.newImage("images/man.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_move = love.graphics.newImage("images/fly.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")

-- calculate
--local W = 1280
--local H = 720
local cell_size = 72
local offset = 7.2
local board = {
    x = 287.2,
    y = 7.2,
    size = cell_size * 9 + offset * 8
}
local cell = {}  -- координаты ячеек
local grid = { {521.2, 7.2, 521.2, 712.8}, {758.8, 7.2, 758.8, 712.8}, {287.2, 241.2, 992.8, 241.2}, {287.2, 478.8, 992.8, 478.8} }
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 54 )
local info_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 36 )
local offset_info = 0
local offset_anim = 0
local vector_anim = 1
local coord = {
    p1 = {x = 0, y = 0},
    p2 = {x = 0, y = 0},
    h1 ={x = 0, y = 0},
    h2 = {x = 0, y = 0},
    info = {x = 0, y = 0},
    menu = {x = 0, y = 0},
    bot = {x = 0, y = 0},
    human = {x = 0, y = 0},
    about = {x = 0, y = 0},
    exit = {x = 0, y = 0}
}

-- game
local matrix = {}
local big_matrix = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
local player = 1  -- 1 or 2, 0 if draw
local press_cell = {0, 0, 0, 0}  -- выбор ячейки
local select_big = {0, 0}  -- выбор поля для игры
local is_bot = true
local is_block = true
local is_gameover = true
local is_show_menu = false
local is_show_info = false
local press_button = ""
local info_text = "Info text"
local group = tick.group()

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_true = love.audio.newSource("audio/error.ogg", "static")
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


local function resize()
    --W = love.graphics.getWidth()
    --H = love.graphics.getHeight()

    if W > H then
        cell_size = math.min(W / 18, H / 10)
    else
        cell_size = math.min(W / 10, H / 18)
    end

    offset = cell_size / 10
    board.size = cell_size * 9 + offset * 8
    board.x = W / 2 - board.size / 2
    board.y = H / 2 - board.size / 2
    k_scale = cell_size / image_menu:getWidth()

    for row=1,3 do
        for col=1,3 do
            for i=1,3 do
                for j=1,3 do
                    cell[row][col][i][j].x = board.x + cell_size * (col-1) * 3 + offset * (col-1) * 3 + cell_size * (j-1) + offset
                    cell[row][col][i][j].y = board.y + cell_size * (row-1) * 3 + offset * (row-1) * 3 + cell_size * (i-1) + offset
                end
            end
        end
    end

    grid = {
        {
            board.x + cell_size * 3 + offset * 2.5, board.y + offset,
            board.x + cell_size * 3 + offset * 2.5, board.y + board.size - offset
        },
        {
            board.x + cell_size * 6 + offset * 5.5, board.y + offset,
            board.x + cell_size * 6 + offset * 5.5, board.y + board.size - offset
        },
        {
            board.x + offset, board.y + cell_size * 3 + offset * 2.5,
            board.x + board.size - offset, board.y + cell_size * 3 + offset * 2.5
        },
        {
            board.x + offset, board.y + cell_size * 6 + offset * 5.5,
            board.x + board.size - offset, board.y + cell_size * 6 + offset * 5.5
        }
    }

    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.75 )
    info_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.5 )
    info_font:setLineHeight( 0.9 )

    coord = {
        p1 = {x = offset * 2, y = H - cell_size * 2 - offset * 2},
        p2 = {x = W - cell_size * 2 - offset * 2, y = H - cell_size * 2 - offset * 2},
        h1 = {x = offset * 2, y = H - cell_size * 4 - offset * 2},
        h2 = {x = W - offset * 2, y = H - cell_size * 4 - offset * 2},
        info = {x = offset * 2, y = offset * 2},
        menu = {x = W - cell_size * 2 - offset * 2, y = offset * 2},
        bot = {x = board.x + board.size / 2 - cell_size * 4.8, y = board.y + offset},
        human = {x = board.x + board.size / 2 - cell_size * 4.8, y = board.y + offset + cell_size * 2.5},
        about = {x = board.x + board.size / 2 - cell_size * 4.8, y = board.y + offset + cell_size * 5},
        exit = {x = board.x + board.size / 2 - cell_size * 4.8, y = board.y + offset + cell_size * 7.5}
    }
end


local function is_free_cell(mtx, big)
    for row=1,3 do
        for col=1,3 do
            if big[row][col] == 0 then
                for i=1,3 do
                    for j=1,3 do
                        if mtx[row][col][i][j] == 0 then return true end
                    end
                end
            end
        end
    end
    return false
end


local function human_analyze(human_matrix, human_big_matrix, human_click)
    local temp_matrix = deepcopy(human_matrix)
    local temp_big_matrix = deepcopy(human_big_matrix)
    local row, col, i, j = human_click[1], human_click[2], human_click[3], human_click[4]
    temp_matrix[row][col][i][j] = 1

    if (temp_matrix[row][col][1][1] == temp_matrix[row][col][1][2] and temp_matrix[row][col][1][1] == temp_matrix[row][col][1][3] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][2][1] == temp_matrix[row][col][2][2] and temp_matrix[row][col][2][1] == temp_matrix[row][col][2][3] and temp_matrix[row][col][2][1] ~= 0)
    or (temp_matrix[row][col][3][1] == temp_matrix[row][col][3][2] and temp_matrix[row][col][3][1] == temp_matrix[row][col][3][3] and temp_matrix[row][col][3][1] ~= 0)
    or (temp_matrix[row][col][1][1] == temp_matrix[row][col][2][1] and temp_matrix[row][col][1][1] == temp_matrix[row][col][3][1] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][1][2] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][2] == temp_matrix[row][col][3][2] and temp_matrix[row][col][1][2] ~= 0)
    or (temp_matrix[row][col][1][3] == temp_matrix[row][col][2][3] and temp_matrix[row][col][1][3] == temp_matrix[row][col][3][3] and temp_matrix[row][col][1][3] ~= 0)
    or (temp_matrix[row][col][1][1] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][1] == temp_matrix[row][col][3][3] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][1][3] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][3] == temp_matrix[row][col][3][1] and temp_matrix[row][col][1][3] ~= 0) then
        temp_big_matrix[row][col] = 1
    end

    local super_matrix = deepcopy(temp_big_matrix)
    for x=1,3 do
        for y=1,3 do
            if temp_big_matrix[x][y] == 1 then
                super_matrix[x][y] = 3
            elseif temp_big_matrix[x][y] == -1 then
                super_matrix[x][y] = -3
            elseif temp_big_matrix[x][y] == 0 then
                local is_empty = false
                for r=1,3 do
                    for c=1,3 do
                        if temp_matrix[x][y][r][c] == 0 then
                            is_empty = true
                        end
                    end
                end

                if is_empty then
                    -- считаем ряды, находим максимум
                    super_matrix[x][y] = math.max(
                        temp_matrix[x][y][1][1] + temp_matrix[x][y][1][2] + temp_matrix[x][y][1][3],
                        temp_matrix[x][y][2][1] + temp_matrix[x][y][2][2] + temp_matrix[x][y][2][3],
                        temp_matrix[x][y][3][1] + temp_matrix[x][y][3][2] + temp_matrix[x][y][3][3],
                        temp_matrix[x][y][1][1] + temp_matrix[x][y][2][1] + temp_matrix[x][y][3][1],
                        temp_matrix[x][y][1][2] + temp_matrix[x][y][2][2] + temp_matrix[x][y][3][2],
                        temp_matrix[x][y][1][3] + temp_matrix[x][y][2][3] + temp_matrix[x][y][3][3],
                        temp_matrix[x][y][1][1] + temp_matrix[x][y][2][2] + temp_matrix[x][y][3][3],
                        temp_matrix[x][y][1][3] + temp_matrix[x][y][2][2] + temp_matrix[x][y][3][1]
                    )
                else
                    super_matrix[x][y] = 0
                end
            end
        end
    end

    -- считаем ряды, находим максимум в super_matrix
    local max_value = math.max(
        super_matrix[1][1] + super_matrix[1][2] + super_matrix[1][3],
        super_matrix[2][1] + super_matrix[2][2] + super_matrix[2][3],
        super_matrix[3][1] + super_matrix[3][2] + super_matrix[3][3],
        super_matrix[1][1] + super_matrix[2][1] + super_matrix[3][1],
        super_matrix[1][2] + super_matrix[2][2] + super_matrix[3][2],
        super_matrix[1][3] + super_matrix[2][3] + super_matrix[3][3],
        super_matrix[1][1] + super_matrix[2][2] + super_matrix[3][3],
        super_matrix[1][3] + super_matrix[2][2] + super_matrix[3][1]
    )

    return max_value
end


local function human_move(bot_matrix, bot_big_matrix, bot_select_big)
    local temp_matrix = deepcopy(bot_matrix)
    local temp_big_matrix = deepcopy(bot_big_matrix)
    local temp_select_big = deepcopy(bot_select_big)

    local result = {}
    for row=1,3 do
        for col=1,3 do
            if temp_big_matrix[row][col] == 0 and ( (temp_select_big[1] == 0 and temp_select_big[2] == 0) or (temp_select_big[1] == row and temp_select_big[2] == col) ) then
                for i=1,3 do
                    for j=1,3 do
                        if temp_matrix[row][col][i][j] == 0 then
                            table.insert( result, human_analyze(temp_matrix, temp_big_matrix, {row, col, i, j}) )
                        end
                    end
                end
            end
        end
    end

    local max_value = -9
    for _k,v in pairs(result) do
        if v > max_value then max_value = v end
    end

    return max_value
end


local function bot_analyze(bot_matrix, bot_click)
    local temp_matrix = deepcopy(bot_matrix)
    local temp_big_matrix = deepcopy(big_matrix)
    local temp_select_big = {0, 0}
    local row, col, i, j = bot_click[1], bot_click[2], bot_click[3], bot_click[4]
    temp_matrix[row][col][i][j] = -1

    if (temp_matrix[row][col][1][1] == temp_matrix[row][col][1][2] and temp_matrix[row][col][1][1] == temp_matrix[row][col][1][3] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][2][1] == temp_matrix[row][col][2][2] and temp_matrix[row][col][2][1] == temp_matrix[row][col][2][3] and temp_matrix[row][col][2][1] ~= 0)
    or (temp_matrix[row][col][3][1] == temp_matrix[row][col][3][2] and temp_matrix[row][col][3][1] == temp_matrix[row][col][3][3] and temp_matrix[row][col][3][1] ~= 0)
    or (temp_matrix[row][col][1][1] == temp_matrix[row][col][2][1] and temp_matrix[row][col][1][1] == temp_matrix[row][col][3][1] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][1][2] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][2] == temp_matrix[row][col][3][2] and temp_matrix[row][col][1][2] ~= 0)
    or (temp_matrix[row][col][1][3] == temp_matrix[row][col][2][3] and temp_matrix[row][col][1][3] == temp_matrix[row][col][3][3] and temp_matrix[row][col][1][3] ~= 0)
    or (temp_matrix[row][col][1][1] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][1] == temp_matrix[row][col][3][3] and temp_matrix[row][col][1][1] ~= 0)
    or (temp_matrix[row][col][1][3] == temp_matrix[row][col][2][2] and temp_matrix[row][col][1][3] == temp_matrix[row][col][3][1] and temp_matrix[row][col][1][3] ~= 0) then
        temp_big_matrix[row][col] = -1
    end

    if temp_big_matrix[i][j] == 0 and (temp_matrix[i][j][1][1] == 0 or temp_matrix[i][j][1][2] == 0 or temp_matrix[i][j][1][3] == 0 or temp_matrix[i][j][2][1] == 0 or temp_matrix[i][j][2][2] == 0 or temp_matrix[i][j][2][3] == 0 or temp_matrix[i][j][3][1] == 0 or temp_matrix[i][j][3][2] == 0 or temp_matrix[i][j][3][3] == 0) then
        temp_select_big = {i, j}
    end

    if (temp_big_matrix[1][1] == temp_big_matrix[1][2] and temp_big_matrix[1][1] == temp_big_matrix[1][3] and temp_big_matrix[1][1] ~= 0)
    or (temp_big_matrix[2][1] == temp_big_matrix[2][2] and temp_big_matrix[2][1] == temp_big_matrix[2][3] and temp_big_matrix[2][1] ~= 0)
    or (temp_big_matrix[3][1] == temp_big_matrix[3][2] and temp_big_matrix[3][1] == temp_big_matrix[3][3] and temp_big_matrix[3][1] ~= 0)
    or (temp_big_matrix[1][1] == temp_big_matrix[2][1] and temp_big_matrix[1][1] == temp_big_matrix[3][1] and temp_big_matrix[1][1] ~= 0)
    or (temp_big_matrix[1][2] == temp_big_matrix[2][2] and temp_big_matrix[1][2] == temp_big_matrix[3][2] and temp_big_matrix[1][2] ~= 0)
    or (temp_big_matrix[1][3] == temp_big_matrix[2][3] and temp_big_matrix[1][3] == temp_big_matrix[3][3] and temp_big_matrix[1][3] ~= 0)
    or (temp_big_matrix[1][1] == temp_big_matrix[2][2] and temp_big_matrix[1][1] == temp_big_matrix[3][3] and temp_big_matrix[1][1] ~= 0)
    or (temp_big_matrix[1][3] == temp_big_matrix[2][2] and temp_big_matrix[1][3] == temp_big_matrix[3][1] and temp_big_matrix[1][3] ~= 0) then
        return -9  -- если конец игры (победа)
    elseif not is_free_cell(temp_matrix, temp_big_matrix) then
        return -9  -- если конец игры (ничья)
    else
        return human_move(temp_matrix, temp_big_matrix, temp_select_big)
    end
end


local function bot_move()
    local bot_matrix = deepcopy(matrix)
    local result = {}

    for row=1,3 do
        for col=1,3 do
            if big_matrix[row][col] == 0 and ( (select_big[1] == 0 and select_big[2] == 0) or (select_big[1] == row and select_big[2] == col) ) then
                for i=1,3 do
                    for j=1,3 do
                        if bot_matrix[row][col][i][j] == 0 then
                            table.insert( result, { row, col, i, j, bot_analyze(bot_matrix, {row, col, i, j}) } )
                        end
                    end
                end
            end
        end
    end

    if #result == 0 then
        msg("ERROR Bot no moves!")
        return 0
    else
        local random_turn = love.math.random( 1, 100 )
        if random_turn > 90 then -- 10% chance random move
            local bot_index = love.math.random( 1, #result )
            return result[bot_index]
        else  -- minmax
            local min_value = 9
            for k,v in pairs(result) do
                if v[5] < min_value then min_value = v[5] end
            end

            local minmax = {}
            for k,v in pairs(result) do
                if v[5] == min_value then table.insert(minmax, v) end
            end

            local bot_index = love.math.random( 1, #minmax )
            return minmax[bot_index]
        end
    end
end


local function analyze(pass_player)
    local pass = pass_player or false
    if (big_matrix[1][1] == big_matrix[1][2] and big_matrix[1][1] == big_matrix[1][3] and big_matrix[1][1] ~= 0)
    or (big_matrix[2][1] == big_matrix[2][2] and big_matrix[2][1] == big_matrix[2][3] and big_matrix[2][1] ~= 0)
    or (big_matrix[3][1] == big_matrix[3][2] and big_matrix[3][1] == big_matrix[3][3] and big_matrix[3][1] ~= 0)
    or (big_matrix[1][1] == big_matrix[2][1] and big_matrix[1][1] == big_matrix[3][1] and big_matrix[1][1] ~= 0)
    or (big_matrix[1][2] == big_matrix[2][2] and big_matrix[1][2] == big_matrix[3][2] and big_matrix[1][2] ~= 0)
    or (big_matrix[1][3] == big_matrix[2][3] and big_matrix[1][3] == big_matrix[3][3] and big_matrix[1][3] ~= 0)
    or (big_matrix[1][1] == big_matrix[2][2] and big_matrix[1][1] == big_matrix[3][3] and big_matrix[1][1] ~= 0)
    or (big_matrix[1][3] == big_matrix[2][2] and big_matrix[1][3] == big_matrix[3][1] and big_matrix[1][3] ~= 0) then
        is_gameover = true  -- player win
        if is_sound then sound_gameover:play() end
        love.system.vibrate(0.150)
    elseif not is_free_cell(matrix, big_matrix) then
        is_gameover = true  -- game draw
        player = 0
        if is_sound then sound_gameover:play() end
        love.system.vibrate(0.150)
    else  -- next turn
        if not pass then
            if player == 1 then player = 2 else player = 1 end
        end
        if player == 1 or not is_bot then
            is_block = false
        else
            local bot_turn = bot_move()
            if bot_turn ~= 0 then
                press_cell = {bot_turn[1], bot_turn[2], bot_turn[3], bot_turn[4]}
                group:delay(function() click_cell(bot_turn[1], bot_turn[2], bot_turn[3], bot_turn[4]) end, 0.300)
            end
        end
    end
end


function click_cell(row, col, i, j)  -- global для доступа из любого места кода
    if player == 2 and is_bot then  -- для хода бота
        press_cell = {0, 0, 0, 0}
        if is_sound then sound_click:play() end
    end

    if matrix[row][col][i][j] == 0 and big_matrix[row][col] == 0 and ((select_big[1] == 0 and select_big[2] == 0) or (select_big[1] == row and select_big[2] == col)) then
        if player == 1 then matrix[row][col][i][j] = 1 else matrix[row][col][i][j] = -1 end

        if (matrix[row][col][1][1] == matrix[row][col][1][2] and matrix[row][col][1][1] == matrix[row][col][1][3] and matrix[row][col][1][1] ~= 0)
        or (matrix[row][col][2][1] == matrix[row][col][2][2] and matrix[row][col][2][1] == matrix[row][col][2][3] and matrix[row][col][2][1] ~= 0)
        or (matrix[row][col][3][1] == matrix[row][col][3][2] and matrix[row][col][3][1] == matrix[row][col][3][3] and matrix[row][col][3][1] ~= 0)
        or (matrix[row][col][1][1] == matrix[row][col][2][1] and matrix[row][col][1][1] == matrix[row][col][3][1] and matrix[row][col][1][1] ~= 0)
        or (matrix[row][col][1][2] == matrix[row][col][2][2] and matrix[row][col][1][2] == matrix[row][col][3][2] and matrix[row][col][1][2] ~= 0)
        or (matrix[row][col][1][3] == matrix[row][col][2][3] and matrix[row][col][1][3] == matrix[row][col][3][3] and matrix[row][col][1][3] ~= 0)
        or (matrix[row][col][1][1] == matrix[row][col][2][2] and matrix[row][col][1][1] == matrix[row][col][3][3] and matrix[row][col][1][1] ~= 0)
        or (matrix[row][col][1][3] == matrix[row][col][2][2] and matrix[row][col][1][3] == matrix[row][col][3][1] and matrix[row][col][1][3] ~= 0) then
            if player == 1 then big_matrix[row][col] = 1 else big_matrix[row][col] = -1 end
            if is_sound then sound_true:play() end
            love.system.vibrate(0.150)
        end

        if big_matrix[i][j] == 0 and (matrix[i][j][1][1] == 0 or matrix[i][j][1][2] == 0 or matrix[i][j][1][3] == 0 or matrix[i][j][2][1] == 0 or matrix[i][j][2][2] == 0 or matrix[i][j][2][3] == 0 or matrix[i][j][3][1] == 0 or matrix[i][j][3][2] == 0 or matrix[i][j][3][3] == 0) then
            select_big = {i, j}
        else
            select_big = {0, 0}
        end

        group:delay(function() analyze() end, 0.300)

    else
        is_block = false
    end
end


local function new_game()
    is_block = true

    -- очистка
    big_matrix = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
    for row=1,3 do
        for col=1,3 do
            for i=1,3 do
                for j=1,3 do
                    matrix[row][col][i][j] = 0
                end
            end
        end
    end
    select_big = {0, 0}

    local turn = love.math.random( 1, 100 )
    if turn <= 50 then player = 1 else player = 2 end

    is_gameover = false
    analyze(true)
end


local function save_game()
    local data = {}
    data.player = player
    data.is_bot = is_bot
    data.is_gameover = is_gameover
    data.matrix = deepcopy(matrix)
    data.big_matrix = deepcopy(big_matrix)
    data.select_big = deepcopy(select_big)

    local serialized = lume.serialize(data)
    love.filesystem.write("xo", serialized)
end


function game.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("Game vs Bot", "Game vs Bot")
    s:set("Game vs Human", "Game vs Human")
    s:set("About game", "About game")
    s:set("Exit game", "Exit game")
    s:set("Info text", [[TIC-TAC-TOE OF THE NEW GENERATION
There is a small 3x3 field in each cell of the usual 3x3 playing field. You put a tic-tac-toe in a small field. When you line up three of your pieces in a row on a small field, you win on it. To win the game, you need to win on three small fields in a row. Which of the nine small fields to play on is determined by the opponent's previous move. If the field is already occupied, then choose any available one.]])
    s:set("About text", [[ABOUT GAME

Idea: Ben Orlin blog author
mathwithbaddrawings.com

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
    s:set("Info text", [[КРЕСТИКИ-НОЛИКИ НОВОГО ПОКОЛЕНИЯ

В каждой клетке обычного игрового поля 3х3 находится малое поле 3х3. Вы ставите крестик или нолик в малом поле. Когда выстраиваете в ряд три свои фигуры на малом поле, то побеждаете на нём. Для победы в игре нужно выиграть на трёх малых полях в ряд. На каком из девяти малых полей играть определяется предыдущим ходом соперника. Если поле уже занято, то выбираете любое свободное.]])
    s:set("About text", [[ОБ ИГРЕ

Идея: Бен Орлин автор блога
mathwithbaddrawings.com

Изображения: OpenMoji
openmoji.org

Язык Программирования Lua
lua.org

LÖVE Свободный 2D Игровой Движок
love2d.org

(c) 2026 Антон Бездольный
avbezdolny.github.io]])

    s:set_namespace(game_lang)

    -- default matrix and cell coord
    for row=1,3 do
        table.insert(matrix, {})
        table.insert(cell, {})
        for _col=1,3 do
            table.insert(matrix[row], {
                {0, 0, 0},
                {0, 0, 0},
                {0, 0, 0}
            })
            table.insert(cell[row], {
                {{x=0, y=0}, {x=0, y=0}, {x=0, y=0}},
                {{x=0, y=0}, {x=0, y=0}, {x=0, y=0}},
                {{x=0, y=0}, {x=0, y=0}, {x=0, y=0}}
            })
        end
    end

    -- load saved file
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("xo") then
            local file = love.filesystem.read("xo")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local ok, msg = pcall( function()
            if not (data.player == 0 or data.player == 1 or data.player == 2) then error("Incorrect save data!")
            else player = data.player end

            if not (data.is_bot == true or data.is_bot == false) then error("Incorrect save data!")
            else is_bot = data.is_bot end

            if not (data.is_gameover == true or data.is_gameover == false) then error("Incorrect save data!")
            else is_gameover = data.is_gameover end

            for row=1,3 do
                for col=1,3 do
                    for i=1,3 do
                        for j=1,3 do
                            if not (data.matrix[row][col][i][j] == 0 or data.matrix[row][col][i][j] == 1 or data.matrix[row][col][i][j] == -1) then error("Incorrect save data!")
                            else matrix[row][col][i][j] = data.matrix[row][col][i][j] end
                        end
                    end
                end
            end

            for r=1,3 do
                for c=1,3 do
                    if not (data.big_matrix[r][c] == 0 or data.big_matrix[r][c] == 1 or data.big_matrix[r][c] == -1) then error("Incorrect save data!")
                    else big_matrix[r][c] = data.big_matrix[r][c] end
                end
            end

            if not (data.select_big[1] == 0 or data.select_big[1] == 1 or data.select_big[1] == 2 or data.select_big[1] == 3)
            or not (data.select_big[2] == 0 or data.select_big[2] == 1 or data.select_big[2] == 2 or data.select_big[2] == 3)
            or (data.select_big[1] == 0 and not data.select_big[2] == 0)
            or (data.select_big[2] == 0 and not data.select_big[1] == 0) then
                error("Incorrect save data!")
            else
                select_big = {data.select_big[1], data.select_big[2]}
            end
        end )

        if ok then  -- при выполнении защищенного кода ошибок нет
            analyze(true)  -- Не менять текущего игрока!
        else  -- защищенный код вызвал ошибку
            msg("Error reading saved data! " .. (msg or "..."))
            new_game()
        end
    else
        --love.window.showMessageBox("Message", "Saved data was not found!\n" .. (err or "..."), "info")
        new_game()
    end

    resize()
end


function game.update(dt)
    group:update(dt)
    
    if is_anim then
        -- hand
        offset_anim = offset_anim + cell_size * dt * vector_anim * 0.2
        if math.abs(offset_anim) >= cell_size * 0.25 then offset_anim = 0 end  -- для исправления скачков анимации при паузах
        if offset_anim >= cell_size * 0.1 then
            vector_anim = -1
        elseif offset_anim <= 0 then
            vector_anim = 1
        end
    end
end


function game.draw()
    local bcolor = {1, 1, 1, 0.5}
    
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        --love.graphics.rectangle("fill", board.x, board.y, board.size, board.size)
        love.graphics.setColor(color_fg)
        love.graphics.setLineWidth(offset/2)
        for l=1,4 do love.graphics.line(grid[l]) end

        for row=1,3 do
            for col=1,3 do
                if big_matrix[row][col] == 0 then
                    for i=1,3 do
                        for j=1,3 do
                            if matrix[row][col][i][j] == 0 then
                                if not is_block and ((select_big[1] == 0 and select_big[2] == 0) or (select_big[1] == row and select_big[2] == col)) then
                                    if press_cell[1] == row and press_cell[2] == col and press_cell[3] == i and press_cell[4] == j then
                                        bcolor = color_press_cell
                                    else
                                        bcolor = color_select_cell
                                    end
                                else
                                    bcolor = color_empty_cell
                                end
                            end

                            if player == 2 and is_bot then
                                if press_cell[1] == row and press_cell[2] == col and press_cell[3] == i and press_cell[4] == j then
                                    bcolor = color_press_cell
                                end
                            end

                            if matrix[row][col][i][j] == 1 then
                                draw_button(cell[row][col][i][j].x + cell_size * 0.032, cell[row][col][i][j].y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, color_red)
                                love.graphics.setColor(1, 1, 1, 1)
                                love.graphics.draw(
                                image_cross,
                                cell[row][col][i][j].x,
                                cell[row][col][i][j].y,
                                0,
                                k_scale,
                                k_scale
                            )
                            elseif matrix[row][col][i][j] == -1 then
                                draw_button(cell[row][col][i][j].x + cell_size * 0.032, cell[row][col][i][j].y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, color_blue)
                                love.graphics.setColor(1, 1, 1, 1)
                                love.graphics.draw(
                                image_zero,
                                cell[row][col][i][j].x,
                                cell[row][col][i][j].y,
                                0,
                                k_scale,
                                k_scale
                            )
                            else
                                draw_button(cell[row][col][i][j].x + cell_size * 0.032, cell[row][col][i][j].y + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor, {1, 1, 1, 0})
                            end
                        end
                    end
                elseif big_matrix[row][col] == 1 then
                    draw_button(cell[row][col][1][1].x + cell_size * 0.032, cell[row][col][1][1].y + cell_size * 0.032, cell_size * 3 - cell_size * 0.064, cell_size * 3 - cell_size * 0.064, color_red)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        image_cross,
                        cell[row][col][1][1].x,
                        cell[row][col][1][1].y,
                        0,
                        k_scale * 3,
                        k_scale * 3
                    )
                elseif big_matrix[row][col] == -1 then
                    draw_button(cell[row][col][1][1].x + cell_size * 0.032, cell[row][col][1][1].y + cell_size * 0.032, cell_size * 3 - cell_size * 0.064, cell_size * 3 - cell_size * 0.064, color_blue)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        image_zero,
                        cell[row][col][1][1].x,
                        cell[row][col][1][1].y,
                        0,
                        k_scale * 3,
                        k_scale * 3
                    )
                end
            end
        end

        -- УКАЗАТЕЛИ
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_x, coord.p1.x, coord.p1.y, 0, k_scale * 2, k_scale * 2)
        love.graphics.draw(image_o, coord.p2.x, coord.p2.y, 0, k_scale * 2, k_scale * 2)
        if not is_gameover then
            if player == 1 then
                love.graphics.draw(image_hand, coord.h1.x, coord.h1.y - offset_anim + cell_size * 0.25, 0, k_scale * 2, k_scale * 2)
            elseif player == 2 then
                love.graphics.draw(image_hand, coord.h2.x, coord.h2.y - offset_anim + cell_size * 0.25, 0, -k_scale * 2, k_scale * 2)
            end
        else
            if player == 1 or player == 0 then
                love.graphics.draw(image_win, coord.h1.x, coord.h1.y - offset_anim + cell_size * 0.25, 0, k_scale * 2, k_scale * 2)
            end
            if player == 2 or player == 0 then
                love.graphics.draw(image_win, coord.h2.x, coord.h2.y - offset_anim + cell_size * 0.25, 0, -k_scale * 2, k_scale * 2)
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if press_button == "info" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(coord.info.x + cell_size * 0.032, coord.info.y + cell_size * 0.032, cell_size * 2 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
    
    if press_button == "menu" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
    draw_button(coord.menu.x + cell_size * 0.032, coord.menu.y + cell_size * 0.032, cell_size * 2 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    if not is_show_menu and not is_show_info then love.graphics.draw(image_info, coord.info.x, coord.info.y, 0, k_scale * 2, k_scale * 2)
    elseif is_show_menu then love.graphics.draw(image_lang, coord.info.x, coord.info.y, 0, k_scale * 2, k_scale * 2)
    elseif is_show_info then love.graphics.draw(image_back, coord.info.x, coord.info.y, 0, k_scale * 2, k_scale * 2) end
    if not is_show_menu then love.graphics.draw(image_menu, coord.menu.x, coord.menu.y, 0, k_scale * 2, k_scale * 2) else love.graphics.draw(image_back, coord.menu.x, coord.menu.y, 0, k_scale * 2, k_scale * 2) end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if press_button == "bot" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.bot.x + cell_size * 0.032, coord.bot.y + cell_size * 0.032, cell_size * 9.6 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
        
        if press_button == "human" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.human.x + cell_size * 0.032, coord.human.y + cell_size * 0.032, cell_size * 9.6 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
        
        if press_button == "about" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.about.x + cell_size * 0.032, coord.about.y + cell_size * 0.032, cell_size * 9.6 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
        
        if press_button == "exit" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.exit.x + cell_size * 0.032, coord.exit.y + cell_size * 0.032, cell_size * 9.6 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_bot, coord.bot.x + cell_size * 0.25, coord.bot.y, 0, k_scale * 2, k_scale * 2)
        love.graphics.draw(image_human, coord.human.x + cell_size * 0.25, coord.human.y, 0, k_scale * 2, k_scale * 2)
        love.graphics.draw(image_about, coord.about.x + cell_size * 0.25, coord.about.y, 0, k_scale * 2, k_scale * 2)
        love.graphics.draw(image_exit, coord.exit.x + cell_size * 0.25, coord.exit.y, 0, k_scale * 2, k_scale * 2)

        love.graphics.setColor(color_fg)
        love.graphics.setFont(game_font)
        love.graphics.printf(s("Game vs Bot"), coord.bot.x + cell_size, coord.bot.y + cell_size * 0.5, cell_size * 8.5, "center")
        love.graphics.printf(s("Game vs Human"), coord.human.x + cell_size, coord.human.y + cell_size * 0.5, cell_size * 8.5, "center")
        love.graphics.printf(s("About game"), coord.about.x + cell_size, coord.about.y + cell_size * 0.5, cell_size * 8.5, "center")
        love.graphics.printf(s("Exit game"), coord.exit.x + cell_size, coord.exit.y + cell_size * 0.5, cell_size * 8.5, "center")

        if press_button == "anim" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.p1.x + cell_size * 0.032, coord.p1.y + cell_size * 0.032, cell_size * 2 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
        
        if press_button == "sound" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(coord.p2.x + cell_size * 0.032, coord.p2.y + cell_size * 0.032, cell_size * 2 - cell_size * 0.064, cell_size * 2 - cell_size * 0.064, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        if is_anim then love.graphics.draw(image_move, coord.p1.x, coord.p1.y, 0, k_scale * 2, k_scale * 2)
        else love.graphics.draw(image_stop, coord.p1.x, coord.p1.y, 0, k_scale * 2, k_scale * 2) end
        if is_sound then love.graphics.draw(image_sound, coord.p2.x, coord.p2.y, 0, k_scale * 2, k_scale * 2)
        else love.graphics.draw(image_mute, coord.p2.x, coord.p2.y, 0, k_scale * 2, k_scale * 2) end
    end

    -- ИНФО
    if is_show_info then
        love.graphics.setColor(color_fg)
        love.graphics.setFont(info_font)
        love.graphics.printf(s(info_text), board.x, board.y + offset_info, board.size, "center")
    end

end


local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)  -- пересечение точки с прямоугольником
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


local function calculate_offset_info()
    local _w, t = info_font:getWrap(s(info_text), board.size)
    offset_info = ( board.size - #t * cell_size * 0.5 * 1.2 ) / 2
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
            for row=1,3 do
                for col=1,3 do
                    for i=1,3 do
                        for j=1,3 do
                            if is_collide(x, y, cell[row][col][i][j].x, cell[row][col][i][j].y, cell_size, cell_size) then
                                press_cell = {row, col, i, j}
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, coord.info.x, coord.info.y, cell_size * 2, cell_size * 2) then
        press_button = "info"
    elseif is_collide(x, y, coord.menu.x, coord.menu.y, cell_size * 2, cell_size * 2) then
        press_button = "menu"
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, coord.bot.x, coord.bot.y, cell_size * 9.6, cell_size * 2) then
            press_button = "bot"
        elseif is_collide(x, y, coord.human.x, coord.human.y, cell_size * 9.6, cell_size * 2) then
            press_button = "human"
        elseif is_collide(x, y, coord.about.x, coord.about.y, cell_size * 9.6, cell_size * 2) then
            press_button = "about"
        elseif is_collide(x, y, coord.exit.x, coord.exit.y, cell_size * 9.6, cell_size * 2) then
            press_button = "exit"
        elseif is_collide(x, y, coord.p1.x, coord.p1.y, cell_size * 2, cell_size * 2) then
            press_button = "anim"
        elseif is_collide(x, y, coord.p2.x, coord.p2.y, cell_size * 2, cell_size * 2) then
            press_button = "sound"
        end
    end

end


function game.mousereleased( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        if not is_block and is_collide(x, y, board.x, board.y, board.size, board.size) then
            for row=1,3 do
                for col=1,3 do
                    for i=1,3 do
                        for j=1,3 do
                            if is_collide(x, y, cell[row][col][i][j].x, cell[row][col][i][j].y, cell_size, cell_size) then
                                if press_cell[1] == row and press_cell[2] == col and press_cell[3] == i and press_cell[4] == j then
                                    is_block = true
                                    if is_sound then sound_click:play() end
                                    click_cell(row, col, i, j)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, coord.info.x, coord.info.y, cell_size * 2, cell_size * 2) and press_button == "info" then
        if is_show_menu then
            if is_sound then sound_click:play() end
            if game_lang == "en" then game_lang = "ru" else game_lang = "en" end
            s:set_namespace(game_lang)
        elseif not is_show_menu then
            if is_sound then sound_click:play() end
            info_text = "Info text"
            calculate_offset_info()
            is_show_info = not is_show_info
        end
    elseif is_collide(x, y, coord.menu.x, coord.menu.y, cell_size * 2, cell_size * 2) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, coord.bot.x, coord.bot.y, cell_size * 9.6, cell_size * 2) and press_button == "bot" then
            if is_sound then sound_click:play() end
            is_show_menu = false
            is_bot = true
            new_game()
        elseif is_collide(x, y, coord.human.x, coord.human.y, cell_size * 9.6, cell_size * 2) and press_button == "human" then
            if is_sound then sound_click:play() end
            is_show_menu = false
            is_bot = false
            new_game()
        elseif is_collide(x, y, coord.about.x, coord.about.y, cell_size * 9.6, cell_size * 2) and press_button == "about" then
            if is_sound then sound_click:play() end
            info_text = "About text"
            calculate_offset_info()
            is_show_menu = false
            is_show_info = true
        elseif is_collide(x, y, coord.exit.x, coord.exit.y, cell_size * 9.6, cell_size * 2) and press_button == "exit" then
            if is_sound then sound_click:play() end
            --group:delay(function() love.event.quit(0) end, 0.300)
            
            -- Возврат в лаунчер
            save_game()
            is_show_menu = false
            current_state = launcher
            current_state.load()
        elseif is_collide(x, y, coord.p1.x, coord.p1.y, cell_size * 2, cell_size * 2) and press_button == "anim" then
            if is_sound then sound_click:play() end
            is_anim = not is_anim
            offset_anim = 0
            vector_anim = 1
        elseif is_collide(x, y, coord.p2.x, coord.p2.y, cell_size * 2, cell_size * 2) and press_button == "sound" then
            if is_sound then sound_click:play() end
            is_sound = not is_sound
        end
    end

    press_cell = {0, 0, 0, 0}
    press_button = ""
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
