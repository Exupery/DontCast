SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local optionsFrame = nil
local cdTextFrame = nil
local resizeButton = nil

local playerServer = nil
local config = {}
local tempConfig = {}
local auras = {}

local upAuras = {}
local updCtr = 0

local BASE = "base"
local MAGICAL = "magical"
local PHYSICAL = "physical"

local function colorPrint(msg)
  print("|cffb2b2b2"..msg)
end

local function errorPrint(err)
  print("|cffff0000"..err)
end

local function hideIfNotInConfig()
  if not mainFrame:IsMouseEnabled() then
    mainFrame:Hide()
  end
end

local function showAndUnlockFrame()
  textFrame:SetText("Click here to move")
  cdTextFrame:SetText("")
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
  mainFrame:SetPoint("CENTER", UIParent, "CENTER")
end

local function defaultConfig()
  return {
    threshold = 1.5,
    fontstyle = "Fonts\\skurri.ttf",
    fontalignment = "LEFT",
    aurabeginsound = "",
    auraendsound = ""
  }
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

  return DontCastConfig[playerServer]
end

local function updateConfig(key, value)
  DontCastConfig[playerServer][key] = value
  local updated = DontCastConfig[playerServer][key] == value
  if updated then
    config = DontCastConfig[playerServer]
  end
  return updated
end

local function setFontStyle(style)
  cdTextFrame:SetFont(style, mainFrame:GetHeight() * 0.6)
  textFrame:SetFont(style, mainFrame:GetHeight() * 0.75)
end

local function setFontAlignment(justification)
  textFrame:SetJustifyH(justification)
end

local function addAurasToList(list, values)
  for _, id in ipairs(values) do
    local name = GetSpellInfo(id)
    list[name] = true
  end
end

local function defaultBaseAuras()
  return {
    186265, -- Aspect of the Turtle
    33786,  -- Cyclone
    19263,  -- Deterrence
    47585,  -- Dispersion
    642,    -- Divine Shield
    228049, -- Guardian of the Forgotten Queen
    45438,  -- Ice Block
    221527, -- Imprison
    196555, -- Netherwalk
    115078, -- Paralysis
    28272,  -- Polymorph
    184662, -- Shield of Vengeance
    76577,  -- Smoke Bomb
    198111, -- Temporal Shield
    122470, -- Touch of Karma
  }
end

local function defaultMagicalAuras()
  return {
    48707,  -- Anti-Magic Shell
    204018, -- Blessing of Spellwarding
    31224,  -- Cloak of Shadows
    122783, -- Diffuse Magic
    212295, -- Nether Ward
    23920,  -- Spell Reflection
  }
end

local function defaultPhysicalAuras()
  return {
    1022,   -- Blessing of Protection
    118038, -- Die by the Sword
    210918, -- Ethereal Form
    199754, -- Riposte
  }
end

local function defaultAuras()
  local defaults = {}
  defaults[BASE] = defaultBaseAuras()
  defaults[MAGICAL] = defaultMagicalAuras()
  defaults[PHYSICAL] = defaultPhysicalAuras()
  return defaults
end

local function isCasterOrHealer()
  -- return early if spec not set yet (i.e. addon may get loaded before GetSpecialization returns non-nil value)
  -- defaulting to true since addon was originally written for casters but this shouldn't
  -- end up mattering as the auras assignment will get re-called when ACTIVE_TALENT_GROUP_CHANGED fires
  if GetSpecialization() == nil then return true end

  local specId = GetSpecializationInfo(GetSpecialization())

  local casterIds = {[62] = true, [63] = true, [64] = true, [102] = true, [258] = true, [262] = true, [265] = true, [266] = true, [267] = true}

  local healerIds = {[65] = true, [105] = true, [256] = true, [257] = true, [264] = true, [270] = true}

  return casterIds[specId] or healerIds[specId]
end

-- adds values from secondTable to firstTable
local function mergeTables(firstTable, secondTable)
  for k, v in pairs(secondTable) do firstTable[k] = v end
end

