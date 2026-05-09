SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local optionsFrame = nil
local optionsCategory = nil
local cooldownFrame = nil
local resizeButton = nil

local playerServer = nil
local config = {}
local tempConfig = {} -- used to copy profile settings
local profiles = {}

local upAuras = false

local DEFAULT_POINT = "CENTER"
local DEFAULT_WIDTH = 300
local DEFAULT_HEIGHT = 50

local SOUNDS = {
  None = "",
  ChestUnlock1 = SOUNDKIT.UI_GARRISON_COMMAND_TABLE_CHEST_UNLOCK,
  ChestUnlock2 = SOUNDKIT.UI_GARRISON_COMMAND_TABLE_CHEST_UNLOCK_GOLD_SUCCESS,
  DoubleBell = SOUNDKIT.AUCTION_WINDOW_CLOSE,
  Ethereal1 = SOUNDKIT.UI_ETHEREAL_WINDOW_OPEN,
  Ethereal2 = SOUNDKIT.UI_ETHEREAL_WINDOW_CLOSE,
  Keys = SOUNDKIT.KEY_RING_OPEN,
  MissionFail = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL,
  MissionSuccess = SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_MISSION_SUCCESS,
  Money = SOUNDKIT.MONEY_FRAME_OPEN,
  PageTurn = SOUNDKIT.UI_TRANSMOG_PAGE_TURN,
  PetBattle = SOUNDKIT.UI_PET_BATTLE_START,
  RaidWarning = SOUNDKIT.RAID_WARNING,
  ReadyCheck = SOUNDKIT.READY_CHECK,
  Roar = SOUNDKIT.UI_VOID_STORAGE_UNLOCK,
  SingleBell = SOUNDKIT.AUCTION_WINDOW_OPEN,
  Ship1 = SOUNDKIT.UI_GARRISON_SHIPYARD_PLACE_DREADNOUGHT,
  Ship2 = SOUNDKIT.UI_GARRISON_SHIPYARD_PLACE_SUBMARINE,
  Ship3 = SOUNDKIT.UI_GARRISON_SHIPYARD_PLACE_LANDING_CRAFT,
  ShipYard = SOUNDKIT.UI_GARRISON_SHIPYARD_START_MISSION,
  Slam = SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_FINISHED,
}

local FONTS = {
  Arial = "Fonts\\ARIALN.TTF",
  FritzQuad = "Fonts\\FRIZQT__.TTF",
  Morpheus = "Fonts\\MORPHEUS.ttf",
  Skurri = "Fonts\\skurri.ttf",
  Emblem = "Interface\\Addons\\Dontcast\\Fonts\\Emblem.ttf",
  Avengeance = "Interface\\Addons\\Dontcast\\Fonts\\Avengeance.ttf",
  BradleyGratis = "Interface\\Addons\\Dontcast\\Fonts\\BradleyGratis.ttf",
  Brave = "Interface\\Addons\\Dontcast\\Fonts\\Brave.ttf",
  ComebackHome = "Interface\\Addons\\Dontcast\\Fonts\\ComebackHome.ttf",
  Danvers = "Interface\\Addons\\Dontcast\\Fonts\\Danvers.ttf",
  Jedi = "Interface\\Addons\\Dontcast\\Fonts\\Jedi.ttf",
  Marvelous = "Interface\\Addons\\Dontcast\\Fonts\\Marvelous.ttf",
  Memoirs = "Interface\\Addons\\Dontcast\\Fonts\\Memoirs.ttf",
  Rebellion = "Interface\\Addons\\Dontcast\\Fonts\\Rebellion.ttf",
  Wakanda = "Interface\\Addons\\Dontcast\\Fonts\\Wakanda.ttf",
  Walt = "Interface\\Addons\\Dontcast\\Fonts\\Walt.ttf",
  SfDiegoSans = "Interface\\Addons\\Dontcast\\Fonts\\SF Diego Sans.ttf",
  koKR = "Fonts\\2002.ttf",
  ruRU = "Fonts\\ARIALN.TTF",
  zhCN = "Fonts\\ARKai_T.ttf",
  zhTW = "Fonts\\bkAI00M.ttf",
}

local FONT_ALIGNMENTS = {
  Left = "LEFT",
  Center = "CENTER",
  Right = "RIGHT"
}

local function colorPrint(msg)
  print("|cffb2b2b2"..msg)
end

local function errorPrint(err)
  print("|cffff0000"..err)
end

local function updateConfig(key, value)
  DontCastConfig[playerServer][key] = value
  local updated = DontCastConfig[playerServer][key] == value
  if updated then
    config = DontCastConfig[playerServer]
  end
  return updated
