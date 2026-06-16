local ADDON_NAME = ...

local Audit = CreateFrame("Frame")
local MAX_ENTRIES = 200
local isHooked = false

local DEFAULT_DB = {
    entries = {},
    showRaw = false,
}

local PREFIX_CANDIDATES = {
    PallyPower = true,
    PLPWR = true,
    PP = true,
}

local CLASS_NAMES = {
    [1] = "Warrior",
    [2] = "Rogue",
    [3] = "Priest",
    [4] = "Druid",
    [5] = "Paladin",
    [6] = "Hunter",
    [7] = "Mage",
    [8] = "Warlock",
    [9] = "Shaman",
    [10] = "Death Knight",
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}

local BLESSING_NAMES = {
    [0] = "None",
    [1] = "Wisdom",
    [2] = "Might",
    [3] = "Kings",
    [4] = "Salvation",
    [5] = "Light",
    [6] = "Sanctuary",
    [7] = "Sacrifice",
}

local AURA_NAMES = {
    [0] = "None",
    [1] = "Devotion",
    [2] = "Retribution",
    [3] = "Concentration",
    [4] = "Shadow Resistance",
    [5] = "Frost Resistance",
    [6] = "Fire Resistance",
    [7] = "Sanctity",
    [8] = "Crusader",
}

local ASSIGNMENT_COMMANDS = {
    ASSIGN = true,
    PASSIGN = true,
    MASSIGN = true,
    NASSIGN = true,
    AASSIGN = true,
    CLEAR = true,
}

local function EnsureDB()
    if type(PallyPowerAuditDB) ~= "table" then
        PallyPowerAuditDB = {}
    end

    for key, value in pairs(DEFAULT_DB) do
        if PallyPowerAuditDB[key] == nil then
            if type(value) == "table" then
                PallyPowerAuditDB[key] = {}
            else
                PallyPowerAuditDB[key] = value
            end
        end
    end
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PallyPowerAudit|r: " .. tostring(message))
end

local function TrimRealm(name)
    if type(name) ~= "string" then
        return "unknown"
    end

    return name:match("^([^%-]+)") or name
end

local function FormatBlessing(value)
    local numberValue = tonumber(value)
    return BLESSING_NAMES[numberValue] or tostring(value or "unknown")
end

local function FormatAura(value)
    local numberValue = tonumber(value)
    return AURA_NAMES[numberValue] or tostring(value or "unknown")
end

local function FormatClass(value)
    if not value then
        return "unknown"
    end

    local numberValue = tonumber(value)
    if numberValue and CLASS_NAMES[numberValue] then
        return CLASS_NAMES[numberValue]
    end

    local upperValue = string.upper(tostring(value))
    return CLASS_NAMES[upperValue] or tostring(value)
end

local function ParseMessage(message)
    if type(message) ~= "string" then
        return "unknown change"
    end

    local command, rest = message:match("^(%S+)%s*(.*)$")
    if not command then
        return message
    end

    command = string.upper(command)

    if command == "CLEAR" then
        return "cleared assignments"
    end

    if command == "ASSIGN" then
        local paladin, classToken, blessing = rest:match("^(%S+)%s+(%S+)%s+(%S+)")
        if paladin and classToken and blessing then
            return string.format(
                "set %s class blessing for %s to %s",
                FormatClass(classToken),
                TrimRealm(paladin),
                FormatBlessing(blessing)
            )
        end
    end

    if command == "NASSIGN" then
        local paladin, classToken, player, blessing = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        if paladin and classToken and player and blessing then
            return string.format(
                "set %s blessing for %s via %s to %s",
                FormatClass(classToken),
                TrimRealm(player),
                TrimRealm(paladin),
                FormatBlessing(blessing)
            )
        end
    end

    if command == "MASSIGN" then
        local paladin, blessing = rest:match("^(%S+)%s+(%S+)")
        if paladin and blessing then
            return string.format(
                "set all class blessings for %s to %s",
                TrimRealm(paladin),
                FormatBlessing(blessing)
            )
        end
    end

    if command == "PASSIGN" then
        local paladin, assignments = rest:match("^(%S+)@(%S+)")
        if paladin and assignments then
            return string.format("updated packed class assignments for %s", TrimRealm(paladin))
        end
    end

    if command == "AASSIGN" then
        local paladin, aura = rest:match("^(%S+)%s+(%S+)")
        if paladin and aura then
            return string.format("set aura for %s to %s", TrimRealm(paladin), FormatAura(aura))
        end
    end

    return message
