local game = {}

local dict = require("modules/dict")
local tick = require("modules/tick")
local lume = require("modules/lume")
local serpent = require("modules/serpent")
local utf8 = require("utf8")  -- это встроенный модуль Love2D

-- colors
local color_red = {234/255, 90/255, 71/255, 0.5}  -- #e5321a
local color_blue = {146/255, 211/255, 245/255, 0.5}  -- #15a1ea
local color_green = {177/255, 204/255, 51/255, 0.5}  -- #4bd37b
local color_select = {252/255, 234/255, 43/255, 0.5}  -- #ffdd67

-- images
local image_menu = love.graphics.newImage("images/gear.png")
local image_back = love.graphics.newImage("images/back.png")
local image_help = love.graphics.newImage("images/help.png")
local image_bot = love.graphics.newImage("images/robot.png")
local image_human = love.graphics.newImage("images/man.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_fly = love.graphics.newImage("images/fly.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")
local image_hand = love.graphics.newImage("images/hand_left.png")
local image_win = love.graphics.newImage("images/hand_victory.png")
local image_history = love.graphics.newImage("images/clipboard.png")

-- calculate
local cell_size = 120
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 60 )
local key_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 30 )
local info_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 20 )
--local W = 1280
--local H = 720
local board = {x=0, y=0}

-- game
local is_block = true
local is_show_menu = false
local is_show_info = false
local is_show_keyboard = false
local is_show_history = false
local group = tick.group()
local is_touch = false
local matrix = {}
local select_path = {}
local select_key = {}
local words_by_length = {}
local matrix_color = {}
local history_color = {}
local history = {}
local press_button = ""
local player = 1  -- 1 or 2
local score = {0, 0}
local is_bot = true
local bot_rotation = math.rad(0)
local anim_offset = 0
local anim_dir = 1
local count_pass = 0

-- INFO
local info_text = ""
local scrollY = 0
local maxScrollY = 0
local scrollSpeed = 30
-- Размеры окна просмотра
local viewX, viewY = 340, 30
local viewWidth, viewHeight = 600, 600
-- Размеры скроллбара
local sbWidth = 10
local sbX = viewX + viewWidth + 10
local sbHeight = 0
local sbY = 0
local showScrollbar = false
-- Переменные для перетаскивания (Drag & Drop)
local isDragging = false
local startMouseY = 0
local startScrollY = 0

-- thread
local is_thread = false
local is_stop = false
local thread
local threadCode = [[
local dict = require("modules/dict")
local lume = require("modules/lume")
local serpent = require("modules/serpent")
local utf8 = require("utf8")

-- data
local Mtx = love.thread.getChannel("matrix")
-- Ждем, пока придет строка
local matrixString = Mtx:demand()
-- Восстанавливаем таблицу из строки
local chunkM = loadstring(matrixString)
local matrix = chunkM()

local His = love.thread.getChannel("history")
-- Ждем, пока придет строка
local historyString = His:demand()
-- Восстанавливаем таблицу из строки
local chunkH = loadstring(historyString)
local history = chunkH()

local words_by_length = {}
local directions = { {-1, 0}, {1, 0}, {0, -1}, {0, 1} }  -- Направления движения
local visited = {}  -- Массив посещенных клеток
local result_path = {}


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


local function find_matches(search_mask)
    -- Считаем длину маски по количеству букв (знак "?" считается за 1 букву)
    local length = utf8.len(search_mask)
    local results = {}
    
    -- Получаем список слов только нужной длины
    local sub_list = words_by_length[length]
    if not sub_list then return results end
    
    -- Превращаем "?" в ".." (так как 1 русская буква в UTF-8 = 2 байта)
    -- Экранируем знак "?" процентом (%), так как в Lua это спецсимвол
    local pattern = "^" .. string.gsub(search_mask, "%?", "..") .. "$"
    
    -- Перебираем только отфильтрованные по длине слова
    for _, word in ipairs(sub_list) do
        if string.match(word, pattern) then
            table.insert(results, word)
        end
    end
    
    return results
end


local function dfs(r, c, path)
    table.insert(path, {r, c})
    visited[r][c] = true
    
    local count_empty = 0
    if #path > 1 then
        for _, rc in ipairs(path) do
            if matrix[ rc[1] ][ rc[2] ] == "?" then count_empty = count_empty + 1 end
        end
        if count_empty == 1 then
            table.insert( result_path, deepcopy(path) )
        end
    end
    
    if #path <= 8 and count_empty <= 1 then
        for _, dir in ipairs(directions) do
            local nr, nc = r + dir[1], c + dir[2]
            
            if nr >= 1 and nr <= 5 and nc >= 1 and nc <= 5 then
                if not visited[nr][nc] then
                    dfs(nr, nc, path)
                end
            end
        end
    end

    -- Возврат (backtracking)
    visited[r][c] = false
    table.remove(path)
end


-- ===== MAIN =====
for key, val in pairs(dict) do
    local len = utf8.len(key) -- Считаем именно буквы, а не байты
    if len then
        if not words_by_length[len] then
            words_by_length[len] = {}
        end
        table.insert(words_by_length[len], key)
    end
end

for r = 1, 5 do
    visited[r] = {}
    for c = 1, 5 do visited[r][c] = false end
end
    
for i = 1, 5 do
    for j = 1, 5 do
        dfs(i, j, {})
    end
end

math.randomseed(os.time())  -- для lume
result_path = lume.shuffle(result_path)
local bot_result = { word="", path={} }
local start_time = os.clock()

for _, p in ipairs(result_path) do
    if (os.clock() - start_time) > 5 and #bot_result.path > 0 then
        break  -- ограничиваем поиск 5 сек
    elseif #p > #bot_result.path then
        local word_mask = ""  -- ищем слово
        for _, t in ipairs(p) do
            word_mask = word_mask .. matrix[ t[1] ][ t[2] ]
        end
        local word_list = find_matches(word_mask)
        if #word_list > 0 then
            word_list = lume.shuffle(word_list)
            for _, w in ipairs(word_list) do
                -- проверяем в истории
                if not lume.find(history, w) then
                    bot_result = { word=w, path=p }
                    break
                end
            end
        end
    end
end

local botString = serpent.dump(bot_result)
love.thread.getChannel("bot"):push(botString)
]]

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_tile = love.audio.newSource("audio/tile.ogg", "static")
local sound_error = love.audio.newSource("audio/error.ogg", "static")
local sound_gameover = love.audio.newSource("audio/gameover.ogg", "static")


