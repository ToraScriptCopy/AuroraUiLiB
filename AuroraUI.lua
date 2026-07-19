--[[
	AuroraUI
	A Fluent/Mica-inspired UI library for Roblox, in the spirit of WPF UI.
	Single-module, no dependencies.

	Design language:
	  - "Mica" layered backgrounds (soft gradient + noise-free blur illusion)
	  - Acrylic side panels with translucency
	  - Accent-driven glow highlights instead of flat borders
	  - Spring-eased motion (overshoot) instead of linear tweens
	  - Rounded 10px corners, 1px hairline strokes at 8% opacity

	MIT License. See README.md.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--=============================================================
-- THEME
--=============================================================

local Themes = {
	Midnight = {
		Base = Color3.fromRGB(18, 19, 24),
		Layer1 = Color3.fromRGB(24, 26, 32),
		Layer2 = Color3.fromRGB(30, 32, 40),
		Layer3 = Color3.fromRGB(38, 41, 50),
		Stroke = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(235, 236, 240),
		SubText = Color3.fromRGB(150, 153, 165),
		Accent = Color3.fromRGB(120, 130, 255),
		AccentDim = Color3.fromRGB(80, 88, 190),
		Success = Color3.fromRGB(95, 210, 140),
		Warning = Color3.fromRGB(240, 180, 80),
		Danger = Color3.fromRGB(235, 95, 110),
	},
	Dawn = {
		Base = Color3.fromRGB(246, 247, 250),
		Layer1 = Color3.fromRGB(255, 255, 255),
		Layer2 = Color3.fromRGB(238, 240, 245),
		Layer3 = Color3.fromRGB(226, 229, 238),
		Stroke = Color3.fromRGB(20, 20, 30),
		Text = Color3.fromRGB(25, 27, 35),
		SubText = Color3.fromRGB(100, 103, 115),
		Accent = Color3.fromRGB(90, 100, 235),
		AccentDim = Color3.fromRGB(120, 128, 240),
		Success = Color3.fromRGB(45, 165, 105),
		Warning = Color3.fromRGB(210, 140, 30),
		Danger = Color3.fromRGB(210, 60, 75),
	},
}

--=============================================================
-- UTILITIES
--=============================================================

local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function pad(l, t, r, b)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or l or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingBottom = UDim.new(0, b or t or l or 0),
	})
end

local function gradient(colorSeq, rotation, transparencySeq)
	return create("UIGradient", {
		Color = colorSeq,
		Rotation = rotation or 90,
		Transparency = transparencySeq,
	})
end

