local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }

print("Playing audio..")

local decoder = dfpwm.make_decoder()
for chunk in io.lines("TardisTrainer/assets/themeSong.dfpwm", 16 * 1024) do
    local buffer = decoder(chunk)
    local funcs = {}
	for _, speaker in pairs(speakers) do
        table.insert(funcs, function()
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
        end)
    end
    parallel.waitForAny(table.unpack(funcs))
end