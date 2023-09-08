local requiredSpeed = 80
local isOverlayVisible = false -- Variável para controlar a visibilidade do overlay

-- Esta função é chamada antes de o evento ser ativado. Uma vez que ela retorna true, o overlay será exibido:
function script.prepare(dt)
    ac.debug("speed", ac.getCarState(1).speedKmh)
    return ac.getCarState(1).speedKmh > 60
end

-- ... O código restante do seu script ...

-- Função para alternar a visibilidade do overlay quando o botão é clicado
local function toggleOverlay()
    isOverlayVisible = not isOverlayVisible
end

-- Função para verificar se o mouse está sobre o overlay
local function isMouseOverOverlay(mouseX, mouseY)
    local uiState = ac.getUiState()
    local overlayPosition = vec2(100, 100) -- A posição do overlay
    local overlaySize = vec2(400 * 0.5, 400 * 0.5) -- O tamanho do overlay

    return (
        mouseX >= overlayPosition.x and
        mouseX <= overlayPosition.x + overlaySize.x and
        mouseY >= overlayPosition.y and
        mouseY <= overlayPosition.y + overlaySize.y
    )
end

function script.drawUI()
    -- Verifique se o mouse está sobre o overlay
    local uiState = ac.getUiState()
    local mouseX, mouseY = uiState.mousePos.x, uiState.mousePos.y

    -- Se o mouse estiver sobre o overlay, mostre-o
    if isMouseOverOverlay(mouseX, mouseY) then
        isOverlayVisible = true
    else
        -- Caso contrário, torne o overlay transparente
        isOverlayVisible = false
    end

    -- Desenhe o botão para abrir/fechar o overlay
    if ui.button("Toggle Overlay", ui.ButtonStyle.Default, vec2(10, 10), vec2(100, 30)) then
        toggleOverlay()
    end

    -- Verifique se o overlay deve ser exibido
    if isOverlayVisible then
        -- Desenhe o overlay aqui
        -- Certifique-se de desenhar os elementos do overlay dentro deste bloco
        -- para que eles sejam exibidos apenas quando o overlay estiver visível

        ui.beginTransparentWindow("overtakeScore", vec2(100, 100), vec2(400 * 0.5, 400 * 0.5))
        ui.beginOutline()

        -- ... Resto do seu código do overlay ...

        ui.endTransparentWindow()
    end
end
-- Event state:
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0

function script.update(dt)
    if timePassed == 0 then
        addMessage("Let’s go!", 0)
    end

    local player = ac.getCarState(1)
    if player.engineLifeLeft < 1 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            ac.sendChatMessage("scored " .. totalScore .. " points.")
        end
        totalScore = 0
        comboMeter = 1
        return
    end

    timePassed = timePassed + dt

    local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

    local sim = ac.getSimState()
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = {}
    end

    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        if wheelsWarningTimeout == 0 then
        end
        addMessage("Car is outside", -1)
        wheelsWarningTimeout = 60
    end

    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 3 then
            if totalScore > highestScore then
                highestScore = math.floor(totalScore)
                ac.sendChatMessage("scored " .. totalScore .. " points.")
            end
            totalScore = 0
            comboMeter = 1
        else
            if dangerouslySlowTimer == 0 then
                addMessage("Too slow!", -1)
            end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        return
    else
        dangerouslySlowTimer = 0
    end

    for i = 1, ac.getSimState().carsCount do
        local car = ac.getCarState(i)
        local state = carsState[i]

        if car.pos:closerToThan(player.pos, 10) then
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
                    state.nearMiss = true

                    if car.pos:closerToThan(player.pos, 2.5) then
                        comboMeter = comboMeter + 3
                        addMessage("Very close near miss!", 1)
                    else
                        comboMeter = comboMeter + 1
                        addMessage("Near miss: bonus combo", 0)
                    end
                end
            end

            if car.collidedWith == 0 then
                addMessage("Collision", -1)
                state.collided = true

                if totalScore > highestScore then
                    highestScore = math.floor(totalScore)
                    ac.sendChatMessage("scored " .. totalScore .. " points.")
                end
                totalScore = 0
                comboMeter = 1
            end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.pos - player.pos):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                    totalScore = totalScore + math.ceil(10 * comboMeter)
                    comboMeter = comboMeter + 1
                    comboColor = comboColor + 90
                    addMessage("Overtake", comboMeter > 20 and 1 or 0)
                    state.overtaken = true
                end
            end
        else
            state.maxPosDot = -1
            state.overtaken = false
            state.collided = false
            state.drivingAlong = true
            state.nearMiss = false
        end
    end
end

-- Restante do código permanece inalterado
-- ... (Código da UI semelhante ao fornecido anteriormente)

function script.drawUI()
    local uiState = ac.getUiState()
    updateMessages(uiState.dt)

    if showOvertakeWindow then
        ui.beginTransparentWindow("overtakeScore", vec2(100, 100), vec2(400 * 0.5, 400 * 0.5))
        ui.beginOutline()

        -- ... (Restante do código da UI)

        ui.popFont()
        ui.setCursor(startPos + vec2(0, 4 * 30))

        ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
        ui.setCursorY(0)
        ui.pushFont(ui.Font.Main)
        ui.textColored("Keep speed above " .. requiredSpeed .. " km/h:", colorAccent)
        speedMeter(ui.getCursor() + vec2(-9 * 0.5, 4 * 0.2))

        ui.popFont()
        ui.popStyleVar()

        if ui.button("Fechar", vec2(20, 20), vec2(60, 30)) then
            showOvertakeWindow = false
        end

        ui.endTransparentWindow()
    end
end
