local program = require("program")
local theme = require("theme")
local lib = require("library")

local configManager = lib.config.make("TardisTrainer/conf.json")
local audioAssets = {}
local audioHandles = {}

local function eventHandler()
    while program.low.running do
        local lastError = currentError

        local event, data1, data2, data3 = os.pullEventRaw()  ---@diagnostic disable-line: undefined-field
        if event == "terminate" or event == "computer_unload" or event == "unload" then
            program.low.running = false
            return
        elseif event == "key" then
            local key, isHeld = data1, data2
            if (program.low.holdingCtrl and key == keys.t) or key == keys.rightShift then
                program.low.running = false
                return
            end

            -- TODO: Add support for key releases by making this also catch "key_up"
            program:onKey(key, true, isHeld)

            -- Control and shift modifiers
            program.low.holdingCtrl  = (not program.low.holdingCtrl)  and (key == keys.leftCtrl  or key == keys.rightCtrl)
            program.low.holdingShift = (not program.low.holdingShift) and (key == keys.leftShift or key == keys.rightShift)
        elseif event == "char" then
            local char = data1
            program:onChar(char)
        elseif event == "mouse_click" or event == "monitor_touch" then
            local button, x, y = data1, data2, data3
            program:onMouseClick(button, x, y)
        elseif event == "timer" then
            local timerId = data1
            program:onTimer(timerId)
        elseif event == "redstone" then
            program:onRedstone()
        end

        -- Error sound
        if currentError and lastError ~= currentError then
            for speaker in pairs(speakers) do
                speaker.playNote("harp", 1.0, 0.8)
            end
        end
    end
end

local function updateHandler()
    while program.low.running do
        local lastError = program.messages.error
        local deltaStart = os.time()

        -- Killing the audio before updating
        -- So audio will only play again if its run function is called again
        for _, audioAsset in pairs(audioAssets) do
            if not audioAsset.async then
                audioAsset.playing = false
            end
        end

        -- Resetting redstone event signals before updating
        for _, side in pairs({ program.config.redstoneEventOutputSide }) do
            redstone.setAnalogOutput(side, 0)
        end

        -- Updating and rendering
        program:update()
        for _, monitor in pairs(program.devices.monitors) do
            term.redirect(monitor)
            monitor.setBackgroundColor(program.theme.back.clear)
            monitor.setTextColor(program.theme.front.text)
            monitor.clear()
            monitor.setCursorPos(1,1)
            program:draw(monitor)
        end

        -- Error display
        if program.messages.error ~= nil then
            for _, monitor in pairs(program.devices.monitors) do
                local x, y = width / 2, height / 2
                monitor.setBackgroundColor(program.theme.back.clear2)
                monitor.clear()

                local titleText = "ERROR"
                term.setBackgroundColor(program.theme.back.clear)
                monitor.setTextColor(colors.red)
                monitor.setCursorPos(x - (#titleText / 2), y-2)
                monitor.write(titleText)

                -- TODO: Separate the word wrapping and new line functionality into the library so it can be used everywhere
                monitor.setCursorPos(x, y)
                term.setBackgroundColor(program.theme.back.clear2)
                local split = {}
                local current = ""
                for i = 1, #program.messages.error do
                    local char = program.messages.error:sub(i, i)

                    if char == "\n" or i+1 > #program.messages.error or (#current > width * 0.5 and char == " ") then
                        current = current .. char
                        table.insert(split, current)
                        current = ""
                    else
                        current = current .. char
                    end
                end
                for i = 1, #split do
                    local line = split[i]
                    monitor.setCursorPos(x - (#line / 2), y + i)
                    monitor.write(line)
                end

                local exitText = "Press any key to continue"
                monitor.setCursorPos(x - (#exitText / 2), y + #split + 2)
                monitor.setTextColor(colors.gray)
                monitor.write(exitText)
            end
        end

        -- Error sound
        if program.messages.error ~= nil and lastError ~= program.messages.error then
            for speaker in pairs(speakers) do
                speaker.playNote("harp", 1.0, 0.5)
            end
        end

        -- Waiting between frames and calculating delta time
        local deltaDiff = (os.time() - deltaStart)
        program.low.deltaTime = deltaDiff >= 0 and deltaDiff or 0

        -- Waiting between frames
        sleep(0.05)
    end
end

local function addAudioAssets(assetsTable)
    for _, asset in pairs(assetsTable) do
        if type(asset) == "table" and asset["assetType"] == "audio" then
            -- print(json.stringify(asset))
            table.insert(audioAssets, asset)
            for _, speaker in pairs(program.devices.speakers) do
                table.insert(audioHandles, function()
                    while true do
                        if asset.playing then
                            asset:runInternal(speaker, program.low.deltaTime)
                        end
                        coroutine.yield()
                    end
                end)
            end
        elseif type(asset) == "table" then
            addAudioAssets(asset)
        end
    end
end
if not program.config.muteAudio then
    addAudioAssets(program.assets)
end

-- Entering the program
local loadedConfig = configManager:load(program.config)
if type(loadedConfig) == "table" then
    program.config = loadedConfig
else
    program.messages.error = loadedConfig
end
program.theme = theme.loadBuiltinTheme(program.devices.monitors, program.config.theme)
for _, monitor in pairs(program.devices.monitors) do  -- Changing the monitor scaling
    if program.config.changeMonitorScaling and monitor["setTextScale"] ~= nil then
        monitor.setTextScale(lib.extraMath.clamp(program.config.preferredMonitorScaling, 0.5, 5))
    end
end

-- Running the main loop
program:start()
parallel.waitForAny(eventHandler, updateHandler, table.unpack(audioHandles))

-- Exiting and cleaning up after the program
program:stop()
configManager:save(program.config)
program.theme = theme.unloadTheme(program.devices.monitors)  -- Resets the colour palette
for _, monitor in pairs(program.devices.monitors) do
    if program.config.changeMonitorScaling then
        monitor.setTextScale(1.0)
    end
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1,1)
end
term.setCursorPos(1,1)
term.write("Exited the training program..")
