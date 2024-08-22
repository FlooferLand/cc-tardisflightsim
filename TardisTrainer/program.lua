local lib = require("library")
local theme = require("theme")
local audio = require("audio")
local eventTraining = require("eventTraining")
local nimg = require('lib.nimg')
local json = require('lib.json')

local pages = {
    Title = 0,
    Tutorial = 1,
    Command = 2,
    SelectThrottle = 3,
    EventTraining = 4,
    FlightSim = 5
}

--- Contains all program functions
local program = {
    config = {
        firstTimeSetup = true,
        theme = "generic",

        music = true,
        flightSound = true,
        temporalAdditions = true,
        limitedTime = true
    },
    devices = {
        monitors = { term.current(), peripheral.find("monitor") },  -- TODO: Find some way to add peripheral.find("monitor") and multi-monitor support
        speakers = { peripheral.find("speaker") }
    },
    low = {  -- Low-end system stuff
        running = true,
        holdingCtrl = false,
        holdingShift = false,
        deltaTime = 0.0
    },
    state = {
        page = pages.Title,
        throttle = 0,
        activeTemporalEvent = nil,
        currentGuess = "",
        currentScore = 0
    },
    drawState = {
        repositionStars = 0,
        starsPos = {},
        tardisSpin = 0,
    },
    timers = {
        askNext = nil,
        drawTardisSpin = nil,
        drawStars = nil
    },
    assets = {
        themeSong = audio.load("TardisTrainer/assets/themeSong.dfpwm"),
        flight = {
            takeoff = audio.load("TardisTrainer/assets/FlightTakeoff.dfpwm"),
            loop = audio.load("TardisTrainer/assets/FlightLoop.dfpwm"),
        },
        button = audio.load("TardisTrainer/assets/Button.dfpwm"),
        spinnyTardisFrames = {
            nimg.loadImage("TardisTrainer/assets/spinnyTardis_0"),
            nimg.loadImage("TardisTrainer/assets/spinnyTardis_1")
        }
    },
    messages = {
        error = nil,       --- @type string|nil
        flightHint = nil   --- @type table|nil
    },
    theme = lib.deepcopy(theme)
}

function program:tryResetGuessTimer()
    if self.timers.askNext ~= nil then
        os.cancelTimer(self.timers.askNext)  ---@diagnostic disable-line: undefined-field
    end
    self.timers.askNext = os.startTimer(lib.eventTimeFromThrottle(self.state.throttle))  ---@diagnostic disable-line: undefined-field
    if self.messages.flightHint == nil then
        program:onGuessFinished()
    else
        self.messages.flightHint = nil
    end
    self.state.currentGuess = ""
end

--- Called when the program begins
function program:start()
    
end

--- Called several times per frame (consistently)
function program:update()
    if self.state.page == pages.Title then
        -- Playing the audio
        self.assets.themeSong:run()
    elseif self.state.page == pages.EventTraining then
        -- Audio
        self.assets.flight.takeoff:runOnce()
        if self.assets.flight.takeoff.timesAlreadyLooped > 0 then
            self.assets.flight.loop:run()
        end

        -- Timer
        if self.timers.askNext == nil and self.messages.flightHint == nil then
            self:tryResetGuessTimer()
        end

        -- Hint screen
        if self.messages.flightHint ~= nil and self.timers.askNext ~= nil then
            os.cancelTimer(self.timers.askNext)  ---@diagnostic disable-line: undefined-field
            self.timers.askNext = nil
        end
    else
        self.assets.themeSong:run()
    end

    -- General timers
    if self.timers.drawTardisSpin == nil then
        self.timers.drawTardisSpin = os.startTimer(0.3)  ---@diagnostic disable-line: undefined-field
    end
    if self.timers.drawStars == nil then
        self.timers.drawStars = os.startTimer(0.2)  ---@diagnostic disable-line: undefined-field
    end
end