end

local function movingOrSizingStopped()
  local point, relativeTo, relativePoint, xOfs, yOfs = mainFrame:GetPoint(1)
  local width = mainFrame:GetWidth()
  local height = mainFrame:GetHeight()
  updateConfig("point", point)
  updateConfig("relativePoint", relativePoint)
  updateConfig("xOfs", xOfs)
  updateConfig("yOfs", yOfs)
  updateConfig("width", width)
  updateConfig("height", height)
end

local function updateCountFont(font, height)
  if not DontCastCountFont then
    CreateFont("DontCastCountFont")
  end
  DontCastCountFont:SetFont(font, height * 0.6, "OUTLINE")
  DontCastCountFont:SetTextColor(1, 1, 0.1, 0.95)
  DontCastCountFont:SetShadowColor(0.1, 0.1, 0.1, 0.9)
  DontCastCountFont:SetShadowOffset(2, -2)
  if cooldownFrame then
    cooldownFrame:SetCountdownFont("DontCastCountFont")
  end
end

local function resized(frame, width, height)
  local font = textFrame:GetFont()
  iconFrame:SetSize(height, height)
  textFrame:SetFont(font, height * 0.7)
  textFrame:SetPoint("LEFT", height * 1.1, 0)
  updateCountFont(font, height)
end

local function hideIfNotInConfig()
  if not mainFrame:IsMouseEnabled() then
    mainFrame:Hide()
  end
end

local function showAndUnlockFrame()
  textFrame:SetText("Click here to move")
  cooldownFrame:Clear()
  iconFrame:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
  resizeButton:Show()
  mainFrame:Show()
  mainFrame:EnableMouse(true)
end

local function lockFrame(hide)
  mainFrame:EnableMouse(false)
  resizeButton:Hide()
  textFrame:SetSize(mainFrame:GetWidth(), mainFrame:GetHeight())
  if hide then
    mainFrame:Hide()
  end
end

local function hideAndLockFrame()
  lockFrame(true)
end

local function centerFrame()
  mainFrame:ClearAllPoints()
  mainFrame:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT)
  mainFrame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
  movingOrSizingStopped()
  resized(mainFrame, DEFAULT_WIDTH, DEFAULT_HEIGHT)
end

local function defaultConfig()
  return {
    fontstyle = "Arial",
    fontalignment = "Left",
    aurabeginsound = "",
    auraendsound = "",
    point = DEFAULT_POINT,
    relativePoint = DEFAULT_POINT,
    xOfs = 0,
    yOfs = 0,
    width = DEFAULT_WIDTH,
    height = DEFAULT_HEIGHT
  }
end

local function swapConfigKeyValue(key, tbl)
  local curValue = DontCastConfig[playerServer][key]
  if tbl[curValue] == nil and curValue ~= "" then
    for k, v in pairs(tbl) do
      if string.lower(curValue) == string.lower(v) then DontCastConfig[playerServer][key] = k end
    end
  end
end

local function savedConfig()
  local oldGlobal = "OLDGLOBAL"
  if not DontCastConfig then
    DontCastConfig = {}
  elseif DontCastConfig[oldGlobal] == nil then
    -- config was global pre-1.4, migrate old global config
    DontCastConfig[oldGlobal] = {}
    for k, v in pairs(DontCastConfig) do
      if string.find(k, "-") == nil and string.find(k, oldGlobal) == nil then
        DontCastConfig[oldGlobal][k] = v
      end
    end
    for k, _ in pairs(DontCastConfig[oldGlobal]) do
      DontCastConfig[k] = nil
    end
  end

  if not DontCastConfig[playerServer] then
    if DontCastConfig[oldGlobal] ~= nil then
      DontCastConfig[playerServer] = DontCastConfig[oldGlobal]
    else
      DontCastConfig[playerServer] = defaultConfig()
    end
  end

  -- if user upgrades to version that introduces new config vars set to default
  for k, v in pairs(defaultConfig()) do
    if DontCastConfig[playerServer][k] == nil then DontCastConfig[playerServer][k] = v end
  end

  -- update config to use table-based options for users with pre-table configs
  swapConfigKeyValue("fontstyle", FONTS)
  swapConfigKeyValue("fontalignment", FONT_ALIGNMENTS)
  swapConfigKeyValue("aurabeginsound", SOUNDS)
  swapConfigKeyValue("auraendsound", SOUNDS)

  return DontCastConfig[playerServer]
end

