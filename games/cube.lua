local game = {}

local menori = require("modules/menori")
local tick = require("modules/tick")
local flux = require("modules/flux")
local lume = require("modules/lume")
local s = require("modules/say")

-- Menori API
local ml = menori.ml
local vec3 = ml.vec3
local quat = ml.quat
local camera
local environment
local root_node
local scene
local k = {x = 1, y = 1}
local select_box

-- colors
--local color_fg = {63/255, 63/255, 63/255}  -- #3f3f3f
--local color_button_press = {155/255, 155/255, 154/255}  -- #9b9b9a

-- images
local image_menu = love.graphics.newImage("images/gear.png")
local image_back = love.graphics.newImage("images/back.png")
local image_help = love.graphics.newImage("images/help.png")
local image_lang = love.graphics.newImage("images/lang.png")
local image_cube = love.graphics.newImage("images/icecube.png")
local image_random = love.graphics.newImage("images/random.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/door.png")
local image_fly = love.graphics.newImage("images/fly.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")
local image_red = love.graphics.newImage("images/red.png")
local image_orange = love.graphics.newImage("images/orange.png")
local image_blue = love.graphics.newImage("images/blue.png")
local image_green = love.graphics.newImage("images/green.png")
local image_white = love.graphics.newImage("images/white.png")
local image_yellow = love.graphics.newImage("images/yellow.png")

-- calculate
--local W = 1280
--local H = 720
local cell_size = 120  -- 720 / 6
local touch_path = 12
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 42 )

-- game
local is_block = true
local is_show_menu = false
local is_show_info = false
local group = tick.group()
local tween = flux.group()
local is_trace = false
local is_touch = false
local press_button = ""
local info_text = "Help text"
local win_text = ""

-- test
local vertices = {}

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_tween = love.audio.newSource("audio/rotate.ogg", "static")
local sound_popup = love.audio.newSource("audio/popup.ogg", "static")


-- Математическое округление
local function round(num, dp)
    dp = dp or 0 -- Если не указано количество знаков, округляем до целого (по умолчанию)
    local mult = 10 ^ dp
    return math.floor(num * mult + 0.5) / mult
end


-- Пересечение точки с прямоугольником
local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


-- Псевдоскалярное (векторное) произведение векторов (p1 -> p2) и (p1 -> p3)
-- Возвращает число. Знак числа определяет поворот
-- Положительное значение -> левый поворот
-- Отрицательное -> правый поворот
-- Ноль -> коллинеарность
local function cross_product(p1, p2, p3)
    return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
end


-- Функция сравнения для сортировки по полярному углу относительно точки p0
local function compare_points(p0)
    return function(a, b)
        local cross = cross_product(p0, a, b)
        if cross == 0 then
            -- Если угол одинаковый, оставляем ближайшую к p0
            return (a.x - p0.x)^2 + (a.y - p0.y)^2 < (b.x - p0.x)^2 + (b.y - p0.y)^2
        end
        return cross > 0 -- Сортируем по возрастанию угла
    end
end


-- Поиск выпуклой оболочки методом Грэхэма
local function convex_hull(points)
    if #points < 3 then return points end -- Выпуклый многоугольник требует >= 3 точек

    -- 1. Находим точку с минимальной y (и минимальной x при равенстве)
    local p0 = points[1]
    for i = 2, #points do
        if points[i].y < p0.y or (points[i].y == p0.y and points[i].x < p0.x) then
            p0 = points[i]
        end
    end

    -- 2. Сортируем точки по полярному углу относительно p0
    table.sort(points, compare_points(p0))

    -- 3. Строим оболочку с помощью стека
    local hull = {points[1], points[2]}
    for i = 3, #points do
        -- Пока последняя тройка точек делает не левый поворот, удаляем предпоследнюю точку из hull
        while #hull > 1 and cross_product(hull[#hull-1], hull[#hull], points[i]) <= 0 do
            table.remove(hull) -- Удаляем последнюю точку из стека
        end
        table.insert(hull, points[i]) -- Добавляем текущую точку в стек
    end

    return hull
end


