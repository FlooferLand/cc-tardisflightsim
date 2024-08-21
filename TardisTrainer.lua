-- Launcher and installer for the trainer
-- Has to be regularly updated over on (INSERT LINK)

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
    "spinnyTardis_0.nfp",
    "spinnyTardis_1.nfp",
    "themeSong.dfpwm",
}
local libraries = {
    {
        name = "json.lua",
        url = "https://gist.githubusercontent.com/tylerneylon/59f4bcf316be525b30ab/raw/7f69cc2cea38bf68298ed3dbfc39d197d53c80de/json.lua"
    }
}

-- Utility
local function install(path, link)
    local req = http.get(link)
    local f = fs.open(path, 'w')
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
        install(fs.combine(paths.folders.assets, filename), git .. filename)
    end
else
    print("Dev env detected")
end
for _, lib in pairs(libraries) do
    install(fs.combine(paths.folders.libs, lib.name), lib.url)
end
sleep(0.1)

-- Running the system
if not (fs.exists(".owner") or fs.exists(fs.combine(paths.folders.install, ".owner"))) then
    print("Starting TARDIS flight trainer")
    sleep(0.8)
end
print("Executing \"" .. paths.entry .. "\"")
shell.run(paths.entry)

