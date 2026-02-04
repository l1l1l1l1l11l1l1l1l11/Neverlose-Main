local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local ScreenGui = Instance.new("ScreenGui")
ProtectGui(ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local Toggles = {}
local Options = {}

getgenv().Toggles = Toggles
getgenv().Options = Options

local Theme = {
    Font = Enum.Font.Code,
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 85, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    RiskColor = Color3.fromRGB(255, 50, 50),
    SuccessColor = Color3.fromRGB(50, 255, 50),
    WarningColor = Color3.fromRGB(255, 255, 50),
    Black = Color3.new(0, 0, 0),
    White = Color3.new(1, 1, 1),
    
    GetDarkerColor = function(color)
        local h, s, v = Color3.toHSV(color)
        return Color3.fromHSV(h, s, v / 1.5)
    end
}

Theme.AccentColorDark = Theme.GetDarkerColor(Theme.AccentColor)

local Library = {
    Theme = Theme,
    ScreenGui = ScreenGui,
    Registry = {},
    RegistryMap = {},
    Signals = {},
    OpenedFrames = {},
    Elements = {},
    
    CurrentRainbowHue = 0,
    CurrentRainbowColor = Color3.new(1, 1, 1),
    
    ColorClipboard = nil,
    ToggleKeybind = nil,
    
    Notifications = {},
    Watermark = nil,
    KeybindFrame = nil
}

local function CreateInstance(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties) do
        instance[prop] = value
    end
    return instance
end

local function ApplyTextStroke(instance)
    instance.TextStrokeTransparency = 1
    local stroke = CreateInstance("UIStroke", {
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = instance
    })
    return stroke
end

function Library:CreateLabel(properties)
    local label = CreateInstance("TextLabel", {
        BackgroundTransparency = 1,
        Font = Theme.Font,
        TextColor3 = Theme.FontColor,
        TextSize = 16,
        TextStrokeTransparency = 0
    })
    
    ApplyTextStroke(label)
    
    self:AddToRegistry(label, {
        TextColor3 = "FontColor"
    })
    
    for prop, value in pairs(properties) do
        label[prop] = value
    end
    
    return label
end

function Library:AddToRegistry(instance, properties)
    local data = {
        Instance = instance,
        Properties = properties,
        Id = #self.Registry + 1
    }
    
    table.insert(self.Registry, data)
    self.RegistryMap[instance] = data
    return data
end

function Library:RemoveFromRegistry(instance)
    local data = self.RegistryMap[instance]
    if data then
        for i = #self.Registry, 1, -1 do
            if self.Registry[i] == data then
                table.remove(self.Registry, i)
                break
            end
        end
        self.RegistryMap[instance] = nil
    end
end

function Library:UpdateColors()
    for _, data in pairs(self.Registry) do
        for property, colorKey in pairs(data.Properties) do
            if type(colorKey) == "string" then
                data.Instance[property] = Theme[colorKey]
            elseif type(colorKey) == "function" then
                data.Instance[property] = colorKey()
            end
        end
    end
end

function Library:MakeDraggable(frame, handleHeight)
    handleHeight = handleHeight or 20
    local dragging = false
    local dragStart, frameStart
    
    local function Update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            frameStart.X.Scale, 
            frameStart.X.Offset + delta.X,
            frameStart.Y.Scale,
            frameStart.Y.Offset + delta.Y
        )
    end
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = Vector2.new(
                Mouse.X - frame.AbsolutePosition.X,
                Mouse.Y - frame.AbsolutePosition.Y
            )
            
            if pos.Y <= handleHeight then
                dragging = true
                dragStart = input.Position
                frameStart = frame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            Update(input)
        end
    end)
end

function Library:MouseIsOverFrame(frame)
    local pos = frame.AbsolutePosition
    local size = frame.AbsoluteSize
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    return mousePos.X >= pos.X and mousePos.X <= pos.X + size.X and
           mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + size.Y
end

