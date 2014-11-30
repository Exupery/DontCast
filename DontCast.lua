SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local optionsFrame = nil
local cdTextFrame = nil
local resizeButton = nil
local auras = {}
local config = {}
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

local function savedConfig()
	if not DontCastConfig then
		DontCastConfig = {["threshold"] = 1.5}
	end
	return DontCastConfig
end

local function setThreshold(threshold, echo)
	local asNum = tonumber(threshold)
	if type(asNum) == "number" then
		DontCastConfig.threshold = asNum
	end
	if DontCastConfig.threshold == asNum then
		config = savedConfig()
		if echo then colorPrint("Threshold set to "..threshold) end
	else
		errorPrint("Unable to set threshold to "..threshold)
	end
end

local function defaultAuras()
	return {
			["Anti-Magic Shell"] = true,
			["Cloak of Shadows"] = true,
			["Cyclone"] = true,
			["Deterrence"] = true,
			["Diffuse Magic"] = true,
			["Dispersion"] = true,
			["Divine Shield"] = true,
			["Ice Block"] = true,
			["Smoke Bomb"] = true,
			["Spell Reflection"] = true,
			["Touch of Karma"] = true
		}
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

local function validSmoke()
	--only concerned with Smoke Bomb when player NOT also in smoke
	local targetInSmoke = UnitDebuff("target", "Smoke Bomb")
	local playerInSmoke = UnitDebuff("player", "Smoke Bomb")
	return (targetInSmoke and not playerInSmoke) or (not targetInSmoke and playerInSmoke)
end

local function validKarma()
	--only display ToK for buffed Monk, not the recipient
	local name = UnitBuff("target", "Touch of Karma")
	local _, classFileName = UnitClass("target")
	return name and classFileName == "MONK"
end

local function isValid(name)
	if (name == "Smoke Bomb") then
		return validSmoke()
	elseif (name == "Touch of Karma") then
		return validKarma()
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
				mainFrame:Show()
				hasAura = true
			end
		end
		if not hasAura then
			hideIfNotInConfig()
		end
	end
end

local function targetChanged(self, event, unit, ...)
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
	end
end

local function resized(frame, width, height)
	local font = textFrame:GetFont()
	iconFrame:SetSize(height, height)
	cdTextFrame:SetFont(font, height * 0.95)
	textFrame:SetFont(font, height * 0.75)
	textFrame:SetPoint("LEFT", height * 1.1, 0)
end

local function createButton(text, parent)
	local button = CreateFrame("Button", text.."Button", parent, "UIPanelButtonTemplate")
	button:SetHeight(20)
	button:SetWidth(100)
	button:SetText(text)
	button:ClearAllPoints()
	return button
end

local function createInputBox(text, parent)
	local box = CreateFrame("EditBox", text.."EditBox", parent, "InputBoxTemplate")
	box:SetHeight(20)
	box:SetWidth(35)
	box:SetAutoFocus(false)
	box:ClearAllPoints()
	box:SetText(text)
	return box
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
	parent.threshold = createInputBox("threshold", parent)
	parent.threshold:SetMaxLetters(4)
	parent.threshold:SetPoint("TOPLEFT", xOffset, yOffset)

	local textFrame = optionsFrame:CreateFontString("ThresholdText", "OVERLAY", "GameFontNormal")
	textFrame:SetPoint("LEFT", parent.threshold, "RIGHT", 10, 0)
	textFrame:SetText("Expiring soon threshold (seconds)")
end

local function saveOptions()
	setThreshold(optionsFrame.threshold:GetText(), false)
end

local function createOptionsPanel()
	local xOffset = 20
	optionsFrame = CreateFrame("Frame", "Options", UIParent)
	optionsFrame.name = "DontCast"
	InterfaceOptions_AddCategory(optionsFrame)

	optionsFrame.okay = saveOptions
	optionsFrame.cancel = hideAndLockFrame

	optionsFrame.title = optionsFrame:CreateFontString("DontCastOptionsTitle", "OVERLAY", "GameFontNormalLarge")
	optionsFrame.title:SetPoint("TOPLEFT", xOffset, -20)
	optionsFrame.title:SetText("DontCast Options")

	drawPositioningOptions(optionsFrame, xOffset, -50)
	drawThresholdOptions(optionsFrame, xOffset, -85)

	-- TODO add aura
	-- TODO remove aura
	-- TODO list/show auras
	-- TODO revert to default auras
	-- TODO text color
	-- TODO text font
	-- TODO toggle sound

	errorPrint("OPTIONS FRAME CREATED") -- TODO DELME
end

local function updateOptionsUI()
	optionsFrame.threshold:SetText(config.threshold)
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

		resizeButton = CreateFrame("Button", nil, mainFrame)
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

		local eventFrame = CreateFrame("Frame", "eventFrame", UIParent)
		eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("UNIT_AURA")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		eventFrame:SetScript("OnEvent", eventHandler)
		eventFrame:SetScript("OnUpdate", onUpdate)

		lockFrame(true)
		createOptionsPanel()
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