-- Spring-ish eased tween (overshoot feel), used everywhere for "premium" motion
local function springTween(inst, props, duration, style)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.28, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function ripple(button, accentColor)
	local mouse = UserInputService:GetMouseLocation()
	local rel = mouse - Vector2.new(button.AbsolutePosition.X, button.AbsolutePosition.Y)

	local dot = create("Frame", {
		BackgroundColor3 = accentColor,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(rel.X, rel.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = button.ZIndex + 5,
		Parent = button,
	})
	corner(999).Parent = dot
	local maxDim = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.8
	springTween(dot, { Size = UDim2.fromOffset(maxDim, maxDim), BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quart)
	task.delay(0.55, function()
		dot:Destroy()
	end)
end

--=============================================================
-- LIBRARY
--=============================================================

local AuroraUI = {}
AuroraUI.__index = AuroraUI
AuroraUI.Themes = Themes

function AuroraUI:CreateWindow(config)
	config = config or {}
	local themeName = config.Theme or "Midnight"
	local T = Themes[themeName] or Themes.Midnight

	local self = setmetatable({}, AuroraUI)
	self.Theme = T
	self.Tabs = {}
	self.ActiveTab = nil
	self.Flags = {} -- component values keyed by Flag string, for saving/reading config
	self.Callbacks = {}

	-- destroy previous instance of this GUI, if reloaded via re-run
	local existing = PlayerGui:FindFirstChild("AuroraUI")
	if existing then
		existing:Destroy()
	end

	local screenGui = create("ScreenGui", {
		Name = "AuroraUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})
	self.ScreenGui = screenGui

	-- ===== root window =====
	local windowSize = config.Size or UDim2.fromOffset(620, 420)
	local root = create("Frame", {
		Name = "Root",
		Size = windowSize,
		Position = UDim2.new(0.5, -windowSize.X.Offset / 2, 0.5, -windowSize.Y.Offset / 2),
		BackgroundColor3 = T.Base,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	})
	corner(14).Parent = root
	stroke(T.Stroke, 1, 0.88).Parent = root

	-- Mica-style layered gradient backdrop (fake acrylic depth)
	local micaGlow = create("Frame", {
		Name = "MicaGlow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = root,
	})
	gradient(ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.Accent),
		ColorSequenceKeypoint.new(0.35, T.Base),
		ColorSequenceKeypoint.new(1, T.Base),
	}), 120, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.88),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(1, 1),
	})).Parent = micaGlow

	-- drop shadow illusion
	local shadow = create("ImageLabel", {
		Name = "Shadow",
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		Size = UDim2.new(1, 60, 1, 60),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = -1,
		Parent = root,
	})

	-- ===== title bar =====
	local titleBar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = root,
	})
	pad(16, 0, 16, 0).Parent = titleBar

	local accentDot = create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = T.Accent,
		Parent = titleBar,
	})
	corner(999).Parent = accentDot

	create("TextLabel", {
		Text = config.Title or "Aurora",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 18, 0, 0),
		Parent = titleBar,
	})

	create("TextLabel", {
		Text = config.SubTitle or "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 250, 1, 0),
		Position = UDim2.new(0, 18, 0, 14),
		Parent = titleBar,
	})

	local closeBtn = create("TextButton", {
		Text = "",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = T.Layer2,
		AutoButtonColor = false,
		Parent = titleBar,
	})
	corner(8).Parent = closeBtn
	create("TextLabel", {
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = closeBtn,
	})
	closeBtn.MouseEnter:Connect(function()
		springTween(closeBtn, { BackgroundColor3 = T.Danger }, 0.15)
	end)
	closeBtn.MouseLeave:Connect(function()
		springTween(closeBtn, { BackgroundColor3 = T.Layer2 }, 0.15)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		springTween(root, { Size = UDim2.fromOffset(windowSize.X.Offset, 0), BackgroundTransparency = 1 }, 0.25)
		task.delay(0.25, function()
			screenGui.Enabled = false
		end)
	end)

	local minBtn = create("TextButton", {
		Text = "",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -62, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = T.Layer2,
		AutoButtonColor = false,
		Parent = titleBar,
	})
	corner(8).Parent = minBtn
	create("TextLabel", {
		Text = "—",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = minBtn,
	})
	local minimized = false
	local fullSize = windowSize
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			springTween(root, { Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 46) }, 0.3)
		else
			springTween(root, { Size = fullSize }, 0.3)
		end
	end)

	-- drag support
	do
		local dragging, dragStart, startPos
		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = root.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end

	-- ===== sidebar (tab list) =====
	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 150, 1, -46),
		Position = UDim2.new(0, 0, 0, 46),
		BackgroundColor3 = T.Layer1,
		BackgroundTransparency = 0.4,
		Parent = root,
	})
	pad(10, 12, 10, 12).Parent = sidebar
	local sidebarList = create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebar,
	})

	-- vertical divider glow
	create("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = T.Stroke,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	-- ===== content pages container =====
	local pagesHolder = create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, -150, 1, -46),
		Position = UDim2.new(0, 150, 0, 46),
		BackgroundTransparency = 1,
		Parent = root,
	})

	self.Root = root
	self.Sidebar = sidebar
	self.PagesHolder = pagesHolder
	self.ScreenGui2 = screenGui

	-- open animation
	root.Size = UDim2.fromOffset(windowSize.X.Offset, 0)
	springTween(root, { Size = windowSize }, 0.4, Enum.EasingStyle.Back)

	-- Notifications container
	local notifHolder = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(300, 400),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	create("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notifHolder,
	})
	self.NotifHolder = notifHolder

	-- toggle GUI visibility with config.ToggleKey (default RightControl)
	local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == toggleKey then
			screenGui.Enabled = not screenGui.Enabled
		end
	end)

	return self