local function savedAuras()
  if not DontCastAuras then
    DontCastAuras = {}
  end

  if DontCastAuras[BASE] == nil then
    DontCastAuras[BASE] = {}
    -- migrate pre-1.4 auras to handle user-added auras
    for k, v in pairs(DontCastAuras) do
      if string.find(k, BASE) == nil then
        DontCastAuras[BASE][k] = v
      end
    end
    for k, _ in pairs(DontCastAuras[BASE]) do
      DontCastAuras[k] = nil
    end
    addAurasToList(DontCastAuras[BASE], defaultBaseAuras())
  end

  if DontCastAuras[MAGICAL] == nil then
    DontCastAuras[MAGICAL] = {}
    addAurasToList(DontCastAuras[MAGICAL], defaultMagicalAuras())
  end

  if DontCastAuras[PHYSICAL] == nil then
    DontCastAuras[PHYSICAL] = {}
    addAurasToList(DontCastAuras[PHYSICAL], defaultPhysicalAuras())
  end

  local specAuras = {}
  mergeTables(specAuras, DontCastAuras[BASE])
  if isCasterOrHealer() then
    mergeTables(specAuras, DontCastAuras[MAGICAL])
  else
    mergeTables(specAuras, DontCastAuras[PHYSICAL])
  end
  return specAuras
end

local function addAura(aura, listName)
  DontCastAuras[listName][aura] = true
  if DontCastAuras[listName][aura] then
    auras = savedAuras()
    colorPrint("Added "..aura)
  else
    errorPrint("Unable to add "..aura)
  end
end

local function removeAura(aura)
  for listName, _ in pairs(defaultAuras()) do
    if DontCastAuras[listName][aura] then
      DontCastAuras[listName][aura] = false
      if not DontCastAuras[listName][aura] then
        auras = savedAuras()
        colorPrint("Removed "..aura)
      else
        errorPrint("Unable to remove "..aura)
      end
    end
  end
end

local function addNewDefaults()
  for listName, list in pairs(defaultAuras()) do
    for _, auraId in pairs(list) do
      local aura = GetSpellInfo(auraId)
      if DontCastAuras[listName][aura] == nil then addAura(aura, listName) end
    end
  end
end

local function displayAuras()
  colorPrint("DontCast is triggered by the following:")
  for aura, _ in pairs(auras) do
    if auras[aura] then print(aura) end
  end
end

local function formatTime(remaining)
  if remaining < 3 then
    return string.format("%.1f", remaining)
  elseif remaining >= 3 and remaining < 100 then
    return string.format("%.0f", remaining)
  else
    return string.format("%.0f", remaining / 60).."m"
  end
end

local function displayCountdown(duration)
  local txt = ""
  if duration and duration > 0 then
    if duration < config.threshold then
      cdTextFrame:SetTextColor(1, 0.1, 0.1, 1)
    else
      cdTextFrame:SetTextColor(1, 1, 0.1, 0.85)
    end
    txt = formatTime(duration)
  end
  cdTextFrame:SetText(txt)
end

local function isValid(name)
  if auras[name] == nil or auras[name] == false then
    return false
  end

  local localalizedSmokeBomb = GetSpellInfo(76577)
  local localalizedTouchOfKarma = GetSpellInfo(122470)
  if (name == localalizedSmokeBomb) then
    --only concerned with Smoke Bomb when player NOT also in smoke
    local targetInSmoke = UnitDebuff("target", localalizedSmokeBomb)
    local playerInSmoke = UnitDebuff("player", localalizedSmokeBomb)
    return (targetInSmoke and not playerInSmoke) or (not targetInSmoke and playerInSmoke)
  elseif (name == localalizedTouchOfKarma) then
    --only display ToK for buffed Monk, not the recipient
    local _, _, _, _, _, _, _, caster = UnitBuff("target", localalizedTouchOfKarma)
    return caster == "target"
  else
    return true
  end
end

local function targetIsHostile()
  return UnitIsEnemy("player", "target") or UnitCanAttack("player", "target")
end

local function auraUpdated(self, event, unit, ...)
  if unit == "target" and targetIsHostile() then
    local hasAura = false
    for aura, _ in pairs(auras) do
      local name, rank, icon, count, type, dur, expTime = UnitBuff(unit, aura)
      if not name then
        name, rank, icon, count, type, dur, expTime = UnitDebuff(unit, aura)
      end
      if name and isValid(name) then
        textFrame:SetText(name)
        iconFrame:SetTexture(icon)
        if not mainFrame:IsShown() and config.aurabeginsound ~= "" then
          PlaySound(config.aurabeginsound, "Master")
        end
        mainFrame:Show()
        hasAura = true
        upAuras[name] = true
      end
    end
    if not hasAura then
      if next(upAuras) ~= nil then
        if config.auraendsound ~= "" then
          PlaySound(config.auraendsound, "Master")
        end
        upAuras = {}
      end
      hideIfNotInConfig()
    end
  end