function Library:AddSignal(signal)
    table.insert(self.Signals, signal)
    return signal
end

function Library:Unload()
    for i = #self.Signals, 1, -1 do
        local signal = table.remove(self.Signals, i)
        if signal.Disconnect then
            signal:Disconnect()
        end
    end
    
    if self.OnUnload then
        self:OnUnload()
    end
    
    ScreenGui:Destroy()
end

function Library:OnUnload(callback)
    self.OnUnload = callback
end

local RainbowStep = 0
local RainbowHue = 0
Library:AddSignal(RunService.RenderStepped:Connect(function(delta)
    RainbowStep = RainbowStep + delta
    
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        RainbowHue = (RainbowHue + (1 / 300)) % 1
        Library.CurrentRainbowHue = RainbowHue
        Library.CurrentRainbowColor = Color3.fromHSV(RainbowHue, 0.8, 1)
    end
end))

function Library:CreateWindow(config)
    config = config or {}
    
    local window = {
        Tabs = {},
        Container = nil,
        IsOpen = false
    }
    
    local outer = CreateInstance("Frame", {
        Name = "Window",
        BackgroundColor3 = Theme.Black,
        BorderSizePixel = 0,
        Position = config.Position or UDim2.new(0.5, -275, 0.5, -300),
        Size = config.Size or UDim2.new(0, 550, 0, 600),
        Visible = false,
        Parent = ScreenGui
    })
    
    local inner = CreateInstance("Frame", {
        BackgroundColor3 = Theme.MainColor,
        BorderColor3 = Theme.AccentColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.new(0, 1, 0, 1),
        Parent = outer
    })
    
    self:AddToRegistry(inner, {
        BackgroundColor3 = "MainColor",
        BorderColor3 = "AccentColor"
    })
    
    local titleBar = CreateInstance("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 25),
        Parent = inner
    })
    
    local titleLabel = self:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0.5, -8, 1, 0),
        Text = config.Title or "Window",
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar
    })
    
    self:MakeDraggable(outer, 25)
    
    local closeButton = CreateInstance("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -25, 0, 0),
        Size = UDim2.new(0, 25, 1, 0),
        Text = "X",
        TextColor3 = Theme.FontColor,
        Font = Theme.Font,
        TextSize = 16,
        Parent = titleBar
    })
    
    self:AddToRegistry(closeButton, {
        TextColor3 = "FontColor"
    })
    
    local tabArea = CreateInstance("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 30),
        Size = UDim2.new(1, -16, 0, 30),
        Parent = inner
    })
    
    local tabLayout = CreateInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = tabArea
    })
    
    local contentArea = CreateInstance("Frame", {
        BackgroundColor3 = Theme.BackgroundColor,
        BorderColor3 = Theme.OutlineColor,
        Position = UDim2.new(0, 8, 0, 65),
        Size = UDim2.new(1, -16, 1, -73),
        Parent = inner
    })
    
    self:AddToRegistry(contentArea, {
        BackgroundColor3 = "BackgroundColor",
        BorderColor3 = "OutlineColor"
    })
    
    function window:SetTitle(text)
        titleLabel.Text = text
    end
    
    function window:Toggle()
        self.IsOpen = not self.IsOpen
        outer.Visible = self.IsOpen
    end
    
    function window:Show()
        self.IsOpen = true
        outer.Visible = true
    end
    
    function window:Hide()
        self.IsOpen = false
        outer.Visible = false
    end
    
    closeButton.MouseButton1Click:Connect(function()
        window:Hide()
    end)
    
    local function createTabContent()
        local content = CreateInstance("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.AccentColor,
            Visible = false,
            Parent = contentArea
        })
        
        self:AddToRegistry(content, {
            ScrollBarImageColor3 = "AccentColor"
        })
        
        local layout = CreateInstance("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = content
        })
        
        local padding = CreateInstance("UIPadding", {
            PaddingTop = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            Parent = content
        })
        
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
        end)
        
        return content
    end
    
    function window:AddTab(name)
        local tab = {
            Name = name,
            Content = nil,
            Button = nil,
            Groupboxes = {}
        }
        
        local tabButton = CreateInstance("TextButton", {
            BackgroundColor3 = Theme.BackgroundColor,
            BorderColor3 = Theme.OutlineColor,
            Size = UDim2.new(0, 80, 1, 0),
            Text = name,
            TextColor3 = Theme.FontColor,
            Font = Theme.Font,
            TextSize = 14,
            Parent = tabArea
        })
        
        self:AddToRegistry(tabButton, {
            BackgroundColor3 = "BackgroundColor",
            BorderColor3 = "OutlineColor",
            TextColor3 = "FontColor"
        })
        
        local content = createTabContent()
        
        function tab:Show()
            for _, otherTab in pairs(window.Tabs) do
                otherTab:Hide()
            end
            
            content.Visible = true
            tabButton.BackgroundColor3 = Theme.AccentColor
            Library:UpdateColors()
        end
        
        function tab:Hide()
            content.Visible = false
            tabButton.BackgroundColor3 = Theme.BackgroundColor
            Library:UpdateColors()
        end
        
        function tab:AddGroupbox(name)
            local groupbox = {
                Name = name,
                Container = nil,
                Elements = {}
            }
            
            local outerBox = CreateInstance("Frame", {
                BackgroundColor3 = Theme.MainColor,
                BorderColor3 = Theme.OutlineColor,
                Size = UDim2.new(1, 0, 0, 0),
                Parent = content
            })
            
            self:AddToRegistry(outerBox, {
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor"
            })
            
            local header = CreateInstance("Frame", {
                BackgroundColor3 = Theme.AccentColor,
                Size = UDim2.new(1, 0, 0, 2),
                Parent = outerBox
            })
            
            self:AddToRegistry(header, {
                BackgroundColor3 = "AccentColor"
            })
            
            local title = self:CreateLabel({
                Position = UDim2.new(0, 8, 0, 4),
                Size = UDim2.new(1, -16, 0, 20),
                Text = name,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = outerBox
            })
            
            local container = CreateInstance("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 30),
                Size = UDim2.new(1, -16, 1, -38),
                Parent = outerBox
            })
            
            local layout = CreateInstance("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = container
            })
            
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                outerBox.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 38)
            end)
            
            groupbox.Container = container
            tab.Groupboxes[name] = groupbox
            
            function groupbox:AddElement(element)
                table.insert(self.Elements, element)
                element.Parent = container
                
                local function updateSize()
                    local totalHeight = 0
                    for _, elem in pairs(self.Elements) do
                        if elem.Visible then
                            totalHeight = totalHeight + (elem.Size.Y.Offset or elem.Size.Y.Scale * container.AbsoluteSize.Y)
                        end
                    end
                    outerBox.Size = UDim2.new(1, 0, 0, totalHeight + 38)
                end
                
                if element:IsA("GuiObject") then
                    element:GetPropertyChangedSignal("Visible"):Connect(updateSize)
                end
                updateSize()
                
                return element
            end
            
            setmetatable(groupbox, {
                __index = function(self, key)
                    local elementTypes = {
                        Toggle = function(name, options)
                            options = options or {}
                            local toggle = {
                                Value = options.Default or false,
                                Type = "Toggle",
                                Callback = options.Callback or function() end
                            }
                            
                            local holder = CreateInstance("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 20),
                                Parent = self.Container
                            })
                            
                            local boxOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Size = UDim2.new(0, 14, 0, 14),
                                Position = UDim2.new(0, 0, 0, 3),
                                Parent = holder
                            })
                            
                            local boxInner = CreateInstance("Frame", {
                                BackgroundColor3 = toggle.Value and Theme.AccentColor or Theme.MainColor,
                                BorderColor3 = toggle.Value and Theme.AccentColorDark or Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = boxOuter
                            })
                            
                            Library:AddToRegistry(boxInner, {
                                BackgroundColor3 = function()
                                    return toggle.Value and Theme.AccentColor or Theme.MainColor
                                end,
                                BorderColor3 = function()
                                    return toggle.Value and Theme.AccentColorDark or Theme.OutlineColor
                                end
                            })
                            
                            local label = Library:CreateLabel({
                                Position = UDim2.new(0, 22, 0, 0),
                                Size = UDim2.new(1, -22, 1, 0),
                                Text = name,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = holder
                            })
                            
                            local function updateToggle()
                                boxInner.BackgroundColor3 = toggle.Value and Theme.AccentColor or Theme.MainColor
                                boxInner.BorderColor3 = toggle.Value and Theme.AccentColorDark or Theme.OutlineColor
                                Library:UpdateColors()
                            end
                            
                            function toggle:SetValue(value)
                                toggle.Value = value
                                updateToggle()
                                Library:SafeCallback(toggle.Callback, value)
                                if toggle.Changed then
                                    toggle.Changed(value)
                                end
                            end
                            
                            function toggle:OnChanged(callback)
                                toggle.Changed = callback
                                callback(toggle.Value)
                            end
                            
                            local hitbox = CreateInstance("TextButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 1, 0),
                                Text = "",
                                Parent = holder
                            })
                            
                            hitbox.MouseButton1Click:Connect(function()
                                toggle:SetValue(not toggle.Value)
                            end)
                            
                            if options.Risky then
                                label.TextColor3 = Theme.RiskColor
                                Library:AddToRegistry(label, {
                                    TextColor3 = "RiskColor"
                                })
                            end
                            
                            Toggles[name] = toggle
                            updateToggle()
                            
                            return self:AddElement(holder)
                        end,
                        
                        Slider = function(name, options)
                            options = options or {}
                            local slider = {
                                Value = options.Default or options.Min or 0,
                                Min = options.Min or 0,
                                Max = options.Max or 100,
                                Rounding = options.Rounding or 0,
                                Type = "Slider",
                                Callback = options.Callback or function() end
                            }
                            
                            local holder = CreateInstance("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 40),
                                Parent = self.Container
                            })
                            
                            local label = Library:CreateLabel({
                                Size = UDim2.new(1, 0, 0, 15),
                                Text = name,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = holder
                            })
                            
                            local valueLabel = Library:CreateLabel({
                                Position = UDim2.new(1, -50, 0, 0),
                                Size = UDim2.new(0, 50, 0, 15),
                                Text = tostring(slider.Value),
                                TextXAlignment = Enum.TextXAlignment.Right,
                                Parent = holder
                            })
                            
                            local trackOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Position = UDim2.new(0, 0, 0, 20),
                                Size = UDim2.new(1, 0, 0, 10),
                                Parent = holder
                            })
                            
                            local trackInner = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.MainColor,
                                BorderColor3 = Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = trackOuter
                            })
                            
                            Library:AddToRegistry(trackInner, {
                                BackgroundColor3 = "MainColor",
                                BorderColor3 = "OutlineColor"
                            })
                            
                            local fill = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.AccentColor,
                                BorderColor3 = Theme.AccentColorDark,
                                Size = UDim2.new(0, 0, 1, 0),
                                Parent = trackInner
                            })
                            
                            Library:AddToRegistry(fill, {
                                BackgroundColor3 = "AccentColor",
                                BorderColor3 = "AccentColorDark"
                            })
                            
                            local function round(num)
                                if slider.Rounding == 0 then
                                    return math.floor(num)
                                end
                                return tonumber(string.format("%." .. slider.Rounding .. "f", num))
                            end
                            
                            local function updateSlider()
                                local percent = (slider.Value - slider.Min) / (slider.Max - slider.Min)
                                fill.Size = UDim2.new(percent, 0, 1, 0)
                                valueLabel.Text = tostring(slider.Value)
                            end
                            
                            function slider:SetValue(value)
                                slider.Value = math.clamp(round(value), slider.Min, slider.Max)
                                updateSlider()
                                Library:SafeCallback(slider.Callback, slider.Value)
                                if slider.Changed then
                                    slider.Changed(slider.Value)
                                end
                            end
                            
                            function slider:OnChanged(callback)
                                slider.Changed = callback
                                callback(slider.Value)
                            end
                            
                            local dragging = false
                            trackOuter.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                    dragging = true
                                    local mouseX = Mouse.X
                                    local trackAbsX = trackOuter.AbsolutePosition.X
                                    local trackWidth = trackOuter.AbsoluteSize.X
                                    
                                    while dragging do
                                        local newX = math.clamp(Mouse.X - trackAbsX, 0, trackWidth)
                                        local percent = newX / trackWidth
                                        local value = slider.Min + (percent * (slider.Max - slider.Min))
                                        slider:SetValue(round(value))
                                        RunService.RenderStepped:Wait()
                                    end
                                end
                            end)
                            
                            trackOuter.InputEnded:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                    dragging = false
                                end
                            end)
                            
                            updateSlider()
                            Options[name] = slider
                            
                            return self:AddElement(holder)
                        end,
                        
                        Dropdown = function(name, options)
                            options = options or {}
                            local dropdown = {
                                Value = options.Default,
                                Values = options.Values or {},
                                Multi = options.Multi or false,
                                Type = "Dropdown",
                                Callback = options.Callback or function() end,
                                Open = false
                            }
                            
                            local holder = CreateInstance("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 40),
                                Parent = self.Container
                            })
                            
                            local label = Library:CreateLabel({
                                Size = UDim2.new(1, 0, 0, 15),
                                Text = name,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = holder
                            })
                            
                            local boxOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Position = UDim2.new(0, 0, 0, 20),
                                Size = UDim2.new(1, 0, 0, 20),
                                Parent = holder
                            })
                            
                            local boxInner = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.MainColor,
                                BorderColor3 = Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = boxOuter
                            })
                            
                            Library:AddToRegistry(boxInner, {
                                BackgroundColor3 = "MainColor",
                                BorderColor3 = "OutlineColor"
                            })
                            
                            local displayText = Library:CreateLabel({
                                Position = UDim2.new(0, 5, 0, 0),
                                Size = UDim2.new(1, -25, 1, 0),
                                Text = dropdown.Value or "Select...",
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = boxInner
                            })
                            
                            local arrow = CreateInstance("ImageLabel", {
                                BackgroundTransparency = 1,
                                Position = UDim2.new(1, -20, 0.5, -6),
                                Size = UDim2.new(0, 12, 0, 12),
                                Image = "rbxassetid://6031091003",
                                Parent = boxInner
                            })
                            
                            local listOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Position = UDim2.new(0, 0, 1, 1),
                                Size = UDim2.new(1, 0, 0, 0),
                                Visible = false,
                                ClipsDescendants = true,
                                Parent = boxOuter
                            })
                            
                            local listInner = CreateInstance("ScrollingFrame", {
                                BackgroundColor3 = Theme.MainColor,
                                BorderColor3 = Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                CanvasSize = UDim2.new(0, 0, 0, 0),
                                ScrollBarThickness = 4,
                                ScrollBarImageColor3 = Theme.AccentColor,
                                Parent = listOuter
                            })
                            
                            Library:AddToRegistry(listInner, {
                                BackgroundColor3 = "MainColor",
                                BorderColor3 = "OutlineColor",
                                ScrollBarImageColor3 = "AccentColor"
                            })
                            
                            local listLayout = CreateInstance("UIListLayout", {
                                FillDirection = Enum.FillDirection.Vertical,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                                Parent = listInner
                            })
                            
                            local function updateDisplay()
                                if dropdown.Multi then
                                    local selected = {}
                                    for _, value in pairs(dropdown.Values) do
                                        if dropdown.Value[value] then
                                            table.insert(selected, value)
                                        end
                                    end
                                    displayText.Text = #selected > 0 and table.concat(selected, ", ") or "Select..."
                                else
                                    displayText.Text = dropdown.Value or "Select..."
                                end
                            end
                            
                            local function updateList()
                                for _, child in pairs(listInner:GetChildren()) do
                                    if not child:IsA("UIListLayout") then
                                        child:Destroy()
                                    end
                                end
                                
                                for _, value in pairs(dropdown.Values) do
                                    local button = CreateInstance("TextButton", {
                                        BackgroundColor3 = Theme.MainColor,
                                        BorderColor3 = Theme.OutlineColor,
                                        BorderSizePixel = 1,
                                        Size = UDim2.new(1, 0, 0, 20),
                                        Text = "",
                                        Parent = listInner
                                    })
                                    
                                    local buttonLabel = Library:CreateLabel({
                                        Size = UDim2.new(1, -10, 1, 0),
                                        Position = UDim2.new(0, 5, 0, 0),
                                        Text = value,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        Parent = button
                                    })
                                    
                                    local selected = dropdown.Multi and dropdown.Value[value] or dropdown.Value == value
                                    buttonLabel.TextColor3 = selected and Theme.AccentColor or Theme.FontColor
                                    
                                    Library:AddToRegistry(buttonLabel, {
                                        TextColor3 = function()
                                            local sel = dropdown.Multi and dropdown.Value[value] or dropdown.Value == value
                                            return sel and "AccentColor" or "FontColor"
                                        end
                                    })
                                    
                                    button.MouseButton1Click:Connect(function()
                                        if dropdown.Multi then
                                            dropdown.Value[value] = not dropdown.Value[value]
                                        else
                                            dropdown.Value = dropdown.Value == value and nil or value
                                        end
                                        
                                        updateDisplay()
                                        updateList()
                                        Library:SafeCallback(dropdown.Callback, dropdown.Value)
                                        if dropdown.Changed then
                                            dropdown.Changed(dropdown.Value)
                                        end
                                    end)
                                end
                                
                                local itemCount = #dropdown.Values
                                local maxHeight = math.min(itemCount * 22, 110)
                                listOuter.Size = UDim2.new(1, 0, 0, maxHeight)
                                listInner.CanvasSize = UDim2.new(0, 0, 0, itemCount * 22)
                            end
                            
                            function dropdown:SetValues(values)
                                dropdown.Values = values
                                updateList()
                            end
                            
                            function dropdown:SetValue(value)
                                if dropdown.Multi then
                                    if type(value) == "table" then
                                        dropdown.Value = value
                                    else
                                        dropdown.Value = {}
                                        dropdown.Value[value] = true
                                    end
                                else
                                    dropdown.Value = value
                                end
                                updateDisplay()
                                updateList()
                                Library:SafeCallback(dropdown.Callback, dropdown.Value)
                            end
                            
                            function dropdown:OnChanged(callback)
                                dropdown.Changed = callback
                                if dropdown.Value then
                                    callback(dropdown.Value)
                                end
                            end
                            
                            local function toggleList()
                                dropdown.Open = not dropdown.Open
                                listOuter.Visible = dropdown.Open
                                arrow.Rotation = dropdown.Open and 180 or 0
                            end
                            
                            boxInner.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                    toggleList()
                                end
                            end)
                            
                            Library:AddSignal(UserInputService.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                    if dropdown.Open and not Library:MouseIsOverFrame(listOuter) and not Library:MouseIsOverFrame(boxInner) then
                                        toggleList()
                                    end
                                end
                            end))
                            
                            if dropdown.Default then
                                dropdown:SetValue(dropdown.Default)
                            end
                            
                            updateList()
                            Options[name] = dropdown
                            
                            return self:AddElement(holder)
                        end,
                        
                        Button = function(name, options)
                            options = options or {}
                            local button = {
                                Type = "Button",
                                Callback = options.Callback or function() end
                            }
                            
                            local holder = CreateInstance("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 25),
                                Parent = self.Container
                            })
                            
                            local btnOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = holder
                            })
                            
                            local btnInner = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.MainColor,
                                BorderColor3 = Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = btnOuter
                            })
                            
                            Library:AddToRegistry(btnInner, {
                                BackgroundColor3 = "MainColor",
                                BorderColor3 = "OutlineColor"
                            })
                            
                            local label = Library:CreateLabel({
                                Size = UDim2.new(1, 0, 1, 0),
                                Text = name,
                                Parent = btnInner
                            })
                            
                            local hitbox = CreateInstance("TextButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 1, 0),
                                Text = "",
                                Parent = btnOuter
                            })
                            
                            hitbox.MouseButton1Click:Connect(function()
                                Library:SafeCallback(button.Callback)
                            end)
                            
                            Library:OnHighlight(hitbox, btnOuter,
                                { BorderColor3 = "AccentColor" },
                                { BorderColor3 = "Black" }
                            )
                            
                            return self:AddElement(holder)
                        end,
                        
                        Input = function(name, options)
                            options = options or {}
                            local input = {
                                Value = options.Default or "",
                                Placeholder = options.Placeholder or "",
                                Type = "Input",
                                Callback = options.Callback or function() end
                            }
                            
                            local holder = CreateInstance("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 40),
                                Parent = self.Container
                            })
                            
                            local label = Library:CreateLabel({
                                Size = UDim2.new(1, 0, 0, 15),
                                Text = name,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = holder
                            })
                            
                            local boxOuter = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.Black,
                                BorderColor3 = Theme.Black,
                                Position = UDim2.new(0, 0, 0, 20),
                                Size = UDim2.new(1, 0, 0, 20),
                                Parent = holder
                            })
                            
                            local boxInner = CreateInstance("Frame", {
                                BackgroundColor3 = Theme.MainColor,
                                BorderColor3 = Theme.OutlineColor,
                                BorderMode = Enum.BorderMode.Inset,
                                Size = UDim2.new(1, 0, 1, 0),
                                Parent = boxOuter
                            })
                            
                            Library:AddToRegistry(boxInner, {
                                BackgroundColor3 = "MainColor",
                                BorderColor3 = "OutlineColor"
                            })
                            
                            local textBox = CreateInstance("TextBox", {
                                BackgroundTransparency = 1,
                                Position = UDim2.new(0, 5, 0, 0),
                                Size = UDim2.new(1, -10, 1, 0),
                                Text = input.Value,
                                PlaceholderText = input.Placeholder,
                                TextColor3 = Theme.FontColor,
                                PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
                                Font = Theme.Font,
                                TextSize = 14,
                                ClearTextOnFocus = false,
                                Parent = boxInner
                            })
                            
                            Library:AddToRegistry(textBox, {
                                TextColor3 = "FontColor"
                            })
                            
                            function input:SetValue(value)
                                input.Value = value
                                textBox.Text = value
                                Library:SafeCallback(input.Callback, value)
                                if input.Changed then
                                    input.Changed(value)
                                end
                            end
                            
                            function input:OnChanged(callback)
                                input.Changed = callback
                                callback(input.Value)
                            end
                            
                            textBox.FocusLost:Connect(function()
                                input:SetValue(textBox.Text)
                            end)
                            
                            Options[name] = input
                            
                            return self:AddElement(holder)
                        end,
                        
                        Label = function(text)
                            local label = Library:CreateLabel({
                                Size = UDim2.new(1, 0, 0, 20),
                                Text = text,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = self.Container
                            })
                            
                            return self:AddElement(label)
                        end
                    }
                    
                    if elementTypes[key] then
                        return function(name, options)
                            return elementTypes[key](name, options)
                        end
                    end
                end
            })
            
            return groupbox
        end
        
        tabButton.MouseButton1Click:Connect(function()
            tab:Show()
        end)
        
        tab.Content = content
        tab.Button = tabButton
        window.Tabs[name] = tab
        
        if #window.Tabs == 1 then
            tab:Show()
        end
        
        return tab
    end
    
    if config.AutoShow then
        window:Show()
    end
    
    window.Container = outer
    Library.Elements[config.Title or "Window"] = window
    
    return window
