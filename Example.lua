--[[
	AuroraUI — usage example
	Put this in a LocalScript (e.g. StarterPlayerScripts) alongside AuroraUI.lua,
	or load AuroraUI straight from GitHub with loadstring (see README).
]]

local AuroraUI = require(script.Parent.AuroraUI) -- or loadstring(game:HttpGet("..."))()

local Window = AuroraUI:CreateWindow({
	Title = "Aurora",
	SubTitle = "example.lua",
	Theme = "Midnight",        -- "Midnight" or "Dawn"
	Size = UDim2.fromOffset(620, 420),
	ToggleKey = Enum.KeyCode.RightControl,
})

----------------------------------------------------------------
-- Tab: Main
----------------------------------------------------------------
local Main = Window:CreateTab({ Name = "Main", Icon = "🏠" })

Main:AddLabel("Player")

Main:AddButton({
	Name = "Say Hello",
	Callback = function()
		Window:Notify({ Title = "Hello!", Content = "Button pressed.", Type = "Success", Duration = 3 })
	end,
})

Main:AddToggle({
	Name = "Infinite Jump",
	Flag = "InfJump",
	Default = false,
	Callback = function(state)
		print("Infinite Jump:", state)
	end,
})

Main:AddSlider({
	Name = "Walk Speed",
	Flag = "WalkSpeed",
	Min = 16,
	Max = 200,
	Default = 16,
	Increment = 1,
	Suffix = "",
	Callback = function(value)
		local char = game.Players.LocalPlayer.Character
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.WalkSpeed = value
		end
	end,
})

Main:AddDropdown({
	Name = "Theme",
	Flag = "SelectedTheme",
	Options = { "Midnight", "Dawn" },
	Default = "Midnight",
	Callback = function(value)
		print("Selected:", value)
	end,
})

Main:AddTextbox({
	Name = "Username",
	Flag = "TargetUser",
	Placeholder = "Enter a name...",
	Callback = function(text, enterPressed)
		print("Textbox:", text, enterPressed)
	end,
})

----------------------------------------------------------------
-- Tab: Info
----------------------------------------------------------------
local Info = Window:CreateTab({ Name = "Info", Icon = "ℹ️" })

Info:AddParagraph({
	Title = "About AuroraUI",
	Content = "A Fluent/Mica-inspired UI kit built for Roblox scripts. Lightweight, single module, no external assets required.",
})

Info:AddButton({
	Name = "Show a Warning Notification",
	Callback = function()
		Window:Notify({ Title = "Heads up", Content = "This is a warning-type toast.", Type = "Warning", Duration = 4 })
	end,
})
