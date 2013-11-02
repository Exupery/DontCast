SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil
local auras = {}

SlashCmdList["DONTCAST"] = function(cmd)
	if mainFrame and textFrame and iconFrame then
		if cmd=="show" then
			print("|cff9382C9".."Right click and drag to move, when done type /dontcast hide")
			showAndUnlockFrame(mainFrame, textFrame)
		elseif cmd=="hide" then
			hideAndLockFrame(mainFrame)
		elseif cmd=="reset" then
			moveToCenter(mainFrame)
		else
			print("|cff9382C9".."DontCast commands:")
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
		print("|cff9382C9".."DontCast loaded, for help type /dontcast ?")
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
		auras = getAuras()		
	end
end

function getAuras()
	if not DontCastAuras then
		DontCastAuras = {
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
	return DontCastAuras
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
	--if unit == "target" and targetIsHostile() then
	if unit == "target" then
		local hasAura = false
		for _, aura in pairs(DontCastAuras) do
			print(aura) --DELME
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