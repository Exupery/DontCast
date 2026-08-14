SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local previewText = nil
local previewIcon = nil
local optionsFrame = nil
local optionsCategory = nil
local resizeButton = nil

local playerServer = nil
local config = {}
local tempConfig = {} -- used to copy profile settings
local profiles = {}

-- 12.1 replaced direct aura reads with AuraContainers: the container tracks, filters and
-- updates the auras itself and we only get to say what each row looks like. Aura data (name,
-- icon, remaining time, and even whether a row is shown) is secret and never passes through
-- this file.
local auraContainer = nil
-- Set as soon as the build starts, where auraContainer is only set once it has finished, so a
-- re-entrant call during the build can't start a second container.
local containerBuilt = false
-- Every AuraButton the container has created, with the regions we registered on it, so a font
-- or size change can restyle them all. See restyleAuraButtons for why that is not always allowed.
local auraButtons = {}
local restylePending = false
local restyleTicker = nil
local bounceScheduled = false
-- True while the frame is unlocked for positioning; the container is parked on "none" so real
-- auras can't draw over the placeholder row.
local previewing = false

local DEFAULT_POINT = "CENTER"
local DEFAULT_WIDTH = 300
local DEFAULT_HEIGHT = 50

-- Row geometry, shared by the real aura rows and the unlock-mode placeholder so both look the
-- same. All of it derives from the frame height, which is one row.
local ICON_INSET_RATIO = 1.1 -- where the text starts, just past the square icon
local TEXT_HEIGHT_RATIO = 0.7
local COUNT_HEIGHT_RATIO = 0.6

