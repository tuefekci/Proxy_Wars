--[[
Parameters:
	Required:
		name - Name of the tab GUI object
		navButtons - Array of tables {name="", caption=""}
		tabs - Table of functions that are given keys that match a navButton name
			 - These functions will be provided the flow of the tab to add elements to
		
	One of the following:
		player - Player object
		parent - Factorio GUI object
		
	Optional:
		active - name of the active tab
		
Example:
	GUI.TabLib.Create{
		name = "Tabbed_Frame",
		navButtons = 
		{
			{
				name="Option_1",
				caption="Option 1 Caption"
			},
			{
				name="Option_2",
				caption="Option 2 Caption"
			}
		},
		tabs = 
		{
			Option_1 = func(),
			Option_2 = func()
		},
		player = game.players[event.player_index],
		active = "Option_2"
	}
]]--

--[[
Tab UI Hierarchy:
"name (type - direction [if needed]) - description"

data.name (frame - vertical) - The whole tab UI
├─ data.name.."_nav" (flow - horizontal) - Navigation flow
│	├── data.name.."_nav_"..navButton[1].name (label) - The first button is "active" by default, but whichever button is active is a label
│	├── data.name.."_nav_"..navButton[2].name (button) -  The rest are buttons. All nav buttons/labels have the navButton.caption as the caption
│	├── data.name.."_nav_"..navButton[3].name (button)
│	└── ...
└─ data.name.."_"..data.active.."_tab" (flow - vertical) - The flow used for the tab data itself
	└── data.tab -	The function for the active tab is used to draw the interior of this flow
]]--

Utils.TabLib = {}

Utils.TabLib.Init = function()
	global.TabLibData = global.TabLibData or {}
end

Utils.TabLib.Debug = function(message)
	Debug.info("[TabLib]"..message)
end

--If it already exists then switch to the active tab
Utils.TabLib.Create = function(d, verified)
	d.verified = verified
	local data = Utils.TabLib.VerifyData(d)
	
	if data then
		Utils.TabLib.Debug("Creating tab for "..data.name)
		if not Utils.TabLib.Verify(data) then
			Utils.TabLib.Draw(data)
			Utils.TabLib.RegisterEvents(data)
		else
			Utils.TabLib.Switch(data, true)
		end
	end
end

--Either create the whole GUI if it doesn't exist, destroy it if the active tab matches the data, or switch to the data.active
Utils.TabLib.Toggle = function(d, verified)
	d.verified = verified
	local data = Utils.TabLib.VerifyData(d)
	
	if data then
		Utils.TabLib.Debug("Toggling tab for "..data.name)
		if Utils.TabLib.Verify(data) then
			if Utils.TabLib.VerifyActive(data) then
				Utils.TabLib.Destroy(data, true)
			else
				Utils.TabLib.Refresh(data, true)
			end
		else
			Utils.TabLib.Create(data, true)
		end
	end
end

Utils.TabLib.Switch = function(d, verified)
	d.verified = verified
	local data = Utils.TabLib.VerifyData(d)
	
	if data then
		Utils.TabLib.Debug("Switching tab for "..data.name)
		--If the tab UI exists and if the active tab in the data is not already shown
		if Utils.TabLib.Verify(data) and not Utils.TabLib.VerifyActive(data) then
			Utils.TabLib.Refresh(data, true)
		end
	end
end

Utils.TabLib.Refresh = function(d, verified)
	d.verified = verified
	local data = Utils.TabLib.VerifyData(d)
	
	if data then
		Utils.TabLib.Debug("Refreshing tab for "..data.name)
		if Utils.TabLib.Verify(data) then
			Utils.TabLib.Destroy(data, true)
			Utils.TabLib.Draw(data)
		end
	end
end

Utils.TabLib.Destroy = function(d, verified)
	d.verified = verified
	local data = Utils.TabLib.VerifyData(d)
	
	if data then
		Utils.TabLib.Debug("Destroying tab for "..data.name)
		if Utils.TabLib.Verify(data) then
			data.parent[data.name].destroy()
			global.TabLibData[data.name][data.player.name] = nil
		end
	end
end

Utils.TabLib.Draw = function(data)
	Utils.TabLib.Debug("Drawing "..data.active.." tab for "..data.name)
	local mainFrame = data.parent.add{type="frame", name=data.name, direction="vertical"}
	local navFlow = mainFrame.add{type="flow", name=data.name.."_nav", direction="horizontal"}
	
	for _, navButton in pairs(data.navButtons) do
		if data.active == navButton.name then
			navFlow.add{type="label", name=Utils.TabLib.NavButtonName(navButton, data), caption=navButton.caption, style="Proxy_Wars_tab_nav_active"} --TODO - these styles need made
		else
			navFlow.add{type="button", name=Utils.TabLib.NavButtonName(navButton, data), caption=navButton.caption, style="Proxy_Wars_tab_nav_inactive"} --TODO - these styles need made
		end
	end
	
	local tabFlow = mainFrame.add{type="flow", name=data.name.."_"..data.active.."_tab", direction="vertical"}
	data.tabs[data.active](tabFlow)
	
	global.TabLibData[data.name] = global.TabLibData[data.name] or {}
	global.TabLibData[data.name][data.player.name] = data
end

Utils.TabLib.RegisterEvents = function(data)
	for _, navButton in pairs(data.navButtons) do
		Utils.Events.GUI.Add(Utils.TabLib.NavButtonName(navButton, data), Utils.TabLib.Events.OnGuiClicked)
	end
end

Utils.TabLib.NavButtonName = function(navButton, data)
	return data.name.."_nav_"..navButton.name
end

Utils.TabLib.Events = {}
Utils.TabLib.Events.OnGuiClicked = function(event)
	local element = event.element
	local player = game.players[event.player_index]
	
	--Only if a different tab was selected
	if element.type == "button" then
		local data = global.TabLibData[element.parent.parent.name][player.name]
		data.active = string.sub(element.name, string.len(data.name) + 6) --Trim off the unique parts of the navButtonName
		Utils.TabLib.Switch(data)
	end
end

Utils.TabLib.Verify = function(data)
	if data.parent[data.name] then
		return true
	end
	return false
end

Utils.TabLib.VerifyActive = function(data)
	if Utils.TabLib.Verify(data) then
		for _, navButton in pairs(data.parent[data.name][data.name.."_nav"].children) do
			if navButton.type == "label" then
				if string.find(navButton.name, data.active) then
					return true
				end
				return false
			end
		end
	end
	return false
end

Utils.TabLib.VerifyData = function(d)
	local data = Utils.Table.Deepcopy(d)
	if data and data.name and data.navButtons and data.tabs then
		--If this data has already been verified then skip further verification
		if data.verified then return data end
		
		--Either player or parent is required
		--Make sure we have somewhere to draw the tab
		if data.parent then
			if not data.parent.valid then return nil end
			if not data.player then
				data.player = data.parent.player
			end
		else
			if not data.player then return nil end
			data.parent = data.player.gui.center
		end
		
		--Verify that each nav button has a tab
		for _, navButton in pairs(data.navButtons) do
			if navButton.name and navButton.caption then
				if not data.tabs[navButton.name] then return nil end
				if type(data.tabs[navButton.name]) ~= "function" then return nil end
			else
				return nil
			end
		end
		
		--Verify the active tab or set it
		if not data.active then
			data.active = data.navButtons[1].name
		end
		
		data.verified = true
		return data
	end
	return nil
end