end

--=============================================================
-- NOTIFICATIONS
--=============================================================

function AuroraUI:Notify(config)
	config = config or {}
	local T = self.Theme
	local kind = config.Type or "Info" -- Info / Success / Warning / Danger
	local color = T.Accent
	if kind == "Success" then color = T.Success
	elseif kind == "Warning" then color = T.Warning
	elseif kind == "Danger" then color = T.Danger end

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Layer2,
		ClipsDescendants = true,
		Parent = self.NotifHolder,
	})
	corner(10).Parent = card
	stroke(T.Stroke, 1, 0.88).Parent = card
	pad(14, 12, 14, 12).Parent = card

	local bar = create("Frame", {
		Size = UDim2.new(0, 3, 1, -4),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = color,
		Parent = card,
	})
	corner(999).Parent = bar

	local layout = create("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = card,
	})

	create("TextLabel", {
		Text = config.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = card,
	})
	local desc = create("TextLabel", {
		Text = config.Content or "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})

	card.BackgroundTransparency = 1
	card.Position = UDim2.new(0, 40, 0, 0)
	springTween(card, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Back)

	task.delay(config.Duration or 4, function()
		if card and card.Parent then
			springTween(card, { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 0) }, 0.3)
			task.delay(0.3, function()
				card:Destroy()
			end)
		end
	end)
end

--=============================================================
-- TABS
--=============================================================

function AuroraUI:CreateTab(config)
	config = config or {}
	local T = self.Theme
	local windowSelf = self

	local tabBtn = create("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = T.Layer2,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		LayoutOrder = #self.Tabs + 1,
		Parent = self.Sidebar,
	})
	corner(8).Parent = tabBtn
	pad(10, 0, 10, 0).Parent = tabBtn

	create("TextLabel", {
		Text = (config.Icon and (config.Icon .. "  ") or "") .. (config.Name or "Tab"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
        Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Parent = tabBtn,
	})

	local page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Accent,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
		Visible = false,
		Parent = self.PagesHolder,
	})
	pad(18, 16, 18, 16).Parent = page
	create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})

	local tabObj = { Button = tabBtn, Page = page, Name = config.Name }
	table.insert(self.Tabs, tabObj)

	local function selectTab()
		for _, t in ipairs(windowSelf.Tabs) do
			t.Page.Visible = false
			springTween(t.Button, { BackgroundTransparency = 1 }, 0.2)
			t.Button.Label.TextColor3 = T.SubText
		end
		page.Visible = true
		springTween(tabBtn, { BackgroundTransparency = 0.5 }, 0.2)
		tabBtn.Label.TextColor3 = T.Text
		windowSelf.ActiveTab = tabObj
	end

	tabBtn.MouseButton1Click:Connect(selectTab)
	tabBtn.MouseEnter:Connect(function()
		if windowSelf.ActiveTab ~= tabObj then
			springTween(tabBtn, { BackgroundTransparency = 0.8 }, 0.15)
		end
	end)
	tabBtn.MouseLeave:Connect(function()
		if windowSelf.ActiveTab ~= tabObj then
			springTween(tabBtn, { BackgroundTransparency = 1 }, 0.15)
		end
	end)

	if #self.Tabs == 1 then
		selectTab()
	end

	--=========================================================
	-- COMPONENT FACTORY (scoped to this tab/page)
	--=========================================================
	local Components = {}
	local library = windowSelf

	local function sectionCard(height)
		local c = create("Frame", {
			Size = UDim2.new(1, 0, 0, height or 46),
			AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
			BackgroundColor3 = T.Layer2,
			BackgroundTransparency = 0.25,
			Parent = page,
		})
		corner(10).Parent = c
		stroke(T.Stroke, 1, 0.9).Parent = c
		return c
	end

	function Components:AddLabel(text)
		create("TextLabel", {
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = page,
		})
	end

	function Components:AddButton(cfg)
		cfg = cfg or {}
		local card = sectionCard(44)
		local btn = create("TextButton", {
			Text = "",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ClipsDescendants = true,
			Parent = card,
		})
		corner(10).Parent = btn
		create("TextLabel", {
			Text = cfg.Name or "Button",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = T.Text,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = btn,
		})
		btn.MouseEnter:Connect(function()
			springTween(card, { BackgroundColor3 = T.Layer3 }, 0.15)
		end)
		btn.MouseLeave:Connect(function()
			springTween(card, { BackgroundColor3 = T.Layer2 }, 0.15)
		end)
		btn.MouseButton1Click:Connect(function()
			ripple(btn, T.Accent)
			if cfg.Callback then
				task.spawn(cfg.Callback)
			end
		end)
		return btn
	end

	function Components:AddToggle(cfg)
		cfg = cfg or {}
		local state = cfg.Default or false
		local card = sectionCard(44)
		create("TextLabel", {
			Text = cfg.Name or "Toggle",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			Parent = card,
		})

		local switch = create("TextButton", {
			Text = "",
			Size = UDim2.fromOffset(40, 22),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = state and T.Accent or T.Layer3,
			AutoButtonColor = false,
			Parent = card,
		})
		corner(999).Parent = switch
		local knob = create("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = switch,
		})
		corner(999).Parent = knob

		local function set(newState, fireCallback)
			state = newState
			springTween(switch, { BackgroundColor3 = state and T.Accent or T.Layer3 }, 0.2)
			springTween(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.2, Enum.EasingStyle.Back)
			if cfg.Flag then library.Flags[cfg.Flag] = state end
			if fireCallback ~= false and cfg.Callback then
				task.spawn(cfg.Callback, state)
			end
		end

		switch.MouseButton1Click:Connect(function()
			set(not state)
		end)

		if cfg.Flag then library.Flags[cfg.Flag] = state end
		return { Set = function(_, v) set(v) end, Get = function() return state end }
	end

	function Components:AddSlider(cfg)
		cfg = cfg or {}
		local min, max = cfg.Min or 0, cfg.Max or 100
		local value = math.clamp(cfg.Default or min, min, max)
		local increment = cfg.Increment or 1

		local card = sectionCard(52)
		create("TextLabel", {
			Text = cfg.Name or "Slider",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -70, 0, 20),
			Position = UDim2.new(0, 14, 0, 6),
			Parent = card,
		})
		local valueLabel = create("TextLabel", {
			Text = tostring(value) .. (cfg.Suffix or ""),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = T.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 56, 0, 20),
			Position = UDim2.new(1, -70, 0, 6),
			Parent = card,
		})

		local track = create("Frame", {
			Size = UDim2.new(1, -28, 0, 6),
			Position = UDim2.new(0, 14, 1, -16),
			BackgroundColor3 = T.Layer3,
			Parent = card,
		})
		corner(999).Parent = track
		local fill = create("Frame", {
			Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
			BackgroundColor3 = T.Accent,
			Parent = track,
		})
		corner(999).Parent = fill
		local grabber = create("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = track,
		})
		corner(999).Parent = grabber
		stroke(T.Accent, 2, 0).Parent = grabber

		local dragging = false
		local function setFromAlpha(alpha)
			alpha = math.clamp(alpha, 0, 1)
			local raw = min + (max - min) * alpha
			raw = math.floor(raw / increment + 0.5) * increment
			raw = math.clamp(raw, min, max)
			value = raw
			local a = (value - min) / (max - min)
			fill.Size = UDim2.new(a, 0, 1, 0)
			grabber.Position = UDim2.new(a, 0, 0.5, 0)
			valueLabel.Text = tostring(value) .. (cfg.Suffix or "")
			if cfg.Flag then library.Flags[cfg.Flag] = value end
			if cfg.Callback then task.spawn(cfg.Callback, value) end
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
				setFromAlpha(alpha)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
				setFromAlpha(alpha)
			end
		end)

		if cfg.Flag then library.Flags[cfg.Flag] = value end
		return { Set = function(_, v) setFromAlpha((v - min) / (max - min)) end, Get = function() return value end }
	end

	function Components:AddDropdown(cfg)
		cfg = cfg or {}
		local options = cfg.Options or {}
		local selected = cfg.Default or options[1]
		local open = false

		local card = sectionCard(44)
		card.ClipsDescendants = true
		create("TextLabel", {
			Text = cfg.Name or "Dropdown",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, 0, 0, 44),
			Position = UDim2.new(0, 14, 0, 0),
			Parent = card,
		})
		local btn = create("TextButton", {
			Text = "",
			Size = UDim2.new(0.5, -14, 0, 30),
			Position = UDim2.new(1, -14, 0, 7),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = T.Layer3,
			AutoButtonColor = false,
			Parent = card,
		})
		corner(8).Parent = btn
		local selLabel = create("TextLabel", {
			Text = tostring(selected or "Select..") .. "  ▾",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = T.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = btn,
		})

		local list = create("Frame", {
			Size = UDim2.new(1, -28, 0, #options * 28),
			Position = UDim2.new(0, 14, 0, 44),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local listLayout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

		for _, opt in ipairs(options) do
			local optBtn = create("TextButton", {
				Text = "",
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = T.Layer3,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Parent = list,
			})
			corner(6).Parent = optBtn
			create("TextLabel", {
				Text = tostring(opt),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = T.SubText,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = optBtn,
			})
			optBtn.MouseEnter:Connect(function()
				springTween(optBtn, { BackgroundTransparency = 0.6 }, 0.12)
			end)
			optBtn.MouseLeave:Connect(function()
				springTween(optBtn, { BackgroundTransparency = 1 }, 0.12)
			end)
			optBtn.MouseButton1Click:Connect(function()
				selected = opt
				selLabel.Text = tostring(selected) .. "  ▾"
				open = false
				springTween(card, { Size = UDim2.new(1, 0, 0, 44) }, 0.2)
				if cfg.Flag then library.Flags[cfg.Flag] = selected end
				if cfg.Callback then task.spawn(cfg.Callback, selected) end
			end)
		end

		btn.MouseButton1Click:Connect(function()
			open = not open
			if open then
				springTween(card, { Size = UDim2.new(1, 0, 0, 44 + #options * 28 + 6) }, 0.25)
			else
				springTween(card, { Size = UDim2.new(1, 0, 0, 44) }, 0.2)
			end
		end)

		if cfg.Flag then library.Flags[cfg.Flag] = selected end
		return {
			Set = function(_, v)
				selected = v
				selLabel.Text = tostring(v) .. "  ▾"
			end,
			Get = function() return selected end,
		}
	end

	function Components:AddTextbox(cfg)
		cfg = cfg or {}
		local card = sectionCard(44)
		create("TextLabel", {
			Text = cfg.Name or "Input",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			Parent = card,
		})
		local box = create("TextBox", {
			Text = cfg.Default or "",
			PlaceholderText = cfg.Placeholder or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = T.Text,
			PlaceholderColor3 = T.SubText,
			ClearTextOnFocus = false,
			BackgroundColor3 = T.Layer3,
			Size = UDim2.new(0.5, -14, 0, 28),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = card,
		})
		corner(8).Parent = box
		pad(8, 0, 8, 0).Parent = box

		box.FocusLost:Connect(function(enterPressed)
			if cfg.Flag then library.Flags[cfg.Flag] = box.Text end
			if cfg.Callback then task.spawn(cfg.Callback, box.Text, enterPressed) end
		end)

		if cfg.Flag then library.Flags[cfg.Flag] = box.Text end
		return { Set = function(_, v) box.Text = v end, Get = function() return box.Text end }
	end

	function Components:AddParagraph(cfg)
		cfg = cfg or {}
		local card = sectionCard()
		pad(14, 12, 14, 12).Parent = card
		local layout = create("UIListLayout", { Padding = UDim.new(0, 4), Parent = card })
		create("TextLabel", {
			Text = cfg.Title or "",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = card,
		})
		create("TextLabel", {
			Text = cfg.Content or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = T.SubText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		})
	end

	tabObj.Components = Components
	return Components
end

return AuroraUI