-- Проверяет, находится ли точка 'point' внутри выпуклого многоугольника 'polygon'.
-- 'polygon' должен быть массивом вершин в порядке обхода (либо по часовой, либо против часовой стрелки).
-- Функция возвращает true, если точка внутри или на границе, и false, если снаружи.
local function is_point_in_convex_polygon(polygon, point)
    -- Сохраняем знак первого вычисленного произведения
    local prev_sign = nil

    -- Количество вершин в многоугольнике
    local n = #polygon

    -- Перебираем все рёбра многоугольника
    for i = 1, n do
        -- Находим текущую вершину и следующую за ней.
        -- Для последней вершины следующей будет первая (замыкаем контур)
        local v1 = polygon[i]
        local v2 = polygon[i % n + 1]

        -- Вычисляем векторное произведение для текущего ребра и проверяемой точки
        local cross = cross_product(v1, v2, point)

        -- Если точка лежит точно на ребре
        if cross == 0 then
            return true -- Точка на границе считается находящейся внутри
        end

        -- Определяем знак первого ненулевого произведения
        if prev_sign == nil then
            prev_sign = cross > 0 -- true для '+', false для '-'
        else
            -- Если знак текущего произведения не совпадает с первым знаком,
            -- значит точка находится по разные стороны от рёбер -> снаружи многоугольника
            if (cross > 0) ~= prev_sign then
                return false
            end
        end
    end

    -- Если мы прошли по всем рёбрам и знаки совпали, точка внутри
    return true
end


local function resize()
    --W = love.graphics.getWidth()
    --H = love.graphics.getHeight()
    
    if love.window.getFullscreen() then
        k = {x = 1, y = 1}
    else
        k = {x = W / 1280, y = H / 720}
    end

    cell_size = math.min(W / 6, H / 6)
    touch_path = cell_size / 10
    k_scale = cell_size / image_menu:getWidth()

    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.35 )
    game_font:setLineHeight( 0.8 )
    love.graphics.setFont(game_font)
    
    camera = menori.PerspectiveCamera(60, W/H, 0.5, 32)
    environment = menori.Environment(camera)
end


local function create_box(x, y, z)  -- передаем смещение для оси вращения
    local ox, oy, oz = x or 0, y or 0, z or 0
    
    local box_node = menori.Node('box')
    
    local front_side = menori.Box(1, 1, 0.00001)
    local right_side = menori.Box(0.00001, 1, 1)
    local top_side = menori.Box(1, 0.00001, 1)
    
    local marker_front_1 = menori.Node('marker')
    local marker_front_2 = menori.Node('marker')
    local marker_front_3 = menori.Node('marker')
    local marker_front_4 = menori.Node('marker')
    
    marker_front_1:set_position(-0.5, -0.5, 0)
    marker_front_2:set_position(0.5, -0.5, 0)
    marker_front_3:set_position(-0.5, 0.5, 0)
    marker_front_4:set_position(0.5, 0.5, 0)
    
    local marker_right_1 = menori.Node('marker')
    local marker_right_2 = menori.Node('marker')
    local marker_right_3 = menori.Node('marker')
    local marker_right_4 = menori.Node('marker')
    
    marker_right_1:set_position(0, -0.5, -0.5)
    marker_right_2:set_position(0, 0.5, -0.5)
    marker_right_3:set_position(0, -0.5, 0.5)
    marker_right_4:set_position(0, 0.5, 0.5)
    
    local marker_top_1 = menori.Node('marker')
    local marker_top_2 = menori.Node('marker')
    local marker_top_3 = menori.Node('marker')
    local marker_top_4 = menori.Node('marker')
    
    marker_top_1:set_position(-0.5, 0, -0.5)
    marker_top_2:set_position(0.5, 0, -0.5)
    marker_top_3:set_position(-0.5, 0, 0.5)
    marker_top_4:set_position(0.5, 0, 0.5)
    
    local red_node = menori.ModelNode(front_side)
    red_node.material.main_texture = image_red
    red_node:set_position(0 + ox, 0 + oy, 0.499995 + oz)
    red_node.name = 'side'
    red_node:attach(marker_front_1)
    red_node:attach(marker_front_2)
    red_node:attach(marker_front_3)
    red_node:attach(marker_front_4)
    
    local orange_node = menori.ModelNode(front_side)
    orange_node.material.main_texture = image_orange
    orange_node:set_position(0 + ox, 0 + oy, -0.499995 + oz)
    orange_node.name = 'side'
    orange_node:attach(marker_front_1:clone())
    orange_node:attach(marker_front_2:clone())
    orange_node:attach(marker_front_3:clone())
    orange_node:attach(marker_front_4:clone())
    
    local blue_node = menori.ModelNode(right_side)
    blue_node.material.main_texture = image_blue
    blue_node:set_position(0.499995 + ox, 0 + oy, 0 + oz)
    blue_node.name = 'side'
    blue_node:attach(marker_right_1)
    blue_node:attach(marker_right_2)
    blue_node:attach(marker_right_3)
    blue_node:attach(marker_right_4)
    
    local green_node = menori.ModelNode(right_side)
    green_node.material.main_texture = image_green
    green_node:set_position(-0.499995 + ox, 0 + oy, 0 + oz)
    green_node.name = 'side'
    green_node:attach(marker_right_1:clone())
    green_node:attach(marker_right_2:clone())
    green_node:attach(marker_right_3:clone())
    green_node:attach(marker_right_4:clone())
    
    local white_node = menori.ModelNode(top_side)
    white_node.material.main_texture = image_white
    white_node:set_position(0 + ox, 0.499995 + oy, 0 + oz)
    white_node.name = 'side'
    white_node:attach(marker_top_1)
    white_node:attach(marker_top_2)
    white_node:attach(marker_top_3)
    white_node:attach(marker_top_4)
    
    local yellow_node = menori.ModelNode(top_side)
    yellow_node.material.main_texture = image_yellow
    yellow_node:set_position(0 + ox, -0.499995 + oy, 0 + oz)
    yellow_node.name = 'side'
    yellow_node:attach(marker_top_1:clone())
    yellow_node:attach(marker_top_2:clone())
    yellow_node:attach(marker_top_3:clone())
    yellow_node:attach(marker_top_4:clone())
    
    box_node:attach(red_node)
    box_node:attach(orange_node)
    box_node:attach(blue_node)
    box_node:attach(green_node)
    box_node:attach(white_node)
    box_node:attach(yellow_node)

    box_node.center = vec3(ox, oy, oz)
    return box_node
