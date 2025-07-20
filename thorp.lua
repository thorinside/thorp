-- Thorp Arpeggiator v3.0
-- 16 ARP slots + song sequencing

-- Page constants
local PAGE_SLOT, PAGE_PATTERN, PAGE_SCALE, PAGE_SONG = 1, 2, 3, 4
local pageNames = {"slot", "pattern", "scale", "song"}

-- Sequence mode constants
local MODE_SEQ, MODE_PINGPONG, MODE_RNDWALK, MODE_RANDOM = 1, 2, 3, 4
local sequenceModeLabels = {"seq", "pingpong", "rndwalk", "random"}

-- Play mode constants
local PLAY_MODE_OFF, PLAY_MODE_JAM, PLAY_MODE_SONG = 1, 2, 3
local playModeLabels = {"Off", "Jam", "Song"}

-- Pot takeover configuration
local POT_TAKEOVER_THRESHOLD = 0.02
local POT_TAKEOVER_SCALE_FACTOR = 0.7
local POT_COUNT = 3

-- Initial pot values by type
local POT_INITIAL_VALUES = {
    GATE_LENGTH = 0.5,      -- 50%
    GATE_PROBABILITY = 1.0,  -- 100%
    OCT_JUMP = 0.0,         -- 0%
    OCT_RANGE = 0.0,        -- Maps to 1
    GLOBAL_OCT = 0.5,       -- 100%
    SEQ_MODE = 0.25         -- Maps to MODE_SEQ
}

--------------------------------------------------------------------------------
-- REUSABLE LIBRARY MODULES
--------------------------------------------------------------------------------

-- SmoothPotTakeover Library - Handles smooth pot value transitions
local SmoothPotTakeover = {}
SmoothPotTakeover.__index = SmoothPotTakeover

function SmoothPotTakeover:new(config)
    local instance = {
        threshold = config.threshold or 0.02,
        scaleFactor = config.scaleFactor or 0.7,
        potCount = config.potCount or 3,
        physicalPots = {},
        takeover = {
            active = {},
            startPhysical = {}
        }
    }
    
    -- Initialize arrays
    for i = 1, instance.potCount do
        instance.physicalPots[i] = 0.5
        instance.takeover.active[i] = false
        instance.takeover.startPhysical[i] = 0
    end
    
    setmetatable(instance, self)
    return instance
end

function SmoothPotTakeover:processTurn(potNum, rawValue, currentPage, pageValues)
    local logical = pageValues[currentPage] and pageValues[currentPage][potNum]
    if not logical then return nil end
    
    local distance = math.abs(rawValue - logical)
    
    if not self.takeover.active[potNum] then
        -- Direct control
        self.physicalPots[potNum] = rawValue
        return rawValue
    end
    
    -- Takeover mode
    if distance < self.threshold then
        self.takeover.active[potNum] = false
        self.physicalPots[potNum] = rawValue
        return rawValue
    else
        -- Apply scaling
        local delta = rawValue - self.physicalPots[potNum]
        local scale = 1 - (distance * self.scaleFactor)
        local scaled = logical + (delta * scale)
        self.physicalPots[potNum] = rawValue
        return math.max(0, math.min(1, scaled))
    end
end

function SmoothPotTakeover:activateForPageChange(fromPage, toPage, pageValues)
    for i = 1, self.potCount do
        local oldValue = pageValues[fromPage] and pageValues[fromPage][i]
        local newValue = pageValues[toPage] and pageValues[toPage][i]
        
        if oldValue and newValue and math.abs(self.physicalPots[i] - newValue) > self.threshold then
            self.takeover.active[i] = true
            self.takeover.startPhysical[i] = self.physicalPots[i]
        end
    end
end

function SmoothPotTakeover:getSetupValues(currentPage, pageValues)
    local values = {}
    for i = 1, self.potCount do
        values[i] = (pageValues[currentPage] and pageValues[currentPage][i]) or 0.5
    end
    return values
end

-- PotDefinitionManager Library - Manages pot configurations and logical values
local PotDefinitionManager = {}
PotDefinitionManager.__index = PotDefinitionManager

function PotDefinitionManager:new(definitions)
    local instance = {
        definitions = definitions,
        logicalValues = {}
    }
    
    -- Initialize logical values from definitions
    for page, defs in pairs(definitions) do
        instance.logicalValues[page] = {}
        for i, def in ipairs(defs) do
            instance.logicalValues[page][i] = def.type == "continuous" and def.initial or nil
        end
    end
    
    setmetatable(instance, self)
    return instance
end

function PotDefinitionManager:getLogicalValues()
    return self.logicalValues
end

function PotDefinitionManager:updateValue(page, potNum, value)
    if self.logicalValues[page] then
        self.logicalValues[page][potNum] = value
    end
end

function PotDefinitionManager:getDefinition(page, potNum)
    return self.definitions[page] and self.definitions[page][potNum]
end

-- ActionDispatcher Library - Generic action routing system
local ActionDispatcher = {}
ActionDispatcher.__index = ActionDispatcher

function ActionDispatcher:new(actions, defaultHandler)
    local instance = {
        actions = actions,
        defaultHandler = defaultHandler
    }
    setmetatable(instance, self)
    return instance
end

function ActionDispatcher:dispatch(context, key1, key2, ...)
    local action = self.actions[key1] and self.actions[key1][key2]
    if action then
        return action(context, ...)
    elseif self.defaultHandler then
        return self.defaultHandler(context, key1, key2, ...)
    end
end

--------------------------------------------------------------------------------
-- END OF LIBRARY MODULES
--------------------------------------------------------------------------------