local alphabet = {
        {"а", "б", "в", "г", "д", "е", "ж", "з"},
        {"и", "й", "к", "л", "м", "н", "о", "п"},
        {"р", "с", "т", "у", "ф", "х", "ц", "ч"},
        {"ш", "щ", "ъ", "ы", "ь", "э", "ю", "я"}
    }


local ru_lower_to_upper = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г",
    ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё", ["ж"] = "Ж",
    ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К",
    ["л"] = "Л", ["м"] = "М", ["н"] = "Н", ["о"] = "О",
    ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т",
    ["у"] = "У", ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц",
    ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ",
    ["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю",
    ["я"] = "Я"
}


local function stop_thread()
    if is_thread then
        is_thread = false
        if thread:isRunning( ) then
            thread:wait()  -- замораживает GUI
            love.thread.getChannel( "bot" ):pop()
        end
    end
    is_stop = false
end


local function bot_move()
    if is_stop then return end
    thread:start()
    
    -- data
    local matrixString = serpent.dump(matrix)
    local historyString = serpent.dump(history)
    
    love.thread.getChannel("matrix"):push(matrixString)
    love.thread.getChannel("history"):push(historyString)
    
    is_thread = true
end


local function after_move()
    if is_stop then return end
    
    if #history == 21 or count_pass == 2 then
        love.system.vibrate(0.150)
        if is_sound then sound_gameover:play() end
        if score[1] > score[2] then msg("Победа синего игрока!")
        elseif score[2] > score[1] then msg("Победа красного игрока!")
        else msg("Ничья!") end
    else
        if #history == 1 then select_path = {}
        else
            if player == 1 then player = 2 else player = 1 end
        end
        
        if player == 1 or not is_bot then is_block = false
        else bot_move() end
    end
end


function update_matrix(word, path, color)  -- Global; color он же player 1 or 2, 3 - для начала игры
    if is_stop then return end
    
    count_pass = 0
    local index = 1
    for _, c in utf8.codes(word) do
        local char = utf8.char(c)  -- получаем отдельную букву в виде строки
        matrix[ path[index][1] ][ path[index][2] ] = char
        if matrix_color[ path[index][1] ][ path[index][2] ] == 0 then matrix_color[ path[index][1] ][ path[index][2] ] = color end
        index = index + 1
    end
    
    table.insert(history_color, color)
    table.insert(history, word)
    
    if color ~= 3 then score[color] = score[color] + #path end
    group:delay(function() after_move() end, 0.150)
end


local function calculate_info()
    startMouseY = 0
    startScrollY = 0
    scrollY = 0
    maxScrollY = 0
    sbHeight = 0
    sbY = 0
    
    local _, tlines = info_font:getWrap(info_text, viewWidth)
    local totalTextHeight = #tlines * info_font:getHeight() * 0.78
    
    maxScrollY = math.max(0, totalTextHeight - viewHeight)

    if totalTextHeight > viewHeight then
        showScrollbar = true
        sbHeight = (viewHeight / totalTextHeight) * viewHeight
        if sbHeight < 20 then sbHeight = 20 end
    else
        showScrollbar = false
    end
end


local function resize()
    --W = love.graphics.getWidth()
    --H = love.graphics.getHeight()

    if W > H then cell_size = math.min(W / 9.5, H / 5.5) else cell_size = math.min(W / 5.5, H / 9.5) end
    k_scale = cell_size / image_menu:getWidth()
    board = {x = W * 0.5 - cell_size * 2.5, y = H * 0.5 - cell_size * 2.5}

    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.75 )
    key_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.45 )
    info_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.3 )
    info_font:setLineHeight( 0.77 )
    
    anim_offset = 0
    anim_dir = 1
    
    -- INFO
    scrollSpeed = cell_size * 0.25
    viewX, viewY = board.x, board.y
    viewWidth, viewHeight = cell_size * 5, cell_size * 5
    sbWidth = cell_size / 10
    sbX = viewX + viewWidth + cell_size / 10
    if info_text ~= '' then calculate_info() end
end


