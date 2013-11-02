SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local auras = {}

SlashCmdList["DONTCAST"] = function(cmd)
	if mainFrame and textFrame and iconFrame then
		if cmd=="show" then
			colorPrint("Right click and drag to move, when done type /dontcast hide")
			showAndUnlockFrame(mainFrame, textFrame)
		elseif cmd=="hide" then
			hideAndLockFrame(mainFrame)
		elseif cmd=="reset" then
			moveToCenter(mainFrame)
		elseif string.match(cmd, "add%s+%w+") then
			local aura = string.match(cmd, "add%s+(.+)")
			if aura then
				addAura(aura)
			end
		elseif cmd=="remove" then
			print("REMOVE")	--DELME
		elseif cmd=="list" then
			displayAuras()
		elseif cmd=="default" then
			DontCastAuras = defaultAuras()
			colorPrint("DontCast reverted to default triggers")			
		else
			colorPrint("DontCast commands:")
			print("/dontcast add NAME - adds the named buff or debuff")
			print("/dontcast remove NAME - removes the named buff or debuff")
			print("/dontcast list - display what will trigger the warning")
			print("/dontcast default - reverts to the default triggers")
			print("/dontcast show - Shows the frame for repositioning")
			print("/dontcast hide - Locks (and hides) the frame")
			print("/dontcast reset - Resets the position to center of screen")
			print("/dontcast ? or /dontcast help - Prints this list")
		end
	else
		print("|cffFF0000".."Error loading DontCast!")
	end
end

function onLoad(self, text, icon)
	if self and text and icon then
		mainFrame = self
		textFrame = text
		iconFrame = icon
		local eventFrame = CreateFrame("Frame", "eventFrame", UIParent)
		eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("UNIT_AURA")
		eventFrame:SetScript("OnEvent", eventHandler)
		hideAndLockFrame(mainFrame)
		colorPrint("DontCast loaded, for help type /dontcast ?")
	else
		print("|cffFF0000".."Unable to load DontCast!")
	end
end

function eventHandler(self, event, unit, ...)
	if event == "UNIT_AURA" then
		auraUpdated(self, event, unit)
	elseif event == "PLAYER_TARGET_CHANGED" then
		targetChanged(self, event, unit)		
	elseif event == "ADDON_LOADED" and unit == "DontCast" then
		auras = savedAuras()		
	end
end

function colorPrint(msg)
	print("|cff9382C9"..msg)
end

function targetIsHostile()
	return UnitIsEnemy("player", "target") or UnitCanAttack("player", "target")
end

function targetChanged(self, event, unit, ...)
	if targetIsHostile() then
		auraUpdated(self, event, "target")
	else
		hideFrame(mainFrame)
	end
end

function auraUpdated(self, event, unit, ...)
	if unit == "target" and targetIsHostile() then
		local hasAura = false
		for _, aura in pairs(DontCastAuras) do
			local name, rank, icon, count, type, dur, expTime = UnitAura(unit, aura)
			if name then
				--TODO display time remaining
				--print(name, icon, expTime - GetTime()) --DELME
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

function addAura(aura)
	local size = #DontCastAuras
	table.insert(DontCastAuras, aura)
	if #DontCastAuras > size then
		auras = savedAuras()
		colorPrint(aura.." added")
	end
end

function removeAura(aura)
	--TODO remove
	print("REMOVING: ", aura)	--DELME
	auras = savedAuras()
end

function displayAuras()
	colorPrint("DontCast is triggered by the following:")
	for _, aura in pairs(DontCastAuras) do
		print(aura)
	end
end

function savedAuras()
	if not DontCastAuras then
		DontCastAuras = defaultAuras()
	end
	return DontCastAuras
end

function defaultAuras()
	return {
			"Anti-Magic Shell",
			"Cloak of Shadows",
			"Cyclone",
			"Deterrence",
			"Divine Shield",
			"Ice Block",
			"Smoke Bomb",
			"Spell Reflection"
		}
end

function showFrame(frame)
	frame:Show()
end

function hideFrame(frame)
	frame:Hide()
end

function showAndUnlockFrame(frame, text)
	text:SetText("Right click here to move")
	iconFrame:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
	showFrame(frame)
	frame:EnableMouse(true)
	frame:RegisterForDrag("RightButton")
end

function hideAndLockFrame(frame)
	frame:EnableMouse(false)
	hideFrame(frame)
end

function moveToCenter(frame)
	frame:SetPoint("CENTER")
end

function dragStart(self, button)
	self:StartMoving()
end

function dragStop(self, button)
	self:StopMovingOrSizing()
end