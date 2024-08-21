local json = require "lib.json"

--- Copy a table
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- @param other table|nil
function table:append(other)
    if other ~= nil then
        for k,v in pairs(other) do
            self[k] = v
        end
    end
    return self
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function table.keys(table)
    local i = 1
    local keyArray = {}
    for key, _ in pairs(table) do
        keyArray[i] = key
        i = i + 1
    end
    return keyArray
end

-- Mafs
local extraMath = {
    lerp = function(a, b, t)
        return a + (b - a) * t
    end,
    clamp = function(_in, low, high)  -- Thank you Garry's Mod
        return math.min(math.max(_in, low), high)
    end,
    smoothen = function(arr, intensity)
        local smoothed = {}
        local n = #arr
        for i = 1, n do
            local prev = arr[i - 1] or arr[i]
            local next = arr[i + 1] or arr[i]
            smoothed[i] = arr[i] + intensity * ((prev + next) / 2 - arr[i])
        end
        return smoothed
    end,
    map = function(x, in_min, in_max, out_min, out_max)
        return out_min + (x - in_min)*(out_max - out_min)/(in_max - in_min)
    end
}

-- Config stuff
local config = {
    path = ""
}

--- Config constructor
---@param path string
function config.make(path)
    local manager = deepcopy(config)
    manager.path = path
    return manager
end

--- Loads from a path
--- @param defaults table
--- @return table|string
function config.load(self, defaults)
    if not fs.exists(self.path) then
        local file = fs.open(self.path, "w")
        file.write(json.stringify(defaults))
        file.close()
    end

    local file = fs.open(self.path, "r")
    local config = json.parse(file.readAll()) or defaults
    file.close()
    if type(config) == "table" then
        return config
    else
        return "Error: Config file at path \""..self.path.."\" is not a JSON object!"
    end
end

--- Saves to a path
--- @param conf table
function config.save(self, conf)
    local file = fs.open(self.path, "w")
    file.write(json.stringify(conf))
    file.close()
end

-- Colour magic
local color = {
    white = 0xF0F0F0,
    orange = 0xF2B233,
    magenta = 0xE57FD8,
    lightBlue = 0x99B2F2,
    yellow = 0xDEDE6C,
    lime = 0x7FCC19,
    pink = 0xF2B2CC,
    gray = 0x4C4C4C,
    lightGray = 0x999999,
    cyan = 0x4C99B2,
    purple = 0xB266E5,
    blue = 0x3366CC,
    brown = 0x7F664C,
    green = 0x57A64E,
    red = 0xCC4C4C,
    black = 0x111111,

    ---@param color1 any
    ---@param color2 any
    ---@param t? number
    ---@return number
    blend = function (color1, color2, t)
        --if color1 == nil or color2 == nil then
        --    return color1 or color2 or nil
        --end
        if t == nil then
            t = 0.5
        end

        local one = {}
        local two = {}
        one.r, one.g, one.b = colors.unpackRGB(color1)
        two.r, two.g, two.b = colors.unpackRGB(color2)
        return colors.packRGB(
            extraMath.lerp(one.r, two.r, t),
            extraMath.lerp(one.g, two.g, t),
            extraMath.lerp(one.b, two.b, t)
        )
    end
}


---@param throttle integer
---@return number
local function eventTimeFromThrottle(throttle)
    return extraMath.map(throttle, 1, 9, 5.0, 10.0)
end

-- Export
return {
    config = config,
    extraMath = extraMath,
    deepcopy = deepcopy,
    color = color,
    eventTimeFromThrottle = eventTimeFromThrottle
}