end

function Library:Notify(text, duration)
    duration = duration or 5
    
    local notification = {
        Time = tick(),
        Duration = duration,
        Frame = nil
    }
    
    local outer = CreateInstance("Frame", {
        BackgroundColor3 = Theme.Black,
        BorderColor3 = Theme.Black,
        Position = UDim2.new(1, -310, 0, 40 + (#self.Notifications * 35)),
        Size = UDim2.new(0, 300, 0, 30),
        Parent = ScreenGui
    })
    
    local inner = CreateInstance("Frame", {
        BackgroundColor3 = Theme.MainColor,
        BorderColor3 = Theme.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = outer
    })
    
    self:AddToRegistry(inner, {
        BackgroundColor3 = "MainColor",
        BorderColor3 = "OutlineColor"
    })
    
    local accent = CreateInstance("Frame", {
        BackgroundColor3 = Theme.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
        Parent = inner
    })
    
    self:AddToRegistry(accent, {
        BackgroundColor3 = "AccentColor"
    })
    
    local label = self:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inner
    })
    
    notification.Frame = outer
    table.insert(self.Notifications, notification)
    
    task.spawn(function()
        task.wait(duration)
        
        for i, notif in pairs(self.Notifications) do
            if notif == notification then
                table.remove(self.Notifications, i)
                break
            end
        end
        
        for i, notif in pairs(self.Notifications) do
            TweenService:Create(notif.Frame, TweenInfo.new(0.2), {
                Position = UDim2.new(1, -310, 0, 40 + ((i - 1) * 35))
            }):Play()
        end
        
        TweenService:Create(outer, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 300, 0, 0)
        }):Play()
        
        task.wait(0.2)
        outer:Destroy()
    end)