end


local function create_cube2x2x2()
    local cube_node = menori.Node()

    local box1 = create_box(0.5, -0.5, 0.5)
    --box1:set_position(0.5, -0.5, 0.5)

    local box2 = create_box(-0.5, -0.5, 0.5)
    --box2:set_position(-0.5, -0.5, 0.5)

    local box3 = create_box(0.5, -0.5, -0.5)
    --box3:set_position(0.5, -0.5, -0.5)

    local box4 = create_box(-0.5, -0.5, -0.5)
    --box4:set_position(-0.5, -0.5, -0.5)

    local box5 = create_box(0.5, 0.5, 0.5)
    --box5:set_position(0.5, 0.5, 0.5)

    local box6 = create_box(-0.5, 0.5, 0.5)
    --box6:set_position(-0.5, 0.5, 0.5)

    local box7 = create_box(0.5, 0.5, -0.5)
    --box7:set_position(0.5, 0.5, -0.5)

    local box8 = create_box(-0.5, 0.5, -0.5)
    --box8:set_position(-0.5, 0.5, -0.5)

    cube_node:attach(box1)
    cube_node:attach(box2)
    cube_node:attach(box3)
    cube_node:attach(box4)
    cube_node:attach(box5)
    cube_node:attach(box6)
    cube_node:attach(box7)
    cube_node:attach(box8)

    return cube_node
end


local function after_start()
    root_node:traverse(function (n)
        if n.name == 'box' then
            n.rotation:normalize()
        end
    end)
    
    local cube = root_node.children[1]
    cube.rotation:normalize()
    
    is_block = false
end


local function new_game()
    is_block = true
    win_text = ""
    
    root_node:traverse(function (n)
        if n.name == 'box' then
            tween:to( n.rotation, 0.180, quat.from_euler_angles(0, 0, 0) )
        end
    end)

    local cube = root_node.children[1]
    tween:to( cube.rotation, 0.180, quat.from_euler_angles(math.rad(-30), math.rad(-35), math.rad(45)) )
    
    if is_sound then sound_tween:play() end
    group:delay(function() after_start() end, 0.200)
end


