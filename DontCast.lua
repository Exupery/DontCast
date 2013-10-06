SLASH_DONTCAST1 = "/dontcast"

local mainFrame = nil
local textFrame = nil
local iconFrame = nil

SlashCmdList["DONTCAST"] = function(cmd)
	if mainFrame and textFrame and iconFrame then
		if cmd=="show" then
			print("|cff9382C9".."Right click and drag to move, when done type /dontcast hide")
			showAndUnlockFrame(mainFrame, textFrame)
		elseif cmd=="hide" then
			hideAndLockFrame(mainFrame)
		elseif cmd=="reset" then
			moveToCenter(mainFrame)
		elseif cmd=="test" then
			print("TESTING DONTCAST")	--DELME
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
		eventFrame = CreateFrame("Frame", "eventFrame", UIParent)
		eventFrame:RegisterEvent("UNIT_AURA")
		eventFrame:SetScript("OnEvent", eventHandler)
		hideAndLockFrame(mainFrame)
		print("|cff9382C9".."DontCast loaded, for help type /dontcast ?")
	else
		print("|cffFF0000".."Error loading DontCast!")
	end
end

function eventHandler(self, event, unit, ...)
	if unit=="target" and event=="UNIT_AURA" then
		local name, rank, icon, count, type, dur, expTime = UnitAura("target", "Unending Breath")
		print(name, icon, expTime - GetTime()) --DELME
		textFrame:SetText(name)
		iconFrame:SetTexture(icon)
		showFrame(mainFrame)
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