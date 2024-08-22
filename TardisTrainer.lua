-- Launcher and installer for the trainer
-- Has to be regularly updated over on https://pastebin.com/wQq755Nd

-- Paths
local paths = {}
paths.folders = {}
paths.folders.install = "/TardisTrainer/"
paths.folders.sources = fs.combine(paths.folders.install)
paths.folders.assets = fs.combine(paths.folders.install, "assets/")
paths.folders.libs = fs.combine(paths.folders.install, "lib/")
paths.entry = fs.combine(paths.folders.sources, "entry.lua")

-- Data
local sources = {
    "audio.lua",
    "entry.lua",
    "eventTraining.lua",
    "library.lua",
    "program.lua",
    "theme.lua",
}
local assets = {
    "Button.dfpwm",
    "FlightLoop.dfpwm",
    "FlightTakeoff.dfpwm",
    "spinnyTardis_0.nimg",
    "spinnyTardis_1.nimg",
    "themeSong.dfpwm",
}
local libraries = {
    {
        name = "json.lua",
        url = "https://gist.githubusercontent.com/tylerneylon/59f4bcf316be525b30ab/raw/7f69cc2cea38bf68298ed3dbfc39d197d53c80de/json.lua"
    },
    {
        name = "nimg.lua",
        url = "https://pastebin.com/raw/2nbDhRXC"
    }
}

-- Utility
---@param path string
---@param link string
---@param isBinary boolean|nil
local function install(path, link, isBinary)
    if isBinary == nil then
        isBinary = false
    end
    local req = http.get(link, nil, isBinary)
    local f = fs.open(path, isBinary and "wb" or "w")
    f.write(req.readAll())
    f.close()
    req.close()
end

-- Making the folders
for i, path in pairs(paths.folders) do
    if not fs.isDir(path) then
        print("Making '"..path.."' folder..")
        fs.makeDir(path)
    end
end

-- Install libraries
if not (fs.exists(".devenv") or fs.exists(fs.combine(paths.folders.install, ".devenv"))) then
    for _, filename in pairs(sources) do
        local git = "https://raw.githubusercontent.com/FlooferLand/cc-tardisflightsim/main/" .. paths.folders.install .. "/"
        install(fs.combine(paths.folders.install, filename), git .. filename)
    end
    for _, filename in pairs(assets) do
        local git = "https://raw.githubusercontent.com/FlooferLand/cc-tardisflightsim/main/" .. paths.folders.install .. "/assets/"
        local isBinary = string.find(filename, ".dfpwm", 1, true) ~= nil
        install(fs.combine(paths.folders.assets, filename), git .. filename, isBinary)
    end
else
    print("Dev env detected")
end
for _, lib in pairs(libraries) do
    install(fs.combine(paths.folders.libs, lib.name), lib.url)
end
sleep(0.1)

-- Nimg
print("Initializing NimG")
shell.run(fs.combine(paths.folders.libs, "nimg.lua") .. " update")
print("Moving NimG dependency 'ButtonG'")
local buttonH = {}
buttonH.initial = "/ButtonH"
buttonH.newFolder = fs.combine(paths.folders.install, "ButtonH")
buttonH.new = fs.combine(buttonH.newFolder, "init.lua")
buttonH.new2 = fs.combine(paths.folders.libs, "ButtonH.lua")
if not fs.exists(buttonH.newFolder) then
    fs.makeDir(buttonH.newFolder)
end
if fs.exists(buttonH.initial) and not fs.exists(buttonH.new) then
    fs.move(buttonH.initial, buttonH.new)
end
if fs.exists(buttonH.new) and not fs.exists(buttonH.new2) then
    fs.copy(buttonH.new, buttonH.new2)
end
term.clear()

-- Running the system
if not (fs.exists(".owner") or fs.exists(fs.combine(paths.folders.install, ".owner"))) then
    print("Starting TARDIS flight trainer")
    sleep(0.8)
end
print("Executing \"" .. paths.entry .. "\"")
shell.run(paths.entry)

