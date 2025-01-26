-- main.lua

-- Requer as bibliotecas
local lume = require "lume"
local suit = require "suit"

-- Variáveis globais
local world
local ground, ceiling
local boxes = {} -- Lista para armazenar as molas criadas
local mouseJoint -- O Joint que permite mover a mola com o mouse
local currentboxID = 0 -- ID único para cada mola criada
local destroyBox = {x = love.graphics.getWidth() - 120, y = 10, w = 100, h = 70} -- Caixa para destruir molas
-- Variáveis globais para as dimensões da mola
local boxWidth = 64
local boxHeight = 64
local springs = {}  -- Lista de molas
local lastMouseX, lastMouseY = love.mouse.getPosition()

function love.load()
    love.physics.setMeter(64) -- Define 1 metro como 64 pixels
    -- Configura o mundo físico
    
    world = love.physics.newWorld(0, 9.81 * 64, true) -- Gravidade padrão

    -- Cria o chão (estático)
    ground = love.physics.newBody(world, love.graphics.getWidth() / 2, love.graphics.getHeight() - 25, "static")
    local groundShape = love.physics.newRectangleShape(love.graphics.getWidth(), 20) -- Chão mais fino
    love.physics.newFixture(ground, groundShape)

    -- Cria o teto (estático)
    ceiling = love.physics.newBody(world, love.graphics.getWidth() / 2, 100, "static") -- Abaixa o teto
    local ceilingShape = love.physics.newRectangleShape(love.graphics.getWidth() * 0.8, 20) -- Teto menor que o canvas
    love.physics.newFixture(ceiling, ceilingShape)

    -- Inicializa o mouseJoint como nulo
    mouseJoint = nil
    
    -- Initialize mouse positions for tracking
    local mx, my = love.mouse.getPosition()
    lastMouseX, lastMouseY = mx, my
end

function love.update(dt)
    -- Atualiza o mundo físico
    world:update(dt)

    -- Atualiza a interface SUIT
    suit.layout:reset(10, 10)


    if suit.Button("Criar peso", suit.layout:row(200, 30)).hit then
       
        createbox()
    end

     suit.layout:row(200, 10)
        -- Verifica se o botão "Criar Mola" foi pressionado
    if suit.Button("Criar mola", suit.layout:row(200, 30)).hit then
        -- Cria a mola como um objeto dinâmico (retângulo)
        createSpring()
    end



    -- Atualiza o MouseJoint se houver uma mola sendo movida
    if mouseJoint then
        local mx, my = love.mouse.getPosition()
        
        -- Verifica se o mouse se moveu desde a última posição
        if mx ~= lastMouseX or my ~= lastMouseY then
            mouseJoint:setTarget(mx, my)  -- Atualiza a posição do mouse joint
            lastMouseX, lastMouseY = mx, my  -- Atualiza a última posição do mouse
        end
    end


    -- Verifique se a mola está presa ao teto e a extremidade está fixa
    for _, spring in ipairs(springs) do
        if spring.joint1 then
            spring.body1:setPosition(spring.body1:getX(), spring.body1:getY())  -- Manter a extremidade 1 fixa
        end

        if spring.joint2 then
            spring.body2:setPosition(spring.body2:getX(), spring.body2:getY())  -- A extremidade 2 pode continuar livre
        end
    end


    -- Calcula a força de cada mola
    for _, spring in ipairs(springs) do
        calculateSpringForce(spring)
    end

