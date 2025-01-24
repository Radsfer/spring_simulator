local suit = require("suit")
local windfield = require("windfield")

local world
local molas = {} -- Tabela para armazenar as molas
local bases = {} -- Tabela para armazenar as bases
local dragging = nil -- Objeto que está sendo arrastado
local offsetX, offsetY = 0, 0 -- Deslocamento do mouse em relação ao objeto
local gravity = 500 -- Aceleração devido à gravidade
local floorY = love.graphics.getHeight() - 50 -- Definir o chão a 50 pixels da parte inferior da tela
local trash = {} -- Lixeira

function love.load()
    -- Cria o mundo físico
    world = windfield.newWorld(0, gravity) -- Configura o mundo com gravidade

    -- Configurações de colisão
    world:addCollisionClass("Apagar")
    world:addCollisionClass("Mola")
    world:addCollisionClass("Base")

    -- Chão
    local floor = world:newRectangleCollider(0, floorY, love.graphics.getWidth(), 50)
    floor:setType("static")

    -- Lixeira
    trash.body = world:newRectangleCollider(550, 30, 200, 60)
    trash.body:setCollisionClass("Apagar")
    trash.body:setType("static")
end

-- Função para verificar se o mouse está sobre um objeto
local function isMouseOverObject(obj, width, height)
    local mouseX, mouseY = love.mouse.getPosition()
    return mouseX >= obj:getX() - width / 2
        and mouseX <= obj:getX() + width / 2
        and mouseY >= obj:getY() - height / 2
        and mouseY <= obj:getY() + height / 2
end

function love.update(dt)
    world:update(dt) -- Atualiza o mundo físico
    suit.layout:reset(50, 50)

    -- Botão para criar molas
    if suit.Button("Criar Mola", suit.layout:row(200, 30)).hit then
        local x, y = love.mouse.getPosition()
        local largura = 20
        local altura = 20

        -- Criação da mola
        local mola = {}
        mola.fixo = world:newRectangleCollider(x, y, 10, altura)
        mola.fixo:setCollisionClass("Mola")
        mola.fixo:setType("dynamic") -- Agora é dinâmico

        mola.movel = world:newRectangleCollider(x + largura - 10, y, 10, altura)
        mola.movel:setCollisionClass("Mola")
        mola.movel:setType("dynamic")

        mola.joint = world:addJoint('DistanceJoint', mola.fixo, mola.movel, x + largura / 2, y, x + largura / 2, y)
        mola.joint:setLength(largura)
        mola.joint:setFrequency(4)
        mola.joint:setDampingRatio(0.5)

        mola.width = largura
        mola.height = altura
        table.insert(molas, mola)
    end

    -- Botão para criar bases
    if suit.Button("Criar Base", suit.layout:row(200, 30)).hit then
        local x, y = love.mouse.getPosition()
        local base = world:newRectangleCollider(x, y, 30, 30)
        base:setCollisionClass("Base")
        base:setType("static")
        table.insert(bases, base)
    end

    -- Verifica se o mouse está pressionado sobre uma mola ou base para arrastar
    if love.mouse.isDown(1) and dragging then
        local mouseX, mouseY = love.mouse.getPosition()
        dragging:setPosition(mouseX - offsetX, mouseY - offsetY)
    elseif love.mouse.isDown(1) then
        local mouseX, mouseY = love.mouse.getPosition()

        -- Checa se está arrastando uma base
        for _, base in ipairs(bases) do
            if isMouseOverObject(base, 30, 30) then
                dragging = base
                offsetX = mouseX - base:getX()
                offsetY = mouseY - base:getY()
                break
            end
        end

        -- Checa se está arrastando uma mola
        if not dragging then
            for _, mola in ipairs(molas) do
                if isMouseOverObject(mola.fixo, 10, 20) then
                    dragging = mola.fixo
                    offsetX = mouseX - mola.fixo:getX()
                    offsetY = mouseY - mola.fixo:getY()
                    break
                elseif isMouseOverObject(mola.movel, 10, 20) then
                    dragging = mola.movel
                    offsetX = mouseX - mola.movel:getX()
                    offsetY = mouseY - mola.movel:getY()
                    break
                end
            end
        end
    elseif not love.mouse.isDown(1) then
        dragging = nil
    end

    -- Verifica se a mola foi solta sobre a lixeira
    for i = #molas, 1, -1 do
        local mola = molas[i]
        local function isInsideTrash(obj)
            local x, y = obj:getX(), obj:getY()
            local trashX, trashY = trash.body:getX(), trash.body:getY()
            local trashWidth, trashHeight = 200, 60
            return x > trashX - trashWidth / 2 and x < trashX + trashWidth / 2
                and y > trashY - trashHeight / 2 and y < trashY + trashHeight / 2
        end

        if isInsideTrash(mola.fixo) or isInsideTrash(mola.movel) then
            mola.fixo:destroy()
            mola.movel:destroy()
            table.remove(molas, i)
        end
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0, 0, 0) -- Fundo preto

    -- Desenha o chão
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.line(0, floorY, love.graphics.getWidth(), floorY)

    -- Desenha as bases
    love.graphics.setColor(0, 0, 1) -- Azul para as bases
    for _, base in ipairs(bases) do
        love.graphics.rectangle("fill", base:getX() - 15, base:getY() - 15, 30, 30)
    end

    -- Desenha os widgets SUIT e objetos físicos
    suit.draw()
    world:draw()

    -- Desenha a lixeira
    love.graphics.setColor(1, 0, 0) -- Vermelho para a lixeira
    love.graphics.rectangle("line", trash.body:getX() - 100, trash.body:getY() - 30, 200, 60)
end