local function new_game()
    is_show_keyboard = false
    is_show_history = false
    is_stop = false

    -- очистка
    score = {0, 0}
    
    matrix = {
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'}
    }
    
    matrix_color = {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
    }
    
    history_color = {}
    history = {}
    
    local turn = love.math.random( 1, 100 )
    if turn <= 50 then player = 1 else player = 2 end
    
    local rand_index = love.math.random( 1, #words_by_length[5] )
    local rand_word = words_by_length[5][rand_index]
    
    select_path = { {3, 1}, {3, 2}, {3, 3}, {3, 4}, {3, 5} }
    group:delay(function() update_matrix(rand_word, select_path, 3) end, 0.150)
end


local function save_game()
    local data = {}
    data.player = player
    data.is_bot = is_bot
    data.count_pass = count_pass
    data.score = score
    data.matrix = matrix
    data.matrix_color = matrix_color
    data.history = history
    data.history_color = history_color

    local serialized = lume.serialize(data)
    love.filesystem.write("bukva", serialized)
end


function game.load()
    -- инициализация
    thread = love.thread.newThread( threadCode )
    
    matrix = {
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'},
        {'?', '?', '?', '?', '?'}
    }
    
    matrix_color = {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
    }
    
    -- вычисление размеров
    resize()
    
    -- Группируем слова по длине (ОДИН раз при старте программы)
    for key, val in pairs(dict) do
        local len = utf8.len(key) -- Считаем именно буквы, а не байты
        if len then
            if not words_by_length[len] then
                words_by_length[len] = {}
            end
            table.insert(words_by_length[len], key)
        end
    end
    
    -- load save data
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("bukva") then
            local file = love.filesystem.read("bukva")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local ok, msg = pcall( function()
            if not ( data.player == 1 or data.player == 2 ) then error("Incorrect saved data!")
            else player = data.player end
            
            if not (data.is_bot == true or data.is_bot == false) then error("Incorrect saved data!")
            else is_bot = data.is_bot end
            
            if not (data.count_pass == 0 or data.count_pass == 1 or data.count_pass == 2) then error("Incorrect saved data!")
            else count_pass = data.count_pass end
            
            if not ( type(data.score) == 'table' and data.score[1] >= 0 and data.score[2] >= 0 ) then error("Incorrect saved data!")
            else score = data.score end
            
            if not ( type(data.matrix) == 'table' and type(data.matrix_color) == 'table' and type(data.history) == 'table' and type(data.history_color) == 'table' ) then error("Incorrect saved data!")
            else
                local is_good = true
                for i = 1, 5 do
                    for j = 1, 5 do
                        if not ( type(data.matrix[i][j]) == 'string' and utf8.len(data.matrix[i][j]) == 1 and ( data.matrix_color[i][j] == 0 or data.matrix_color[i][j] == 1 or data.matrix_color[i][j] == 2 or data.matrix_color[i][j] == 3 ) ) then
                            is_good = false
                        end
                    end
                end
                
                for h=1,#data.history do
                    if not ( type(data.history[h]) == 'string' and ( data.history_color[h] == 1 or data.history_color[h] == 2 or data.history_color[h] == 3 ) ) then
                        is_good = false
                    end
                end
                
                if not is_good then
                    error("Incorrect saved data!")
                else
                    matrix = data.matrix
                    matrix_color = data.matrix_color
                    history = data.history
                    history_color = data.history_color
                end
            end
        end )

        if ok then  -- при выполнении защищенного кода ошибок нет
            if not (#history == 21 or count_pass == 2) then
                if player == 1 or not is_bot then is_block = false
                else bot_move() end
            end
        
        else  -- защищенный код вызвал ошибку
            --love.window.showMessageBox("ERROR", "Not read saved data! " .. (msg or "..."), "error")
            msg("Not read saved data! " .. (msg or "..."))
            new_game()
        end
    else
        --love.window.showMessageBox("INFO", "Saved data was not found! " .. (err or "..."), "info")
        new_game()
    end
end


function game.update(dt)
    group:update(dt)

    if is_anim then
        anim_offset = anim_offset + anim_dir * dt * cell_size * 0.1
        if math.abs(anim_offset) >= cell_size * 0.1 then anim_offset = 0 end  -- для исправления скачков анимации при паузах
        if anim_offset >= cell_size * 0.05 then anim_dir = -1
        elseif anim_offset <= 0 then anim_dir = 1 end
    end
    
    -- INFO
    if is_show_info and isDragging then
        -- Получаем текущие координаты мыши
        local mx, my = love.mouse.getPosition()
        -- Вычисляем, насколько мы переместили мышь по вертикали
        local dy = my - startMouseY
        -- Меняем скролл (знак минус, так как при движении мыши ВНИЗ текст должен идти ВНИЗ, то есть scrollY уменьшается)
        scrollY = startScrollY - dy
        -- Ограничиваем скролл, чтобы не улетал за пределы
        scrollY = math.max(0, math.min(maxScrollY, scrollY))
    end
    -- Обновление позиции ползунка скроллбара
    if showScrollbar and maxScrollY > 0 then
        local scrollRatio = scrollY / maxScrollY
        local trackHeight = viewHeight - sbHeight
        sbY = viewY + (scrollRatio * trackHeight)
    end
    
    if is_thread then
        bot_rotation = bot_rotation + dt * 6
        if math.abs(bot_rotation) >= 2 * math.pi then bot_rotation = math.rad(0) end
        
        if not thread:isRunning( ) then  -- finish thread
            is_thread = false
            bot_rotation = math.rad(0)

            -- data
            local botString = love.thread.getChannel( "bot" ):pop()
            local chunkB = loadstring(botString)
            local bot_result = chunkB()
            
            if #bot_result.path > 0 then
                if is_sound then sound_tile:play() end
                select_path = bot_result.path
                group:delay(function() update_matrix(bot_result.word, bot_result.path, player) end, 0.150)
            else
                love.system.vibrate(0.150)
                if is_sound then sound_error:play() end
                msg("Пас, бот не нашел вариантов!")
                count_pass = count_pass + 1
                group:delay(function() after_move() end, 0.150)
            end
        end
    end
end


local function draw_history()
    love.graphics.setFont(info_font)
    local bcolor = {1, 1, 1, 0.5}
    local count_history = 1
    
    for i=1,7 do
        for j=1,3 do
            bcolor = {1, 1, 1, 0.5}
            if history[count_history] then
                if history_color[count_history] == 1 then bcolor = color_blue
                elseif history_color[count_history] == 2 then bcolor = color_red
                elseif history_color[count_history] == 3 then bcolor = color_green end
            end
            if press_button == "h" .. count_history then bcolor = color_button_press end
            draw_button(board.x + (j - 1) * cell_size * 5 / 3 + cell_size * 0.032, board.y + (i - 1) * cell_size * 5 / 7 + cell_size * 0.032, cell_size * 5 / 3 - cell_size * 0.064, cell_size * 5 / 7 - cell_size * 0.064, bcolor)
            
            love.graphics.setColor(color_fg)
            if history[count_history] then
                local offset = cell_size * 0.15
                local len = utf8.len(history[count_history])
                if len > 9 then offset = 0 end
                love.graphics.printf(history[count_history], board.x + (j - 1) * cell_size * 5 / 3, board.y + (i - 1) * cell_size * 5 / 7 + offset, cell_size * 5 / 3, "center")
            end
            
            count_history = count_history + 1
        end
    end
end


local function draw_keyboard()
    love.graphics.setFont(game_font)
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 0.032, cell_size * 5 - cell_size * 0.064, cell_size - cell_size * 0.064, color_select, {191/255, 172/255, 106/255})
    
    local word = ""
    for s=1,#select_path do
        local char = matrix[ select_path[s][1] ][ select_path[s][2] ]
        if char == "?" and #select_key > 0 then char = ru_lower_to_upper[ alphabet[ select_key[1] ][ select_key[2] ] ] end
        word = word .. char
    end
    
    love.graphics.setColor({0, 0, 0, 0.25})
    love.graphics.printf(word, board.x + cell_size * 0.025, board.y, cell_size * 5, "center")
    love.graphics.setColor(color_fg)
    love.graphics.printf(word, board.x, board.y - cell_size * 0.025, cell_size * 5, "center")
    
    love.graphics.setFont(key_font)
    local bcolor = {1, 1, 1, 0.5}
    for i=1,4 do
        for j=1,8 do
            bcolor = {1, 1, 1, 0.5}
            if select_key[1] == i and select_key[2] == j then bcolor = color_select end
            draw_button(board.x + (j - 1) * cell_size * 5 / 8 + cell_size * 0.032, board.y + (i - 1) * cell_size * 4 / 5 + cell_size + cell_size * 0.032, cell_size * 5 / 8 - cell_size * 0.064, cell_size * 4 / 5 - cell_size * 0.064, bcolor)
            love.graphics.setColor(color_fg)
            love.graphics.printf(ru_lower_to_upper[ alphabet[i][j] ], board.x + (j - 1) * cell_size * 5 / 8, board.y + (i - 1) * cell_size * 4 / 5 + cell_size * 1.1, cell_size * 5 / 8, "center")
        end
    end
    
    bcolor = color_red
    if press_button == "cancel" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 4 / 5 * 4 + cell_size + cell_size * 0.032, cell_size * 2.5 - cell_size * 0.064, cell_size * 4 / 5 - cell_size * 0.064, bcolor)
    bcolor = color_green
    if press_button == "accept" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 2.5 + cell_size * 0.032, board.y + cell_size * 4 / 5 * 4 + cell_size + cell_size * 0.032, cell_size * 2.5 - cell_size * 0.064, cell_size * 4 / 5 - cell_size * 0.064, bcolor)
    love.graphics.setColor(color_fg)
    love.graphics.printf("Отмена", board.x, board.y + cell_size * 4 / 5 * 4 + cell_size * 1.1, cell_size * 2.5, "center")
    love.graphics.printf("Принять", board.x + cell_size * 2.5, board.y + cell_size * 4 / 5 * 4 + cell_size * 1.1, cell_size * 2.5, "center")