-- Centralized pot configuration
local potDefinitions = {
    [PAGE_SLOT] = {
        {type = "push_only", label = "Copy/Paste"},
        {type = "push_only", label = "Save Notes"},
        {type = "continuous", label = "Gate Len", initial = POT_INITIAL_VALUES.GATE_LENGTH}
    },
    [PAGE_PATTERN] = {
        {type = "continuous", label = "G.Prob", initial = POT_INITIAL_VALUES.GATE_PROBABILITY},
        {type = "push_only", label = "Assign Both"},
        {type = "continuous", label = "Gate Len", initial = POT_INITIAL_VALUES.GATE_LENGTH}
    },
    [PAGE_SCALE] = {
        {type = "continuous", label = "Oct Jump", initial = POT_INITIAL_VALUES.OCT_JUMP},
        {type = "continuous", label = "Oct Range", initial = POT_INITIAL_VALUES.OCT_RANGE},
        {type = "continuous", label = "Gate Len", initial = POT_INITIAL_VALUES.GATE_LENGTH}
    },
    [PAGE_SONG] = {
        {type = "continuous", label = "G.Oct Jump", initial = POT_INITIAL_VALUES.GLOBAL_OCT},
        {type = "push_only", label = "Play Mode"},
        {type = "continuous", label = "Seq Mode", initial = POT_INITIAL_VALUES.SEQ_MODE}
    }
}


-- Scale definitions (40+)
local scaleNames = {
    "Ionian", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Aeolian",
    "Locrian", "HarmonicMinor", "MelodicMinorAsc", "MelodicMinorDesc",
    "MajorPentatonic", "MinorPentatonic", "BluesMajor", "BluesMinor",
    "Chromatic", "WholeTone", "Octatonic", "Diminished", "Augmented",
    "NeapolitanMajor", "NeapolitanMinor", "HungarianMinor", "HungarianMajor",
    "Byzantine", "Persian", "Arabian", "Pelog", "Iwato", "InSen", "Prometheus",
    "Enigmatic", "MajorBebop", "MinorBebop", "HalfDiminished", "MajorLocrian",
    "LydianAugmented", "LydianDiminished", "UkrainianDorian", "IonianSharp5"
}

local scales = {
    Ionian = {0, 2, 4, 5, 7, 9, 11},
    Dorian = {0, 2, 3, 5, 7, 9, 10},
    Phrygian = {0, 1, 3, 5, 7, 8, 10},
    Lydian = {0, 2, 4, 6, 7, 9, 11},
    Mixolydian = {0, 2, 4, 5, 7, 9, 10},
    Aeolian = {0, 2, 3, 5, 7, 8, 10},
    Locrian = {0, 1, 3, 5, 6, 8, 10},
    HarmonicMinor = {0, 2, 3, 5, 7, 8, 11},
    MelodicMinorAsc = {0, 2, 3, 5, 7, 9, 11},
    MelodicMinorDesc = {0, 2, 3, 5, 7, 8, 10},
    MajorPentatonic = {0, 2, 4, 7, 9},
    MinorPentatonic = {0, 3, 5, 7, 10},
    BluesMajor = {0, 2, 3, 4, 7, 9},
    BluesMinor = {0, 3, 5, 6, 7, 10},
    Chromatic = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
    WholeTone = {0, 2, 4, 6, 8, 10},
    Octatonic = {0, 2, 3, 5, 6, 8, 9, 11},
    Diminished = {0, 2, 3, 5, 6, 8, 9, 11},
    Augmented = {0, 4, 8},
    NeapolitanMajor = {0, 1, 3, 5, 7, 9, 11},
    NeapolitanMinor = {0, 1, 3, 5, 7, 8, 11},
    HungarianMinor = {0, 2, 3, 6, 7, 8, 11},
    HungarianMajor = {0, 3, 4, 6, 7, 9, 10},
    Byzantine = {0, 1, 4, 5, 7, 8, 10},
    Persian = {0, 1, 4, 5, 6, 8, 11},
    Arabian = {0, 1, 4, 5, 6, 8, 10},
    Pelog = {0, 1, 3, 7, 8},
    Iwato = {0, 1, 5, 6, 10},
    InSen = {0, 1, 5, 6, 10},
    Prometheus = {0, 2, 4, 6, 9, 10},
    Enigmatic = {0, 1, 4, 6, 8, 10, 11},
    MajorBebop = {0, 2, 4, 5, 7, 8, 9, 11},
    MinorBebop = {0, 2, 3, 5, 7, 8, 10, 11},
    HalfDiminished = {0, 2, 3, 5, 6, 8, 10},
    MajorLocrian = {0, 2, 4, 5, 6, 8, 10},
    LydianAugmented = {0, 2, 4, 6, 8, 9, 11},
    LydianDiminished = {0, 2, 3, 6, 7, 9, 11},
    UkrainianDorian = {0, 2, 3, 6, 7, 9, 10},
    IonianSharp5 = {0, 2, 4, 5, 8, 9, 11}
}

-- Rhythmic patterns (23)
local patternNames = {
    "Ascending", "Descending", "UpDown", "DownUp", "Alternate", "TriadOnRoot",
    "TriadOnThird", "SeventhArp", "FifthLeap", "PentatonicAsc",
    "PentatonicDesc", "MajorBlues", "MinorBlues", "CircleOfFifths",
    "Arpeggio4ths", "Arpeggio3rds", "Random1", "Random2", "Random3",
    "Syncopated", "Burst2", "Burst3", "ClusterStep"
}