local function setFontStyle(style)
  local font = FONTS[style]
  if not font then return end
  textFrame:SetFont(font, mainFrame:GetHeight() * 0.7)
  updateCountFont(font, mainFrame:GetHeight())
  updateConfig("fontstyle", style)
  movingOrSizingStopped()
end

local function setFontAlignment(justification)
  local alignment = FONT_ALIGNMENTS[justification]
  if not alignment then return end
  textFrame:SetJustifyH(alignment)
  updateConfig("fontalignment", alignment)
  movingOrSizingStopped()
end

local function getMajorDefensives(unit)
  local result = {}
  AuraUtil.ForEachAura(unit, "HELPFUL|BIG_DEFENSIVE", nil, function(auraData)
    table.insert(result, auraData)
  end, true)
  AuraUtil.ForEachAura(unit, "HELPFUL|EXTERNAL_DEFENSIVE", nil, function(auraData)
    table.insert(result, auraData)
  end, true)
  return result
end

local function targetIsHostile()
  return UnitIsEnemy("player", "target") or UnitCanAttack("player", "target")
end

local function setAura(name, icon, durationSecret)
  if name then
    textFrame:SetText(name)
    iconFrame:SetTexture(icon)
    if durationSecret then
      cooldownFrame:SetCooldownFromDurationObject(durationSecret)
    else
      cooldownFrame:Clear()
    end
    if not mainFrame:IsShown() and SOUNDS[config.aurabeginsound] ~= nil then
      PlaySound(SOUNDS[config.aurabeginsound], "Master")
    end
    mainFrame:Show()
    upAuras = true
    return true
  end
  return false
end

local function auraUpdated(self, event, unit, ...)
  if unit == "target" and targetIsHostile() then
    local defensives = getMajorDefensives(unit)
    local hasAura = false
    if #defensives > 0 then
      local first = defensives[1]
      local durationSecret = C_UnitAuras.GetAuraDuration and first.auraInstanceID
        and C_UnitAuras.GetAuraDuration(unit, first.auraInstanceID)
      hasAura = setAura(first.name, first.icon, durationSecret)
    end

    if not hasAura then
      if upAuras then
        if SOUNDS[config.auraendsound] ~= nil then
          PlaySound(SOUNDS[config.auraendsound], "Master")
        end
        upAuras = false
      end
      cooldownFrame:Clear()
      hideIfNotInConfig()
    end
  end
end

local function targetChanged(self, event, unit, ...)
  upAuras = false
  if targetIsHostile() then
    auraUpdated(self, event, "target")
  else
    hideIfNotInConfig()
  end
end

local function fontStyleSelected(self)
  setFontStyle(self.value)
end

local function fontAlignmentSelected(self)
  setFontAlignment(self.value)
end

local function createButton(text, parent)
  local button = CreateFrame("Button", "DontCast"..text.."Button", parent, "UIPanelButtonTemplate")
  button:SetHeight(20)
  button:SetWidth(100)
  button:SetText(text)
  button:ClearAllPoints()
  return button
end

local function sortedKeys(tbl)
  local sorted = {}
  for k, _ in pairs(tbl) do
    table.insert(sorted, k)
  end
  table.sort(sorted)

  return sorted
end

local function auraSoundDropDownEntries()
  local sorted = {}
  for k, v in pairs(SOUNDS) do
    if k ~= "None" then table.insert(sorted, k) end
  end
  table.sort(sorted)
  table.insert(sorted, 1, "None")

  return sorted
end

local function createDropDown(name, parent, callback, tableValues, selectedValue)
  local SelectBox = LibStub:GetLibrary("SelectBox")
  local dropdown = SelectBox:Create(name, parent, 120, callback, function() return tableValues end, selectedValue)
  dropdown:ClearAllPoints()
  dropdown:UpdateValue()
  return dropdown
end

local function createLabel(text, parent, xOffset, yOffset)
  local label = parent:CreateFontString("DontCast"..text.."Label", "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", xOffset, yOffset)
  label:SetText(text)
  return label
end

local function drawPositioningOptions(parent, xOffset, yOffset)
  local unlockButton = createButton("Unlock", parent)
  local lockButton = createButton("Lock", parent)
  local centerButton = createButton("Center", parent)
  local buttonWidth = unlockButton:GetWidth()

  unlockButton:SetPoint("TOPLEFT", xOffset, yOffset)
  unlockButton:SetScript("PostClick", showAndUnlockFrame)

  lockButton:SetPoint("TOPLEFT", xOffset * 2 + buttonWidth, yOffset)
  lockButton:SetScript("PostClick", hideAndLockFrame)

  centerButton:SetPoint("TOPLEFT", xOffset * 3 + buttonWidth * 2, yOffset)
  centerButton:SetScript("PostClick", centerFrame)