local function shuffle()
    is_block = true
    win_text = ""
    
    local nodes = {}
    root_node:traverse(function (n)
        if n.name == 'box' then
            n:set_rotation( quat.from_euler_angles(0, 0, 0) )
            table.insert(nodes, n)
        end
    end)

    if #nodes > 0 then
        local count_shuffle = 24
        
        while count_shuffle > 0 do
            count_shuffle = count_shuffle - 1
            
            -- Выбираем случайный узел
            local random_index = love.math.random(1, #nodes)
            local random_node = nodes[random_index]
            
            -- Выбираем случайную ось
            random_index = love.math.random(1, 3)
            local random_axis = 'x'
            if random_index == 2 then random_axis = 'y' elseif random_index == 3 then random_axis = 'z' end
            
            -- Выбираем случайное направление вращения
            random_index = love.math.random(1, 2)
            local random_dir = 1
            if random_index == 2 then random_dir = -1 end
            
            local r_box = random_node.rotation:clone()
            local r_center = r_box:multiply_vec3(random_node.center)
            r_center = vec3( round(r_center.x, 3), round(r_center.y, 3), round(r_center.z, 3) )
            
            if random_axis == 'x' then
                for i = 1, #nodes do
                    local n_box = nodes[i].rotation:clone()
                    local n_center = n_box:multiply_vec3(nodes[i].center)
                    n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                    
                    if n_center.x == r_center.x then
                        -- Понимаем куда направлена X и вращаем эту ось!
                        local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                        local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                        local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                        local dot = vec3(math.rad(90) * random_dir * dz.x, math.rad(90) * random_dir * dy.x, math.rad(90) * random_dir * dx.x)
                        nodes[i]:set_rotation( n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ) )
                    end
                end

            elseif random_axis == 'y' then
                for i = 1, #nodes do
                    local n_box = nodes[i].rotation:clone()
                    local n_center = n_box:multiply_vec3(nodes[i].center)
                    n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                    
                    if n_center.y == r_center.y then
                        -- Понимаем куда направлена Y и вращаем эту ось!
                        local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                        local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                        local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                        local dot = vec3(math.rad(90) * random_dir * dz.y, math.rad(90) * random_dir * dy.y, math.rad(90) * random_dir * dx.y)
                        nodes[i]:set_rotation( n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ) )
                    end
                end

            elseif random_axis == 'z' then
                for i = 1, #nodes do
                    local n_box = nodes[i].rotation:clone()
                    local n_center = n_box:multiply_vec3(nodes[i].center)
                    n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                    
                    if n_center.z == r_center.z then
                        -- Понимаем куда направлена Z и вращаем эту ось!
                        local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                        local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                        local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                        local dot = vec3(math.rad(90) * random_dir * dz.z, math.rad(90) * random_dir * dy.z, math.rad(90) * random_dir * dx.z)
                        nodes[i]:set_rotation( n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ) )
                    end
                end
            end
        end
    end
    
    for i = 1, #nodes do
        local i_box = nodes[i].rotation:clone()
        nodes[i]:set_rotation( quat.from_euler_angles(0, 0, 0) )
        tween:to( nodes[i].rotation, 0.180, i_box )
    end
    
    local cube = root_node.children[1]
    tween:to( cube.rotation, 0.180, quat.from_euler_angles(math.rad(-30), math.rad(-35), math.rad(45)) )
    
    if is_sound then sound_tween:play() end
    group:delay(function() after_start() end, 0.200)
end


local function save_game()
    local data = {}
    local nodes = {}
    local count_box = 1
    root_node:traverse(function (n)
        if n.name == 'box' then
            local key = count_box
            nodes[key] = n.rotation
            count_box = count_box + 1
        end
    end)
    data.nodes = nodes
    
    local serialized = lume.serialize(data)
    love.filesystem.write("cube", serialized)
end


