local lib = require("library")
local theme = require("theme")
local audio = require("audio")
local eventTraining = require("eventTraining")

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
        temporalAdditions = true
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
        tardisFrameToDraw = 0,
        throttle = 0,
        activeTemporalEvent = nil,
        currentGuess = "",
        currentScore = 0
    },
    timers = {
        askNext = nil
    },
    assets = {
        themeSong = audio.load("TardisTrainer/assets/themeSong.dfpwm"),
        flight = {
            takeoff = audio.load("TardisTrainer/assets/FlightTakeoff.dfpwm"),
            loop = audio.load("TardisTrainer/assets/FlightLoop.dfpwm"),
        },
        button = audio.load("TardisTrainer/assets/Button.dfpwm"),
        spinnyTardis = {
            paintutils.loadImage("TardisTrainer/assets/spinnyTardis_0.nfp"),
            paintutils.loadImage("TardisTrainer/assets/spinnyTardis_1.nfp")
        }
    },
    messages = {
        error = nil,       --- @type string|nil
        flightHint = nil   --- @type string|nil
    },
    theme = lib.deepcopy(theme)
}

function program:resetGuessTimer()
    self.state.currentGuess = ""
    self.messages.flightHint = nil
    if self.timers.askNext ~= nil then
        os.cancelTimer(self.timers.askNext)
    end
    self.timers.askNext = os.startTimer(lib.eventTimeFromThrottle(self.state.throttle))  ---@diagnostic disable-line: undefined-field
    program:onGuessFinished()
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
        if self.timers.askNext == nil then
            self:resetGuessTimer()
        end

        -- Hint screen
        if self.messages.flightHint ~= nil then
            os.cancelTimer(self.timers.askNext)
            self.timers.askNext = nil
        end
    else
        self.assets.themeSong:run()
    end
end

-- Like update, but called for every single monitor
function program:draw(monitor)
    if self.state.page == pages.Title then
        local pad = 10
        local width = 7
        local height = 6
        local x, y = monitor.getSize()
        x = (x / 2)
        y = (y / 2)
        local xTardis = x - width - pad
        local yTardis = y - height

        -- TODO: Use delta-time and test if it works!
        paintutils.drawImage(self.assets.spinnyTardis[1 + math.floor((self.state.tardisFrameToDraw) % 2)], xTardis, yTardis)
        self.state.tardisFrameToDraw = self.state.tardisFrameToDraw + 0.2

        -- Begin text
        local text = "Press any to begin"
        monitor.setBackgroundColor(colors.black)
        monitor.setCursorPos(xTardis + pad + (#text * 0.25), y)
        print(text)
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
        print("Select the throttle")
        print(lib.extraMath.clamp(self.state.throttle, 1, 15))
    elseif self.state.page == pages.EventTraining then
        monitor.setCursorPos(1, 1)
        if self.state.activeTemporalEvent then
            print("You have encountered a temporal event!")
            print(self.state.activeTemporalEvent.displayName)
            print()

            -- Displaying the current guess
            print("Your answer >" .. self.state.currentGuess .. "<")
        else
            print("Flying normally.. (no events active)\n")
        end

        -- Displaying the flight hint screen
        if self.messages.flightHint ~= nil then
            monitor.clear()
            monitor.setCursorPos(1, 1)
            print(self.messages.flightHint)
        end

        -- Displaying the score
        local _, y = monitor.getSize()
        monitor.setCursorPos(1, y - 2)
        print("Score: " .. self.state.currentScore)
    end
end

-- Called when a timer is finished
function program:onTimer(id)
    if id == self.timers.askNext and self.messages.flightHint ~= nil then
        self:resetGuessTimer()
    end
end

--- Called every time the timer triggers
function program:onGuessFinished()
    -- Deciding if the player succeeded completing the current event or not
    local temporalEvent = self.state.activeTemporalEvent
    if temporalEvent ~= nil then
        local validGuesses = 0
        for _, control in pairs(temporalEvent.controls) do
            local correctGuess = false
            for _, guessName in pairs(control.guessNames) do
                local findStart, findEnd = string.find(self.state.currentGuess, guessName, 1, true)
                if type(findStart) == "number" and type(findEnd) == "number" then
                    correctGuess = true
                    break
                end
            end
            if correctGuess then
                validGuesses = validGuesses + 1
            end
        end
        if validGuesses == #temporalEvent.controls-1 then
            self.state.currentScore = self.state.currentScore + 1
        else
            if not temporalEvent.optional then
                self.state.currentScore = self.state.currentScore - 1
            end

            -- Hint screen
            -- FIXME: The sheer existence of this screen causes the program to bug ouit and calculate score wrong and I have NO fucking clue why
            local flightHint = temporalEvent.description .. "\n" .. "Controls: "
            for i, control in pairs(temporalEvent.controls) do
                flightHint = flightHint .. control.displayName .. (i < #temporalEvent.controls-1 and "," or "")
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
        if key == keys.up or key == keys.w then
            throttle = throttle + 1
        elseif key == keys.down or key == keys.s then
            throttle = throttle - 1
        end
        self.state.throttle = lib.extraMath.clamp(throttle, 1, 15)

        if key == keys.enter and self.state.throttle > 0 then
            self.state.page = pages.EventTraining
        end

        self.assets.button:playOnce()
    elseif self.state.page == pages.EventTraining then
        if key == keys.enter then
            self:resetGuessTimer()
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