end

local function targetChanged(self, event, unit, ...)
  upAuras = {}
  if targetIsHostile() then
    auraUpdated(self, event, "target")
  else
    hideIfNotInConfig()
  end
end

local function onUpdate(self, elapsed)
  updCtr = updCtr + elapsed
  if updCtr > 0.1 and mainFrame:IsShown() then
    local aura = textFrame:GetText()
    if aura then
      local _, _, _, _, _, _, expTime = UnitBuff("target", aura)
      if not expTime then
        _, _, _, _, _, _, expTime = UnitDebuff("target", aura)
      end
      if expTime then
        displayCountdown(expTime - GetTime())
      end
    end
    updCtr = 0
  end
end

local function resized(frame, width, height)
  local font = textFrame:GetFont()
  iconFrame:SetSize(height, height)
  cdTextFrame:SetFont(font, height * 0.65)
  textFrame:SetFont(font, height * 0.75)
  textFrame:SetPoint("LEFT", height * 1.1, 0)
end

local function fontStyleSelected(self)
  setFontStyle(self.value)
  tempConfig.fontstyle = self.value
  MSA_DropDownMenu_SetSelectedID(optionsFrame.fontstyle, self:GetID())
end

local function fontAlignmentSelected(self)
  setFontAlignment(self.value)
  tempConfig.fontalignment = self.value
  MSA_DropDownMenu_SetSelectedID(optionsFrame.fontalignment, self:GetID())
end

local function createButton(text, parent)
  local button = CreateFrame("Button", "DontCast"..text.."Button", parent, "UIPanelButtonTemplate")
  button:SetHeight(20)
  button:SetWidth(100)
  button:SetText(text)
  button:ClearAllPoints()
  return button
end

local function setInputBoxText(inputBox, text)
  inputBox:SetText(text)
  inputBox:SetCursorPosition(0)
end

local function createInputBox(name, parent, defaultText)
  local box = CreateFrame("EditBox", "DontCast"..name.."EditBox", parent, "InputBoxTemplate")
  box:SetHeight(20)
  box:SetWidth(35)
  box:SetAutoFocus(false)
  box:ClearAllPoints()
  setInputBoxText(box, defaultText)
  return box
end

local function createDropDownInfo(text, value, func)
  local info = MSA_DropDownMenu_CreateInfo()
  info.text = text
  info.value = value
  info.func = func

  MSA_DropDownMenu_AddButton(info)
end

local function fontStyleDropDownOnLoad(frame, level, menuList)
  local fonts = {
    Arial = "Fonts\\ARIALN.TTF",
    FritzQuad = "Fonts\\FRIZQT__.TTF",
    Morpheus = "Fonts\\MORPHEUS.ttf",
    Skurri = "Fonts\\skurri.ttf"
  }

  local sorted = {}
  for k, v in pairs(fonts) do
    table.insert(sorted, k)
  end
  table.sort(sorted)
  for i, k in ipairs(sorted) do
    createDropDownInfo(k, fonts[k], fontStyleSelected)
  end

  local selected = tempConfig.fontstyle ~= nil and tempConfig.fontstyle or config.fontstyle
  MSA_DropDownMenu_SetSelectedValue(optionsFrame.fontstyle, selected)
end

local function fontAlignmentDropDownOnLoad(frame, level, menuList)
  local alignments = {
    Left = "LEFT",
    Center = "CENTER",
    Right = "RIGHT"
  }

  for k, v in pairs(alignments) do
    createDropDownInfo(k, v, fontAlignmentSelected)
  end

  local selected = tempConfig.fontalignment ~= nil and tempConfig.fontalignment or config.fontalignment
  MSA_DropDownMenu_SetSelectedValue(optionsFrame.fontalignment, selected)
end

