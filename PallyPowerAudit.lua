local ADDON_NAME = ...

local Audit = CreateFrame("Frame")
local MAX_ENTRIES = 200
local isHooked = false
local LOG_WINDOW_WIDTH = 380
local LOG_WINDOW_HEIGHT = 240
local LOG_WINDOW_PADDING = 12
local LOG_WINDOW_TARGETS = {
    "PallyPowerFrame",
    "PallyPowerMainFrame",
    "PallyPower",
}

local DEFAULT_DB = {
    entries = {},
    showRaw = false,
    windowShown = true,
    windowDocked = true,
    windowPoint = nil,
    windowRelativePoint = nil,
    windowX = nil,
    windowY = nil,
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

local logWindow
local logWindowMessageFrame

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

local function FormatTimestampLine(entry)
    local timestamp = date("%H:%M:%S", entry.time or time())
    local line = string.format("%s %s: %s", timestamp, entry.sender or "unknown", entry.summary or entry.message or "")

    if PallyPowerAuditDB.showRaw then
        line = line .. string.format(" | raw=%s:%s", tostring(entry.prefix), tostring(entry.message))
    end

    return line
end

local function FindDockTarget()
    for index = 1, #LOG_WINDOW_TARGETS do
        local target = _G[LOG_WINDOW_TARGETS[index]]
        if type(target) == "table" and target.IsShown and target:IsShown() then
            return target
        end
    end

    if EnumerateFrames then
        for frame in EnumerateFrames() do
            if frame ~= logWindow and frame.IsShown and frame:IsShown() then
                local name = frame.GetName and frame:GetName()
                if type(name) == "string" and name ~= "PallyPowerAuditLogWindow" and name:find("PallyPower", 1, true) then
                    return frame
                end
            end
        end
    end

    return nil
end

local function SaveWindowPosition()
    if not logWindow then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = logWindow:GetPoint(1)
    PallyPowerAuditDB.windowPoint = point
    PallyPowerAuditDB.windowRelativePoint = relativePoint
    PallyPowerAuditDB.windowX = xOfs
    PallyPowerAuditDB.windowY = yOfs
end

local function ApplyWindowLayout(preserveCurrent)
    if not logWindow then
        return
    end

    if PallyPowerAuditDB.windowDocked then
        local dockTarget = FindDockTarget()
        if dockTarget then
            logWindow:ClearAllPoints()
            logWindow:SetPoint("TOPLEFT", dockTarget, "TOPRIGHT", 8, 0)
            return
        end
    end

    if PallyPowerAuditDB.windowPoint and PallyPowerAuditDB.windowRelativePoint and PallyPowerAuditDB.windowX and PallyPowerAuditDB.windowY then
        logWindow:ClearAllPoints()
        logWindow:SetPoint(PallyPowerAuditDB.windowPoint, UIParent, PallyPowerAuditDB.windowRelativePoint, PallyPowerAuditDB.windowX, PallyPowerAuditDB.windowY)
        return
    end

    if preserveCurrent then
        return
    end

    logWindow:ClearAllPoints()
    logWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function AddWindowMessage(line)
    if not logWindowMessageFrame then
        return
    end

    logWindowMessageFrame:AddMessage(line, 1, 1, 1)
end

local function PopulateWindowFromDB()
    EnsureDB()

    if not logWindowMessageFrame then
        return
    end

    for index = #PallyPowerAuditDB.entries, 1, -1 do
        AddWindowMessage(FormatTimestampLine(PallyPowerAuditDB.entries[index]))
    end
end

local function CreateLogWindow()
    if logWindow then
        return logWindow
    end

    local frame = CreateFrame("Frame", "PallyPowerAuditLogWindow", UIParent, "BackdropTemplate")
    frame:SetSize(LOG_WINDOW_WIDTH, LOG_WINDOW_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetResizeBounds then
        frame:SetResizeBounds(300, 180, 900, 700)
    else
        if frame.SetMinResize then
            frame:SetMinResize(300, 180)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(900, 700)
        end
    end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.96)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PallyPowerAuditDB.windowDocked = false
        SaveWindowPosition()
    end)

    frame:SetScript("OnShow", function()
        if logWindowMessageFrame then
            logWindowMessageFrame:ScrollToBottom()
        end
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not PallyPowerAuditDB.windowDocked or not self:IsShown() then
            return
        end

        self._dockCheck = (self._dockCheck or 0) + elapsed
        if self._dockCheck < 0.5 then
            return
        end

        self._dockCheck = 0
        ApplyWindowLayout(true)
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", LOG_WINDOW_PADDING, -10)
    title:SetText("PallyPowerAudit")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Audit log")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    closeButton:SetScript("OnClick", function()
        PallyPowerAuditDB.windowShown = false
        frame:Hide()
    end)

    local messageFrame = CreateFrame("ScrollingMessageFrame", nil, frame)
    messageFrame:SetPoint("TOPLEFT", LOG_WINDOW_PADDING, -54)
    messageFrame:SetPoint("BOTTOMRIGHT", -24, LOG_WINDOW_PADDING)
    messageFrame:SetFontObject(GameFontHighlightSmall)
    messageFrame:SetJustifyH("LEFT")
    messageFrame:SetFading(false)
    messageFrame:SetMaxLines(MAX_ENTRIES)
    messageFrame:SetSpacing(2)
    messageFrame:EnableMouseWheel(true)
    messageFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeGrip:SetScript("OnMouseDown", function(self)
        self:GetParent():StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function(self)
        self:GetParent():StopMovingOrSizing()
        SaveWindowPosition()
    end)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

    logWindow = frame
    logWindowMessageFrame = messageFrame
    ApplyWindowLayout(false)
    PopulateWindowFromDB()

    if PallyPowerAuditDB.windowShown ~= false then
        frame:Show()
    else
        frame:Hide()
    end

    return frame