function game.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("New cube", "New cube")
    s:set("Shuffle", "Shuffle")
    s:set("About", "About")
    s:set("Exit", "Exit")
    s:set("Complete", "Complete :)")
    s:set("Help text", [[CUBE

Virtual 3D Mini Rubik's Cube!

Rotate the cube in space by moving along the free part of the screen.

Move the faces of the cube by connecting the surfaces of the two elements.

The goal is to assemble the faces of a cube from elements of the same color.]])
    s:set("About text", [[ABOUT GAME

Images: OpenMoji
openmoji.org

The Programming Language Lua
lua.org

LÖVE 2D Game Engine
love2d.org

Menori 3D Library
rozenmad.github.io

(c) 2026 Anton Bezdolny
avbezdolny.github.io]])
    
    -- RU
    s:set_namespace("ru")
    s:set("New cube", "Новый куб")
    s:set("Shuffle", "Перемешать")
    s:set("About", "Об игре")
    s:set("Exit", "Выход")
    s:set("Complete", "Собран :)")
    s:set("Help text", [[КУБ

Виртуальный 3D Мини-Кубик-Рубика!

Вращайте куб в пространстве движениями по свободной части экрана.

Перемещайте грани куба соединяя поверхности двух элементов.

Цель собрать грани куба из элементов одного цвета.]])
    s:set("About text", [[ОБ ИГРЕ

Изображения: OpenMoji
openmoji.org

Язык Программирования Lua
lua.org

LÖVE 2D Игровой Движок
love2d.org

Menori 3D Библиотека
rozenmad.github.io

(c) 2026 Антон Бездольный
avbezdolny.github.io]])
    
    s:set_namespace(game_lang)
    
    resize()
    
    -- Menori 3D
    camera = menori.PerspectiveCamera(60, W/H, 0.5, 32)
    environment = menori.Environment(camera)
    root_node = menori.Node()
    scene = menori.Scene()
    
    local cube = create_cube2x2x2()
    root_node:attach(cube)
    
    -- load save data
    local data = nil
    
    local status, err = pcall( function()
        if love.filesystem.getInfo("cube") then
            local file = love.filesystem.read("cube")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local angles = {}
        
        local ok, msg = pcall( function()
            local nodes = data.nodes
            if #nodes == 8 then
                for k, v in pairs(nodes) do
                    -- quat x, y, z, w
                    if (v.x >= 0 or v.x < 0) and (v.y >= 0 or v.y < 0) and (v.z >= 0 or v.z < 0) and (v.w >= 0 or v.w < 0) then
                        angles[k] = quat():set(v.x, v.y, v.z, v.w)
                    else
                        error("Incorrect save data!")
                    end
                end
            else
                error("Incorrect save data!")
            end
            
        end )

        if ok then  -- при выполнении защищенного кода ошибок нет
            local count_box = 1
            root_node:traverse(function (n)
                if n.name == 'box' then
                    tween:to( n.rotation, 0.180, angles[count_box] )
                    count_box = count_box + 1
                end
            end)
            
            tween:to( cube.rotation, 0.180, quat.from_euler_angles(math.rad(-30), math.rad(-35), math.rad(45)) )
            
            if is_sound then sound_tween:play() end
            group:delay(function() after_start() end, 0.200)
        
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
    
    scene:update_nodes(root_node, environment)
    local zoom = 4.0
    if H > W then zoom = 6.0 end
    local q = quat.from_euler_angles(0, 0, 0) * vec3.unit_z * zoom
    local v = vec3(0, 0, 0)
    camera.center = v
    camera.eye = q + v
    camera:update_view_matrix()
end


local function render_comp(a, b)
    return a:get_world_position().z < b:get_world_position().z
end


function game.draw()
    love.graphics.setFont(game_font)
    
    -- ИГРОВОЕ ПОЛЕ
    if not is_show_menu and not is_show_info then
        love.graphics.setColor(1, 1, 1, 1)
        scene:render_nodes(root_node, environment, {
            --node_sort_comp = menori.Scene.alpha_mode_comp
            --node_sort_comp = menori.Scene.layer_comp
            node_sort_comp = render_comp
        })
        
        -- test
        --[[if #vertices > 0 then
            love.graphics.setColor(179/255, 153/255, 200/255, 1)
            love.graphics.setLineWidth(touch_path)
            love.graphics.polygon('line', vertices)
        end]]
        
        love.graphics.setColor(179/255, 153/255, 200/255, 1)
        love.graphics.printf(win_text, touch_path, H - cell_size * 0.35 - touch_path * 2, W, "center")
    end
    
    -- КНОПКИ ОСНОВНЫЕ
    local bcolor = {1, 1, 1, 0.5}
    if press_button == "menu" then bcolor = color_button_press end
    draw_button(W - cell_size - touch_path + cell_size * 0.032, touch_path + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    bcolor = {1, 1, 1, 0.5}
    if press_button == "help" then bcolor = color_button_press end
    draw_button(touch_path + cell_size * 0.032, touch_path + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
    
    love.graphics.setColor(1, 1, 1, 1)
    if is_show_menu then
        love.graphics.draw(image_back, W - cell_size - touch_path, touch_path, 0, k_scale, k_scale)
        love.graphics.draw(image_lang, touch_path, touch_path, 0, k_scale, k_scale)
    else
        love.graphics.draw(image_menu, W - cell_size - touch_path, touch_path, 0, k_scale, k_scale)
        if not is_show_info then
            love.graphics.draw(image_help, touch_path, touch_path, 0, k_scale, k_scale)
        else
            love.graphics.draw(image_back, touch_path, touch_path, 0, k_scale, k_scale)
        end
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if press_button == "new" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(W * 0.5 - cell_size * 2 + cell_size * 0.032, H * 0.5 - cell_size * 2 + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "random" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(W * 0.5 - cell_size * 2 + cell_size * 0.032, H * 0.5 - cell_size + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "about" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(W * 0.5 - cell_size * 2 + cell_size * 0.032, H * 0.5 + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "exit" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(W * 0.5 - cell_size * 2 + cell_size * 0.032, H * 0.5 + cell_size + cell_size * 0.032, cell_size * 4 - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image_cube, W * 0.5 - cell_size * 2, H * 0.5 - cell_size * 2, 0, k_scale, k_scale)
        love.graphics.draw(image_random, W * 0.5 - cell_size * 2, H * 0.5 - cell_size, 0, k_scale, k_scale)
        love.graphics.draw(image_about, W * 0.5 - cell_size * 2, H * 0.5, 0, k_scale, k_scale)
        love.graphics.draw(image_exit, W * 0.5 - cell_size * 2, H * 0.5 + cell_size, 0, k_scale, k_scale)
        
        love.graphics.setColor(color_fg)
        love.graphics.printf(s("New cube"), W * 0.5 - cell_size * 1.75, H * 0.5 - cell_size * 1.75, cell_size * 4, "center")
        love.graphics.printf(s("Shuffle"), W * 0.5 - cell_size * 1.75, H * 0.5 - cell_size * 0.75, cell_size * 4, "center")
        love.graphics.printf(s("About"), W * 0.5 - cell_size * 1.75, H * 0.5 + cell_size * 0.25, cell_size * 4, "center")
        love.graphics.printf(s("Exit"), W * 0.5 - cell_size * 1.75, H * 0.5 + cell_size * 1.25, cell_size * 4, "center")
        
        if press_button == "sound" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(W - cell_size - touch_path + cell_size * 0.032, H - cell_size - touch_path + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        if press_button == "anim" then bcolor = color_button_press else bcolor = {1, 1, 1, 0.5} end
        draw_button(touch_path + cell_size * 0.032, H - cell_size - touch_path + cell_size * 0.032, cell_size - cell_size * 0.064, cell_size - cell_size * 0.064, bcolor)
        
        love.graphics.setColor(1, 1, 1, 1)
        if is_sound then love.graphics.draw(image_sound, W - cell_size - touch_path, H - cell_size - touch_path, 0, k_scale, k_scale) else love.graphics.draw(image_mute, W - cell_size - touch_path, H - cell_size - touch_path, 0, k_scale, k_scale) end
        if is_anim then love.graphics.draw(image_fly, touch_path, H - cell_size - touch_path, 0, k_scale, k_scale) else love.graphics.draw(image_stop, touch_path, H - cell_size - touch_path, 0, k_scale, k_scale) end
    end

    -- ИНФО
    if is_show_info then
        love.graphics.setColor(color_fg)
        love.graphics.printf(s(info_text), W * 0.5 - cell_size * 3, H * 0.5 - cell_size * 3, cell_size * 6, "center")
    end

end


function game.keypressed(key, scancode, isrepeat)  -- love.keyreleased( key, scancode )
    if key == "escape" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    end
end


local function touch_box(mouse_x, mouse_y)
    vertices = {}  -- test
    local z_coord = -1000000
    local t_box
    local t_side
    
    root_node:traverse(function (node_box)
        if node_box.name == 'box' then
            
            node_box:traverse(function (node_side)
                if node_side.name == 'side' then
                    
                    local matrix = {}
                    
                    node_side:traverse(function (node_marker)
                        if node_marker.name == 'marker' then
                            
                            local xy = camera:world_to_screen_point( node_marker:get_world_position() )
                            xy.x = round(xy.x) * k.x
                            xy.y = round(xy.y) * k.y
                            table.insert(matrix, xy)
                        
                        end
                    end)
                    
                    table.sort(matrix, function(a, b) return tostring(a.x) .. '-' .. tostring(a.y) < tostring(b.x) .. '-' .. tostring(b.y) end)
                    
                    -- Вершины выпуклого многоугольника
                    local hull = convex_hull(matrix)
                    
                    local pt = {['x'] = mouse_x, ['y'] = mouse_y}
                    local inside = is_point_in_convex_polygon(hull, pt)
                    
                    if inside and node_side:get_world_position().z > z_coord then  -- Оставить только полигон с большей word координатой Z
                        z_coord = node_side:get_world_position().z
                        t_box = node_box
                        t_side = node_side
                        
                        vertices = {}  -- test
                        for _, v in ipairs(hull) do
                            table.insert(vertices, v.x)
                            table.insert(vertices, v.y)
                        end
                    end
                    
                end
            end)
        end
    end)
    
    return t_box, t_side
end


function after_rotate()
    local r = {}
    local is_complete = true
    
    root_node:traverse(function (n)
        if n.name == 'box' then
            n.rotation:normalize()
            local c = n.rotation:clone()
            table.insert( r, { x = round(c.x, 3), y = round(c.y, 3), z = round(c.z, 3), w = round(c.w, 3) } )
        end
    end)
    
    if #r > 2 then
        for i = 1, #r - 1 do
            if not ( ( r[i].x == r[i+1].x and r[i].y == r[i+1].y and r[i].z == r[i+1].z and r[i].w == r[i+1].w ) or ( r[i].x == -r[i+1].x and r[i].y == -r[i+1].y and r[i].z == -r[i+1].z and r[i].w == -r[i+1].w ) ) then is_complete = false end
        end
    end
    
    if is_complete then
        if is_sound then sound_popup:play() end
        win_text = s("Complete")
    else
        win_text = ""
    end
    
    is_block = false
end


function game.mousepressed( x, y, button, istouch, presses )
    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, W - cell_size - touch_path, touch_path, cell_size, cell_size) then
        press_button = "menu"
    
    elseif is_collide(x, y, touch_path, touch_path, cell_size, cell_size) then
        press_button = "help"
    
    -- ИГРОВОЕ ПОЛЕ
    elseif not is_show_menu and not is_show_info then
        local select_side
        select_box, select_side = touch_box(x, y)
        
        if select_box and select_side and not is_block then is_touch = true end
        
        if not is_touch then is_trace = true end
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, W - cell_size - touch_path, H - cell_size - touch_path, cell_size, cell_size) then
            press_button = "sound"
        
        elseif is_collide(x, y, touch_path, H - cell_size - touch_path, cell_size, cell_size) then
            press_button = "anim"
        
        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 - cell_size * 2, cell_size * 4, cell_size) then
            press_button = "new"

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 - cell_size, cell_size * 4, cell_size) then
            press_button = "random"

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5, cell_size * 4, cell_size) then
            press_button = "about"

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 + cell_size, cell_size * 4, cell_size) then
            press_button = "exit"
        end
    end
end


function game.mousereleased( x, y, button, istouch, presses )
    -- КНОПКИ ОСНОВНЫЕ
    if is_collide(x, y, W - cell_size - touch_path, touch_path, cell_size, cell_size) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_info = false
        is_show_menu = not is_show_menu
    
    elseif is_collide(x, y, touch_path, touch_path, cell_size, cell_size) and press_button == "help" then
        if is_sound then sound_click:play() end
        if is_show_menu then
            if game_lang == "en" then game_lang = "ru" else game_lang = "en" end
            s:set_namespace(game_lang)
            if win_text ~= "" then win_text = s("Complete") end
        elseif is_show_info then
            is_show_info = false
        else
            info_text = "Help text"
            is_show_info = true
        end
    end

    -- КНОПКИ МЕНЮ
    if is_show_menu then
        if is_collide(x, y, W - cell_size - touch_path, H - cell_size - touch_path, cell_size, cell_size) and press_button == "sound" then
            is_sound = not is_sound
            if is_sound then sound_click:play() end
        
        elseif is_collide(x, y, touch_path, H - cell_size - touch_path, cell_size, cell_size) and press_button == "anim" then
            if is_sound then sound_click:play() end
            is_anim = not is_anim
        
        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 - cell_size * 2, cell_size * 4, cell_size) and press_button == "new" then
            if is_sound then sound_click:play() end
            is_show_menu = false
            new_game()

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 - cell_size, cell_size * 4, cell_size) and press_button == "random" then
            if is_sound then sound_click:play() end
            is_show_menu = false
            shuffle()

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5, cell_size * 4, cell_size) and press_button == "about" then
            if is_sound then sound_click:play() end
            info_text = "About text"
            is_show_menu = false
            is_show_info = true

        elseif is_collide(x, y, W * 0.5 - cell_size * 2, H * 0.5 + cell_size, cell_size * 4, cell_size) and press_button == "exit" then
            if is_sound then sound_click:play() end
            --group:delay(function() love.event.quit(0) end, 0.200)
            
            -- Возврат в лаунчер
            save_game()
            is_show_menu = false
            current_state = launcher
            current_state.load()
        end
    end

    press_button = ""
    select_box = nil
    is_trace = false
    is_touch = false