local function auraSoundDropDownOnLoad(soundSelectFunction, frame, setTo)
  local sounds = {
    None = "",
    DoubleBell = SOUNDKIT.AUCTION_WINDOW_CLOSE,
    RaidWarning = SOUNDKIT.RAID_WARNING,
    ReadyCheck = SOUNDKIT.READY_CHECK,
    SingleBell = SOUNDKIT.AUCTION_WINDOW_OPEN,
  }

  local sorted = {}
  for k, v in pairs(sounds) do
    if k ~= "None" then table.insert(sorted, k) end
  end
  table.sort(sorted)
  table.insert(sorted, 1, "None")
  for i, k in ipairs(sorted) do
    createDropDownInfo(k, sounds[k], soundSelectFunction)
  end

  MSA_DropDownMenu_SetSelectedValue(frame, setTo)
end

local function createDropDown(name, parent)
  local dropdown = CreateFrame("Button", "DontCast"..name.."DropDown", parent, "MSA_DropDownMenuTemplate")
  dropdown:ClearAllPoints()
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

local function drawThresholdOptions(parent, xOffset, yOffset)
  local label = createLabel("Expiring soon threshold (seconds)", parent, xOffset, yOffset)

  parent.threshold = createInputBox("threshold", parent, config.threshold)
  parent.threshold:SetMaxLetters(4)
  parent.threshold:SetPoint("LEFT", label, "RIGHT", 10, 0)
end

local function drawFontStyleOptions(parent, xOffset, yOffset)
  local label = createLabel("Font", parent, xOffset, yOffset)

  parent.fontstyle = createDropDown("DontCastFontStyle", parent)
  parent.fontstyle:SetPoint("LEFT", label, "RIGHT", 0, 0)
  MSA_DropDownMenu_Initialize(parent.fontstyle, fontStyleDropDownOnLoad)

  parent.fontalignment = createDropDown("DontCastFontAlignment", parent)
  parent.fontalignment:SetPoint("LEFT", parent.fontstyle, "RIGHT", 110, 0)
  MSA_DropDownMenu_Initialize(parent.fontalignment, fontAlignmentDropDownOnLoad)
end

local function beginSoundSelected(self)
  PlaySound(self.value, "Master")
  tempConfig.aurabeginsound = self.value
  MSA_DropDownMenu_SetSelectedID(optionsFrame.aurabeginsound, self:GetID())
end

local function endSoundSelected(self)
  PlaySound(self.value, "Master")
  tempConfig.auraendsound = self.value
  MSA_DropDownMenu_SetSelectedID(optionsFrame.auraendsound, self:GetID())
end

local function beginSoundDropDownOnLoad()
  local selected = tempConfig.aurabeginsound ~= nil and tempConfig.aurabeginsound or config.aurabeginsound
  auraSoundDropDownOnLoad(beginSoundSelected, optionsFrame.aurabeginsound, selected)
end

local function endSoundDropDownOnLoad()
  local selected = tempConfig.auraendsound ~= nil and tempConfig.auraendsound or config.auraendsound
  auraSoundDropDownOnLoad(endSoundSelected, optionsFrame.auraendsound, selected)
end

local function drawSoundOptions(parent, xOffset, yOffset)
  local beginLabel = createLabel("Aura begins sound", parent, xOffset, yOffset)
  parent.aurabeginsound = createDropDown("AuraBeginSound", parent)
  parent.aurabeginsound:SetPoint("LEFT", beginLabel, "RIGHT", 0, 0)
  MSA_DropDownMenu_SetWidth(parent.aurabeginsound, 140)
  MSA_DropDownMenu_Initialize(parent.aurabeginsound, beginSoundDropDownOnLoad)

  local endLabel = createLabel("Aura ends sound", parent, xOffset, yOffset - 40)
  parent.auraendsound = createDropDown("AuraEndSound", parent)
  parent.auraendsound:SetPoint("LEFT", endLabel, "RIGHT", 0, 0)
  MSA_DropDownMenu_SetWidth(parent.auraendsound, 140)
  MSA_DropDownMenu_Initialize(parent.auraendsound, endSoundDropDownOnLoad)
end

local function reloadDropDowns()
  fontStyleDropDownOnLoad()
  fontAlignmentDropDownOnLoad()
  beginSoundDropDownOnLoad()
  endSoundDropDownOnLoad()
