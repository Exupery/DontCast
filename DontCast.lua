SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local cdTextFrame = nil
local auras = {}
local config = {}
local updCtr = 0

local function colorPrint(msg)
	print("|cffb2b2b2"..msg)
end

local function errorPrint(err)
	print("|cffff0000"..err)
end

local function showFrame(frame)
	frame:Show()
end

local function hideFrame(frame)
	frame:Hide()
end

local function showAndUnlockFrame(frame, text)
	text:SetText("Click here to move")
	iconFrame:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
	showFrame(frame)
	frame:EnableMouse(true)
end

local function hideAndLockFrame(frame)
	frame:EnableMouse(false)
	hideFrame(frame)
end

local function moveToCenter(frame)
	frame:SetPoint("CENTER")
end

local function dragStart(self, button)
	self:StartMoving()
end

local function dragStop(self, button)
	self:StopMovingOrSizing()
end

local function savedConfig()
	if not DontCastConfig then
		DontCastConfig = {["threshold"] = 1.5}
	end
	return DontCastConfig
end

local function setThreshold(threshold)
	local asNum = tonumber(threshold)
	if type(asNum) == "number" then
		DontCastConfig["threshold"] = asNum
	end
	if DontCastConfig["threshold"] == asNum then
		config = savedConfig()
		colorPrint("Threshold set to "..threshold)
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
		if duration < config["threshold"] then
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
				showFrame(mainFrame)
				hasAura = true
			end
		end
		if not hasAura then
			hideFrame(mainFrame)
		end
	end
end

local function targetChanged(self, event, unit, ...)
	if targetIsHostile() then
		auraUpdated(self, event, "target")
	else
		hideFrame(mainFrame)
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
	elseif event == "ADDON_LOADED" and unit == "DontCast" then
		auras = savedAuras()		
		config = savedConfig()
	end
end

function loadDontCast(self, text, icon, cdText)
	if self and text and icon and cdText then
		mainFrame = self
		mainFrame:RegisterForDrag("LeftButton", "RightButton")
		mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
		mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

		textFrame = text
		iconFrame = icon
		cdTextFrame = cdText

		local eventFrame = CreateFrame("Frame", "eventFrame", UIParent)
		eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("UNIT_AURA")
		eventFrame:SetScript("OnEvent", eventHandler)
		local countdownEventFrame = CreateFrame("Frame", "cdEventFrame", UIParent)
		eventFrame:SetScript("OnUpdate", onUpdate)

		hideAndLockFrame(mainFrame)
		colorPrint("DontCast loaded, for help type /dontcast ?")
	else
		errorPrint("Unable to load DontCast!")
	end
end

SlashCmdList["DONTCAST"] = function(cmd)
	if mainFrame and textFrame and iconFrame then
		if cmd=="show" then
			colorPrint("Click and drag to move, when done type /dontcast hide")
			showAndUnlockFrame(mainFrame, textFrame)
		elseif cmd=="hide" then
			hideAndLockFrame(mainFrame)
		elseif cmd=="center" then
			moveToCenter(mainFrame)
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
			colorPrint("Countdown text changes color at "..config["threshold"].." seconds")
		elseif string.match(cmd, "threshold%s+[0-9.]+") then
			local threshold = string.match(cmd, "threshold%s+(.+)")
			if threshold then
				setThreshold(threshold)
			end
		elseif cmd=="list" then
			displayAuras()
		elseif cmd=="default" then
			DontCastAuras = defaultAuras()
			colorPrint("DontCast reverted to default triggers")			
		else
			colorPrint("DontCast commands:")
			print("/dontcast add NAME - adds the named buff or debuff")
			print("/dontcast remove NAME - removes the named buff or debuff")
			print("/dontcast threshold #.## - set the threshold for changing color of countdown text")
			print("/dontcast show threshold - display the threshold color of countdown text changes")
			print("/dontcast list - display what will trigger the warning")
			print("/dontcast default - reverts to the default triggers")
			print("/dontcast show - Shows the frame for repositioning")
			print("/dontcast hide - Locks (and hides) the frame")
			print("/dontcast center - Sets the position to center of screen")
			print("/dontcast ? or /dontcast help - Prints this list")
		end
	else
		errorPrint("Error loading DontCast!")
	end
end