end


local function draw_select_line()
    if #select_path >= 2 then
        love.graphics.setLineWidth( math.max(1, cell_size * 0.05) )
        local count_empty = 0
        
        for i=1,#select_path-1 do
            local from_x, from_y =  board.x + (select_path[i][2] - 1) * cell_size + cell_size * 0.5, board.y + (select_path[i][1] - 1) * cell_size + cell_size * 0.5
            local to_x, to_y = board.x + (select_path[i+1][2] - 1) * cell_size + cell_size * 0.5, board.y + (select_path[i+1][1] - 1) * cell_size + cell_size * 0.5
            
            if matrix[ select_path[i][1] ][ select_path[i][2] ] == '?' then
                count_empty = count_empty + 1
            end
            
            love.graphics.setColor({177/255, 204/255, 51/255})  -- green
            
            if not ((select_path[i][1] == select_path[i+1][1] and math.abs(select_path[i][2] - select_path[i+1][2]) == 1) or (select_path[i][2] == select_path[i+1][2] and math.abs(select_path[i][1] - select_path[i+1][1]) == 1)) or (matrix[ select_path[i+1][1] ][ select_path[i+1][2] ] == '?' and count_empty > 0) or count_empty > 1 then
                love.graphics.setColor({234/255, 90/255, 71/255})  -- red
            end
            
            love.graphics.line(from_x, from_y, to_x, to_y)
            love.graphics.circle("fill", to_x, to_y, math.max(1, cell_size * 0.1))
        end
    end
end