end

function Library:SafeCallback(func, ...)
    if not func then return end
    local success, result = pcall(func, ...)
    if not success and self.NotifyOnError then
        self:Notify("Callback error: " .. tostring(result), 3)
    end
end

function Library:OnHighlight(instance, target, hoverProps, normalProps)
    instance.MouseEnter:Connect(function()
        for prop, value in pairs(hoverProps) do
            target[prop] = Theme[value] or value
        end
        self:UpdateColors()
    end)
    
    instance.MouseLeave:Connect(function()
        for prop, value in pairs(normalProps) do
            target[prop] = Theme[value] or value
        end
        self:UpdateColors()
    end)
end

function Library:SetWatermark(text)
    if not self.Watermark then
        local outer = CreateInstance("Frame", {
            BackgroundColor3 = Theme.Black,
            BorderColor3 = Theme.Black,
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0, 200, 0, 25),
            Parent = ScreenGui
        })
        
        local inner = CreateInstance("Frame", {
            BackgroundColor3 = Theme.MainColor,
            BorderColor3 = Theme.AccentColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = outer
        })
        
        self:AddToRegistry(inner, {
            BackgroundColor3 = "MainColor",
            BorderColor3 = "AccentColor"
        })
        
        local label = self:CreateLabel({
            Size = UDim2.new(1, -8, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            Text = text,
            Parent = inner
        })
        
        self:MakeDraggable(outer, 25)
        self.Watermark = outer
        self.WatermarkText = label
    else
        self.WatermarkText.Text = text
    end
end

Library:AddSignal(ScreenGui.DescendantRemoving:Connect(function(instance)
    if Library.RegistryMap[instance] then
        Library:RemoveFromRegistry(instance)
    end
end))

Library:SetWatermark("UI Library v" .. LIBRARY_VERSION)

getgenv().Library = Library
return Library