end


function game.mousemoved( x, y, dx, dy, istouch )
    if is_touch then
        local over_box, over_side = touch_box(x, y)
        
        if over_box and over_side and not (over_box.center.x == select_box.center.x and over_box.center.y == select_box.center.y and over_box.center.z == select_box.center.z) and (math.abs(dx) >= touch_path or math.abs(dy) >= touch_path) then
            is_touch = false
            local dir = 1
            
            local o_box = over_box.rotation:clone()
            local o_center = o_box:multiply_vec3(over_box.center)
            o_center = vec3( round(o_center.x, 3), round(o_center.y, 3), round(o_center.z, 3) )
            local select_side = o_box:multiply_vec3(over_side.position)  -- показывает по какой оси активная грань
            
            local s_box = select_box.rotation:clone()
            local s_center = s_box:multiply_vec3(select_box.center)
            s_center = vec3( round(s_center.x, 3), round(s_center.y, 3), round(s_center.z, 3) )
            
            local nodes = {}
            root_node:traverse(function (n)
                if n.name == 'box' then
                    table.insert(nodes, n)
                end
            end)

            if #nodes > 0 then
                if o_center.x == s_center.x and o_center.y == s_center.y then  -- rotate XY
                    if math.abs(select_side.x) > math.abs(select_side.y) and math.abs(select_side.x) > math.abs(select_side.z) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.z - s_center.z) * o_center.x > 0 then dir = -1 else dir = 1 end
                            
                            if n_center.y == o_center.y then
                                -- Понимаем куда направлена Y и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.y, math.rad(90) * dir * dy.y, math.rad(90) * dir * dx.y)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    
                    elseif math.abs(select_side.y) > math.abs(select_side.x) and math.abs(select_side.y) > math.abs(select_side.z) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.z - s_center.z) * o_center.y < 0 then dir = -1 else dir = 1 end
                            
                            if n_center.x == o_center.x then
                                -- Понимаем куда направлена X и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.x, math.rad(90) * dir * dy.x, math.rad(90) * dir * dx.x)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    end
                
                elseif o_center.x == s_center.x and o_center.z == s_center.z then -- rotate XZ
                    
                    if math.abs(select_side.x) > math.abs(select_side.y) and math.abs(select_side.x) > math.abs(select_side.z) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.y - s_center.y) * o_center.x < 0 then dir = -1 else dir = 1 end
                            
                            if n_center.z == o_center.z then
                                -- Понимаем куда направлена Z и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.z, math.rad(90) * dir * dy.z, math.rad(90) * dir * dx.z)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    
                    elseif math.abs(select_side.z) > math.abs(select_side.x) and math.abs(select_side.z) > math.abs(select_side.y) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.y - s_center.y) * o_center.z > 0 then dir = -1 else dir = 1 end
                            
                            if n_center.x == o_center.x then
                                -- Понимаем куда направлена X и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.x, math.rad(90) * dir * dy.x, math.rad(90) * dir * dx.x)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    end
                
                elseif o_center.z == s_center.z and o_center.y == s_center.y then  -- rotate ZY
                    
                    if math.abs(select_side.z) > math.abs(select_side.x) and math.abs(select_side.z) > math.abs(select_side.y) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.x - s_center.x) * o_center.z < 0 then dir = -1 else dir = 1 end
                            
                            if n_center.y == o_center.y then
                                -- Понимаем куда направлена Y и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.y, math.rad(90) * dir * dy.y, math.rad(90) * dir * dx.y)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    
                    elseif math.abs(select_side.y) > math.abs(select_side.x) and math.abs(select_side.y) > math.abs(select_side.z) then
                        for i = 1, #nodes do
                            local n_box = nodes[i].rotation:clone()
                            local n_center = n_box:multiply_vec3(nodes[i].center)
                            n_center = vec3( round(n_center.x, 3), round(n_center.y, 3), round(n_center.z, 3) )
                            if (o_center.x - s_center.x) * o_center.y > 0 then dir = -1 else dir = 1 end
                            
                            if n_center.z == o_center.z then
                                -- Понимаем куда направлена Z и вращаем эту ось!
                                local dx = n_box:multiply_vec3( vec3(1, 0, 0) )
                                local dy = n_box:multiply_vec3( vec3(0, 1, 0) )
                                local dz = n_box:multiply_vec3( vec3(0, 0, 1) )
                                local dot = vec3(math.rad(90) * dir * dz.z, math.rad(90) * dir * dy.z, math.rad(90) * dir * dx.z)
                                
                                tween:to(nodes[i].rotation, 0.180, n_box:mul( quat.from_euler_angles(dot.x, dot.y, dot.z) ))
                                is_block = true
                            end
                        end
                    end
                end
            end
            
            if is_block then
                if is_sound then sound_tween:play() end
                group:delay(function() after_rotate() end, 0.200)
            end
        end
    
    elseif is_trace then
        local cube = root_node.children[1]
        local q_cube = cube.rotation
        local q_mouse = quat.from_euler_angles(math.rad(0), math.rad(dx), math.rad(dy))
        cube:set_rotation(q_mouse:mul(q_cube))
        cube.rotation:normalize()
    end
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
