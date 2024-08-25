local lib = require("library")
local theme = require("theme")
local audio = require("audio")
local eventTraining = require("eventTraining")
local nimg = require("lib.nimg")
local json = require("lib.json")

local redstoneEvent = {
    GoodGuess = 13,
    BadGuess = 14,
    TardisGoBoomBoom = 15
}

local pages = {
    Title = 0,
    TitleSubpage = 1,
    Tutorial = 2,
    Command = 3,
    SelectThrottle = 4,
    EventTraining = 5,
    TardisGoBoomBoom = 6,
    FlightSim = 7
}
local subpages = {
    Title = {
        Settings = { pages.Title, 0 }
    }
}
function subpages.isSubpageOf(parentPage, thisPage)
    if type(thisPage) == "table" then
        if #thisPage > 0 then
            return thisPage[1] == parentPage
        end
    end
    return false
end

local initialProgram = {}
local program = {  --- Contains all program functions
    config = {
        firstTimeSetup = true,
        theme = "generic",

        fancyGraphics = true,
        audioVolume = 0.8,
        music = true,
        flightSound = true,
        temporalAdditions = true,
        limitedTime = true,
        redstoneEventInputSide = "left",
        redstoneEventOutputSide = "left",
        redstoneThrottleInputSide = "right",
        changeMonitorScaling = true,
        preferredMonitorScaling = 0.5,  -- Range: 0.5 <-> 1.5
        muteAudio = false,
        limitedLives = true
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
        currentGuessRedstone = 0,
        currentScore = 0,
        livesLeft = 5
    },
    drawState = {
        repositionStars = false,
        repositionTimeVortex = false,
        starsPos = {},
        timeVortexWavesPos = {},
        tardisSpin = 0,
    },
    timers = {
        askNext = nil,
        drawTardisSpin = nil,
        drawStars = nil,
        drawTimeVortex = nil
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

function program:nextPage()
    if self.state.page == pages.Title then
        self.assets.themeSong.effects.volume = 0.8
        if self.config.firstTimeSetup then
            self.state.page = pages.Tutorial
        else 
            self.state.page = pages.SelectThrottle
        end
    elseif self.state.page == pages.Tutorial then
        self.state.page = pages.SelectThrottle
    elseif self.state.page == pages.SelectThrottle then
        self.state.page = pages.EventTraining
        print("Loading..")
        sleep(1.5)
    end
end

function program:reset()
    program = initialProgram
    self.state.page = pages.Title  -- CHECKME: Might not be necessary
end

--- @param value integer
function program:setThrottle(value)
    self.state.throttle = lib.extraMath.clamp(value, 1, 9)
    for _, speaker in pairs(self.devices.speakers) do
        speaker.playNote("hat", 1.0, 12 + self.state.throttle)
    end
end

function program:tryResetGuessTimer()
    if self.timers.askNext ~= nil then
        os.cancelTimer(self.timers.askNext)  ---@diagnostic disable-line: undefined-field
    end
    self.timers.askNext = os.startTimer(lib.eventTimeFromThrottle(self.state.throttle))  ---@diagnostic disable-line: undefined-field
    if self.messages.flightHint == nil then
        self:onGuessFinished()
    else
        self.messages.flightHint = nil
    end
    self.state.currentGuess = ""
    self.state.currentGuessRedstone = 0
end

--- Called when the program begins
function program:start()
    if self.config.muteAudio then
        self.devices.speakers = {}
    end

    initialProgram = self
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
    end

    -- General timers
    if self.timers.drawTardisSpin == nil then
        self.timers.drawTardisSpin = os.startTimer(0.3)  ---@diagnostic disable-line: undefined-field
    end
    if self.config.fancyGraphics then
        if self.timers.drawStars == nil then
            self.timers.drawStars = os.startTimer(0.5)  ---@diagnostic disable-line: undefined-field
        end
        -- if self.timers.drawTimeVortex == nil then
        --     self.timers.drawTimeVortex = os.startTimer(0.15)  ---@diagnostic disable-line: undefined-field
        -- end
    end
end

-- Like update, but called for every single monitor
function program:draw(monitor)
    if self.state.page == pages.Title or subpages.isSubpageOf(pages.Title, self.state.page) then
        local pad = 12
        local tardisWidth = 7
        local tardisHeight = 6
        local width, height = monitor.getSize()
        local xMiddle = (width / 2)
        local yMiddle = (height / 2)
        local xTardis = xMiddle - tardisWidth - pad
        local yTardis = yMiddle - tardisHeight

        local monitorName = monitor
        if monitorName == nil then
            monitorName = "default"
        end

        -- Drawing the stars
        if self.drawState.repositionStars then
            self.drawState.starsPos[monitorName] = {}
            for i = 0, 64 / (width / height) do
                local cols = { colors.gray, colors.lightGray, colors.lightBlue, colors.yellow }
                
                self.drawState.starsPos[monitorName][i] = {
                    x = math.random(0, width - i),
                    y = math.random(0, height),
                    color = cols[math.random(1, #cols)],
                }
            end
            self.drawState.repositionStars = false
        end
        if self.drawState.starsPos[monitorName] ~= nil then
            for _, star in pairs(self.drawState.starsPos[monitorName]) do
                local chars = { '*', '+', 'x' }
                monitor.setBackgroundColor(self.theme.back.clear)
                monitor.setTextColor(star.color)
                monitor.setCursorPos(star.x, star.y)
                monitor.write(chars[math.random(1, #chars)])
            end
        end
        
        -- Page specific stuff
        if self.state.page == pages.Title then
            -- Drawing the spinning TARDIS
            self.assets.spinnyTardisFrames[1 + self.drawState.tardisSpin % #self.assets.spinnyTardisFrames]:draw(monitor, xTardis, yTardis - (self.drawState.tardisSpin % 2))

            -- Title
            monitor.setCursorPos(2, 2)
            monitor.setBackgroundColor(self.theme.back.clear2)
            monitor.setTextColor(self.theme.front.primary)
            print("TARDIS Training Software")
            monitor.setCursorPos(2, 3)
            monitor.setTextColor(self.theme.front.secondary)
            print("by FlooferLand (Corvus Escort 1)")

            -- Begin text
            local beginText = "Press any to begin"
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(self.drawState.tardisSpin == 2 and self.theme.front.primary or self.theme.front.text)
            monitor.setCursorPos(xTardis + pad + (#beginText * 0.3), yMiddle)
            print(beginText)

            -- Additional text
            local additionalText = "Press 'c' to view config"
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(self.theme.back.secondary)
            monitor.setCursorPos(xTardis + pad + (#additionalText * 0.225), yMiddle + 1)
            print(additionalText)
        elseif self.state.page == subpages.Title.Settings then
            -- Config info text
            monitor.setCursorPos(2, 2)
            monitor.setBackgroundColor(self.theme.back.clear2)
            monitor.setTextColor(self.theme.front.primary)
            print("To edit the settings, open conf.json and edit it manually\n")

            -- Config text
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(self.theme.front.text)
            for k, config in pairs(self.config) do
                print(k .. " = " .. tostring(config))
            end
            print()

            -- Exit text
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setTextColor(self.theme.front.primary)
            print("Press any to go back")
        end
    elseif self.state.page == pages.Tutorial then
        monitor.setCursorPos(1, 1)
        print("Welcome to event training!\n")
        print("Here you shall learn to fly the TARDIS without ripping a hole through its pocket dimension and scattering all your person belongings into the time vortex\n")
        print("You will be shown events and you need to handle them according to your TARDIS manual!")
        print("If your TARDIS automatically handles temporal additions for you, you can disable your training for those in the config file!\n")
        print("Press right shift or CTRL + T at any time to exit the software\n")
        print("Alons-y!")
    elseif self.state.page == pages.Command then
        -- TODO: Add a command line that sorta acts like a main menu
    elseif self.state.page == pages.SelectThrottle then
        -- Info text
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(self.theme.back.clear)
        monitor.setTextColor(self.theme.front.text)
        monitor.write("Select the throttle using your arrow keys")

        -- Left arrow
        if self.state.throttle > 1 then
            monitor.setCursorPos(1, 2)
            monitor.setBackgroundColor(self.theme.back.clear2)
            monitor.setTextColor(self.theme.front.text)
            monitor.write("<")
        end

        -- Throttle amount display
        monitor.setCursorPos(3, 2)
        monitor.setBackgroundColor(self.theme.back.clear)
        monitor.setTextColor(self.theme.front.text)
        monitor.write(self.state.throttle .. " / 9")

        -- Right arrow
        if self.state.throttle < 9 then
            monitor.setCursorPos(9, 2)
            monitor.setBackgroundColor(self.theme.back.clear2)
            monitor.setTextColor(self.theme.front.text)
            monitor.write(">")
        end
    elseif self.state.page == pages.EventTraining then
        if self.messages.flightHint == nil then
            -- Drawing the time vortex
            -- if self.drawState.repositionTimeVortex then
            --     local width, height = monitor.getSize()
            --     table.clear(self.drawState.timeVortexWavesPos)
            --     for i = 0, 64 / (width / height) do
            --         local cols = { colors.cyan, colors.blue }
            --         local new = {
            --             x = math.random(0, width),
            --             y = math.random(0, height),
            --             color = cols[math.random(1, #cols)],
            --         }
            --         self.drawState.timeVortexWavesPos[i] = {
            --             x = lib.extraMath.lerp((self.drawState.timeVortexWavesPos[i] or new).x, new.x, 0.4),
            --             y = lib.extraMath.lerp((self.drawState.timeVortexWavesPos[i] or new).y, new.y, 0.4),
            --             color = new.color
            --         }
            --     end
            --     self.drawState.repositionTimeVortex = false
            -- end
            -- for _, pos in pairs(self.drawState.timeVortexWavesPos) do
            --     local chars = { '\\', '/', '|', '-' }
            --     monitor.setBackgroundColor(self.theme.back.clear)
            --     monitor.setTextColor(pos.color)
            --     monitor.setCursorPos(pos.x, pos.y)
            --     monitor.write(chars[math.random(1, #chars)])
            -- end

            -- Drawing the text
            monitor.setCursorPos(1, 2)
            if self.state.activeTemporalEvent then
                monitor.setCursorPos(1, 2)
                monitor.setTextColor(self.theme.front.text)
                print("You have encountered a temporal event!")
                monitor.setCursorPos(1, 3)
                monitor.setTextColor(self.theme.front.primary)
                print("> " .. self.state.activeTemporalEvent.displayName)
                print()

                -- Displaying the current guess
                monitor.setTextColor(self.theme.front.secondary)
                print("Your answer >" .. self.state.currentGuess .. "<" .. " ")
            else
                print("Flying normally.. (no events active)\n")
            end
        else
            -- Displaying the flight hint screen
            monitor.setCursorPos(1, 2)
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
        if self.config.limitedLives then
            monitor.setCursorPos(1, y - 3)
            print("Lives: " .. self.state.livesLeft)
        else
            monitor.setCursorPos(1, y - 2)
        end
        print("Score: " .. self.state.currentScore)
        print("Time: " .. lib.eventTimeFromThrottle(self.state.throttle) .. "s (throt=" .. self.state.throttle .. ")")
        monitor.setTextColor(self.theme.front.secondary)
        print("(time limits for training are currently not available)")
    elseif self.state.page == pages.TardisGoBoomBoom then
        monitor.setTextColor(self.theme.front.primary)
        monitor.setCursorPos(1, 1)
        print("Your TARDIS blew up!")
        monitor.setTextColor(self.theme.back.secondary)
        print("Press any button to reset")
    end
end

-- Called when a timer is finished
function program:onTimer(id)
    -- TODO: Figure out why this timer wont work, and why flightHint keeps switching between nil and a value causing the event flight screen to keep moving one line down radnomly
    -- Geuss timer
    -- if id == self.timers.askNext and self.messages.flightHint ~= nil then
    --     self:tryResetGuessTimer()
    -- end

    -- Drawing
    if id == self.timers.drawTardisSpin then
        self.drawState.tardisSpin = self.drawState.tardisSpin + 1
        self.timers.drawTardisSpin = nil
    elseif id == self.timers.drawStars then
        self.drawState.repositionStars = true
        self.timers.drawStars = nil
    elseif id == self.timers.drawTimeVortex then
        self.drawState.repositionTimeVortex = true
        self.timers.drawTimeVortex = nil
    end
end

---@param control table
---@param guess string
---@param guessRed integer
---@return boolean
function program:isGuessCorrect(control, guess, guessRed)
    local correctGuess = false
    for _, name in pairs(control.guessNames) do
        if string.find(string.lower(guess), string.lower(name), 1, true) or guessRed == control.redstoneSignal then
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
    if temporalEvent ~= nil then
        local validGuesses = 0
        for _, control in pairs(temporalEvent.controls) do
            if self:isGuessCorrect(control, self.state.currentGuess, self.state.currentGuessRedstone) then
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

        if debug then return end
        if validGuesses == (#temporalEvent.controls) then  -- Good guess
            self.state.currentScore = self.state.currentScore + 1
            self.state.currentGuess = ""
            self.state.currentGuessRedstone = 0
            redstone.setAnalogOutput(self.config.redstoneEventOutputSide, redstoneEvent.GoodGuess)
        else
            if not temporalEvent.optional then  -- Bad guess
                self.state.currentScore = self.state.currentScore - 1
                redstone.setAnalogOutput(self.config.redstoneEventOutputSide, redstoneEvent.BadGuess)
                self.state.livesLeft = self.state.livesLeft - 1
                if self.state.livesLeft == 0 then
                    self.state.page = pages.TardisGoBoomBoom
                end
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

                if self:isGuessCorrect(control, self.state.currentGuess, self.state.currentGuessRedstone) then
                    flightHint.youGot = flightHint.youGot .. control.displayName .. comma
                else
                    flightHint.youGot = "(none)"
                end
            end
            self.messages.flightHint = flightHint
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

-- Called when redstone changes in some way
function program:onRedstone()
    local eventInput = redstone.getAnalogInput(self.config.redstoneEventInputSide)
    if eventInput > 0 then
        self.state.currentGuessRedstone = eventInput
        self:tryResetGuessTimer()
    end

    local throttleInput = redstone.getAnalogInput(self.config.redstoneThrottleInputSide)
    if throttleInput > 0 then
        self:setThrottle(throttleInput)
    end
end

-- Called when the mouse clicks or when an advanced monitor is tapped
function program:onMouseClick(button, x, y)
    if self.state.page == pages.Title or subpages.isSubpageOf(pages.Title, self.state.page) then
        if self.state.page == pages.Title then
            self:nextPage()
        else
            self.state.page = pages.Title
        end
    elseif self.state.page == pages.Tutorial then
        self:nextPage()
    elseif self.state.page == pages.SelectThrottle then
        local throttle = self.state.throttle

        -- FIXME: The throttle arrow click positions use magic numbers
        if (y > 1 and y < 4) and x < 12 then
            if (x > 0 and x < 4) then
                self:setThrottle(throttle - 1)
            elseif (x > 7 and x < 10) then
                self:setThrottle(throttle + 1)
            end
        else
            self:nextPage()
        end
    elseif self.state.page == pages.EventTraining then
        if self.messages.flightHint ~= nil then
            self:tryResetGuessTimer()
        end
    elseif self.state.page == pages.TardisGoBoomBoom then
        self:reset()
    end
end

-- Called when the mouse scrolls
function program:onMouseScroll(direction, x, y)
    self:setThrottle(self.state.throttle - direction)
    if self.state.page ~= pages.SelectThrottle then
        for _, monitor in pairs(self.devices.monitors) do
            local _, y = monitor.getSize()
            monitor.setTextColor(self.theme.front.text)
            monitor.setBackgroundColor(self.theme.back.clear2)
            monitor.setCursorPos(1, y - 1)
            term.redirect(monitor)
            print("Throttle = "..self.state.throttle)
            monitor.setTextColor(self.theme.front.text)
            monitor.setBackgroundColor(self.theme.back.clear)
            monitor.setCursorPos(1, 1)
        end
    end
end

-- Called when a key is pressed, held, or released
function program:onKey(key, pressed, held)
    if held or not pressed then
        return
    end

    -- Throttle control
    local throttle = self.state.throttle
    if (key == keys.up or key == keys.right) or ((key == keys.w or key == keys.d) and self.state.page == pages.SelectThrottle) then
        self:setThrottle(throttle + 1)
    elseif (key == keys.down or key == keys.left) or ((key == keys.s or key == keys.a) and self.state.page == pages.SelectThrottle) then
        self:setThrottle(throttle - 1)
    end

    -- Title pages
    if self.state.page == pages.Title then
        if key ~= keys.c then
            self:nextPage()
        else
            self.state.page = subpages.Title.Settings
        end
    elseif subpages.isSubpageOf(pages.Title, self.state.page) then
        self.state.page = pages.Title
    end

    -- Other pages
    if self.state.page == pages.Tutorial then
        self:nextPage()
    elseif self.state.page == pages.SelectThrottle then
        if key == keys.enter and self.state.throttle > 0 then
            -- FIXME: All audio intersects somehow, playing over each other at random times
            -- self.assets.button:playOnce()
            self:nextPage()
        end
    elseif self.state.page == pages.EventTraining then
        if key == keys.enter then
            self:tryResetGuessTimer()
        elseif key == keys.backspace then
            self.state.currentGuess = string.sub(self.state.currentGuess, 1, #self.state.currentGuess - 1)
        end
    elseif self.state.page == pages.TardisGoBoomBoom then
        self:reset()
    end
end

--- Called when the program stops
function program:stop()
    self.config.firstTimeSetup = false
end

return program