end

local function copyConfigSelected(self)
  tempConfig.copyconfig = self.value
  for k, v in pairs(self.value) do
    tempConfig[k] = v
  end
  setInputBoxText(optionsFrame.threshold, tempConfig.threshold)
  setFontStyle(tempConfig.fontstyle)
  setFontAlignment(tempConfig.fontalignment)
  reloadDropDowns()
  MSA_DropDownMenu_SetSelectedID(optionsFrame.copyconfig, self:GetID())
end

local function copyConfigDropDownOnLoad()
  local sorted = {}
  for k, _ in pairs(DontCastConfig) do
    if k ~= "OLDGLOBAL" then table.insert(sorted, k) end
  end
  table.sort(sorted)
  for _, k in ipairs(sorted) do
    createDropDownInfo(k, DontCastConfig[k], copyConfigSelected)
  end

  if tempConfig.copyconfig then
    MSA_DropDownMenu_SetSelectedValue(optionsFrame.copyconfig, tempConfig.copyconfig)
  else
    MSA_DropDownMenu_SetSelectedName(optionsFrame.copyconfig, playerServer)
  end
end

local function drawCopyConfigOptions(parent, xOffset, yOffset)
  local label = createLabel("Copy configuration from", parent, xOffset, yOffset)
  parent.copyconfig = createDropDown("CopyConfig", parent)
  parent.copyconfig:SetPoint("LEFT", label, "RIGHT", 0, 0)
  MSA_DropDownMenu_SetWidth(parent.copyconfig, 225)
  MSA_DropDownMenu_Initialize(parent.copyconfig, copyConfigDropDownOnLoad)
end

local function updateOptionsUI()
  setInputBoxText(optionsFrame.threshold, config.threshold)
  reloadDropDowns()
  copyConfigDropDownOnLoad()
end

local function setThreshold(threshold, echo)
  local asNum = tonumber(threshold)
  if type(asNum) == "number" then
    local updated = updateConfig("threshold", asNum)
    if updated then
      if echo then colorPrint("Threshold set to "..threshold) end
      setInputBoxText(optionsFrame.threshold, threshold)
    else
      errorPrint("Unable to set threshold to "..threshold)
    end
  elseif echo then
    errorPrint("Threshold NOT changed! Must be set to a number.")
  end
end

local function resetTempConfig()
  tempConfig = {}
end

local function saveOptions()
  setThreshold(optionsFrame.threshold:GetText(), false)
  updateConfig("fontstyle", textFrame:GetFont())
  updateConfig("fontalignment", textFrame:GetJustifyH())

  if tempConfig.aurabeginsound ~= nil then
    updateConfig("aurabeginsound", tempConfig.aurabeginsound)
  end
  if tempConfig.auraendsound ~= nil then
    updateConfig("auraendsound", tempConfig.auraendsound)
  end
  resetTempConfig()
end

local function cancelOptions()
  resetTempConfig()
  setFontStyle(config.fontstyle)
  setFontAlignment(config.fontalignment)
  hideAndLockFrame()
end

local function defaultOptions()
  DontCastAuras = defaultAuras()
  auras = savedAuras()
  config = defaultConfig()
  DontCastConfig[playerServer] = config
  setThreshold(config.threshold, false)
  setFontStyle(config.fontstyle)
  setFontAlignment(config.fontalignment)
  centerFrame()
  hideAndLockFrame()
  InterfaceOptionsFrame:Hide()
  resetTempConfig()
  colorPrint("All DontCast options reset to default")
end

local function createOptionsPanel()
  local xOffset = 20
  optionsFrame = CreateFrame("Frame", "DontCastOptions", UIParent)
  optionsFrame.name = "DontCast"
  InterfaceOptions_AddCategory(optionsFrame)

  optionsFrame.okay = saveOptions
  optionsFrame.cancel = cancelOptions
  optionsFrame.default = defaultOptions

  optionsFrame.title = optionsFrame:CreateFontString("DontCastOptionsTitle", "OVERLAY", "GameFontNormalLarge")
  optionsFrame.title:SetPoint("TOPLEFT", xOffset, -20)
  optionsFrame.title:SetText("DontCast Options")

  drawPositioningOptions(optionsFrame, xOffset, -50)
  drawThresholdOptions(optionsFrame, xOffset, -90)
  drawFontStyleOptions(optionsFrame, xOffset, -130)
  drawSoundOptions(optionsFrame, xOffset, -170)
  drawCopyConfigOptions(optionsFrame, xOffset, -270)

  updateOptionsUI()
