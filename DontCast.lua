SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local optionsFrame = nil
local cdTextFrame = nil
local resizeButton = nil
local auras = {}
local config = {}
local tempConfig = {}
local upAuras = {}
local updCtr = 0

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
		aurabeginsound = "",
		auraendsound = ""
	}
end

local function savedConfig()
	if not DontCastConfig then
		DontCastConfig = defaultConfig()
	end
	-- if user upgrades to version that introduces new config vars set to default
	for k, v in pairs(defaultConfig()) do
		if DontCastConfig[k] == nil then DontCastConfig[k] = v end
	end
	return DontCastConfig
end

local function updateConfig(key, value)
	DontCastConfig[key] = value
	local updated = DontCastConfig[key] == value
	if updated then
		config = savedConfig()
	end
	return updated
end

local function setFontStyle(style)
	cdTextFrame:SetFont(style, mainFrame:GetHeight() * 0.95)
	textFrame:SetFont(style, mainFrame:GetHeight() * 0.75)
end

local function defaultAuras()
	local spellIds = {
		48707,	-- Anti-Magic Shell
		31224,	-- Cloak of Shadows
		33786,	-- Cyclone
		19263,	-- Deterrence
		122783,	-- Diffuse Magic
		47585,	-- Dispersion
		642,	-- Divine Shield
		45438,	-- Ice Block
		76577,	-- Smoke Bomb
		23920,	-- Spell Reflection
		122470	-- Touch of Karma
	}

	local names = {}
	for _, id in ipairs(spellIds) do
		local name = GetSpellInfo(id)
		names[name] = true
	end
	return names
end

local function savedAuras()
	if not DontCastAuras then
		DontCastAuras = defaultAuras()
	end
	return DontCastAuras
end

local function addAura(aura)
	DontCastAuras[aura] = true
	if DontCastAuras[aura] then
		auras = savedAuras()
		colorPrint("Added "..aura)
	else
		errorPrint("Unable to add "..aura)
	end
end

local function removeAura(aura)
	DontCastAuras[aura] = nil
	if DontCastAuras[aura] == nil then
		auras = savedAuras()
		colorPrint("Removed "..aura)
	else
		errorPrint("Unable to remove "..aura)
	end
end

local function displayAuras()
	colorPrint("DontCast is triggered by the following:")
	for aura, _ in pairs(DontCastAuras) do
		print(aura)
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
		for aura, _ in pairs(DontCastAuras) do
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
	cdTextFrame:SetFont(font, height * 0.95)
	textFrame:SetFont(font, height * 0.75)
	textFrame:SetPoint("LEFT", height * 1.1, 0)
end

local function fontStyleSelected(self)
	setFontStyle(self.value)
	tempConfig.fontstyle = self.value
	Lib_UIDropDownMenu_SetSelectedID(optionsFrame.fontstyle, self:GetID())
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
	local info = Lib_UIDropDownMenu_CreateInfo()
	info.text = text
	info.value = value
	info.func = func

	Lib_UIDropDownMenu_AddButton(info)
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
	Lib_UIDropDownMenu_SetSelectedValue(optionsFrame.fontstyle, selected)
end

local function auraSoundDropDownOnLoad(soundSelectFunction, frame, setTo)
	local sounds = {
		None = "",
		DoubleBell = "AuctionWindowClose",
		RaidWarning = "RaidWarning",
		ReadyCheck = "ReadyCheck",
		SingleBell = "AuctionWindowOpen"
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

	Lib_UIDropDownMenu_SetSelectedValue(frame, setTo)
end

local function createDropDown(name, parent)
	local dropdown = CreateFrame("Button", "DontCast"..name.."DropDown", parent, "Lib_UIDropDownMenuTemplate")
	dropdown:ClearAllPoints()
	return dropdown
end

local function createCheckBox(text, parent)
	local checkbox = CreateFrame("CheckButton", "DontCast"..text.."CheckButton", parent, "UICheckButtonTemplate")
	checkbox:ClearAllPoints()
	_G[checkbox:GetName().."Text"]:SetText(text)
	return checkbox
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
	Lib_UIDropDownMenu_Initialize(parent.fontstyle, fontStyleDropDownOnLoad)
end

local function drawAuraOptions(parent, xOffset, yOffset)
	local y = yOffset
	for aura, _ in pairs(DontCastAuras) do
		local checkbox = createCheckBox(aura, parent)
		checkbox:SetPoint("TOPLEFT", xOffset, y)
		y = y - 25
	end
end

local function beginSoundSelected(self)
	PlaySound(self.value, "Master")
	tempConfig.aurabeginsound = self.value
	Lib_UIDropDownMenu_SetSelectedID(optionsFrame.aurabeginsound, self:GetID())
end

local function endSoundSelected(self)
	PlaySound(self.value, "Master")
	tempConfig.auraendsound = self.value
	Lib_UIDropDownMenu_SetSelectedID(optionsFrame.auraendsound, self:GetID())
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
	Lib_UIDropDownMenu_Initialize(parent.aurabeginsound, beginSoundDropDownOnLoad)

	local endLabel = createLabel("Aura ends sound", parent, xOffset, yOffset - 40)
	parent.auraendsound = createDropDown("AuraEndSound", parent)
	parent.auraendsound:SetPoint("LEFT", endLabel, "RIGHT", 0, 0)
	Lib_UIDropDownMenu_Initialize(parent.auraendsound, endSoundDropDownOnLoad)
end

local function updateOptionsUI()
	setInputBoxText(optionsFrame.threshold, config.threshold)
	fontStyleDropDownOnLoad()
	beginSoundDropDownOnLoad()
	endSoundDropDownOnLoad()
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
	hideAndLockFrame()
end

local function defaultOptions()
	auras = defaultAuras()
	DontCastAuras = auras
	config = defaultConfig()
	DontCastConfig = config
	setThreshold(config.threshold, false)
	setFontStyle(config.fontstyle)
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

	updateOptionsUI()
end

local function eventHandler(self, event, unit, ...)
	if event == "UNIT_AURA" then
		auraUpdated(self, event, unit)
	elseif event == "PLAYER_TARGET_CHANGED" then
		targetChanged(self, event, unit)
	elseif event == "PLAYER_REGEN_DISABLED" then
		lockFrame(false)
	elseif event == "ADDON_LOADED" and unit == "DontCast" then
		auras = savedAuras()		
		config = savedConfig()
		createOptionsPanel()
		setFontStyle(config.fontstyle)
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
				addAura(aura)
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
			colorPrint("DontCast reverted to default triggers")
		elseif string.match(cmd, "config%w*") then
			-- call twice to workaround WoW bug where very first call opens wrong tab
			InterfaceOptionsFrame_OpenToCategory("DontCast")
			InterfaceOptionsFrame_OpenToCategory("DontCast")
			updateOptionsUI() -- values may have been modified via slash commands
		else
			colorPrint("DontCast commands:")
			print("/dontcast add NAME - adds the named buff or debuff")
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