end

local function ShowLogWindow()
    EnsureDB()
    CreateLogWindow()
    PallyPowerAuditDB.windowShown = true
    ApplyWindowLayout(false)
    logWindow:Show()
    if logWindowMessageFrame then
        logWindowMessageFrame:ScrollToBottom()
    end
end

local function HideLogWindow()
    if logWindow then
        logWindow:Hide()
    end
    EnsureDB()
    PallyPowerAuditDB.windowShown = false
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

    AddWindowMessage(FormatTimestampLine(entry))
    if logWindowMessageFrame then
        logWindowMessageFrame:ScrollToBottom()
    end
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

    ShowLogWindow()

    if #PallyPowerAuditDB.entries == 0 then
        Print("no entries yet")
    end
end

local function HandleSlashCommand(input)
    EnsureDB()

    local command = string.lower((input or ""):match("^(%S+)") or "show")

    if command == "clear" then
        PallyPowerAuditDB.entries = {}
        if logWindow then
            logWindow:Hide()
            logWindow = nil
            logWindowMessageFrame = nil
        end
        CreateLogWindow()
        ShowLogWindow()
        Print("cleared local audit history")
        return
    end

    if command == "raw" then
        PallyPowerAuditDB.showRaw = not PallyPowerAuditDB.showRaw
        if logWindow then
            logWindow:Hide()
            logWindow = nil
            logWindowMessageFrame = nil
        end
        CreateLogWindow()
        ShowLogWindow()
        Print("raw logging is now " .. (PallyPowerAuditDB.showRaw and "on" or "off"))
        return
    end

    if command == "hide" then
        HideLogWindow()
        return
    end

    if command == "window" then
        if PallyPowerAuditDB.windowDocked then
            PallyPowerAuditDB.windowDocked = false
            ShowLogWindow()
            SaveWindowPosition()
            Print("window is now undocked")
        else
            PallyPowerAuditDB.windowDocked = true
            ShowLogWindow()
            Print("window is now docked when PallyPower is visible")
        end
        return
    end

    if command == "status" then
        Print("PallyPower loaded: " .. (type(PallyPower) == "table" and "yes" or "no"))
        Print("PallyPower SendMessage: " .. (type(PallyPower) == "table" and type(PallyPower.SendMessage) == "function" and "yes" or "no"))
        Print("local hook: " .. (isHooked and "yes" or "no"))
        Print("raw logging: " .. (PallyPowerAuditDB.showRaw and "on" or "off"))
        Print("window shown: " .. (PallyPowerAuditDB.windowShown and "yes" or "no"))
        Print("window docked: " .. (PallyPowerAuditDB.windowDocked and "yes" or "no"))
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
            CreateLogWindow()
            Print("loaded. Use /ppaudit to manage the audit window.")
        end
        if loadedAddon == "PallyPower" then
            TryHookPallyPower()
            if logWindow then
                ApplyWindowLayout(true)
            end
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if logWindow then
            ApplyWindowLayout(true)
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
Audit:RegisterEvent("PLAYER_LOGIN")
Audit:RegisterEvent("CHAT_MSG_ADDON")

SLASH_PALLYPOWERAUDIT1 = "/ppaudit"
SlashCmdList.PALLYPOWERAUDIT = HandleSlashCommand