end

local function getSelectedFontStyle()
  return config.fontstyle
end

local function getSelectedFontAlignment()
  return config.fontalignment
end

local function drawFontStyleOptions(parent, xOffset, yOffset)
  local label = createLabel("Font", parent, xOffset, yOffset)

  local fonts = sortedKeys(FONTS)
  local selectedFont = getSelectedFontStyle()
  parent.fontstyle = createDropDown("DontCastFontStyle", parent, fontStyleSelected, fonts, selectedFont)
  parent.fontstyle:SetPoint("LEFT", label, "RIGHT", 0, 0)

  local fontAlignments = sortedKeys(FONT_ALIGNMENTS)
  local selectedAlign = getSelectedFontAlignment()
  parent.fontalignment = createDropDown("DontCastFontAlignment", parent, fontAlignmentSelected, fontAlignments, selectedAlign)
  parent.fontalignment:SetPoint("LEFT", parent.fontstyle, "RIGHT", 60, 0)
end

local function beginSoundSelected(self)
  if SOUNDS[self.value] ~= nil then PlaySound(SOUNDS[self.value], "Master") end
  config.aurabeginsound = self.value
end

local function endSoundSelected(self)
  if SOUNDS[self.value] ~= nil then PlaySound(SOUNDS[self.value], "Master") end
  config.auraendsound = self.value
end

local function getSelectedBeginSound()
  return config.aurabeginsound
end

local function getSelectedEndSound()
  return config.auraendsound
end

local function drawSoundOptions(parent, xOffset, yOffset)
  local sounds = auraSoundDropDownEntries()

  local beginLabel = createLabel("Aura begins sound", parent, xOffset, yOffset)
  local selectedBegin = getSelectedBeginSound()
  parent.aurabeginsound = createDropDown("DontCastAuraBeginSound", parent, beginSoundSelected, sounds, selectedBegin)
  parent.aurabeginsound:SetPoint("LEFT", beginLabel, "RIGHT", 0, 0)
  parent.aurabeginsound:SetWidth(140)

  local endLabel = createLabel("Aura ends sound", parent, xOffset, yOffset - 40)
  local selectedEnd = getSelectedEndSound()
  parent.auraendsound = createDropDown("DontCastAuraEndSound", parent, endSoundSelected, sounds, selectedEnd)
  parent.auraendsound:SetPoint("LEFT", endLabel, "RIGHT", 0, 0)
  parent.auraendsound:SetWidth(140)
end

local function reloadDropDowns()
  optionsFrame.fontstyle:SetText(getSelectedFontStyle())
  optionsFrame.fontalignment:SetText(getSelectedFontAlignment())
  optionsFrame.aurabeginsound:SetText(getSelectedBeginSound())
  optionsFrame.auraendsound:SetText(getSelectedEndSound())
end

local function copyConfigSelected(self)
  tempConfig.copyconfig = self.value
  local profileToCopy = profiles[self.value]
  if not profileToCopy then return end
  for k, v in pairs(profileToCopy) do
    tempConfig[k] = v
    config[k] = v
  end
  setFontStyle(tempConfig.fontstyle)
  setFontAlignment(tempConfig.fontalignment)
  if tempConfig.point ~= nil then
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(tempConfig.point, UIParent, tempConfig.relativePoint, tempConfig.xOfs, tempConfig.yOfs)
    mainFrame:SetSize(tempConfig.width, tempConfig.height)
  end
  reloadDropDowns()
end

local function copyConfigEntries()
  local tbl = {}
  for k, v in pairs(DontCastConfig) do
    if k ~= "OLDGLOBAL" then tbl[k] = v end
  end
  return tbl
end

local function drawCopyConfigOptions(parent, xOffset, yOffset)
  local label = createLabel("Copy configuration from", parent, xOffset, yOffset)
  local selected = tempConfig.copyconfig ~= nil and tempConfig.copyconfig or playerServer
  local profileNames = sortedKeys(profiles)
  parent.copyconfig = createDropDown("DontCastCopyConfig", parent, copyConfigSelected, profileNames, selected)
  parent.copyconfig:SetPoint("LEFT", label, "RIGHT", 0, 0)
  parent.copyconfig:SetWidth(225)
end

local function updateOptionsUI()
  reloadDropDowns()
end