-- Like update, but called for every single monitor
function program:draw(monitor)
    if self.state.page == pages.Title then
        local pad = 12
        local tardisWidth = 7
        local tardisHeight = 6
        local width, height = monitor.getSize()
        local xMiddle = (width / 2)
        local yMiddle = (height / 2)
        local xTardis = xMiddle - tardisWidth - pad
        local yTardis = yMiddle - tardisHeight

        -- Drawing the stars
        if self.drawState.repositionStars then
            table.clear(self.drawState.starsPos)
            for i = 0, 64 / (width / height) do
                local cols = { colors.gray, colors.lightGray }
                self.drawState.starsPos[i] = {
                    x = math.random(0, width),
                    y = math.random(0, height),
                    color = cols[math.random(1, #cols)],
                }
            end
            self.drawState.repositionStars = false
        end
        for _, star in pairs(self.drawState.starsPos) do
            local chars = { '*', '+', 'x' }
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(star.color)
            monitor.setCursorPos(star.x, star.y)
            monitor.write(chars[math.random(1, #chars)])
        end
        
        -- Drawing the spinning TARDIS
        self.assets.spinnyTardisFrames[1 + self.drawState.tardisSpin % #self.assets.spinnyTardisFrames]:draw(monitor, xTardis, yTardis)

        -- Title
        monitor.setCursorPos(2, 2)
        monitor.setBackgroundColor(self.theme.back.clear2)
        monitor.setTextColor(self.theme.front.primary)
        print("TARDIS Training Software")
        monitor.setCursorPos(2, 3)
        monitor.setTextColor(self.theme.front.secondary)
        print("by FlooferLand (T Corvus Escort 1)")

        -- Begin text
        local beginText = "Press any to begin"
        monitor.setBackgroundColor(self.theme.back.clear)
        monitor.setTextColor(self.drawState.tardisSpin == 2 and self.theme.front.primary or self.theme.front.text)
        monitor.setCursorPos(xTardis + pad + (#beginText * 0.3), yMiddle)
        print(beginText)
    elseif self.state.page == pages.Tutorial then
        monitor.setCursorPos(1, 1)
        print("Welcome to event training!\n")
        print("Here you shall learn to fly the TARDIS without ripping a hole through its pocket dimension and scattering all your person belongings into the time vortex\n")
        print("You will be shown events and you need to handle them according to your TARDIS manual!")
        print("If your TARDIS automatically handles temporal additions for you, you can disable your training for those in the config file!\n")
        print("Alons-y!")
    elseif self.state.page == pages.Command then
        -- TODO: Add a command line that sorta acts like a main menu
    elseif self.state.page == pages.SelectThrottle then
        monitor.setCursorPos(1, 1)
        print("Select the throttle using your arrow keys")
        local leftArrow = (self.state.throttle > 1) and "<" or " "
        local rightArrow = (self.state.throttle < 9) and ">" or " "
        print(leftArrow .. " " .. lib.extraMath.clamp(self.state.throttle, 1, 9) .. " / 9" .. " " .. rightArrow)
    elseif self.state.page == pages.EventTraining then
        monitor.setCursorPos(1, 1)
        if self.state.activeTemporalEvent then
            monitor.setCursorPos(1, 1)
            monitor.setTextColor(self.theme.front.text)
            print("You have encountered a temporal event!")
            monitor.setCursorPos(1, 2)
            monitor.setTextColor(self.theme.front.primary)
            print("> " .. self.state.activeTemporalEvent.displayName)
            print()

            -- Displaying the current guess
            monitor.setTextColor(self.theme.front.secondary)
            print("Your answer >" .. self.state.currentGuess .. "<")
        else
            print("Flying normally.. (no events active)\n")
        end

        -- Displaying the flight hint screen
        if self.messages.flightHint ~= nil then
            monitor.clear()
            monitor.setCursorPos(1, 1)
            monitor.setTextColor(self.theme.front.text)
            monitor.setBackgroundColor(self.theme.back.clear2)
            print("Wrong answer!\n")
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(self.theme.front.secondary)
            print(self.messages.flightHint.name)
            print(self.messages.flightHint.description .. "\n")
            monitor.setTextColor(self.theme.front.primary)
            print("Correct:  " .. self.messages.flightHint.controls)
            print("You got:  " .. self.messages.flightHint.youGot)
        end

        -- Displaying the score
        monitor.setTextColor(self.theme.front.text)
        local _, y = monitor.getSize()
        monitor.setCursorPos(1, y - 2)
        print("Score: " .. self.state.currentScore)
    end
end

-- Called when a timer is finished
function program:onTimer(id)
    -- Geuss timer
    if id == self.timers.askNext and self.messages.flightHint ~= nil then
        self:tryResetGuessTimer()
    end

    -- Drawing
    if id == self.timers.drawTardisSpin then
        self.drawState.tardisSpin = self.drawState.tardisSpin + 1
        self.timers.drawTardisSpin = nil
    elseif id == self.timers.drawStars then
        self.drawState.repositionStars = true
        self.timers.drawStars = nil
    end
end

---@param control table
---@param guess string
---@return boolean
function program:isGuessCorrect(control, guess)
    local correctGuess = false
    for _, name in pairs(control.guessNames) do
        if string.find(string.lower(guess), string.lower(name), 1, true) then
            correctGuess = true
            break
        end
    end
    return correctGuess
end

--- Called every time the timer triggers
function program:onGuessFinished()
    if self.messages.flightHint ~= nil then
        return
    end

    local debug = false

    -- Deciding if the player succeeded completing the current event or not
    local temporalEvent = self.state.activeTemporalEvent
    if temporalEvent ~= nil and #self.state.currentGuess > 0 then
        local validGuesses = 0
        for _, control in pairs(temporalEvent.controls) do
            if program:isGuessCorrect(control, self.state.currentGuess) then
                validGuesses = validGuesses + 1
            end

            -- DEBUG
            if debug then
                self.messages.flightHint = {
                    name = "DEBUG",
                    description = "Guess names: " .. string.lower(json.stringify(control.guessNames)),
                    controls = "Your guess was \"" .. string.lower(self.state.currentGuess) .. "\""
                }
            end
        end
        if not debug then
            if validGuesses == (#temporalEvent.controls) then
                self.state.currentScore = self.state.currentScore + 1
                self.state.currentGuess = ""
            else
                if not temporalEvent.optional then
                    self.state.currentScore = self.state.currentScore - 1
                end

                -- Hint screen
                -- FIXME: The sheer existence of this screen causes the program to bug ouit and calculate score wrong and I have NO fucking clue why
                local flightHint = {
                    name = "> " .. temporalEvent.displayName .. " <",
                    description = temporalEvent.description,
                    controls = "",
                    youGot = ""
                }
                for i, control in pairs(temporalEvent.controls) do
                    local comma = (i < #temporalEvent.controls and ", " or "")
                    flightHint.controls = flightHint.controls .. control.displayName .. comma

                    if program:isGuessCorrect(control, self.state.currentGuess) then
                        flightHint.youGot = flightHint.youGot .. control.displayName .. comma
                    else
                        flightHint.youGot = "(none)"
                    end
                end
                self.messages.flightHint = flightHint
            end
        end
    end

    -- Creating the new guess
    local keyArray = table.keys(eventTraining.events)
    local randomKey = keyArray[math.random(1, (#keyArray)-1)]
    self.state.activeTemporalEvent = eventTraining.events[randomKey]
end

-- Called when a character is typed in
function program:onChar(char)
    if self.state.page == pages.EventTraining then
        self.state.currentGuess = self.state.currentGuess .. char
    end
end

-- Called when a key is pressed, held, or released
function program:onKey(key, pressed, held)
    if held or not pressed then
        return
    end

    if self.state.page == pages.Title then
        if self.config.firstTimeSetup then
            self.state.page = pages.Tutorial
        else 
            self.state.page = pages.SelectThrottle
        end
        self.assets.themeSong.effects.volume = 0.8
    elseif self.state.page == pages.Tutorial then
        self.state.page = pages.SelectThrottle
    elseif self.state.page == pages.SelectThrottle then
        -- Picking the throttle
        local throttle = self.state.throttle
        if key == keys.up or key == keys.right or key == keys.w or key == keys.d then
            throttle = throttle + 1
        elseif key == keys.down or key == keys.left or key == keys.s or key == keys.a then
            throttle = throttle - 1
        end
        self.state.throttle = lib.extraMath.clamp(throttle, 1, 9)

        if key == keys.enter and self.state.throttle > 0 then
            sleep(0.1)
            self.state.page = pages.EventTraining
        end

        self.assets.button:playOnce()
    elseif self.state.page == pages.EventTraining then
        if key == keys.enter then
            self:tryResetGuessTimer()
        elseif key == keys.backspace then
            self.state.currentGuess = string.sub(self.state.currentGuess, 1, #self.state.currentGuess - 1)
        end
    end

    -- Other
    -- [..]
end

--- Called when the program stops
function program:stop()
    self.config.firstTimeSetup = false
end

return program
