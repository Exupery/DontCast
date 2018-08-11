local Dropdown = LibStub('Classy-1.0'):New('Frame'); Dropdown:Hide()
DontCastDropdown = Dropdown

function Dropdown:New(name, parent, width)
	local f = self:Bind(CreateFrame('Frame', parent:GetName() .. name, parent, 'UIDropDownMenuTemplate'))
	UIDropDownMenu_SetWidth(f, width)

	f:SetScript('OnShow', f.UpdateValue)
	return f
end

function Dropdown:SetSavedValue(value)
	UIDropDownMenu_SetSelectedValue(self, value)
end

function Dropdown:GetSavedValue()
	UIDropDownMenu_GetSelectedValue(self)
end

function Dropdown:GetSavedText()
  return self:GetSavedValue()
end

function Dropdown:UpdateValue()
	UIDropDownMenu_SetSelectedValue(self, self:GetSavedValue())
	UIDropDownMenu_SetText(self, self:GetSavedText())
end

function Dropdown:AddItem(name, value, tooltip)
  value = value or name

	local info = UIDropDownMenu_CreateInfo()
	info.text = name
  info.checked = (self:GetSavedValue() == value)
	info.func = function()
    self:SetSavedValue(value)
    self:UpdateValue()
  end

  if tooltip then
    info.tooltipTitle = name
    info.tooltipText = tooltip
    info.tooltipOnButton = true
  end

	UIDropDownMenu_AddButton(info)
end