-- Filter tokens combine with AND, never OR, so "HELPFUL|BIG_DEFENSIVE|EXTERNAL_DEFENSIVE" would
-- match only auras flagged as both - i.e. almost nothing. Two groups on one container is the
-- idiom for OR: they lay out as one continuous column and an empty group collapses, so a lone
-- external defensive still renders on the first row. The negation keeps an aura flagged as both
-- out of the second group, so it is never drawn twice.
local AURA_GROUPS = {
  { key = "bigdefensive", filter = "HELPFUL|BIG_DEFENSIVE" },
  { key = "externaldefensive", filter = "HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE" },
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

local function rowWidth()
  return mainFrame and mainFrame:GetWidth() or DEFAULT_WIDTH
end

local function rowHeight()
  return mainFrame and mainFrame:GetHeight() or DEFAULT_HEIGHT
end

local function currentFont()
  return FONTS[config.fontstyle] or FONTS.Arial
end

-- config.fontalignment holds the resolved value ("LEFT") once the user has picked one, but the
-- key ("Left") when it comes from defaults or a pre-table config, so accept either.
local function currentAlignment()
  local alignment = config.fontalignment
  return FONT_ALIGNMENTS[alignment] or alignment or "LEFT"
end

-- The spell-name font string of a row. The engine owns its text and shown state; the face,
-- size, colour and placement stay ours.
local function styleAuraText(fontString, height)
  fontString:SetFont(currentFont(), math.max(1, math.floor(height * TEXT_HEIGHT_RATIO)))
  fontString:SetJustifyH(currentAlignment())
  fontString:SetJustifyV("MIDDLE")
  fontString:SetTextColor(1, 1, 0.1, 0.9)
  fontString:SetShadowColor(0.1, 0.1, 0.1, 0.9)
  fontString:SetShadowOffset(2, -2)
end

-- Every row's cooldown draws its countdown with this shared font object, so changing the object
-- restyles all of them at once. That matters because it is not an AuraButton API: the numbers
-- keep up with a font or size change even mid-combat, when the buttons themselves are untouchable.
local function updateCountFont(height)
  if not DontCastCountFont then
    CreateFont("DontCastCountFont")
  end
  DontCastCountFont:SetFont(currentFont(), math.max(1, math.floor(height * COUNT_HEIGHT_RATIO)), "OUTLINE")
  DontCastCountFont:SetTextColor(1, 1, 0.1, 0.95)
  DontCastCountFont:SetShadowColor(0.1, 0.1, 0.1, 0.9)
  DontCastCountFont:SetShadowOffset(2, -2)
end

-- Reused rather than rebuilt per call: the engine copies and validates what it is handed, so
-- one table is enough for both groups.
local groupLayout = {}

local function buildGroupLayout()
  groupLayout.elementWidth = rowWidth()
  groupLayout.elementHeight = rowHeight()
  groupLayout.elementSpacing = 0
  groupLayout.lineSpacing = 0
  groupLayout.groupSpacing = 0
  groupLayout.groupLineSpacing = 0
  return groupLayout
end

local function applyGroupLayout()
  if not auraContainer then return end
  local layout = buildGroupLayout()
  for _, group in ipairs(AURA_GROUPS) do
    -- SetAuraGroupLayout errors on a key the container doesn't carry, and this can be reached
    -- from a layout pass part-way through building the groups.
    if auraContainer:HasAuraGroup(group.key) then
      auraContainer:SetAuraGroupLayout(group.key, layout)
    end
  end
end

-- AuraButton APIs raise a Lua error from addon code whenever auras are secret, which covers
-- combat but also out-of-combat moments inside encounters, M+ runs and PvP matches - so
-- InCombatLockdown on its own is not enough of a guard.
local function stylingRestricted()
  if InCombatLockdown() then
    return true
  end
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    return C_Secrets.ShouldAurasBeSecret()
  end
  return false
end

local restyleAuraButtons -- forward declaration; the retry ticker below calls it

local function setRestylePending(pending)
  if restylePending == pending then return end
  restylePending = pending

  if pending then
    -- PLAYER_REGEN_ENABLED catches the common case immediately, but there is no event for
    -- auras stopping being secret, so a slow poll covers the rest. It only runs while a
    -- restyle is actually owed.
    if not restyleTicker then
      restyleTicker = C_Timer.NewTicker(1, function() restyleAuraButtons() end)
    end
  elseif restyleTicker then
    restyleTicker:Cancel()
    restyleTicker = nil
  end
end

local function applyButtonStyle(widgets, width, height)
  widgets.button:SetSize(width, height)
  widgets.icon:SetSize(height, height)
  widgets.text:ClearAllPoints()
  widgets.text:SetPoint("LEFT", widgets.button, "LEFT", height * ICON_INSET_RATIO, 0)
  widgets.text:SetPoint("RIGHT", widgets.button, "RIGHT", 0, 0)
  styleAuraText(widgets.text, height)
end

-- Re-applies size and font to every row the container has created. Refused while the buttons
-- are untouchable; the pending flag and the ticker above settle it once they are not. The pcall
-- is a backstop for a client whose restriction we failed to predict - an error here would spam
-- the user rather than just delay a restyle.
function restyleAuraButtons()
  if #auraButtons == 0 then
    setRestylePending(false)
    return
  end

  if stylingRestricted() then
    setRestylePending(true)
    return
  end

  local width, height = rowWidth(), rowHeight()

  for _, widgets in ipairs(auraButtons) do
    local ok = pcall(applyButtonStyle, widgets, width, height)
    if not ok then
      setRestylePending(true)
      return
    end
  end

  setRestylePending(false)
end

-- Called once per AuraButton the container creates. This is the only place a button is
-- guaranteed not to be forbidden, so everything a row is made of has to be built and registered
-- here - a row created inside an arena keeps whatever it was born with until the match ends.
local function initializeAuraButton(button)
  -- Composite the icon, swipe and text in one render pass so the text is not buried by the
  -- cooldown, which is a child frame.
  button:SetFlattensRenderLayers(true)
  -- No tooltips: the frame sits over the world and never took the mouse before.
  button:EnableMouse(false)

  local height = rowHeight()

  local icon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  icon:SetPoint("LEFT", button, "LEFT", 0, 0)
  button:SetIcon(icon)

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(icon)
  cooldown:SetReverse(true)
  cooldown:SetDrawEdge(false)
  cooldown:SetDrawBling(false)
  cooldown:SetDrawSwipe(true)
  cooldown:SetHideCountdownNumbers(false)
  cooldown:SetCountdownFont("DontCastCountFont")
  -- The engine drives this from the aura's remaining time, which we never see.
  button:SetDurationCooldown(cooldown)

  -- Inherits a template purely so the string is never faceless: registering it below hands its
  -- text to the engine, which writes the current aura's name into it straight away, and SetText
  -- errors on a font string with no font. styleAuraText then puts the configured face on it -
  -- before the registration, for the same reason.
  local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  styleAuraText(text, height)
  button:SetSpellName(text)

  local widgets = { button = button, icon = icon, cooldown = cooldown, text = text }
  auraButtons[#auraButtons + 1] = widgets

  applyButtonStyle(widgets, rowWidth(), height)
end

-- Config pushed from addon code (a new unit, a new layout) only marks the container dirty; it
-- cannot arm the secure-side pass that consumes those marks. Hiding and showing the container
-- is the one thing addon code can do that does: the intrinsic OnShow runs untainted and issues
-- a full refresh. Nothing renders between the two calls, and it is coalesced to once per frame
-- because a refresh calls several setters in a row.
local function bounceContainer()
  if bounceScheduled or not auraContainer then return end
  bounceScheduled = true

  C_Timer.After(0, function()
    bounceScheduled = false
    if auraContainer and auraContainer:IsShown() then
      auraContainer:Hide()
      auraContainer:Show()
    end
  end)
end

local function targetIsHostile()
  return UnitIsEnemy("player", "target") or UnitCanAttack("player", "target")
end

-- Points the container at the current target, or parks it. The park-and-repoint is not
-- redundant: when you switch from one enemy to another the token string is still "target", so
-- the container sees no change and would keep showing the previous target's auras.
local function refreshTarget()
  if not auraContainer then return end

  auraContainer:SetUnit("none")

  if not previewing and targetIsHostile() then
    auraContainer:SetUnit("target")
  end

  bounceContainer()
end

local function createAuraContainer()
  if auraContainer or containerBuilt then return end
  containerBuilt = true

  -- Each row's cooldown asks for this font by name as it is built, so it has to exist first.
  -- Not left to setFontStyle, which bails out on an unrecognised saved font.
  updateCountFont(rowHeight())

  local created, frame = pcall(CreateFrame, "AuraContainer", "DontCastAuraContainer", mainFrame, "CustomAuraContainerTemplate")

  if not created or not frame then
    errorPrint("DontCast needs World of Warcraft 12.1 or later to show auras.")
    return
  end

  -- Built hidden: a container parses as soon as it is visible, so one created shown would parse
  -- before its groups carry their filters, and that parse is what would stay on screen.
  frame:Hide()
  frame:SetSize(1, 1)
  frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
  frame:SetUnit("none")

  -- Rows stack downward from the top-left of the frame, so a single aura occupies exactly the
  -- frame the user positioned and a second one hangs below it.
  if frame.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
    frame:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    frame:SetFlowLayoutAnchorPoint("TOPLEFT")
    frame:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
  end

  local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.BigDefensive

  for _, group in ipairs(AURA_GROUPS) do
    -- One row per category: with maxFrameCount 1 the sort decides which aura wins the slot,
    -- and BigDefensive is the engine's own ordering for exactly this kind of display.
    frame:AddAuraGroup(group.key, group.filter, {
      maxFrameCount = 1,
      sortMethod = sortMethod,
      initializeFrame = initializeAuraButton,
      layout = buildGroupLayout(),
    })
  end

  -- Published to the rest of the file only now. AddAuraGroup runs initializeAuraButton for a
  -- whole batch of rows and resolves this frame's rect on the way, and either can re-enter
  -- resized() - which would have asked a container with no groups yet to lay them out.
  auraContainer = frame

  -- Picks up a size the deferred layout pass may have settled while the groups were being built.
  applyGroupLayout()
  restyleAuraButtons()

  -- The groups exist now, so the container can be let out. This show is the arming refresh.
  frame:Show()
  refreshTarget()
end

-- The unlock-mode placeholder, laid out like a real row so what the user positions is what they
-- will see.
local function updatePreview()
  if not previewText or not previewIcon then return end

  local height = rowHeight()

  previewIcon:SetSize(height, height)
  previewText:ClearAllPoints()
  previewText:SetPoint("LEFT", mainFrame, "LEFT", height * ICON_INSET_RATIO, 0)
  previewText:SetPoint("RIGHT", mainFrame, "RIGHT", 0, 0)
  styleAuraText(previewText, height)
end

local function resized(frame, width, height)
  if not mainFrame then return end
  updateCountFont(rowHeight())
  updatePreview()
  applyGroupLayout()
  restyleAuraButtons()
end

local function showAndUnlockFrame()
  previewing = true
  previewText:SetText("Click here to move")
  previewIcon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
  previewText:Show()
  previewIcon:Show()
  resizeButton:Show()
  mainFrame:EnableMouse(true)
  updatePreview()
  refreshTarget()
end

-- The frame itself now stays shown whether or not anything is up: its background is fully
-- transparent, and the container inside can only draw rows while it is visible.
local function lockFrame()
  previewing = false
  mainFrame:EnableMouse(false)
  resizeButton:Hide()
  previewText:Hide()
  previewIcon:Hide()
  refreshTarget()
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

  return DontCastConfig[playerServer]
end

local function setFontStyle(style)
  if not FONTS[style] then return end
  updateConfig("fontstyle", style)
  updateCountFont(rowHeight())
  updatePreview()
  restyleAuraButtons()
  movingOrSizingStopped()
end

local function setFontAlignment(justification)
  local alignment = FONT_ALIGNMENTS[justification]
  if not alignment then return end
  updateConfig("fontalignment", alignment)
  updatePreview()
  restyleAuraButtons()
  movingOrSizingStopped()
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
  lockButton:SetScript("PostClick", lockFrame)

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

local function reloadDropDowns()
  optionsFrame.fontstyle:SetText(getSelectedFontStyle())
  optionsFrame.fontalignment:SetText(getSelectedFontAlignment())
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
    resized(mainFrame)
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
  drawCopyConfigOptions(optionsFrame, xOffset, -130)

  updateOptionsUI()
end

local function eventHandler(self, event, arg1, ...)
  if event == "PLAYER_TARGET_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
    refreshTarget()
  elseif event == "PLAYER_REGEN_DISABLED" then
    lockFrame()
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- The most common moment the button restriction lifts.
    if restylePending then restyleAuraButtons() end
  elseif event == "ADDON_LOADED" and arg1 == "DontCast" then
    playerServer = UnitName("player").." - "..GetRealmName()
    config = savedConfig()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(config.point, UIParent, config.relativePoint, config.xOfs, config.yOfs)
    mainFrame:SetSize(config.width, config.height)
    createOptionsPanel()
    setFontStyle(config.fontstyle)
    setFontAlignment(config.fontalignment)
    -- After the fonts, so the first batch of rows is built with the right face and size: a row
    -- can only be styled at creation or outside combat.
    createAuraContainer()
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

function loadDontCast(self, text, icon)
  if self and text and icon then
    mainFrame = self
    previewText = text
    previewIcon = icon

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
      -- Explicit rather than relying on OnSizeChanged: 12.1 suppresses addon-installed
      -- OnSizeChanged handlers on anything in an aura container's layout family, and this
      -- frame hosts one. Every other place the size changes re-lays out the same way.
      resized(mainFrame)
    end)

    local eventFrame = CreateFrame("Frame", "DontCastEventFrame", UIParent)
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", eventHandler)

    lockFrame()
    registerFonts()
  else
    errorPrint("Unable to load DontCast!")
  end
end

SlashCmdList["DONTCAST"] = function(cmd)
  if mainFrame and previewText and previewIcon then
    if cmd == "show" or cmd == "unlock" then
      colorPrint("Drag text or icon to move, lower-right-corner to resize, when done type /dontcast hide")
      showAndUnlockFrame()
    elseif cmd == "hide" or cmd == "lock" then
      lockFrame()
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