local function createOptionsPanel()
  local xOffset = 20
  optionsFrame = CreateFrame("Frame", "DontCastOptions", UIParent)
  optionsFrame.name = "DontCast"

  optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsFrame, optionsFrame.name, optionsFrame.name)
  Settings.RegisterAddOnCategory(optionsCategory)

  optionsFrame.title = optionsFrame:CreateFontString("DontCastOptionsTitle", "OVERLAY", "GameFontNormalLarge")
  optionsFrame.title:SetPoint("TOPLEFT", xOffset, -20)
  optionsFrame.title:SetText("DontCast Options")

  profiles = copyConfigEntries()

  drawPositioningOptions(optionsFrame, xOffset, -50)
  drawFontStyleOptions(optionsFrame, xOffset, -90)
  drawSoundOptions(optionsFrame, xOffset, -130)
  drawCopyConfigOptions(optionsFrame, xOffset, -230)

  updateOptionsUI()
end

-- 7.3 changed the sound API to take a constant
-- instead of a string to specify the sound to play,
-- update old config strings to current table keys
local function updateSoundConfig()
  local soundKitIds = {
    AuctionWindowOpen = "SingleBell",
    AuctionWindowClose = "DoubleBell",
  }

  if soundKitIds[config.aurabeginsound] ~= nil then
    updateConfig("aurabeginsound", soundKitIds[config.aurabeginsound])
  end

  if soundKitIds[config.auraendsound] ~= nil then
    updateConfig("auraendsound", soundKitIds[config.auraendsound])
  end
end

local function eventHandler(self, event, unit, ...)
  if event == "UNIT_AURA" then
    auraUpdated(self, event, unit)
  elseif event == "PLAYER_TARGET_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
    targetChanged(self, event, unit)
  elseif event == "PLAYER_REGEN_DISABLED" then
    lockFrame(false)
  elseif event == "ADDON_LOADED" and unit == "DontCast" then
    playerServer = UnitName("player").." - "..GetRealmName()
    config = savedConfig()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(config.point, UIParent, config.relativePoint, config.xOfs, config.yOfs)
    updateSoundConfig()
    createOptionsPanel()
    setFontStyle(config.fontstyle)
    setFontAlignment(config.fontalignment)
  end
end

function registerFonts()
  local SharedMedia = LibStub("LibSharedMedia-3.0")
  local fonts = {
    "Avengeance",
    "BradleyGratis",
    "Brave",
    "ComebackHome",
    "Danvers",
    "Emblem",
    "Jedi",
    "Marvelous",
    "Memoirs",
    "Rebellion",
    "Wakanda",
    "Walt"
  }
  for _, font in ipairs(fonts) do
    SharedMedia:Register(SharedMedia.MediaType.FONT, font, "Interface\\Addons\\DontCast\\Fonts\\"..font..".ttf", SharedMedia.LOCALE_BIT_western)
  end
end

function loadDontCast(self, text, icon, cooldown)
  if self and text and icon and cooldown then
    mainFrame = self
    textFrame = text
    iconFrame = icon
    cooldownFrame = cooldown

    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton", "RightButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function()
      mainFrame:StopMovingOrSizing()
      movingOrSizingStopped()
    end)

    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(32, 16, 512, 256)
    mainFrame:SetScript("OnSizeChanged", resized)

    resizeButton = CreateFrame("Button", "DontCastResizeFrame", mainFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT")
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function()
      mainFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function()
      mainFrame:StopMovingOrSizing()
      movingOrSizingStopped()
    end)

    local eventFrame = CreateFrame("Frame", "DontCastEventFrame", UIParent)
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", eventHandler)

    lockFrame(true)
    registerFonts()
  else
    errorPrint("Unable to load DontCast!")
  end
end

SlashCmdList["DONTCAST"] = function(cmd)
  if mainFrame and textFrame and iconFrame then
    if cmd == "show" or cmd == "unlock" then
      colorPrint("Drag text or icon to move, lower-right-corner to resize, when done type /dontcast hide")
      showAndUnlockFrame()
    elseif cmd == "hide" or cmd == "lock" then
      lockFrame(true)
    elseif cmd == "center" then
      centerFrame()
    elseif string.match(cmd, "config%w*") then
      if optionsCategory then
        Settings.OpenToCategory(optionsCategory:GetID())
      end
      updateOptionsUI() -- values may have been modified via slash commands
    else
      colorPrint("DontCast commands:")
      print("/dontcast show - Shows the addon for repositioning and resizing")
      print("/dontcast hide - Hides (and locks) the frame")
      print("/dontcast center - Sets the position to center of screen")
      print("/dontcast config - Opens the options panel")
      print("/dontcast ? or /dontcast help - Prints this list")
    end
  else
    errorPrint("Error loading DontCast!")
  end
end