local function draw_menu()
    local bcolor = {1, 1, 1, 0.5}
    if press_button == "bot" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 0.5 + cell_size * 0.032, cell_size * 5 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    bcolor = {1, 1, 1, 0.5}
    if press_button == "human" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 1.5 + cell_size * 0.032, cell_size * 5 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    bcolor = {1, 1, 1, 0.5}
    if press_button == "about" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 2.5 + cell_size * 0.032, cell_size * 5 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    bcolor = {1, 1, 1, 0.5}
    if press_button == "exit" then bcolor = color_button_press end
    draw_button(board.x + cell_size * 0.032, board.y + cell_size * 3.5 + cell_size * 0.032, cell_size * 5 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image_bot, board.x, board.y + cell_size * 0.5, 0, k_scale, k_scale)
    love.graphics.draw(image_human, board.x, board.y + cell_size * 1.5, 0, k_scale, k_scale)
    love.graphics.draw(image_about, board.x, board.y + cell_size * 2.5, 0, k_scale, k_scale)
    love.graphics.draw(image_exit, board.x, board.y + cell_size * 3.5, 0, k_scale, k_scale)
    
    love.graphics.setFont(key_font)
    love.graphics.setColor(color_fg)
    love.graphics.printf('Игра с ботом', board.x + cell_size * 0.5, board.y + cell_size * 0.66, cell_size * 4.5, "center")
    love.graphics.printf('Игра с другом', board.x + cell_size * 0.5, board.y + cell_size * 1.66, cell_size * 4.5, "center")
    love.graphics.printf('Об игре', board.x + cell_size * 0.5, board.y + cell_size * 2.66, cell_size * 4.5, "center")
    love.graphics.printf('Выход', board.x + cell_size * 0.5, board.y + cell_size * 3.66, cell_size * 4.5, "center")
    
    bcolor = {1, 1, 1, 0.5}
    if press_button == "anim" then bcolor = color_button_press end
    draw_button(cell_size * 0.25 + cell_size * 0.032, H - cell_size * 1.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    bcolor = {1, 1, 1, 0.5}
    if press_button == "sound" then bcolor = color_button_press end
    draw_button(W - cell_size * 1.25 + cell_size * 0.032, H - cell_size * 1.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    love.graphics.setColor(1, 1, 1, 1)
    if is_anim then love.graphics.draw(image_fly, cell_size * 0.25, H - cell_size * 1.25, 0, k_scale, k_scale) else love.graphics.draw(image_stop, cell_size * 0.25, H - cell_size * 1.25, 0, k_scale, k_scale) end
    if is_sound then love.graphics.draw(image_sound, W - cell_size * 1.25, H - cell_size * 1.25, 0, k_scale, k_scale) else love.graphics.draw(image_mute, W - cell_size * 1.25, H - cell_size * 1.25, 0, k_scale, k_scale) end
end


function game.draw()
    local bcolor = {1, 1, 1, 0.5}
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        -- HISTORY
        if is_show_history then draw_history()
        -- KEYBOARD
        elseif is_show_keyboard then draw_keyboard()
        -- GAMEBOARD
        else
            for i=1,5 do
                for j=1,5 do
                    bcolor = {1, 1, 1, 0.5}
                    if matrix_color[i][j] == 1 then bcolor = color_blue
                    elseif matrix_color[i][j] == 2 then bcolor = color_red
                    elseif matrix_color[i][j] == 3 then bcolor = color_green end
                    
                    for _, rec in ipairs(select_path) do
                        if i == rec[1] and j == rec[2] then
                            bcolor = color_select
                            break
                        end
                    end
                    
                    draw_button(board.x + (j - 1) * cell_size + cell_size * 0.032, board.y + (i - 1) * cell_size + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
                    
                    love.graphics.setFont(game_font)
                    --love.graphics.setColor(color_fg)
                    if matrix[i][j] ~= '?' then
                        love.graphics.setColor({0, 0, 0, 0.25})  -- shadow
                        love.graphics.printf(ru_lower_to_upper[matrix[i][j]], board.x + (j - 1) * cell_size + cell_size * 0.025, board.y + (i - 1) * cell_size + cell_size * 0.025, cell_size, "center")
                        love.graphics.setColor(color_fg)
                        love.graphics.printf(ru_lower_to_upper[matrix[i][j]], board.x + (j - 1) * cell_size, board.y + (i - 1) * cell_size, cell_size, "center")
                    end
                end
            end
            
            if #select_path >= 2 then draw_select_line() end
        end
        
        -- score
        bcolor = color_blue
        draw_button(cell_size * 0.25 + cell_size * 0.032, H - cell_size * 1.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor, {1, 1, 1, 0})
        bcolor = color_red
        draw_button(W - cell_size * 1.25 + cell_size * 0.032, H - cell_size * 1.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor, {1, 1, 1, 0})
        love.graphics.setFont(game_font)
        love.graphics.setColor({0, 0, 0, 0.25})  -- shadow
        love.graphics.printf(score[1], cell_size * 0.25 + cell_size * 0.025, H - cell_size * 1.25 + cell_size * 0.025, cell_size, "center")
        love.graphics.setColor(color_fg)
        love.graphics.printf(score[1], cell_size * 0.25, H - cell_size * 1.25, cell_size, "center")
        if is_thread then  -- bot analyze
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image_bot, W - cell_size * 0.75, H - cell_size * 0.75, bot_rotation, k_scale, k_scale, image_bot:getWidth() * 0.5, image_bot:getHeight() * 0.5)
        else
            love.graphics.setColor({0, 0, 0, 0.25})
            love.graphics.printf(score[2], W - cell_size * 1.25 + cell_size * 0.025, H - cell_size * 1.25 + cell_size * 0.025, cell_size, "center")
            love.graphics.setColor(color_fg)
            love.graphics.printf(score[2], W - cell_size * 1.25, H - cell_size * 1.25, cell_size, "center")
        end
        
        -- указатели
        if (not is_show_history) and (not is_show_keyboard) then
            love.graphics.setColor(1, 1, 1, 1)
            if #history > 0 and #history < 21 and count_pass < 2 then
                if player == 1 then
                    love.graphics.draw(image_hand, cell_size * 1.25 + anim_offset - cell_size * 0.1, H - cell_size * 1.25, 0, k_scale, k_scale)
                    -- pass button
                    bcolor = color_select
                    if press_button == "pass" then bcolor = color_button_press end
                    draw_button(cell_size * 0.25 + cell_size * 0.032, H - cell_size * 1.75 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size * 0.5 - cell_size * 0.064, bcolor)
                    love.graphics.setColor(color_fg)
                    love.graphics.setFont(info_font)
                    love.graphics.printf('ПАС', cell_size * 0.25, H - cell_size * 1.7, cell_size, "center")
                elseif player == 2 then
                    love.graphics.draw(image_hand, W - cell_size * 1.25 - anim_offset + cell_size * 0.1, H - cell_size * 1.25, 0, -k_scale, k_scale)
                    if not is_bot then
                        -- pass button
                        bcolor = color_select
                        if press_button == "pass" then bcolor = color_button_press end
                        draw_button(W - cell_size * 1.25 + cell_size * 0.032, H - cell_size * 1.75 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size * 0.5 - cell_size * 0.064, bcolor)
                        love.graphics.setColor(color_fg)
                        love.graphics.setFont(info_font)
                        love.graphics.printf('ПАС', W - cell_size * 1.25, H - cell_size * 1.7, cell_size, "center")
                    end
                end
            elseif #history == 21 or count_pass == 2 then
                if score[1] >= score[2] then love.graphics.draw(image_win, cell_size * 1.25 - cell_size * 0.1, H - cell_size * 1.25 - anim_offset, 0, k_scale, k_scale) end
                if score[2] >= score[1] then love.graphics.draw(image_win, W - cell_size * 1.25 + cell_size * 0.1, H - cell_size * 1.25 - anim_offset, 0, -k_scale, k_scale) end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    bcolor = {1, 1, 1, 0.5}
    if press_button == "history" then bcolor = color_button_press end
    draw_button(cell_size * 0.25 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    bcolor = {1, 1, 1, 0.5}
    if press_button == "menu" then bcolor = color_button_press end
    draw_button(W - cell_size * 1.25 + cell_size * 0.032, cell_size * 0.25 + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    
    if is_show_history or is_show_info then
        love.graphics.draw(image_back, cell_size * 0.25, cell_size * 0.25, 0, k_scale, k_scale)
    elseif is_show_menu then
        love.graphics.draw(image_help, cell_size * 0.25, cell_size * 0.25, 0, k_scale, k_scale)
    else
        love.graphics.draw(image_history, cell_size * 0.25, cell_size * 0.25, 0, k_scale, k_scale)
    end
    
    if is_show_menu then
        love.graphics.draw(image_back, W - cell_size * 1.25, cell_size * 0.25, 0, k_scale, k_scale)
    else
        love.graphics.draw(image_menu, W - cell_size * 1.25, cell_size * 0.25, 0, k_scale, k_scale)
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then draw_menu() end

    -- ИНФО
    if is_show_info then
        love.graphics.setFont(info_font)
        love.graphics.setColor(color_fg)
        
        -- 1. Рамка текстового окна
        love.graphics.setColor(color_fg)
        love.graphics.setLineWidth( math.max(1, cell_size * 0.01) )
        love.graphics.rectangle("line", viewX - cell_size / 20, viewY - cell_size / 20, viewWidth + cell_size / 10, viewHeight + cell_size / 10)
        -- 2. Текст с обрезкой
        love.graphics.setScissor(viewX, viewY, viewWidth, viewHeight)
        --love.graphics.setColor(color_fg)
        love.graphics.printf(info_text, viewX, viewY - scrollY, viewWidth, "center")
        love.graphics.setScissor()
        -- 3. Отрисовка скроллбара
        if showScrollbar then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("fill", sbX, viewY, sbWidth, viewHeight)
            love.graphics.setColor(color_blue)
            love.graphics.rectangle("fill", sbX, sbY, sbWidth, sbHeight)
        end
    end

end


local function show_keyboard()
    select_key = {}
    is_show_keyboard = true
end


local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)  -- пересечение точки с прямоугольником
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


function game.keypressed(key, scancode, isrepeat)  -- love.keyreleased( key, scancode )
    if key == "escape" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_history = false
        is_show_menu = not is_show_menu
    end
end


function game.mousepressed( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        -- HISTORY
        if is_show_history then
            local count_history = 1
            
            for i=1,7 do
                for j=1,3 do
                    if is_collide(x, y, board.x + (j - 1) * cell_size * 5 / 3, board.y + (i - 1) * cell_size * 5 / 7, cell_size * 5 / 3, cell_size * 5 / 7) then
                        press_button = "h" .. count_history
                        break
                    end
                    
                    count_history = count_history + 1
                end
            end
        -- KEYBOARD
        elseif is_show_keyboard then
            for i=1,4 do
                for j=1,8 do
                    -- Клавиатура
                    if is_collide(x, y, board.x + (j - 1) * cell_size * 5 / 8, board.y + (i - 1) * cell_size * 4 / 5 + cell_size, cell_size * 5 / 8, cell_size * 4 / 5) then
                        if is_sound then sound_tile:play() end
                        select_key = {i, j}
                        break
                    end
                end
            end
            
            -- Отмена
            if is_collide(x, y, board.x, board.y + cell_size * 4 / 5 * 4 + cell_size, cell_size * 2.5, cell_size * 4 / 5) then
                press_button = "cancel"
            
            -- Принять
            elseif is_collide(x, y, board.x + cell_size * 2.5, board.y + cell_size * 4 / 5 * 4 + cell_size, cell_size * 2.5, cell_size * 4 / 5) then
                press_button = "accept"
            end
        -- GAMEBOARD    
        elseif is_collide(x, y, board.x, board.y, cell_size * 5, cell_size * 5) then
            select_path = {}
            if not is_block then
                is_touch = true
                for i=1,5 do
                    for j=1,5 do
                        if is_collide(x, y, board.x + (j - 1) * cell_size, board.y + (i - 1) * cell_size, cell_size, cell_size) then
                            table.insert(select_path, {i, j})
                            if is_sound then sound_tile:play() end
                            break
                        end
                    end
                end
            end
        -- PASS BUTTON
        elseif (not is_show_history) and (not is_show_keyboard) then
            if #history > 0 and #history < 21 and count_pass < 2 then
                if player == 1 then
                    if is_collide(x, y, cell_size * 0.25, H - cell_size * 1.75, cell_size, cell_size * 0.5) then
                        press_button = "pass"
                    end
                elseif player == 2 then
                    if not is_bot then
                        if is_collide(x, y, W - cell_size * 1.25, H - cell_size * 1.75, cell_size, cell_size * 0.5) then
                            press_button = "pass"
                        end
                    end
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, cell_size * 0.25, cell_size * 0.25, cell_size, cell_size) then
        press_button = "history"
    elseif is_collide(x, y, W - cell_size * 1.25, cell_size * 0.25, cell_size, cell_size) then
        press_button = "menu"
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, board.x, board.y + cell_size * 0.5, cell_size * 5, cell_size) then
            press_button = "bot"
        elseif is_collide(x, y, board.x, board.y + cell_size * 1.5, cell_size * 5, cell_size) then
            press_button = "human"
        elseif is_collide(x, y, board.x, board.y + cell_size * 2.5, cell_size * 5, cell_size) then
            press_button = "about"
        elseif is_collide(x, y, board.x, board.y + cell_size * 3.5, cell_size * 5, cell_size) then
            press_button = "exit"
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 1.25, cell_size, cell_size) then
            press_button = "anim"
        elseif is_collide(x, y, W - cell_size * 1.25, H - cell_size * 1.25, cell_size, cell_size) then
            press_button = "sound"
        end
    end
    
    -- INFO
    if is_show_info then
        if is_collide(x, y, viewX, viewY, viewWidth, viewHeight) then
            isDragging = true
            startMouseY = y        -- Запоминаем, где была мышь в момент клика
            startScrollY = scrollY -- Запоминаем текущую прокрутку текста
        end
    end
end


function game.mousemoved( x, y, dx, dy, istouch )
    if is_touch and not is_block and not is_show_menu and not is_show_info then
        for i=1,5 do
            for j=1,5 do
                if is_collide(x, y, board.x + (j - 1) * cell_size, board.y + (i - 1) * cell_size, cell_size, cell_size) then
                    local is_select = false
                    
                    for _, rec in ipairs(select_path) do
                        if i == rec[1] and j == rec[2] then
                            is_select = true
                            break
                        end
                    end
                    
                    if not is_select then
                        table.insert(select_path, {i, j})
                        if is_sound then sound_tile:play() end
                    end
                    
                    break
                end
            end
        end
    end
end


function game.mousereleased( x, y, button, istouch, presses )
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        -- HISTORY
        if is_show_history then
            local count_history = 1
            for i=1,7 do
                for j=1,3 do
                        if is_collide(x, y, board.x + (j - 1) * cell_size * 5 / 3, board.y + (i - 1) * cell_size * 5 / 7, cell_size * 5 / 3, cell_size * 5 / 7) and press_button == "h" .. count_history then
                            if history[count_history] then
                                if is_sound then sound_click:play() end
                                info_text = dict[ history[count_history] ] or '...'
                                calculate_info()
                                is_show_info = true
                            end
                            break
                        end
                    
                    count_history = count_history + 1
                end
            end
        -- KEYBOARD
        elseif is_show_keyboard then
            -- Отмена
            if is_collide(x, y, board.x, board.y + cell_size * 4 / 5 * 4 + cell_size, cell_size * 2.5, cell_size * 4 / 5) and press_button == "cancel" then
                if is_sound then sound_click:play() end
                select_key = {}
                select_path = {}
                is_show_keyboard = false
                is_block = false
            
            -- Принять
            elseif is_collide(x, y, board.x + cell_size * 2.5, board.y + cell_size * 4 / 5 * 4 + cell_size, cell_size * 2.5, cell_size * 4 / 5) and press_button == "accept" then
                if #select_key > 0 then
                    local word = ""
                    for s=1,#select_path do
                        local char = matrix[ select_path[s][1] ][ select_path[s][2] ]
                        if char == "?" then char = alphabet[ select_key[1] ][ select_key[2] ] end
                        word = word .. char
                    end
                    
                    local result = dict[word]
                    if result then
                        local is_history = false
                        for _, rec in ipairs(history) do
                            if word == rec then
                                is_history = true
                            end
                        end
                        
                        if is_history then
                            love.system.vibrate(0.150)
                            if is_sound then sound_error:play() end
                            msg("Такое слово уже было!")
                        else
                            is_show_keyboard = false
                            if is_sound then sound_click:play() end
                            group:delay(function() update_matrix(word, select_path, player) end, 0.150)
                        end
                    else
                        love.system.vibrate(0.150)
                        if is_sound then sound_error:play() end
                        msg("Такого слова не найдено в словаре!")
                    end
                
                else
                    love.system.vibrate(0.150)
                    if is_sound then sound_error:play() end
                    msg("Выберите букву!")
                end
            end
        -- GAMEBOARD
        elseif not is_block and is_touch then
            is_block = true
            local count_empty = 0
            local is_correct = true
            
            for index, rec in ipairs(select_path) do
                if matrix[rec[1]][rec[2]] == '?' then
                    count_empty = count_empty + 1
                end
                if index > 1 then  -- проверка выделения прямым углом
                    if not ((select_path[index][1] == select_path[index - 1][1] and math.abs(select_path[index][2] - select_path[index - 1][2]) == 1) or (select_path[index][2] == select_path[index - 1][2] and math.abs(select_path[index][1] - select_path[index - 1][1]) == 1)) then
                        is_correct = false
                    end
                end
            end
            
            if #select_path >= 2 and count_empty == 1 and is_correct then
                group:delay(function() show_keyboard() end, 0.150)
            elseif #select_path == 1 then  -- тихая ошибка
                is_block = false
                select_path = {}
            else
                love.system.vibrate(0.150)
                if is_sound then sound_error:play() end
                msg("Выделите слово правильно!")
                is_block = false
                select_path = {}
            end
        -- PASS BUTTON
        elseif (not is_show_history) and (not is_show_keyboard) then
            if #history > 0 and #history < 21 and count_pass < 2 then
                if player == 1 then
                    if is_collide(x, y, cell_size * 0.25, H - cell_size * 1.75, cell_size, cell_size * 0.5) and press_button == "pass" then
                        count_pass = count_pass + 1
                        if #history == 1 then
                            if player == 1 then player = 2 else player = 1 end
                        end
                        if is_sound then sound_click:play() end
                        group:delay(function() after_move() end, 0.150)
                    end
                elseif player == 2 then
                    if not is_bot then
                        if is_collide(x, y, W - cell_size * 1.25, H - cell_size * 1.75, cell_size, cell_size * 0.5) and press_button == "pass" then
                            count_pass = count_pass + 1
                            if #history == 1 then
                                if player == 1 then player = 2 else player = 1 end
                            end
                            if is_sound then sound_click:play() end
                            group:delay(function() after_move() end, 0.150)
                        end
                    end
                end
            end
        end
    end

    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, cell_size * 0.25, cell_size * 0.25, cell_size, cell_size) and press_button == "history" then
        if is_sound then sound_click:play() end
        if not is_show_menu and not is_show_info then
            is_show_history = not is_show_history
        elseif is_show_info then
            is_show_info = false
        elseif is_show_menu then
            info_text = [[БУКВА
Игра на поле 5х5, клетки центральной строки которого содержат случайное слово из 5 букв. Игроки ходят по очереди. Во время хода игрок добавляет букву в пустую клетку, примыкающую по вертикали или горизонтали к заполненной клетке таким образом, чтобы получалась неразрывная и несамопересекающаяся прямоугольная линия, представляющая собой слово (имя существительное в именительном падеже и единственном числе или множественном числе, если слово не имеет единственного числа). Количество букв в слове добавляет очки игроку. Игрок может пропустить ход (если оба игрока подряд пропускают ход, то фиксируется конец игры). Слова в одной игре повторяться не могут. Побеждает игрок набравший больше очков!]]
            calculate_info()
            is_show_menu = false
            is_show_info = true
        end
    elseif is_collide(x, y, W - cell_size * 1.25, cell_size * 0.25, cell_size, cell_size) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_history = false
        is_show_menu = not is_show_menu
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, board.x, board.y + cell_size * 0.5, cell_size * 5, cell_size) and press_button == "bot" then
            if is_sound then sound_click:play() end
            is_block = true
            is_stop = true
            stop_thread()
            is_bot = true
            is_show_menu = false
            group:delay(function() new_game() end, 0.150)
        
        elseif is_collide(x, y, board.x, board.y + cell_size * 1.5, cell_size * 5, cell_size) and press_button == "human" then
            if is_sound then sound_click:play() end
            is_block = true
            is_stop = true
            stop_thread()
            is_bot = false
            is_show_menu = false
            group:delay(function() new_game() end, 0.150)
        
        elseif is_collide(x, y, board.x, board.y + cell_size * 2.5, cell_size * 5, cell_size) and press_button == "about" then
            if is_sound then sound_click:play() end
            info_text = [[ОБ ИГРЕ

Изображения: OpenMoji
openmoji.org

Язык Программирования Lua
lua.org

LÖVE Свободный 2D Игровой Движок
love2d.org

*  *  *

(c) 2026 Антон Бездольный
avbezdolny.github.io]]
            calculate_info()
            is_show_menu = false
            is_show_info = true
        
        elseif is_collide(x, y, board.x, board.y + cell_size * 3.5, cell_size * 5, cell_size) and press_button == "exit" then
            if is_sound then sound_click:play() end
            is_stop = true
            stop_thread()
            --group:delay(function() love.event.quit(0) end, 0.150)
            
            -- Возврат в лаунчер
            save_game()
            is_show_menu = false
            current_state = launcher
            current_state.load()
        
        elseif is_collide(x, y, cell_size * 0.25, H - cell_size * 1.25, cell_size, cell_size) and press_button == "anim" then
            if is_sound then sound_click:play() end
            is_anim = not is_anim
            anim_offset = 0
            anim_dir = 1
        
        elseif is_collide(x, y, W - cell_size * 1.25, H - cell_size * 1.25, cell_size, cell_size) and press_button == "sound" then
            is_sound = not is_sound
            if is_sound then sound_click:play() end
        end
    end

    is_touch = false
    isDragging = false
    press_button = ""
end


function game.wheelmoved(x, y)  -- Колесико мыши
    if y > 0 then
        scrollY = math.max(0, scrollY - scrollSpeed)
    elseif y < 0 then
        scrollY = math.min(maxScrollY, scrollY + scrollSpeed)
    end
end


function game.threaderror(thread, errorstr)  -- If not overwritten this callback will raise an error!
  if is_sound then sound_error:play() end
  love.system.vibrate(0.150)
  msg("Thread error! " .. (errorstr or "..."))
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
    save_game()
    return false
end


return game
