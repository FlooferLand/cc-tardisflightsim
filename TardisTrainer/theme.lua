local lib = require("library")
local hexColors = lib.color

local themes = {
    generic = "generic",
    steampunk = "steampunk"
}
local theme = {
    front = {  -- Foreground
        text = colors.white,
        primary = colors.pink,
        secondary = colors.pink,
    },
    back = {  -- Background
        primary = colors.black,
        secondary = colors.black,
        clear = colors.black,
        clear2 = colors.black
    }
}
theme.unloadTheme = function(monitors)
    for key, value in pairs(theme) do
        if type(value) ~= "table" then goto continue end
        for name, color in pairs(value) do
            if type(color) == "number" and hexColors[name] ~= nil then
                for _, monitor in pairs(monitors) do
                    monitor.setPaletteColor(color, hexColors[name])
                end
            end
        end
    end
    ::continue::
end
theme.loadBuiltinTheme = function(monitors, themeToLoad)
    theme.unloadTheme()
    local newTheme = lib.deepcopy(theme)
    if themeToLoad == themes.generic then
        for _, monitor in pairs(monitors) do
            monitor.setPaletteColor(colors.white, hexColors.white)
            monitor.setPaletteColor(colors.cyan, hexColors.blend(hexColors.cyan, hexColors.black, 0.2))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.gray, hexColors.black, 0.2))
            monitor.setPaletteColor(colors.pink, hexColors.blend(hexColors.black, hexColors.brown, 0.3))
        end

        newTheme.front = {
            text = colors.white,
            primary = colors.cyan,
            secondary = colors.lightGray,
        }
        newTheme.back = {
            primary = colors.cyan,
            secondary = colors.gray,
            clear = colors.black,
            clear2 = colors.pink
        }
    elseif themeToLoad == themes.steampunk then
        for _, monitor in pairs(monitors) do
            monitor.setPaletteColor(colors.white, hexColors.blend(hexColors.white, hexColors.brown))
            monitor.setPaletteColor(colors.red, hexColors.blend(hexColors.red, hexColors.brown))
            monitor.setPaletteColor(colors.cyan, hexColors.blend(hexColors.red, hexColors.brown))
            
            monitor.setPaletteColor(colors.brown, hexColors.blend(hexColors.black, hexColors.brown, 0.6))
            monitor.setPaletteColor(colors.gray, hexColors.blend(hexColors.black, hexColors.brown, 0.3))
            monitor.setPaletteColor(colors.black, hexColors.blend(hexColors.black, hexColors.brown, 0.15))
            monitor.setPaletteColor(colors.pink, hexColors.blend(hexColors.black, hexColors.brown, 0.05))
        end
        newTheme.front = {
            text = colors.white,
            primary = colors.red,
            secondary = colors.cyan,
        }
        newTheme.back = {
            primary = colors.brown,
            secondary = colors.gray,
            clear = colors.black,
            clear2 = colors.pink
        }
    end

    -- Returning the modified theme
    return newTheme
end

return theme