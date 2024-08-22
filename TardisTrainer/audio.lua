local dfpwm = require("cc.audio.dfpwm")
local lib = require("library")

local audio = {
    assetType = "audio",
    path = "",
    effects = {
        volume = 1.0,
        delay = 0.0,
        distort = 0.0,
        highPass = 0.0
    },
    playing = false,
    loop = true,
    timesAlreadyLooped = 0,
    async = false
}

---Loads and caches audio data from a file system path
---@param path string
---@return table
function audio.load(path)
    audio.encoder = dfpwm.make_encoder()
    audio.decoder = dfpwm.make_decoder()
    local self = lib.deepcopy(audio)
    self.path = path
    return self
end

--- Plays the next chunk of the audio
function audio:run()
    self.playing = true
    self.loop = true
    self.async = false
end

--- Plays the next chunk of the audio, only loops once
function audio:runOnce()
    self.playing = true
    self.loop = false
    self.async = false
end

--- Resets the audio for runOnce, letting it play again
function audio:resetOnce()
    self.timesAlreadyLooped = 0
end

--- Plays the audio asynchronously without looping
function audio:playOnce()
    self.playing = true
    self.loop = false
    self.async = true
end

--- Gets called every frame no matter what
function audio:runInternal(speaker, delta)
    if not self.playing then
        return
    end

    if self.loop == false and self.timesAlreadyLooped > 0 and not self.async then
        self.playing = false
        return
    end

    local i = 0
    local previousBuffer = nil
    local smoothenIntensity = 0.2 + self.effects.delay
    for chunk in io.lines(self.path, 4 * 1024) do
        local buffer = self.decoder(chunk)

        -- Quitting
        if not self.playing then
            break
        end

        -- Applying effects (volume, etc)
        local newBuffer = {}
        for _, a in pairs(buffer) do
            -- Volume
            a = a * self.effects.volume + smoothenIntensity

            -- Distortion
            a = lib.extraMath.lerp(a, 0.0, ((a+128) / 128) * self.effects.distort)

            -- Final
            table.insert(newBuffer, lib.extraMath.clamp(a, -128, 127))
        end

        -- Crossfade with the previous buffer
        if previousBuffer ~= nil and self.effects.delay > 0.0 then
            for c = 1, math.min(#newBuffer, #previousBuffer) do
                local t = (1 - smoothenIntensity)
                newBuffer[c] = lib.extraMath.lerp(previousBuffer[c], newBuffer[c], t)
                newBuffer[c] = lib.extraMath.clamp(newBuffer[c], -128, 127)
            end
        end

        -- Plays the buffer and waits for it to finish playing
        -- before moving onto the next buffer
        while not speaker.playAudio(newBuffer) do
            os.pullEvent("speaker_audio_empty")
            if not self.playing then
                break
            end
        end

        previousBuffer = newBuffer
        i = i + 1
    end
    self.timesAlreadyLooped = self.timesAlreadyLooped + 1
    self.playing = false
end

return audio