end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        -- Esquerdo: Criar um MouseJoint para mover a extremidade da mola
        for _, spring in ipairs(springs) do
            local x1, y1 = spring.body1:getPosition()
            local x2, y2 = spring.body2:getPosition()
            local distance1 = math.sqrt((x1 - x)^2 + (y1 - y)^2)
            local distance2 = math.sqrt((x2 - x)^2 + (y2 - y)^2)

            if distance1 < 15 then
                mouseJoint = love.physics.newMouseJoint(spring.body1, x, y)
                break
            elseif distance2 < 15 then
                mouseJoint = love.physics.newMouseJoint(spring.body2, x, y)
                break
            end
        end

                -- Se não clicou em nenhuma extremidade da mola, verificar se clicou em alguma caixa

        for _, box in ipairs(boxes) do
            local bx, by = box.body:getPosition()
              
                -- Verificar se o clique está dentro da caixa
            if x >= bx - boxWidth / 2 and x <= bx + boxWidth / 2 and y >= by - boxHeight / 2 and y <= by + boxHeight / 2 then
                    mouseJoint = love.physics.newMouseJoint(box.body, x, y) -- Passar box.body aqui
                    break
            end
        end



    elseif button == 2 then
        -- Direito: Fixar extremidade ao teto
        for _, spring in ipairs(springs) do
            local x1, y1 = spring.body1:getPosition()
            local x2, y2 = spring.body2:getPosition()


            if math.abs(y1 - ceiling:getY()) < 40 then
                local anchorX, anchorY = spring.body1:getPosition()
                local joint = love.physics.newDistanceJoint(spring.body1, ceiling, anchorX, anchorY, anchorX, ceiling:getY())
                joint:setFrequency(0)  -- Fixar sem elasticidade
                spring.joint1 = joint
            elseif math.abs(y2 - ceiling:getY()) < 40 then
                local anchorX, anchorY = spring.body2:getPosition()
                local joint = love.physics.newDistanceJoint(spring.body2, ceiling, anchorX, anchorY, anchorX, ceiling:getY())
                joint:setFrequency(0)
                spring.joint2 = joint
            end
        end
    end
end


function love.mousereleased(x, y, button, istouch, presses)
    -- Quando o mouse for liberado, remove o MouseJoint
    if button == 1 and mouseJoint then
        mouseJoint:destroy()
        mouseJoint = nil
        
        -- Verifica se a mola que estava sendo movida foi solta dentro da caixinha de destruição
        for _, box in ipairs(boxes) do
            local sx, sy = box.body:getPosition()
            local width, height = box.width, box.height
            
            -- Verifica se a mola está dentro da caixinha de destruição
            if sx > destroyBox.x and sx < destroyBox.x + destroyBox.w and sy > destroyBox.y and sy < destroyBox.y + destroyBox.h then
                chooseboxToDestroy(box.id) -- Marca a mola para ser destruída
                break
            end
        end
    end
end


function love.draw()
    -- Desenha o chão
    love.graphics.setColor(0.5, 1, 0.5) -- Cor verde para o chão
    love.graphics.polygon("fill", ground:getWorldPoints(ground:getFixtures()[1]:getShape():getPoints()))

    -- Desenha o teto
    love.graphics.setColor(1, 0.5, 0.5) -- Cor vermelha para o teto
    love.graphics.polygon("fill", ceiling:getWorldPoints(ceiling:getFixtures()[1]:getShape():getPoints()))

    -- Desenha os pesos
    for _, box in ipairs(boxes) do
        love.graphics.setColor(0.8, 0.8, 0) -- Cor amarela para o peso
        love.graphics.polygon("fill", box.body:getWorldPoints(box.shape:getPoints()))
    end
        -- Desenha as molas
    for _, spring in ipairs(springs) do
        local x1, y1 = spring.body1:getPosition()
        local x2, y2 = spring.body2:getPosition()

        love.graphics.setColor(0.8, 0.8, 0)  -- Cor amarela para as molas
        love.graphics.line(x1, y1, x2, y2)
        -- Desenha o contorno da hitbox das extremidades da mola (para visualização)
        love.graphics.setColor(1, 0.5, 0.5)  -- Cor preta para a borda
        love.graphics.circle("line", x1, y1, 10)  -- Para a extremidade 1
        love.graphics.setColor(0.5, 1, 0.5)  -- Cor preta para a borda
        love.graphics.circle("line", x2, y2, 10)  -- Para a extremidade 2
    end

    -- Desenha a caixinha de destruição
    love.graphics.setColor(1, 0, 0, 0.5) -- Cor semi-transparente para a caixinha
    love.graphics.rectangle("fill", destroyBox.x, destroyBox.y, destroyBox.w, destroyBox.h)

    -- Desenha a interface SUIT
    suit.draw()
end