local patterns = {
    Ascending = {1, 2, 3, 4, 5, 6, 7, 8},
    Descending = {8, 7, 6, 5, 4, 3, 2, 1},
    UpDown = {1, 2, 3, 4, 5, 6, 7, 6},
    DownUp = {8, 7, 6, 5, 4, 3, 2, 3},
    Alternate = {1, 8, 2, 7, 3, 6, 4, 5},
    TriadOnRoot = {1, 3, 5, 1, 3, 5, 1, 3},
    TriadOnThird = {3, 5, 1, 3, 5, 1, 3, 5},
    SeventhArp = {1, 3, 5, 7, 5, 3, 1, 3},
    FifthLeap = {1, 5, 2, 6, 3, 7, 4, 8},
    PentatonicAsc = {1, 2, 3, 5, 6, 1, 2, 3},
    PentatonicDesc = {6, 5, 3, 2, 1, 6, 5, 3},
    MajorBlues = {1, 2, 3, 5, 6, 5, 3, 2},
    MinorBlues = {1, 3, 4, 5, 7, 5, 4, 3},
    CircleOfFifths = {1, 5, 2, 6, 3, 7, 4, 1},
    Arpeggio4ths = {1, 4, 7, 3, 6, 2, 5, 8},
    Arpeggio3rds = {1, 3, 5, 7, 2, 4, 6, 8},
    Random1 = {2, 5, 1, 7, 3, 8, 4, 6},
    Random2 = {3, 6, 2, 8, 4, 1, 5, 7},
    Random3 = {5, 2, 8, 4, 7, 3, 1, 6},
    Syncopated = {1, 0, 2, 0, 3, 0, 4, 0},
    Burst2 = {1, 2, 0, 0, 5, 6, 0, 0},
    Burst3 = {1, 2, 3, 0, 0, 0, 6, 7},
    ClusterStep = {1, 2, 3, 4, 0, 4, 3, 2}
}

-- Velocity patterns (0-100%)
local velocityPatternNames = {
    "Constant", "Accent", "OffBeat", "Crescendo", "Diminuendo", 
    "Strong/Weak", "Swing Feel", "Random Walk", "Pulse", "Breathe",
    "Hard/Soft", "Build Up", "Break Down", "Pump", "Subtle"
}

local velocityPatterns = {
    Constant = {100, 100, 100, 100, 100, 100, 100, 100},
    Accent = {100, 70, 80, 70, 100, 70, 80, 70},
    OffBeat = {70, 100, 80, 100, 70, 100, 80, 100},
    Crescendo = {50, 60, 70, 80, 85, 90, 95, 100},
    Diminuendo = {100, 95, 90, 85, 80, 70, 60, 50},
    StrongWeak = {100, 60, 100, 60, 100, 60, 100, 60},
    SwingFeel = {100, 80, 90, 75, 100, 80, 90, 75},
    RandomWalk = {85, 100, 65, 90, 75, 95, 80, 100},
    Pulse = {100, 50, 100, 50, 100, 50, 100, 50},
    Breathe = {80, 85, 90, 95, 100, 95, 90, 85},
    HardSoft = {100, 40, 100, 40, 100, 40, 100, 40},
    BuildUp = {60, 65, 70, 75, 80, 85, 90, 95},
    BreakDown = {95, 90, 85, 80, 75, 70, 65, 60},
    Pump = {100, 70, 90, 80, 100, 70, 90, 80},
    Subtle = {90, 85, 95, 80, 90, 85, 95, 80}
}

-- 16 fixed ARP slots
local arps = {}
for i = 1, 16 do
    arps[i] = {
        pattern = 1,
        notes = {},
        length = #patterns[patternNames[1]],
        offset = 0,
        reverse = false,
        -- Default velocity pattern (Constant)
        velocities = {100, 100, 100, 100, 100, 100, 100, 100},
        velocityPattern = 1, -- Index into velocityPatternNames
        -- Step probabilities (default 100% chance for all steps)
        probabilities = {100, 100, 100, 100, 100, 100, 100, 100},
        -- Octave jump settings
        octaveJumpChance = 0,  -- 0-100% chance of octave jumps
        octaveJumpRange = 1,   -- +/- octaves (1, 2, or 3)
        octaveJumpUpOnly = false  -- if true, only jump up
    }
end

-- Clipboard for copy/paste functionality
local slotClipboard = nil

-- Song chain state
local chain = {}
local chainPos = 1
local localStep = 0
local sequenceMode = MODE_SEQ
local pingDir = 1

-- Global state
local activeNotes = {}
local latchedNotes = {}
local lastNote = nil
local page = PAGE_SLOT
local arpSlot = 1
local gateLen = 50
local msg = ""
local msgT = 0
local stepCount = 0

local helpText = {
    [PAGE_SLOT] = {
        pots = {"Copy/Paste", "Save Notes", "Gate Len"},
        encoders = {"Slot", "Len/Offset"}
    },
    [PAGE_PATTERN] = {
        pots = {"G.Prob", "Assign Both", "Gate Len"},
        encoders = {"Rhythm Pattern", "Velocity Pattern"}
    },
    [PAGE_SCALE] = {
        pots = {"Oct Jump", "Oct Range", "Gate Len"},
        encoders = {"Root", "Scale"}
    },
    [PAGE_SONG] = {
        pots = {"G.Oct Jump", "Play Mode", "Seq Mode"},
        encoders = {"Add Slot", "Position"}
    }
}

-- Initialize library modules
local potTakeoverSystem = SmoothPotTakeover:new({
    threshold = POT_TAKEOVER_THRESHOLD,
    scaleFactor = POT_TAKEOVER_SCALE_FACTOR,
    potCount = POT_COUNT
})

local potManager = PotDefinitionManager:new(potDefinitions)
local logicalPots = potManager:getLogicalValues()

local lastPage = PAGE_SLOT

