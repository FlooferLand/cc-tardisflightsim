local eventMarkers = {
    TemporalAdditions = 0,
    Optional = 1
}

local controlIdIncrement = 0
---@param displayName string
---@param redstoneSignal integer
---@param guessNames string[]
local function createControl(displayName, redstoneSignal, guessNames)
    local control = {
        runtimeId = controlIdIncrement,   --- @type integer
        displayName = displayName,        --- @type string
        redstoneSignal = redstoneSignal,  --- @type integer
        guessNames = guessNames,          --- @type string[]
        id = function(self)
            return self.runtimeId
        end
    }
    controlIdIncrement = controlIdIncrement + 1
    return control
end
local c = {
    Throttle         = createControl("Throttle",  1, { "throt", "throttle", "speed" }),
    Increment        = createControl("Increment",  2, { "inc", "increment" }),
    Randomiser       = createControl("Randomiser", 3, { "rand", "random", "randomiser", "randomizer" }),
    Dimension        = createControl("Dimension", 4, { "dim", "dimension" }),
    ExteriorFacing   = createControl("Exterior facing", 5, { "exterior facing", "facing", "exterior", "direction" }),
    VerticalLanding  = createControl("Vertical landing gear", 6, { "vertical landing", "landing", "vertical landing gear" }),
    Communicator     = createControl("Communicator", 7, { "com", "comm", "communicator" }),
    Refueler         = createControl("Refueler", 8, { "refueler", "refuel", "fuel" }),
    DoorLock         = createControl("Door lock", 9, { "door", "door lock", "door control" }),
    PosX             = createControl("X", 10, { "x", "pos x", "x pos", "x offset", "x off", "x increment", "increment x" }),
    PosY             = createControl("Y", 11, { "y", "pos y", "y pos", "y offset", "y off", "y increment", "increment y" }),
    PosZ             = createControl("Z", 12, { "z", "pos z", "z pos", "z offset", "z off", "z increment", "increment z" })
}

local eventIdIncrement = 0
---@param displayName string
---@param controls table[]
---@param description string
---@param markers table|nil
local function createEvent(displayName, controls, description, markers)
    if markers == nil then
        markers = {}
    end
    local event = {
        --- @type integer
        runtimeId = eventIdIncrement,

        --- @type string
        displayName = displayName,

        ---@type string
        description = description,

        ---@type table[]
        controls = controls,
        
        --- @type boolean
        temporalAdditions = table:contains(eventMarkers.TemporalAdditions),
        
        --- @type boolean
        optional = table:contains(eventMarkers.Optional)
    }
    controlIdIncrement = controlIdIncrement + 1
    return event
end
local events = {
    TimeRamInstigate = createEvent(
        "Time Ram (Instigate)",
        { c.Communicator, c.Throttle, c.Randomiser },
        "You are on course to collide with another TARDIS. Move out of the way!",
        { eventMarkers.TemporalAdditions }
    ),
    TimeRamReceive = createEvent(
        "Time Ram (Receive)",
        { c.Communicator, c.Randomiser, c.Dimension },
        "You are on course to collide with another TARDIS. Move out of the way!",
        { eventMarkers.TemporalAdditions }
    ),
    VortexScrap = createEvent(
        "Vortex Scrap",
        { c.Randomiser, c.ExteriorFacing },
        "There is junk in the time vortex, move out of the way before it hits you!",
        { eventMarkers.TemporalAdditions }
    ),
    AlternatingTimeWinds = createEvent(
        "Alternating Time Winds",
        { c.Throttle, c.Randomiser },
        "Just like with time winds, winds are pushing against the TARDIS.\nThese winds move back and forth however, you need to randomize to get out of the windy area",
        { eventMarkers.TemporalAdditions }
    ),
    TimeStorm = createEvent(
        "Time Storm",
        { c.Randomiser, c.Increment, c.Throttle },
        "You have entered a time storm, fly out of it as fast as possible!"
    ),
    VectorCalcError = createEvent(
        "Vector Calculation Error",
        { c.PosX, c.PosY, c.PosZ },
        "The current TARDIS location was offset due to a miscalculation. Move it back!"
    ),
    VerticalDisplacementError = createEvent(
        "Vertical Displacement Error",
        { c.VerticalLanding },
        "The TARDIS went through a vertical slope in the time vortex that it couldn't keep up with.\nVertically re-align the TARDIS before it flies out of the vortex!"
    ),
    ExteriorBulkhead = createEvent(
        "Exterior Bulkhead",
        { c.DoorLock },
        "The door got slightly nudged open, Artron energy from the time vortex is starting to seep in!"
    ),
    TimeWinds = createEvent(
        "Time Winds",
        { c.Throttle },
        "Wind is pushing against the TARDIS, push against the wind or you'll be thrown off-course and possibly end up hitting something!"
    ),
    SpatialDriftX = createEvent(
        "Spatial Drift (X)",
        { c.PosX },
        "The TARDIS drifts off-course sometimes. Re-align yourself on the X axis!",
        { eventMarkers.TemporalAdditions }
    ),
    SpatialDriftY = createEvent(
        "Spatial Drift (Y)",
        { c.PosY },
        "The TARDIS drifts off-course sometimes. Re-align yourself on the Y axis!",
        { eventMarkers.TemporalAdditions }
    ),
    SpatialDriftZ = createEvent(
        "Spatial Drift (Z)",
        { c.PosZ },
        "The TARDIS drifts off-course sometimes. Re-align yourself on the Z axis!",
        { eventMarkers.TemporalAdditions }
    ),
    ArtronPocket = createEvent(
        "Artron Pocket found",
        { c.Refueler, c.ExteriorFacing },
        "A pocket of concentrated artron energy was found in the vortex!\nYou can collect it for free fuel!",
        { eventMarkers.Optional }
    )
}

return {
    controls = c,
    events = events
}