function createSpring()
    local springID = #springs + 1
    local springLength = 100  -- Distância inicial entre as extremidades da mola
    local k = 10  -- Constante elástica (quanto maior, mais "rígida")
    
    -- Cria os dois corpos (extremidades da mola)
    local body1 = love.physics.newBody(world, love.graphics.getWidth() / 2 - springLength / 2, love.graphics.getHeight() / 2, "dynamic")
    local shape1 = love.physics.newCircleShape(10)  -- Forma circular para a extremidade
    local fixture1 = love.physics.newFixture(body1, shape1)
    
    local body2 = love.physics.newBody(world, love.graphics.getWidth() / 2 + springLength / 2, love.graphics.getHeight() / 2, "dynamic")
    local shape2 = love.physics.newCircleShape(10)  -- Forma circular para a extremidade
    local fixture2 = love.physics.newFixture(body2, shape2)

    -- Definir amortecimento angular
    body1:setAngularDamping(2)
    body2:setAngularDamping(2)
    
    --Adiciona um spring joint (mola) entre os dois corpos
    local spring = love.physics.newDistanceJoint(body1, body2, body1:getX(), body1:getY(), body2:getX(), body2:getY())
    spring:setDampingRatio(0.3)  -- Amortecimento para evitar oscilações abruptas
    spring:setFrequency(10)  -- Frequência da mola
    
    -- Armazena a mola
    table.insert(springs, {
        id = springID,
        body1 = body1,
        body2 = body2,
        joint = spring,
        restLength = springLength,  -- Distância inicial
        k = k,  -- Constante elástica
    })
end

function calculateSpringForce(spring)
    -- Calcula a distância entre os dois corpos da mola
    local x1, y1 = spring.body1:getPosition()
    local x2, y2 = spring.body2:getPosition()
    local distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)


    -- Força elástica (Lei de Hooke)
    local forceElastic = spring.k * (distance - spring.restLength)
    
    -- Forças gravitacionais (para cada extremidade da mola)
    local mass1 = spring.body1:getMass()
    local mass2 = spring.body2:getMass()
    local g = 9.81  -- Gravidade

    local forceGravity1 = mass1 * g
    local forceGravity2 = mass2 * g

    -- Calcula a diferença entre as forças elásticas e gravitacionais
    local forceDifference = math.abs(forceElastic - (forceGravity1 + forceGravity2))

    -- Verifica se a mola chegou ao equilíbrio (as forças se anulam)
    if forceDifference < 0.1 then
        -- A mola para de esticar, desacelera rapidamente
        spring.joint:setFrequency(0)  -- Não há mais oscilação
        spring.joint:setDampingRatio(1)  -- Máximo de amortecimento
    else
        -- Caso contrário, mantém a mola esticando
        spring.joint:setFrequency(5)  -- Valor ajustável conforme necessidade
        spring.joint:setDampingRatio(0.3)  -- Amortecimento moderado
    end
end


function createbox()
    currentboxID = currentboxID + 1
    local density = 1.0

    -- Cria o corpo da caixa (dinâmico)
    local boxBody = love.physics.newBody(world, love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, "dynamic")

    -- Define a forma da caixa
    local boxShape = love.physics.newRectangleShape(boxWidth, boxHeight)

    -- Cria a fixture da caixa com a forma e a densidade
    local boxFixture = love.physics.newFixture(boxBody, boxShape)
    boxFixture:setDensity(density)

    -- Adiciona a caixa na lista de caixas
    table.insert(boxes, {
        id = currentboxID,
        body = boxBody,
        shape = boxShape,
        fixture = boxFixture
    })
end



-- Função para escolher uma mola para destruição
function chooseboxToDestroy(boxID)
    for _, box in ipairs(boxes) do
        if box.id == boxID then
            destroybox(box.id)  -- Destrói a mola
            break
        end
    end
end

-- Função para destruir uma mola específica
function destroybox(boxID)
    if boxID then
        for i, box in ipairs(boxes) do
            if box.id == boxID then
                box.body:destroy() -- Destrói o corpo da mola
                table.remove(boxes, i) -- Remove da lista
                break
            end
        end
    end
end