-- Pot action handlers by page and pot number
local potActions = {
    [PAGE_PATTERN] = {
        [1] = function(self, value)
            local newVal = math.floor(value * 100)
            self:setParameter(paramIndexes.stepProbability, newVal)
        end
    },
    [PAGE_SCALE] = {
        [1] = function(self, value)
            local slot = arps[arpSlot]
            slot.octaveJumpChance = math.floor(value * 100)
            msg, msgT = "S" .. arpSlot .. " Oct Jump: " .. slot.octaveJumpChance .. "%", 30
        end,
        [2] = function(self, value)
            local slot = arps[arpSlot]
            slot.octaveJumpRange = math.max(1, math.min(3, math.floor(value * 3) + 1))
            msg, msgT = "S" .. arpSlot .. " Oct Range: ±" .. slot.octaveJumpRange, 30
        end
    },
    [PAGE_SONG] = {
        [1] = function(self, value)
            local newVal = math.floor(value * 200)
            self:setParameter(paramIndexes.globalOctaveJump, newVal)
        end,
        [3] = function(self, value)
            local p_idx = paramIndexes.sequenceMode
            local newVal = math.min(#sequenceModeLabels, math.floor(value * #sequenceModeLabels) + 1)
            self:setParameter(p_idx, newVal)
            msg, msgT = "Seq. Mode: " .. sequenceModeLabels[newVal], 30
        end
    }
}

-- Initialize action dispatcher with default handler for pot 3 (gate length)
local potDispatcher = ActionDispatcher:new(potActions, function(self, page, potNum, value)
    if potNum == 3 and page ~= PAGE_SONG then
        gateLen = math.floor(value * 100)
        self:setParameter(paramIndexes.gateLen, gateLen)
    end
end)

local paramIndexes = {
    scale = 1,
    pattern = 2,
    arpSlot = 3,
    gateLen = 4,
    midiChannel = 5,
    playMode = 6,
    rootNote = 7,
    sequenceMode = 8,
    globalOctaveJump = 9,
    globalProbability = 10,
    globalVelocity = 11,
    velocityPattern = 12,
    stepProbability = 13
}

local noteNames = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

-- Quantize helper: snap note to nearest scale degree ≤ note
local function quantizeToScale(note, scaleTbl, rootNote)
    local relative_note = note - rootNote
    local oct = math.floor(relative_note / 12)
    local sem = relative_note % 12
    local deg = scaleTbl[1]
    for _, off in ipairs(scaleTbl) do
        if sem >= off then
            deg = off
        else
            break
        end
    end
    return rootNote + oct * 12 + deg
end

local function midiToNoteName(note)
    if not note then return "-" end
    local n = math.floor(note)
    local octave = math.floor(n / 12) - 1
    local name = noteNames[(n % 12) + 1]
    return name .. octave
end

local function drawCenteredTinyText(x, w, y, text)
    local text_width = #text * 4 -- Approx width of tiny text char
    local text_x = x + math.floor((w - text_width) / 2)
    drawTinyText(text_x, y, text)
end

-- Helper function to draw the Slot Page
local function drawSlotPageUI(self)
    local arp = arps[arpSlot]
    drawText(10, 22, ("Slot: %d"):format(arpSlot))
    
    -- Show length/offset controls (slot-specific)
    local len = (arp and arp.length) or 0
    local offset = (arp and arp.offset) or 0
    local indicatorL = (self.slotEncoderMode == 'length') and ">" or ""
    local indicatorO = (self.slotEncoderMode == 'offset') and ">" or ""
    drawText(10, 36, ("%sLength:%d %sOffset:%d"):format(indicatorL, math.floor(len), indicatorO, math.floor(offset)))

    -- Show notes (main purpose of this page)
    local playMode = self.parameters[paramIndexes.playMode]
    if playMode == PLAY_MODE_JAM then
        local notes_tbl = {}
        for n in pairs(latchedNotes) do
            table.insert(notes_tbl, midiToNoteName(n))
        end
        drawText(10, 50, "Latched: " .. table.concat(notes_tbl, " "))
    else
        local notes_tbl = {}
        if arp and arp.notes then
            for _, note in ipairs(arp.notes) do
                table.insert(notes_tbl, midiToNoteName(note))
            end
        end
        drawText(10, 50, "Notes: " .. table.concat(notes_tbl, " "))
    end
    
    -- Show clipboard status
    if slotClipboard then
        drawText(200, 22, "📋")
    end
end

-- Helper function to draw the Pattern Page
local function drawPatternPageUI(self)
    -- Show current global pattern parameters
    local patternIdx = math.floor(self.parameters[paramIndexes.pattern])
    drawText(10, 22, ("Rhythm: %s"):format(patternNames[patternIdx]))
    
    local velPatternIdx = math.floor(self.parameters[paramIndexes.velocityPattern])
    drawText(10, 36, ("Velocity: %s"):format(velocityPatternNames[velPatternIdx]))
    
    -- Show gate probability
    local gateProb = math.floor(self.parameters[paramIndexes.stepProbability])
    drawText(10, 50, ("G.Prob: %d%%"):format(gateProb))
end

-- Helper function to draw the Scale Page
local function drawScalePageUI(self)
    local rootNoteIdx = math.floor(self.parameters[paramIndexes.rootNote])
    drawText(10, 22, ("Root: %s"):format(noteNames[rootNoteIdx]))
    local scaleIdx = math.floor(self.parameters[paramIndexes.scale])
    drawText(10, 36, ("Scale: %s"):format(scaleNames[scaleIdx]))
    
    -- Show octave jump settings for current slot (controlled by pots)
    local slot = arps[arpSlot]
    if slot then
        local octJump = slot.octaveJumpChance or 0
        local octRange = slot.octaveJumpRange or 1
        drawText(10, 50, ("Oct Jump: %d%% ±%d"):format(octJump, octRange))
    end
end

-- Helper function to draw the Song Page
local function drawSongPageUI(self)
    local current_slot_in_chain = chain[chainPos] or 1
    local len = (arps[current_slot_in_chain] and
                    arps[current_slot_in_chain].length) or 1
    drawText(10, 22,
             ("Step: %d/%d"):format(math.floor(localStep), math.floor(len)))
    local playMode = self.parameters[paramIndexes.playMode]
    local chain_str_tbl = {}
    for i, slot_val in ipairs(chain) do
        local slot_str = tostring(math.floor(slot_val))
        if i == chainPos and playMode == PLAY_MODE_SONG then
            slot_str = ">" .. slot_str
        end
        table.insert(chain_str_tbl, slot_str)
    end
    drawText(10, 36, ("Chain: %s"):format(table.concat(chain_str_tbl, "+")))
    local playModeStr = playModeLabels[playMode]
    drawText(10, 50, ("Mode: %s | Seq: %s"):format(playModeStr,
                                                   sequenceModeLabels[sequenceMode]))
    
    -- Display global octave jump parameter
    local globalOct = self.parameters[paramIndexes.globalOctaveJump]
    drawText(140, 50, ("G.Oct: %d%%"):format(math.floor(globalOct)))
end

-- Helper function to draw the Help Screen
local function drawHelpScreenUI(self)
    if self.helpVisible then
        local y = 45
        drawRectangle(0, y, 256, 64, 0) -- Black background

        local currentHelp = helpText[page]
        if currentHelp then
            -- Restore full help text drawing logic
            -- Line 1
            drawTinyText(5, y + 10, "- Page")
            drawCenteredTinyText(40, 55, y + 10, currentHelp.pots[1])
            drawCenteredTinyText(95, 66, y + 10, currentHelp.pots[2])
            drawCenteredTinyText(161, 55, y + 10, currentHelp.pots[3])
            local p_text = "+ Page"
            drawTinyText(255 - #p_text * 4 - 5, y + 10, p_text)
            -- Line 2
            drawTinyText(5, y + 18, "Exit")
            drawCenteredTinyText(40, 90, y + 18, currentHelp.encoders[1])
            drawCenteredTinyText(130, 90, y + 18, currentHelp.encoders[2])
            local h_text = "Help"
            drawTinyText(255 - #h_text * 4 - 5, y + 18, h_text)

            drawLine(0, y, 255, y, 15) -- White line at the top
        end
    end
end

return {
    name = "Thorp",
    author = "Your Name",

    init = function(self)
        self.lastPitch = 0.0
        self.lastVelocity = 5.0 -- Default to 50% velocity (5V out of 10V)
        self.helpVisible = false
        self.slotEncoderMode = "offset"
        self.lastPlayMode = -1
        self.lastArpSlot = -1
        self.lastSequenceMode = -1
        if self.state then
            arps = self.state.arps or arps
            chain = self.state.chain or chain
            sequenceMode = self.state.sequenceMode or sequenceMode
            gateLen = self.state.gateLen or gateLen
        end
        return {
            inputs = {kGate, kTrigger},
            inputNames = {"Clock", "Step"},
            outputs = {kStepped, kStepped, kStepped},
            outputNames = {"Gate", "V/Oct", "Velocity"},
            midi = {
                channelParameter = paramIndexes.midiChannel,
                messages = {"note"}
            },
            parameters = {
                [paramIndexes.scale] = {"Scale", scaleNames, 1},
                [paramIndexes.pattern] = {"Pattern", patternNames, 1},
                [paramIndexes.arpSlot] = {"Arp Slot", 1, 16, arpSlot},
                [paramIndexes.gateLen] = {"GateLen", 1, 100, gateLen, kPercent},
                [paramIndexes.midiChannel] = {"MIDI channel", 0, 16, 0},
                [paramIndexes.playMode] = {
                    "Play Mode", playModeLabels, PLAY_MODE_JAM
                },
                [paramIndexes.rootNote] = {"Root Note", noteNames, 1},
                [paramIndexes.sequenceMode] = {
                    "Sequence Mode", sequenceModeLabels, 1
                },
                [paramIndexes.globalOctaveJump] = {"Global Octave Jump", 0, 200, 100, kPercent},
                [paramIndexes.globalProbability] = {"Global Probability", 0, 200, 100, kPercent},
                [paramIndexes.globalVelocity] = {"Global Velocity", 0, 200, 100, kPercent},
                [paramIndexes.velocityPattern] = {"Velocity Pattern", velocityPatternNames, 1},
                [paramIndexes.stepProbability] = {"G.Prob", 0, 100, 100, kPercent}
            }
        }
    end,

    step = function(self, dt, inputs)
        -- Poll parameters and call onParameterChanged
        local currentPlayMode = self.parameters[paramIndexes.playMode]
        if currentPlayMode ~= self.lastPlayMode then
            self:onParameterChanged(paramIndexes.playMode, currentPlayMode)
            self.lastPlayMode = currentPlayMode
        end

        local currentArpSlot = self.parameters[paramIndexes.arpSlot]
        if currentArpSlot ~= self.lastArpSlot then
            self:onParameterChanged(paramIndexes.arpSlot, currentArpSlot)
            self.lastArpSlot = currentArpSlot
        end

        local currentSequenceMode = self.parameters[paramIndexes.sequenceMode]
        if currentSequenceMode ~= self.lastSequenceMode then
            self:onParameterChanged(paramIndexes.sequenceMode,
                                    currentSequenceMode)
            self.lastSequenceMode = currentSequenceMode
        end

        if self.gateTime and self.gateTime > 0 then
            self.gateTime = self.gateTime - (dt * 1000) -- dt is in seconds
            if self.gateTime <= 0 then
                self.gateTime = 0
                -- Don't return here - let _advance_step handle outputs consistently
            end
        end
        -- Note: gateTime = -1 means legato mode (gate stays on until next note)
    end,

    -- Track held MIDI notes for capture
    midiMessage = function(self, msg)
        local s, n, v = msg[1], msg[2], msg[3]
        if s == 0x90 and v > 0 then
            -- If no other keys are held, this is the start of a new phrase.
            if next(activeNotes) == nil then
                latchedNotes = {} -- Clear the latched notes
            end
            self:setParameter(paramIndexes.playMode, PLAY_MODE_JAM)

            activeNotes[n] = true;
            lastNote = n

            -- Add the raw, unquantized note to the latched set.
            latchedNotes[n] = true
        elseif s == 0x80 or (s == 0x90 and v == 0) then
            activeNotes[n] = nil
            if lastNote == n then lastNote = next(activeNotes) end
            -- On note-off, we only update activeNotes, leaving latchedNotes untouched.
        end
    end,

    gate = function(self, input, rising)
        if input == 1 and rising then return self:_advance_step() end
    end,

    -- Renamed from trigger2 to be the handler for Input 2 (kTrigger)
    trigger = function(self, input)
        if input == 2 and #chain > 0 then
            msgT = 0
            localStep = localStep + arps[chain[chainPos]].length
            return self:_advance_step()
        end
    end,

    -- Main logic, renamed from trigger
    _advance_step = function(self)
        if msgT > 0 then msgT = msgT - 1 end

        stepCount = stepCount + 1
        local raw_note = nil
        local currentStepIndex = 1 -- Track step index for velocity

        local playMode = self.parameters[paramIndexes.playMode]

        if playMode == PLAY_MODE_SONG and #chain > 0 then
            -- sequence mode
            local slotIdx = chain[chainPos]
            local slot = arps[slotIdx]
            local pat = patterns[patternNames[slot.pattern or 1]]
            local len, off, rev = slot.length, slot.offset, slot.reverse

            if len > 0 and #pat > 0 then
                local idx = ((localStep % len) + 1)
                localStep = localStep + 1
                if localStep >= len then
                    localStep = 0
                    -- advance chainPos based on sequenceMode
                    if sequenceMode == MODE_SEQ then
                        chainPos = (chainPos % #chain) + 1
                    elseif sequenceMode == MODE_PINGPONG and #chain > 1 then
                        if (chainPos == #chain and pingDir == 1) or
                            (chainPos == 1 and pingDir == -1) then
                            pingDir = -pingDir
                        end
                        chainPos = chainPos + pingDir
                    elseif sequenceMode == MODE_RNDWALK and #chain > 1 then
                        chainPos = math.max(1, math.min(#chain, chainPos +
                                                            math.random(-1, 1)))
                    elseif sequenceMode == MODE_RANDOM then
                        chainPos = math.random(1, #chain)
                    end
                end
                -- compute step index with offset & reversal
                local real = ((idx - 1 + off) % #pat) + 1
                if rev then real = #pat + 1 - real end
                currentStepIndex = real
                local step = pat[real]

                if step ~= 0 and slot.notes and #slot.notes > 0 then
                    -- Check step probability with global modifier
                    local stepProb = slot.probabilities and slot.probabilities[real] or 100
                    local globalProbMod = self.parameters[paramIndexes.globalProbability] / 100.0
                    local effectiveProb = math.max(0, math.min(100, stepProb * globalProbMod))
                    if math.random(1, 100) <= effectiveProb then
                        raw_note = slot.notes[((step - 1) % #slot.notes) + 1]
                    end
                end
            end
        elseif playMode == PLAY_MODE_JAM then
            -- jam mode: use latched notes
            local slot = arps[arpSlot]
            local patternIdx = self.parameters[paramIndexes.pattern]
            local pat = patterns[patternNames[patternIdx]]
            local len, off, rev = slot.length, slot.offset, slot.reverse

            local notes_for_arp = {}
            for note_val in pairs(latchedNotes) do
                table.insert(notes_for_arp, note_val)
            end
            table.sort(notes_for_arp)

            if #notes_for_arp > 0 and len > 0 and #pat > 0 then
                local idx = ((stepCount - 1) % len) + 1
                local real = ((idx - 1 + off) % #pat) + 1
                if rev then real = #pat + 1 - real end
                currentStepIndex = real
                local step = pat[real]

                if step ~= 0 then
                    -- Check step probability: use global parameter in Jam mode
                    local stepProb = self.parameters[paramIndexes.stepProbability]
                    local globalProbMod = self.parameters[paramIndexes.globalProbability] / 100.0
                    local effectiveProb = math.max(0, math.min(100, stepProb * globalProbMod))
                    if math.random(1, 100) <= effectiveProb then
                        raw_note = notes_for_arp[((step - 1) % #notes_for_arp) + 1]
                    end
                end
            end
        end

        -- Always output current pitch and velocity, determine gate state separately
        local new_outputs = {}
        
        if raw_note then
            -- Get current slot for velocity and octave settings
            local currentSlot = (playMode == PLAY_MODE_SONG and #chain > 0) and arps[chain[chainPos]] or arps[arpSlot]
            
            -- Get velocity pattern: per-slot in Song mode, global parameter in Jam mode
            local currentStepVelocity = 100 -- Default velocity
            if playMode == PLAY_MODE_SONG and #chain > 0 then
                -- Song mode: use slot's saved velocity pattern
                if currentSlot.velocities and currentSlot.velocities[currentStepIndex] then
                    currentStepVelocity = currentSlot.velocities[currentStepIndex]
                end
            else
                -- Jam mode: use global velocity pattern parameter
                local velPatternIdx = math.floor(self.parameters[paramIndexes.velocityPattern])
                local velPatternName = velocityPatternNames[velPatternIdx]
                local velPattern = velocityPatterns[velPatternName]
                currentStepVelocity = velPattern and velPattern[currentStepIndex] or 100
            end
            
            local globalVelMod = self.parameters[paramIndexes.globalVelocity] / 100.0
            currentStepVelocity = math.max(0, math.min(100, currentStepVelocity * globalVelMod))
            if currentSlot.octaveJumpChance and currentSlot.octaveJumpChance > 0 then
                -- Apply global octave jump modifier
                local globalOctMod = self.parameters[paramIndexes.globalOctaveJump] / 100.0
                local effectiveOctaveChance = currentSlot.octaveJumpChance * globalOctMod
                if math.random(1, 100) <= effectiveOctaveChance then
                    local jumpRange = currentSlot.octaveJumpRange or 1
                    local octaveShift
                    if currentSlot.octaveJumpUpOnly then
                        octaveShift = math.random(1, jumpRange) * 12
                    else
                        octaveShift = math.random(-jumpRange, jumpRange) * 12
                    end
                    raw_note = math.max(0, math.min(127, raw_note + octaveShift))
                end
            end
            
            local scaleIdx = self.parameters[paramIndexes.scale]
            local rootNoteIdx = math.floor(
                                    self.parameters[paramIndexes.rootNote])
            local rootNote = rootNoteIdx - 1
            -- Quantize the raw note to the current scale just before playback.
            local note_to_play = quantizeToScale(raw_note,
                                                 scales[scaleNames[scaleIdx]],
                                                 rootNote)

            local gateLen = self.parameters[paramIndexes.gateLen]
            -- Gate length is 1-100. At 100%, use legato mode (gate stays on)
            if gateLen >= 100 then
                self.gateTime = -1 -- Special value for legato mode
            else
                -- Map 1-99% to ~5-495 ms
                self.gateTime = 5 + (gateLen * 4.9)
            end
            
            -- Update pitch and velocity for new note
            local pitch = (note_to_play - 60) / 12.0 -- V/Oct, with middle C (60) as 0V
            local velocityCV = math.min(10.0, currentStepVelocity / 100.0 * 10.0) -- Velocity CV (0-10V)
            self.lastPitch = pitch
            self.lastVelocity = velocityCV
        end
        
        -- Always output current pitch and velocity
        new_outputs[2] = self.lastPitch
        new_outputs[3] = self.lastVelocity
        
        -- Determine gate state: on for new notes, off for rests, and controlled by gateTime
        if raw_note then
            new_outputs[1] = 5.0 -- Gate on for new note
        elseif self.gateTime and (self.gateTime > 0 or self.gateTime == -1) then
            new_outputs[1] = 5.0 -- Gate stays on during gate time or legato mode
        else
            new_outputs[1] = 0.0 -- Gate off
        end
        
        return new_outputs
    end,

    ui = function(self) return true end,

    setupUi = function(self)
        -- Called when the UI is focused on this script if ui() returns true.
        -- Returns the current normalized values for the parameters controlled by pots
        -- to synchronize the hardware display/behavior.
        return potTakeoverSystem:getSetupValues(page, logicalPots)
    end,
    
    -- Handle pot turn with library modules
    handlePotTurn = function(self, potNum, value)
        local processedValue = potTakeoverSystem:processTurn(potNum, value, page, logicalPots)
        if processedValue then
            potManager:updateValue(page, potNum, processedValue)
            potDispatcher:dispatch(self, page, potNum, processedValue)
        end
    end,
    
    -- Activate takeover for page change
    activateTakeoverForPageChange = function(self, fromPage, toPage)
        potTakeoverSystem:activateForPageChange(fromPage, toPage, logicalPots)
    end,

    -- UI callbacks
    pot1Turn = function(self, v)
        self:handlePotTurn(1, v)
    end,

    pot2Turn = function(self, v)
        self:handlePotTurn(2, v)
    end,

    pot1Push = function(self)
        -- Copy/Paste slot functionality
        if page == PAGE_SLOT then
            if slotClipboard then
                -- Paste: Copy all data from clipboard to current slot
                local source = slotClipboard
                local target = arps[arpSlot]
                target.pattern = source.pattern
                target.notes = {}
                for i, note in ipairs(source.notes) do
                    target.notes[i] = note
                end
                target.length = source.length
                target.offset = source.offset
                target.reverse = source.reverse
                target.velocities = {}
                for i, vel in ipairs(source.velocities) do
                    target.velocities[i] = vel
                end
                target.probabilities = {}
                for i, prob in ipairs(source.probabilities) do
                    target.probabilities[i] = prob
                end
                target.octaveJumpChance = source.octaveJumpChance
                target.octaveJumpRange = source.octaveJumpRange
                target.octaveJumpUpOnly = source.octaveJumpUpOnly
                target.velocityPattern = source.velocityPattern
                msg, msgT = "Pasted to S" .. arpSlot, 30
            else
                -- Copy: Store current slot in clipboard
                local source = arps[arpSlot]
                slotClipboard = {
                    pattern = source.pattern,
                    notes = {},
                    length = source.length,
                    offset = source.offset,
                    reverse = source.reverse,
                    velocities = {},
                    probabilities = {},
                    octaveJumpChance = source.octaveJumpChance,
                    octaveJumpRange = source.octaveJumpRange,
                    octaveJumpUpOnly = source.octaveJumpUpOnly,
                    velocityPattern = source.velocityPattern
                }
                for i, note in ipairs(source.notes) do
                    slotClipboard.notes[i] = note
                end
                for i, vel in ipairs(source.velocities) do
                    slotClipboard.velocities[i] = vel
                end
                for i, prob in ipairs(source.probabilities) do
                    slotClipboard.probabilities[i] = prob
                end
                msg, msgT = "Copied S" .. arpSlot, 30
            end
        end
    end,

    pot2Push = function(self)
        if page == PAGE_SLOT then
            if next(latchedNotes) then
                arps[arpSlot].notes = {}
                for n in pairs(latchedNotes) do
                    table.insert(arps[arpSlot].notes, n)
                end
                table.sort(arps[arpSlot].notes)
                msg, msgT = "Notes saved to S" .. arpSlot, 30
            else
                msg, msgT = "No latched notes to save", 30
            end
        elseif page == PAGE_PATTERN then
            local patternIdx = math.floor(self.parameters[paramIndexes.pattern])
            local velPatternIdx = math.floor(self.parameters[paramIndexes.velocityPattern])
            local slot = arps[arpSlot]
            
            -- Save rhythm pattern
            slot.pattern = patternIdx
            slot.length = #patterns[patternNames[patternIdx]]
            
            -- Save velocity pattern
            slot.velocityPattern = velPatternIdx
            local velPatternName = velocityPatternNames[velPatternIdx]
            local velPattern = velocityPatterns[velPatternName]
            for i = 1, 8 do
                slot.velocities[i] = velPattern[i]
            end
            
            msg, msgT = "S" .. arpSlot .. " -> " .. patternNames[patternIdx] .. " + " .. velPatternName, 30
        elseif page == PAGE_SONG then
            local p_idx = paramIndexes.playMode
            local currentVal = self.parameters[p_idx]
            local newVal = (currentVal % #playModeLabels) + 1
            self:setParameter(p_idx, newVal)
        end
    end,

    pot3Turn = function(self, v)
        self:handlePotTurn(3, v)
    end,

    encoder1Turn = function(self, d)
        if page == PAGE_SLOT or page == PAGE_SONG then
            arpSlot = math.floor(((arpSlot - 1 + d) % 16) + 1)
            self:setParameter(paramIndexes.arpSlot, arpSlot)
            if page == PAGE_SLOT then
                msg, msgT = "Slot: " .. arpSlot, 30
            else
                msg, msgT = "Will add slot: " .. arpSlot, 30
            end
        elseif page == PAGE_PATTERN then
            -- Rhythm pattern control
            local p_idx = paramIndexes.pattern
            local currentVal = self.parameters[p_idx]
            local newVal = currentVal + d
            if newVal > #patternNames then newVal = 1 end
            if newVal < 1 then newVal = #patternNames end
            self:setParameter(p_idx, newVal)
            msg, msgT = "Pattern: " .. patternNames[math.floor(newVal)], 30
        elseif page == PAGE_SONG then
            -- Handled by pot3Turn
        elseif page == PAGE_SCALE then
            local p_idx = paramIndexes.rootNote
            local currentVal = self.parameters[p_idx]
            local newVal = currentVal + d
            if newVal > #noteNames then newVal = 1 end
            if newVal < 1 then newVal = #noteNames end
            self:setParameter(p_idx, newVal)
        end
    end,

    encoder1Push = function(self)
        if page == PAGE_SLOT or page == PAGE_SONG then
            -- add current arpSlot to chain
            table.insert(chain, arpSlot)
            msg, msgT = "Added S" .. arpSlot .. " to Chain", 30
        elseif page == PAGE_SCALE then
            -- Scale page encoder1Push not used currently
        end
    end,

    encoder2Turn = function(self, d)
        if page == PAGE_SLOT then
            local slot = arps[arpSlot]
            if slot then
                if not slot.pattern then slot.pattern = 1 end
                if self.slotEncoderMode == "offset" then
                    local maxP = #patterns[patternNames[slot.pattern]]
                    if maxP > 0 then
                        local offset = slot.offset or 0
                        slot.offset = (offset + d) % maxP
                        msg, msgT = "Offset: " .. math.floor(slot.offset), 30
                    end
                else -- length
                    local maxL = #patterns[patternNames[slot.pattern]]
                    slot.length = math.max(1, math.min(maxL, slot.length + d))
                    msg, msgT = "Length: " .. math.floor(slot.length), 30
                end
            end
        elseif page == PAGE_PATTERN then
            -- Velocity pattern control
            local p_idx = paramIndexes.velocityPattern
            local currentVal = self.parameters[p_idx]
            local newVal = currentVal + d
            if newVal > #velocityPatternNames then newVal = 1 end
            if newVal < 1 then newVal = #velocityPatternNames end
            self:setParameter(p_idx, newVal)
            msg, msgT = "VelPat: " .. velocityPatternNames[math.floor(newVal)], 30
        elseif page == PAGE_SONG then
            if #chain > 0 then
                chainPos = math.max(1, math.min(#chain, chainPos + d))
                msg, msgT = "Play Index: " .. math.floor(chainPos), 30
            end
        elseif page == PAGE_SCALE then
            local p_idx = paramIndexes.scale
            local currentVal = self.parameters[p_idx]
            local newVal = currentVal + d
            if newVal > #scaleNames then newVal = 1 end
            if newVal < 1 then newVal = #scaleNames end
            self:setParameter(p_idx, newVal)
        end
    end,

    encoder2Push = function(self)
        if page == PAGE_SLOT then
            if self.slotEncoderMode == "offset" then
                self.slotEncoderMode = "length"
                msg, msgT = "Editing Length", 30
            else
                self.slotEncoderMode = "offset"
                msg, msgT = "Editing Offset", 30
            end
        elseif page == PAGE_SONG then
            if #chain > 0 then
                local removed_val = table.remove(chain, chainPos)
                if #chain == 0 then
                    chainPos = 1
                else
                    if chainPos > #chain then
                        chainPos = #chain
                    end
                end
                msg, msgT = "Removed S" .. math.floor(removed_val), 30
            end
        elseif page == PAGE_PATTERN then
            -- Pattern page encoder2Push not used currently
        elseif page == PAGE_SCALE then
            -- Scale page encoder2Push not used currently
        end
    end,

    button1Push = function(self)
        -- Previous Page
        lastPage = page
        page = page - 1
        if page < PAGE_SLOT then page = PAGE_SONG end
        self:activateTakeoverForPageChange(lastPage, page)
    end,

    button2Push = function(self)
        -- Exit UI
        exit()
    end,

    button3Push = function(self)
        -- Toggle Help
        self.helpVisible = not self.helpVisible
    end,

    button4Push = function(self)
        -- Next Page
        lastPage = page
        page = page + 1
        if page > PAGE_SONG then page = PAGE_SLOT end
        self:activateTakeoverForPageChange(lastPage, page)
    end,

    draw = function(self)
        -- Header
        drawTinyText(10, 8, ("THORP - %s"):format(string.upper(pageNames[page])))

        if page == PAGE_SLOT then
            drawSlotPageUI(self)
        elseif page == PAGE_PATTERN then
            drawPatternPageUI(self)
        elseif page == PAGE_SCALE then
            drawScalePageUI(self)
        elseif page == PAGE_SONG then
            drawSongPageUI(self)
        end

        -- Transient message in top right corner
        if msgT > 0 then drawTinyText(200, 8, msg) end

        -- Draw help screen using helper
        drawHelpScreenUI(self)

        return true
    end,

    serialise = function(self)
        return {
            arps = arps,
            chain = chain,
            sequenceMode = sequenceMode,
            gateLen = gateLen
        }
    end,

    setParameter = function(self, index, value)
        setParameter(getCurrentAlgorithm(), self.parameterOffset + index, value)
    end,

    onParameterChanged = function(self, id, value)
        if value == nil then return end

        if id == paramIndexes.playMode then
            local playMode = value
            if playMode == PLAY_MODE_SONG then
                -- Reset to the start of the chain when song mode is enabled
                chainPos = 1
                localStep = 0
            elseif playMode == PLAY_MODE_JAM then
                latchedNotes = {}
            end
            msg, msgT = "Play Mode: " .. playModeLabels[playMode], 30
        elseif id == paramIndexes.arpSlot then
            arpSlot = math.floor(value)
        elseif id == paramIndexes.sequenceMode then
            sequenceMode = value
        end
    end
}