end

local function BuildMessage(command, ...)
    local argCount = select("#", ...)
    if argCount == 0 then
        return command
    end

    local parts = { command }
    for index = 1, argCount do
        parts[#parts + 1] = tostring(select(index, ...))
    end

    return table.concat(parts, " ")
end

local function IsAssignmentMessage(message)
    if type(message) ~= "string" then
        return false
    end

    local command = message:match("^(%S+)")
    return command and ASSIGNMENT_COMMANDS[string.upper(command)] or false
end

local function AddEntry(prefix, message, channel, sender)
    EnsureDB()

    local entry = {
        time = time(),
        prefix = prefix,
        message = message,
        channel = channel,
        sender = TrimRealm(sender),
        summary = ParseMessage(message),
    }

    table.insert(PallyPowerAuditDB.entries, 1, entry)

    while #PallyPowerAuditDB.entries > MAX_ENTRIES do
        table.remove(PallyPowerAuditDB.entries)
    end

    Print(string.format("%s: %s", entry.sender, entry.summary))
end

local function TryHookPallyPower()
    if isHooked then
        return
    end

    if type(PallyPower) ~= "table" or type(PallyPower.SendMessage) ~= "function" then
        return
    end

    hooksecurefunc(PallyPower, "SendMessage", function(_, command, ...)
        if type(command) == "string" then
            local commandName = command:match("^(%S+)")
            if commandName then
                commandName = string.upper(commandName)
                if ASSIGNMENT_COMMANDS[commandName] then
                    AddEntry("PallyPower:SendMessage", BuildMessage(command, ...), "LOCAL", UnitName("player"))
                elseif PallyPowerAuditDB and PallyPowerAuditDB.showRaw then
                    AddEntry("PallyPower:SendMessage", BuildMessage(command, ...), "LOCAL", UnitName("player"))
                end
            end
        end
    end)

    isHooked = true
    Print("hooked PallyPower assignment messages")
end

local function RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
        return
    end

    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(prefix)
    end
end

local function RegisterPrefixes()
    for prefix in pairs(PREFIX_CANDIDATES) do
        RegisterPrefix(prefix)
    end
end

local function ShowEntries()
    EnsureDB()

    if #PallyPowerAuditDB.entries == 0 then
        Print("no entries yet")
        return
    end

    Print("recent entries:")

    local limit = math.min(#PallyPowerAuditDB.entries, 20)
    for index = 1, limit do
        local entry = PallyPowerAuditDB.entries[index]
        local timestamp = date("%H:%M:%S", entry.time or time())
        local line = string.format("%s %s: %s", timestamp, entry.sender or "unknown", entry.summary or entry.message or "")

        if PallyPowerAuditDB.showRaw then
            line = line .. string.format(" | raw=%s:%s", tostring(entry.prefix), tostring(entry.message))
        end

        Print(line)
    end
end

local function HandleSlashCommand(input)
    EnsureDB()

    local command = string.lower((input or ""):match("^(%S+)") or "show")

    if command == "clear" then
        PallyPowerAuditDB.entries = {}
        Print("cleared local audit history")
        return
    end

    if command == "raw" then
        PallyPowerAuditDB.showRaw = not PallyPowerAuditDB.showRaw
        Print("raw logging is now " .. (PallyPowerAuditDB.showRaw and "on" or "off"))
        return
    end

    if command == "status" then
        Print("PallyPower loaded: " .. (type(PallyPower) == "table" and "yes" or "no"))
        Print("PallyPower SendMessage: " .. (type(PallyPower) == "table" and type(PallyPower.SendMessage) == "function" and "yes" or "no"))
        Print("local hook: " .. (isHooked and "yes" or "no"))
        Print("raw logging: " .. (PallyPowerAuditDB.showRaw and "on" or "off"))
        return
    end

    ShowEntries()
end

Audit:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            EnsureDB()
            RegisterPrefixes()
            TryHookPallyPower()
            Print("loaded. Use /ppaudit to show recent entries.")
        end
        if loadedAddon == "PallyPower" then
            TryHookPallyPower()
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if PREFIX_CANDIDATES[prefix] and IsAssignmentMessage(message) then
            AddEntry(prefix, message, channel, sender)
        end
    end
end)

Audit:RegisterEvent("ADDON_LOADED")
Audit:RegisterEvent("CHAT_MSG_ADDON")

SLASH_PALLYPOWERAUDIT1 = "/ppaudit"
SlashCmdList.PALLYPOWERAUDIT = HandleSlashCommand
