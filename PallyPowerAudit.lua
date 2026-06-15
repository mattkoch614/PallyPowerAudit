local ADDON_NAME = ...

local Audit = CreateFrame("Frame")
local MAX_ENTRIES = 200

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
    [4] = "Sanctuary",
    [5] = "Light",
    [6] = "Salvation",
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

local function FormatClass(value)
    if not value then
        return "unknown"
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

    if command == "AASSIGN" then
        local paladin, aura = rest:match("^(%S+)%s+(%S+)")
        if paladin and aura then
            return string.format("set aura for %s to %s", TrimRealm(paladin), tostring(aura))
        end
    end

    return message
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

    ShowEntries()
end

Audit:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            EnsureDB()
            RegisterPrefixes()
            Print("loaded. Use /ppaudit to show recent entries.")
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if PREFIX_CANDIDATES[prefix] then
            AddEntry(prefix, message, channel, sender)
        end
    end
end)

Audit:RegisterEvent("ADDON_LOADED")
Audit:RegisterEvent("CHAT_MSG_ADDON")

SLASH_PALLYPOWERAUDIT1 = "/ppaudit"
SlashCmdList.PALLYPOWERAUDIT = HandleSlashCommand