end

-- 7.3 changed the sound API to take a constant
-- instead of a string to specify the sound to play,
-- update old config strings to appropriate constants
local function updateSoundConfig()
  local soundKitIds = {
    AuctionWindowOpen = SOUNDKIT.AUCTION_WINDOW_OPEN,
    AuctionWindowClose = SOUNDKIT.AUCTION_WINDOW_CLOSE,
    RaidWarning = SOUNDKIT.RAID_WARNING,
    ReadyCheck = SOUNDKIT.READY_CHECK,
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
  elseif event == "PLAYER_TARGET_CHANGED" then
    targetChanged(self, event, unit)
  elseif event == "PLAYER_REGEN_DISABLED" then
    lockFrame(false)
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    auras = savedAuras()
  elseif event == "ADDON_LOADED" and unit == "DontCast" then
    playerServer = UnitName("player").." - "..GetRealmName()
    auras = savedAuras()
    addNewDefaults()
    config = savedConfig()
    updateSoundConfig()
    createOptionsPanel()
    setFontStyle(config.fontstyle)
    setFontAlignment(config.fontalignment)
  end
end

function loadDontCast(self, text, icon, cdText)
  if self and text and icon and cdText then
    mainFrame = self
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton", "RightButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

    mainFrame:SetResizable(true)
    mainFrame:SetMinResize(32, 16)
    mainFrame:SetMaxResize(512, 256)
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
    end)

    textFrame = text
    iconFrame = icon
    cdTextFrame = cdText

    local eventFrame = CreateFrame("Frame", "DontCastEventFrame", UIParent)
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", eventHandler)
    eventFrame:SetScript("OnUpdate", onUpdate)

    lockFrame(true)
    colorPrint("DontCast loaded, for help type /dontcast ?")
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
    elseif string.match(cmd, "add%s+%w+") then
      local aura = string.match(cmd, "add%s+(.+)")
      if aura then
        addAura(aura, BASE)
      end
    elseif string.match(cmd, "addm%s+%w+") then
      local aura = string.match(cmd, "addm%s+(.+)")
      if aura then
        addAura(aura, MAGICAL)
      end
    elseif string.match(cmd, "addp%s+%w+") then
      local aura = string.match(cmd, "addp%s+(.+)")
      if aura then
        addAura(aura, PHYSICAL)
      end
    elseif string.match(cmd, "remove%s+%w+") then
      local aura = string.match(cmd, "remove%s+(.+)")
      if aura then
        removeAura(aura)
      end
    elseif string.match(cmd, "show%s+threshold") then
      colorPrint("Countdown text changes color at "..config.threshold.." seconds")
    elseif string.match(cmd, "threshold%s+[0-9.]+") then
      local threshold = string.match(cmd, "threshold%s+(.+)")
      if threshold then
        setThreshold(threshold, true)
      end
    elseif cmd == "list" then
      displayAuras()
    elseif cmd == "default" then
      DontCastAuras = defaultAuras()
      auras = savedAuras()
      colorPrint("DontCast reverted to default triggers")
    elseif string.match(cmd, "config%w*") then
      -- call twice to workaround WoW bug where very first call opens wrong tab
      InterfaceOptionsFrame_OpenToCategory("DontCast")
      InterfaceOptionsFrame_OpenToCategory("DontCast")
      updateOptionsUI() -- values may have been modified via slash commands
    else
      colorPrint("DontCast commands:")
      print("/dontcast add NAME - adds the named buff or debuff")
      print("/dontcast addm NAME - adds the named buff or debuff for magical mode only")
      print("/dontcast addp NAME - adds the named buff or debuff for physical mode only")
      print("/dontcast remove NAME - removes the named buff or debuff")
      print("/dontcast threshold #.## - set the threshold for changing color of countdown text")
      print("/dontcast show threshold - display the threshold color of countdown text changes")
      print("/dontcast list - display what will trigger the warning")
      print("/dontcast default - reverts to the default triggers")
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
