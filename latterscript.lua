    -- =========================================================
    -- Word Suggest + Auto-Type + Arrow GUI (Roblox) — by Ikmal PRO
    -- =========================================================

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager") -- VirtualInputManager (exploit env)
    local LP = Players.LocalPlayer

    -- Config
    local WORDS_URL = "https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words_alpha.txt"
    local WORDS2_URL = "https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words.txt"
    local minLen, maxLen = 3, 12
    local PRIORITY_SUFFIX = { "ism", "logy", "nk", "" }

    -- (safeRequest, CleanWord, load words, PrefixIndex, SuggestWords)
    local function safeRequest(url)
        local ok, res = pcall(function()
            return request({Url = url, Method = "GET"})
        end)
        if ok and res and res.Body and #res.Body > 0 then
            return res.Body
        end
        return nil
    end

    local function CleanWord(w)
        return (w:lower():gsub("[^a-z]", ""))
    end

    local Words, FreqMap = {}, {}
    local specialLabel -- legacy ref (not used for buttons)
    local specialSuffixBox, specialMatchesFrame
    local specialSuffix = "nk"
    -- track which words have been used per-suffix and next index for cycling
    local usedSuffixWords = {} -- map: suffix -> { [word]=true }
    local nextSuffixIndex = {} -- map: suffix -> next search start index (number)

    local function GetMatchesForSuffix(suf)
        suf = (suf or ""):lower()
        if suf == "" then return {} end
        local matches = {}
        local seen = {}

        -- prefer recent suggestions
        if lastSuggestWords then
            for _, w in ipairs(lastSuggestWords) do
                if #w >= #suf and w:sub(-#suf):lower() == suf and not seen[w] then
                    table.insert(matches, w)
                    seen[w] = true
                end
            end
        end

        -- fallback to full Words list
        if Words then
            for _, entry in ipairs(Words) do
                local w = entry.word
                if #w >= #suf and w:sub(-#suf):lower() == suf and not seen[w] then
                    table.insert(matches, w)
                    seen[w] = true
                end
            end
        end

        return matches
    end

    local function LoadWordList(url)
        local body = safeRequest(url)
        if not body then 
            warn("Gagal ambil word list:", url)
            return
        end
        for line in body:gmatch("[^\r\n]+") do
            local clean = CleanWord(line)
            if clean ~= "" then
                FreqMap[clean] = (FreqMap[clean] or 0) + 1
            end
        end
    end

    -- Load kedua list
    LoadWordList(WORDS_URL)
    LoadWordList(WORDS2_URL)

    -- Convert to array
    for w, f in pairs(FreqMap) do
        table.insert(Words, {word = w, freq = f})
    end
    -- batas

    local PrefixIndex = {}
    for _, entry in ipairs(Words) do
        local w = entry.word
        for i = 1, math.min(5,#w) do
            local p = w:sub(1,i)
            PrefixIndex[p] = PrefixIndex[p] or {}
            table.insert(PrefixIndex[p], entry)
        end
    end
    for _, list in pairs(PrefixIndex) do
        table.sort(list, function(a,b)
            if a.freq==b.freq then return a.word<b.word end
            return a.freq>b.freq
        end)
    end

    local function SuggestWords(prefix, maxResult)
        prefix = prefix:lower():gsub("%s+", "")
        if prefix=="" then return {} end
        local pkey = prefix:sub(1, math.min(5,#prefix))
        local list = PrefixIndex[pkey] or Words
        local candidates = {}
        for _, entry in ipairs(list) do
            local wlen = #entry.word
            if entry.word:sub(1,#prefix)==prefix and wlen>=minLen and wlen<=maxLen then
                table.insert(candidates, entry)
                if #candidates>=maxResult*3 then break end
            end
        end
        table.sort(candidates,function(a,b)
            if a.freq==b.freq then return a.word<b.word end
            return a.freq>b.freq
        end)
        local results = {}
        for i=1, math.min(maxResult,#candidates) do
            table.insert(results, candidates[i].word)
        end
        return results
    end

    -- Update special matches (words ending with 'nk') and show in TypingBotGUI if available
    local function UpdateSpecialMatches(words)
        local suffix = specialSuffix
        if specialSuffixBox and specialSuffixBox.Text and #specialSuffixBox.Text > 0 then
            suffix = specialSuffixBox.Text:lower()
        end

        words = words or lastSuggestWords or {}
        if not specialMatchesFrame then return end

        -- clear previous buttons/labels
        for _,c in ipairs(specialMatchesFrame:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end

        if suffix == "" then
            local lbl = Instance.new("TextLabel")
            lbl.Parent = specialMatchesFrame
            lbl.Size = UDim2.new(1, 0, 0, 24)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 14
            lbl.TextColor3 = Color3.fromRGB(220,220,220)
            lbl.Text = "Special (empty suffix): -"
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            return
        end

        local matches = {}
        for _, w in ipairs(words) do
            if #w >= #suffix and w:sub(-#suffix):lower() == suffix then
                table.insert(matches, w)
            end
        end

        if #matches == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Parent = specialMatchesFrame
            lbl.Size = UDim2.new(1, 0, 0, 24)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 14
            lbl.TextColor3 = Color3.fromRGB(220,220,220)
            lbl.Text = "No matches for '"..suffix.."'"
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            specialMatchesFrame.CanvasSize = UDim2.new(0,0,0,24)
        else
            for i, m in ipairs(matches) do
                -- initialize used map for suffix
                usedSuffixWords[suffix] = usedSuffixWords[suffix] or {}
                if usedSuffixWords[suffix][m] then
                    -- show as non-clickable label when already used
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 0, 24)
                    lbl.Position = UDim2.new(0, 0, 0, (i-1) * 26)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextSize = 14
                    lbl.TextColor3 = Color3.fromRGB(150,150,150)
                    lbl.Text = m .. " (used)"
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = specialMatchesFrame
                else
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, 0, 0, 24)
                    btn.Position = UDim2.new(0, 0, 0, (i-1) * 26)
                    btn.BackgroundTransparency = 1
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 14
                    btn.TextColor3 = Color3.fromRGB(200,200,255)
                    btn.Text = m
                    btn.Parent = specialMatchesFrame

                    btn.MouseButton1Click:Connect(function()
                        -- Determine how many letters are already shown in the game's CurrentWord
                        local shown = 0
                        pcall(function()
                            shown = #ReadAllLetters()
                        end)
                        -- Trim the word to only the remaining letters to type
                        local toType = m:sub(shown + 1)
                        Input.Text = toType
                        if resultValue then resultValue.Text = toType end
                        if statusLabel then statusLabel.Text = "Selected special: "..(toType ~= "" and toType or m) end
                        if toType ~= "" then
                            pcall(function()
                                task.spawn(function()
                                    TypeLikePlayer(toType)
                                    -- mark as used after typing and refresh matches
                                    usedSuffixWords[suffix] = usedSuffixWords[suffix] or {}
                                    usedSuffixWords[suffix][m] = true
                                    pcall(function() UpdateSpecialMatches(words) end)
                                end)
                            end)
                        else
                            -- if nothing typed still mark as used (already complete)
                            usedSuffixWords[suffix] = usedSuffixWords[suffix] or {}
                            usedSuffixWords[suffix][m] = true
                            pcall(function() UpdateSpecialMatches(words) end)
                        end
                    end)
                end
            end
            specialMatchesFrame.CanvasSize = UDim2.new(0,0,0, #matches * 26)
        end
    end

    -- =========================================================
    -- MODERN PREMIUM GUI (white & soft grey minimalist)
    -- =========================================================

    -- Color palette (white & soft grey theme)
    local ColorPalette = {
        pure_white = Color3.fromRGB(255, 255, 255),
        white = Color3.fromRGB(252, 252, 254),
        ultra_light_grey = Color3.fromRGB(248, 248, 250),
        light_grey = Color3.fromRGB(242, 242, 246),
        soft_grey = Color3.fromRGB(235, 235, 240),
        medium_grey = Color3.fromRGB(220, 220, 225),
        cool_grey = Color3.fromRGB(180, 185, 195),
        dark_grey = Color3.fromRGB(60, 65, 75),
        accent_blue = Color3.fromRGB(100, 180, 255),
        shadow_dark = Color3.fromRGB(0, 0, 0),
    }

    -- Create main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "ModernWordSuggest"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = game.CoreGui

    -- Main container frame (landscape layout)
    local frame = Instance.new("Frame")
    frame.Name = "MainPanel"
    frame.Size = UDim2.new(0, 950, 0, 580)
    frame.Position = UDim2.new(0.5, -475, 0.5, -290) -- Centered
    frame.BackgroundColor3 = ColorPalette.white
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    -- Corner radius (very smooth 24px)
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 24)
    mainCorner.Parent = frame

    -- Soft shadow effect
    local shadowEffect = Instance.new("UIStroke")
    shadowEffect.Color = ColorPalette.shadow_dark
    shadowEffect.Thickness = 0
    shadowEffect.Transparency = 0.85
    shadowEffect.Parent = frame

    -- Subtle border (thin, low opacity)
    local borderStroke = Instance.new("UIStroke")
    borderStroke.Color = ColorPalette.medium_grey
    borderStroke.Thickness = 1.5
    borderStroke.Transparency = 0.75
    borderStroke.Parent = frame

    -- =========================================================
    -- Title Bar (soft gradient background)
    -- =========================================================
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.BackgroundColor3 = ColorPalette.light_grey
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 70)
    titleBar.Parent = frame

    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 24)
    titleBarCorner.Parent = titleBar

    -- Main title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 30, 0, 10)
    title.Size = UDim2.new(0.6, -40, 0, 35)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24
    title.TextColor3 = ColorPalette.dark_grey
    title.Text = "✨ ikmal suggest word"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 30, 0, 42)
    subtitle.Size = UDim2.new(0.6, -40, 0, 20)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextColor3 = ColorPalette.cool_grey
    subtitle.Text = "Premium minimalist interface • Clean white & soft grey palette"
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar

    -- Close button (soft rounded)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.BackgroundColor3 = ColorPalette.soft_grey
    closeBtn.BorderSizePixel = 0
    closeBtn.Position = UDim2.new(1, -60, 0.5, -15)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = ColorPalette.dark_grey
    closeBtn.Text = "✕"
    closeBtn.Parent = titleBar

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 15)
    closeBtnCorner.Parent = closeBtn

    -- Close button hover effect
    closeBtn.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            closeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.medium_grey}
        ):Play()
    end)

    closeBtn.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            closeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.soft_grey}
        ):Play()
    end)

    -- Divider line
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.BackgroundColor3 = ColorPalette.medium_grey
    divider.BorderSizePixel = 0
    divider.Position = UDim2.new(0, 20, 1, -1)
    divider.Size = UDim2.new(1, -40, 0, 1)
    divider.Parent = titleBar

    -- =========================================================
    -- Resize Grip
    -- =========================================================
    local resizeGrip = Instance.new("TextButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.BackgroundTransparency = 1
    resizeGrip.Position = UDim2.new(1, -25, 1, -25)
    resizeGrip.Size = UDim2.new(0, 25, 0, 25)
    resizeGrip.Font = Enum.Font.GothamBold
    resizeGrip.TextSize = 18
    resizeGrip.TextColor3 = ColorPalette.cool_grey
    resizeGrip.Text = "⋰"
    resizeGrip.Parent = frame

    -- Resize functionality
    local isResizing = false
    local startSize, startMouse

    resizeGrip.MouseButton1Down:Connect(function()
        isResizing = true
        startSize = frame.Size
        startMouse = game:GetService("UserInputService"):GetMouseLocation()
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isResizing = false
        end
    end)

    game:GetService("RunService").RenderStepped:Connect(function()
        if isResizing and startSize and startMouse then
            local currentMouse = game:GetService("UserInputService"):GetMouseLocation()
            local deltaX = currentMouse.X - startMouse.X
            local deltaY = currentMouse.Y - startMouse.Y
            
            -- Calculate new size (minimum 600x400)
            local newWidth = math.max(600, startSize.X.Offset + deltaX)
            local newHeight = math.max(400, startSize.Y.Offset + deltaY)
            
            frame.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)

    -- =========================================================
    -- Content Area (two-column landscape layout)
    -- =========================================================
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.BackgroundTransparency = 1
    contentArea.Position = UDim2.new(0, 0, 0, 70)
    contentArea.Size = UDim2.new(1, 0, 1, -70)
    contentArea.Parent = frame

    -- Left Panel (Input & Suggestions)
    local leftPanel = Instance.new("Frame")
    leftPanel.Name = "LeftPanel"
    leftPanel.BackgroundTransparency = 1
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.Size = UDim2.new(0.55, -15, 1, 0)
    leftPanel.Parent = contentArea

    -- Left panel padding
    local leftPadding = Instance.new("UIPadding")
    leftPadding.PaddingLeft = UDim.new(0, 25)
    leftPadding.PaddingRight = UDim.new(0, 10)
    leftPadding.PaddingTop = UDim.new(0, 20)
    leftPadding.PaddingBottom = UDim.new(0, 20)
    leftPadding.Parent = leftPanel

    -- Input label
    local inputLabel = Instance.new("TextLabel")
    inputLabel.Name = "InputLabel"
    inputLabel.BackgroundTransparency = 1
    inputLabel.Size = UDim2.new(1, 0, 0, 20)
    inputLabel.Font = Enum.Font.GothamBold
    inputLabel.TextSize = 13
    inputLabel.TextColor3 = ColorPalette.dark_grey
    inputLabel.Text = "📝 Enter Text"
    inputLabel.TextXAlignment = Enum.TextXAlignment.Left
    inputLabel.Parent = leftPanel

    -- Input field (smooth rounded)
    local box = Instance.new("TextBox")
    box.Name = "InputBox"
    box.BackgroundColor3 = ColorPalette.light_grey
    box.BorderSizePixel = 0
    box.Position = UDim2.new(0, 0, 0, 28)
    box.Size = UDim2.new(1, 0, 0, 45)
    box.PlaceholderText = "Type to search suggestions..."
    box.PlaceholderColor3 = ColorPalette.cool_grey
    box.TextColor3 = ColorPalette.dark_grey
    box.Font = Enum.Font.Gotham
    box.TextSize = 15
    box.ClearTextOnFocus = false
    box.Parent = leftPanel

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 12)
    boxCorner.Parent = box

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = ColorPalette.medium_grey
    boxStroke.Thickness = 1
    boxStroke.Transparency = 0.75
    boxStroke.Parent = box

    local boxPadding = Instance.new("UIPadding")
    boxPadding.PaddingLeft = UDim.new(0, 16)
    boxPadding.PaddingRight = UDim.new(0, 16)
    boxPadding.Parent = box

    -- Focus effects for input
    box.Focused:Connect(function()
        game:GetService("TweenService"):Create(
            box,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.ultra_light_grey}
        ):Play()
        
        game:GetService("TweenService"):Create(
            boxStroke,
            TweenInfo.new(0.2),
            {Transparency = 0.4}
        ):Play()
    end)

    box.FocusLost:Connect(function()
        game:GetService("TweenService"):Create(
            box,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.light_grey}
        ):Play()
        
        game:GetService("TweenService"):Create(
            boxStroke,
            TweenInfo.new(0.2),
            {Transparency = 0.75}
        ):Play()
    end)

    -- Suggestions label
    local suggestLabel = Instance.new("TextLabel")
    suggestLabel.Name = "SuggestLabel"
    suggestLabel.BackgroundTransparency = 1
    suggestLabel.Position = UDim2.new(0, 0, 0, 85)
    suggestLabel.Size = UDim2.new(1, 0, 0, 20)
    suggestLabel.Font = Enum.Font.GothamBold
    suggestLabel.TextSize = 13
    suggestLabel.TextColor3 = ColorPalette.dark_grey
    suggestLabel.Text = "ikmal suggest word"
    suggestLabel.TextXAlignment = Enum.TextXAlignment.Left
    suggestLabel.Parent = leftPanel

    -- Suggestions list (scrolling frame)
    local list = Instance.new("ScrollingFrame")
    list.Name = "SuggestionsList"
    list.BackgroundColor3 = ColorPalette.light_grey
    list.BorderSizePixel = 0
    list.Position = UDim2.new(0, 0, 0, 112)
    list.Size = UDim2.new(1, 0, 1, -147)
    list.ScrollBarThickness = 6
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(1, 0, 0, 0)
    list.Parent = leftPanel

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 12)
    listCorner.Parent = list

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = ColorPalette.medium_grey
    listStroke.Thickness = 1
    listStroke.Transparency = 0.75
    listStroke.Parent = list

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    -- Right Panel (Results & Controls)
    local rightPanel = Instance.new("Frame")
    rightPanel.Name = "RightPanel"
    rightPanel.BackgroundColor3 = ColorPalette.ultra_light_grey
    rightPanel.BorderSizePixel = 0
    rightPanel.Position = UDim2.new(0.55, 0, 0, 0)
    rightPanel.Size = UDim2.new(0.45, 0, 1, 0)
    rightPanel.Parent = contentArea

    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 16)
    rightCorner.Parent = rightPanel

    -- Right panel padding
    local rightPadding = Instance.new("UIPadding")
    rightPadding.PaddingLeft = UDim.new(0, 20)
    rightPadding.PaddingRight = UDim.new(0, 25)
    rightPadding.PaddingTop = UDim.new(0, 20)
    rightPadding.PaddingBottom = UDim.new(0, 20)
    rightPadding.Parent = rightPanel

    -- Result card title
    local resultCardTitle = Instance.new("TextLabel")
    resultCardTitle.Name = "ResultCardTitle"
    resultCardTitle.BackgroundTransparency = 1
    resultCardTitle.Size = UDim2.new(1, 0, 0, 25)
    resultCardTitle.Font = Enum.Font.GothamBold
    resultCardTitle.TextSize = 13
    resultCardTitle.TextColor3 = ColorPalette.dark_grey
    resultCardTitle.Text = "🎯 Random Result"
    resultCardTitle.TextXAlignment = Enum.TextXAlignment.Left
    resultCardTitle.Parent = rightPanel

    -- Result card
    local resultCard = Instance.new("Frame")
    resultCard.Name = "ResultCard"
    resultCard.BackgroundColor3 = ColorPalette.white
    resultCard.BorderSizePixel = 0
    resultCard.Position = UDim2.new(0, 0, 0, 32)
    resultCard.Size = UDim2.new(1, 0, 0, 80)
    resultCard.Parent = rightPanel

    local resultCardCorner = Instance.new("UICorner")
    resultCardCorner.CornerRadius = UDim.new(0, 14)
    resultCardCorner.Parent = resultCard

    local resultCardStroke = Instance.new("UIStroke")
    resultCardStroke.Color = ColorPalette.medium_grey
    resultCardStroke.Thickness = 1
    resultCardStroke.Transparency = 0.75
    resultCardStroke.Parent = resultCard

    -- Result text
    local resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "ResultLabel"
    resultLabel.BackgroundTransparency = 1
    resultLabel.Position = UDim2.new(0, 15, 0, 10)
    resultLabel.Size = UDim2.new(1, -30, 0, 25)
    resultLabel.Font = Enum.Font.Gotham
    resultLabel.TextSize = 12
    resultLabel.TextColor3 = ColorPalette.cool_grey
    resultLabel.Text = "Current result:"
    resultLabel.TextXAlignment = Enum.TextXAlignment.Left
    resultLabel.Parent = resultCard

    -- Result value
    local resultValue = Instance.new("TextLabel")
    resultValue.Name = "ResultValue"
    resultValue.BackgroundTransparency = 1
    resultValue.Position = UDim2.new(0, 15, 0, 35)
    resultValue.Size = UDim2.new(1, -30, 0, 30)
    resultValue.Font = Enum.Font.GothamBold
    resultValue.TextSize = 18
    resultValue.TextColor3 = ColorPalette.accent_blue
    resultValue.Text = "None"
    resultValue.TextXAlignment = Enum.TextXAlignment.Left
    resultValue.TextWrapped = true
    resultValue.Parent = resultCard

    -- Auto-type button
    local autoTypeBtn = Instance.new("TextButton")
    autoTypeBtn.Name = "AutoTypeButton"
    autoTypeBtn.BackgroundColor3 = ColorPalette.accent_blue
    autoTypeBtn.BorderSizePixel = 0
    autoTypeBtn.Position = UDim2.new(0, 0, 0, 125)
    autoTypeBtn.Size = UDim2.new(1, 0, 0, 45)
    autoTypeBtn.Font = Enum.Font.GothamBold
    autoTypeBtn.TextSize = 14
    autoTypeBtn.TextColor3 = ColorPalette.white
    autoTypeBtn.Text = "⚡ Auto Type (Random)"
    autoTypeBtn.Parent = rightPanel

    local autoTypeBtnCorner = Instance.new("UICorner")
    autoTypeBtnCorner.CornerRadius = UDim.new(0, 12)
    autoTypeBtnCorner.Parent = autoTypeBtn

    -- Button hover effect
    autoTypeBtn.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            autoTypeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = Color3.new(
                math.min(1, ColorPalette.accent_blue.R + 0.1),
                math.min(1, ColorPalette.accent_blue.G + 0.1),
                math.min(1, ColorPalette.accent_blue.B + 0.1)
            )}
        ):Play()
    end)

    autoTypeBtn.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            autoTypeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.accent_blue}
        ):Play()
    end)

    -- Manual type button
    local manualTypeBtn = Instance.new("TextButton")
    manualTypeBtn.Name = "ManualTypeButton"
    manualTypeBtn.BackgroundColor3 = ColorPalette.soft_grey
    manualTypeBtn.BorderSizePixel = 0
    manualTypeBtn.Position = UDim2.new(0, 0, 0, 180)
    manualTypeBtn.Size = UDim2.new(1, 0, 0, 45)
    manualTypeBtn.Font = Enum.Font.GothamBold
    manualTypeBtn.TextSize = 14
    manualTypeBtn.TextColor3 = ColorPalette.dark_grey
    manualTypeBtn.Text = "⌨️ Type Input Text"
    manualTypeBtn.Parent = rightPanel

    local manualTypeBtnCorner = Instance.new("UICorner")
    manualTypeBtnCorner.CornerRadius = UDim.new(0, 12)
    manualTypeBtnCorner.Parent = manualTypeBtn

    -- Manual button hover effect
    manualTypeBtn.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            manualTypeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.medium_grey}
        ):Play()
    end)

    manualTypeBtn.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            manualTypeBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = ColorPalette.soft_grey}
        ):Play()
    end)

    -- Status indicator
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.new(0, 0, 1, -50)
    statusLabel.Size = UDim2.new(1, 0, 0, 30)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextColor3 = ColorPalette.cool_grey
    statusLabel.Text = "✓ Ready • Modern UI Loaded"
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = rightPanel

    -- =========================================================
    -- Suffix List (moved into TypingBotGUI SpecialContainer)
    -- =========================================================
    local Suffixes = { "nk", "ism", "logy", "ing", "ed", "ion", "able", "er", "est" }

    local suffixPanel = Instance.new("Frame")
    suffixPanel.Name = "SuffixPanel"
    suffixPanel.BackgroundTransparency = 1
    -- move suffix quick-list into the TypingBot's right column (SpecialContainer)
    suffixPanel.Parent = nil -- will reparent later if SpecialContainer exists
    suffixPanel.Position = UDim2.new(0, 0, 0, 96)
    suffixPanel.Size = UDim2.new(1, 0, 0, 48)

    local suffixTitle = Instance.new("TextLabel")
    suffixTitle.Parent = suffixPanel
    suffixTitle.Size = UDim2.new(1, 0, 0, 20)
    suffixTitle.Position = UDim2.new(0, 0, 0, 0)
    suffixTitle.BackgroundTransparency = 1
    suffixTitle.Font = Enum.Font.GothamBold
    suffixTitle.TextSize = 12
    suffixTitle.TextColor3 = ColorPalette.dark_grey
    suffixTitle.Text = "Suffix List (AutoType)"
    suffixTitle.TextXAlignment = Enum.TextXAlignment.Left

    local suffixListFrame = Instance.new("ScrollingFrame")
    suffixListFrame.Parent = suffixPanel
    suffixListFrame.Position = UDim2.new(0, 0, 0, 26)
    -- compact list to fit inside TypingBot right column
    suffixListFrame.Size = UDim2.new(1, 0, 0, 18)
    suffixListFrame.BackgroundTransparency = 1
    suffixListFrame.BorderSizePixel = 0
    suffixListFrame.ScrollBarThickness = 6
    suffixListFrame.CanvasSize = UDim2.new(0,0,0,0)

    local suffixLayout = Instance.new("UIListLayout")
    suffixLayout.Parent = suffixListFrame
    suffixLayout.Padding = UDim.new(0, 6)
    suffixLayout.FillDirection = Enum.FillDirection.Vertical

    -- Create buttons for each suffix (compact)
    -- Ensure we don't create duplicate buttons if the same suffix
    -- appears multiple times in the source lists; preserve order.
    local uniqueSuffixes = {}
    local _seenSuffix = {}
    for _, s in ipairs(Suffixes) do
        if not _seenSuffix[s] then
            table.insert(uniqueSuffixes, s)
            _seenSuffix[s] = true
        end
    end

    for i, suf in ipairs(uniqueSuffixes) do
        local btn = Instance.new("TextButton")
        btn.Parent = suffixListFrame
        btn.Size = UDim2.new(1, 0, 0, 18)
        btn.BackgroundColor3 = ColorPalette.ultra_light_grey
        btn.TextColor3 = ColorPalette.dark_grey
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Text = "•" .. suf
        btn.TextXAlignment = Enum.TextXAlignment.Left

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseEnter:Connect(function()
            game:GetService("TweenService"):Create(
                btn,
                TweenInfo.new(0.12),
                {BackgroundColor3 = ColorPalette.soft_grey}
            ):Play()
        end)
        btn.MouseLeave:Connect(function()
            game:GetService("TweenService"):Create(
                btn,
                TweenInfo.new(0.12),
                {BackgroundColor3 = ColorPalette.ultra_light_grey}
            ):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            -- set selected suffix and update special matches
            specialSuffix = suf
            if specialSuffixBox then
                specialSuffixBox.Text = suf
            end
            pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
            if statusLabel then statusLabel.Text = "✓ Selected suffix: " .. suf end
        end)
    end

    -- adjust canvas size based on children
    suffixListFrame.Changed:Connect(function()
        local total = 0
        for _,c in ipairs(suffixListFrame:GetChildren()) do
            if c:IsA("TextButton") then total = total + 20 end
        end
        suffixListFrame.CanvasSize = UDim2.new(0,0,0, total)
    end)

    -- reparent suffixPanel into SpecialContainer if it exists (TypingBot GUI)
    if SpecialContainer then
        suffixPanel.Parent = SpecialContainer
    end

    -- Right-side auto-type first match for selected suffix
    local autoSuffixRightBtn = Instance.new("TextButton")
    autoSuffixRightBtn.Parent = suffixPanel
    autoSuffixRightBtn.Position = UDim2.new(0, 0, 0, 128)
    autoSuffixRightBtn.Size = UDim2.new(1, 0, 0, 24)
    autoSuffixRightBtn.BackgroundColor3 = ColorPalette.accent_blue
    autoSuffixRightBtn.Font = Enum.Font.GothamBold
    autoSuffixRightBtn.TextSize = 12
    autoSuffixRightBtn.TextColor3 = ColorPalette.white
    autoSuffixRightBtn.Text = "Auto-Type First Match (Selected Suffix)"

    autoSuffixRightBtn.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(
            autoSuffixRightBtn,
            TweenInfo.new(0.12),
            {BackgroundColor3 = Color3.new(
                math.min(1, ColorPalette.accent_blue.R + 0.06),
                math.min(1, ColorPalette.accent_blue.G + 0.06),
                math.min(1, ColorPalette.accent_blue.B + 0.06)
            )}
        ):Play()
    end)
    autoSuffixRightBtn.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(
            autoSuffixRightBtn,
            TweenInfo.new(0.12),
            {BackgroundColor3 = ColorPalette.accent_blue}
        ):Play()
    end)

    autoSuffixRightBtn.MouseButton1Click:Connect(function()
        local suf = specialSuffix or (specialSuffixBox and specialSuffixBox.Text) or ""
        if suf == "" then
            if statusLabel then statusLabel.Text = "⚠ No suffix selected" end
            return
        end

        -- try to find an unused matching word in the latest suggestions first
        local matchWord = nil
        usedSuffixWords[suf] = usedSuffixWords[suf] or {}
        if lastSuggestWords then
            for _, w in ipairs(lastSuggestWords) do
                if #w >= #suf and w:sub(-#suf) == suf and not usedSuffixWords[suf][w] then
                    matchWord = w
                    break
                end
            end
        end

        -- fallback: search global Words array for first unused
        if not matchWord and Words then
            for _, entry in ipairs(Words) do
                if #entry.word >= #suf and entry.word:sub(-#suf) == suf and not usedSuffixWords[suf][entry.word] then
                    matchWord = entry.word
                    break
                end
            end
        end

        if not matchWord then
            if statusLabel then statusLabel.Text = "⚠ No matches for suffix: "..suf end
            return
        end

        -- compute remaining to type and TypeLikePlayer
        local shown = 0
        pcall(function() shown = #ReadAllLetters() end)
        local toType = matchWord:sub(shown + 1)
        if not toType or toType == "" then
            if statusLabel then statusLabel.Text = "⚠ Nothing to type (already complete)" end
            return
        end
        if statusLabel then statusLabel.Text = "⌛ Auto-typing: "..toType end
        TypeLikePlayer(toType)
        -- mark used and refresh UI
        usedSuffixWords[suf] = usedSuffixWords[suf] or {}
        usedSuffixWords[suf][matchWord] = true
        pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
        if statusLabel then statusLabel.Text = "✓ Auto-typed: "..toType end
    end)

    -- =========================================================
    -- Update Suggestions (Modern UI)
    -- =========================================================
    local function UpdateSuggestions()
        for _,c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local text = box.Text
        if text=="" then return end
        local suggests = SuggestWords(text,50)
        lastSuggestWords = suggests
        -- refresh special matches display (words ending with 'nk')
        pcall(function() UpdateSpecialMatches(suggests) end)
        table.sort(suggests,function(a,b)
            local aPriority,bPriority=0,0
            for i,suf in ipairs(PRIORITY_SUFFIX) do
                if a:sub(-#suf)==suf then aPriority=i end
                if b:sub(-#suf)==suf then bPriority=i end
            end
            if aPriority~=bPriority then return aPriority<bPriority end
            return a<b
        end)
        for i=1,math.min(50,#suggests) do
            local w=suggests[i]
            local btn = Instance.new("TextButton",list)
            btn.Size=UDim2.new(1,0,0,28)
            btn.BackgroundColor3=ColorPalette.ultra_light_grey
            btn.TextColor3=ColorPalette.dark_grey
            btn.Font=Enum.Font.Gotham
            btn.TextSize=12
            btn.Text=" • "..w
            btn.TextXAlignment=Enum.TextXAlignment.Left
            
            -- Modern styling
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 8)
            btnCorner.Parent = btn
            
            local btnStroke = Instance.new("UIStroke")
            btnStroke.Color = ColorPalette.medium_grey
            btnStroke.Thickness = 1
            btnStroke.Transparency = 0.85
            btnStroke.Parent = btn
            
            -- Hover effect
            btn.MouseEnter:Connect(function()
                game:GetService("TweenService"):Create(
                    btn,
                    TweenInfo.new(0.15),
                    {BackgroundColor3 = ColorPalette.soft_grey}
                ):Play()
            end)
            
            btn.MouseLeave:Connect(function()
                game:GetService("TweenService"):Create(
                    btn,
                    TweenInfo.new(0.15),
                    {BackgroundColor3 = ColorPalette.ultra_light_grey}
                ):Play()
            end)
            
            btn.MouseButton1Click:Connect(function()
                box.Text = w
                UpdateSuggestions()
                resultValue.Text = w
            end)
        end
    end

    -- Update suggestions when text changes
    box.Changed:Connect(function()
        UpdateSuggestions()
    end)

    -- Button event handlers
    autoTypeBtn.MouseButton1Click:Connect(function()
        local currentList = GetLatest50Words()
        if #currentList > 0 then
            local randomWord = currentList[math.random(1, #currentList)]
            box.Text = randomWord
            UpdateSuggestions()
            resultValue.Text = randomWord
            statusLabel.Text = "✓ Auto-typed: " .. randomWord
        end
    end)

    manualTypeBtn.MouseButton1Click:Connect(function()
        if box.Text ~= "" then
            TypeLikePlayer(box.Text)
            statusLabel.Text = "✓ Typed: " .. box.Text
        else
            statusLabel.Text = "⚠ No text to type"
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    -- =========================================================
    -- Auto Read CurrentWord
    -- =========================================================
    local function GetCurrentWordFolder()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local inGame = pg:FindFirstChild("InGame")
        if not inGame then return nil end
        local frameIn = inGame:FindFirstChild("Frame")
        if not frameIn then return nil end
        return frameIn:FindFirstChild("CurrentWord")
    end

    local function ReadAllLetters()
        local cw = GetCurrentWordFolder()
        if not cw then return "" end
        local result = ""
        for i=1,20 do
            local slot = cw:FindFirstChild(tostring(i))
            if not slot then break end
            local letter = slot:FindFirstChild("Letter")
            if letter and letter:IsA("TextLabel") then result = result..letter.Text:lower() end
        end
        return result
    end

    task.spawn(function()
        while task.wait(0.1) do
            local success, word = pcall(ReadAllLetters)
            if success and word~="" and box.Text~=word then
                box.Text = word
                UpdateSuggestions()
            end
        end
    end)

    -- =========================================================
    -- Arrow Controls Min/Max
    -- =========================================================
    local function CreateArrowControl(parent, posX, labelText, isMin, defaultVal)
        local value = defaultVal
        
        -- Container frame for better organization
        local controlContainer = Instance.new("Frame", parent)
        controlContainer.Name = labelText .. "Container"
        controlContainer.BackgroundTransparency = 1
        controlContainer.Size = UDim2.new(0, 110, 0, 50)
        -- Place controls anchored to the bottom of the parent (just under the suggestions list)
        controlContainer.Position = UDim2.new(0, posX, 1, -60)
        
        -- Label
        local label = Instance.new("TextLabel", controlContainer)
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = ColorPalette.dark_grey
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Text = labelText .. value

        -- Left Arrow Button
        local leftArrow = Instance.new("TextButton", controlContainer)
        leftArrow.Name = "LeftArrow"
        leftArrow.Size = UDim2.new(0, 28, 0, 28)
        leftArrow.Position = UDim2.new(0, 0, 0, 22)
        leftArrow.Text = "−"
        leftArrow.Font = Enum.Font.GothamBold
        leftArrow.TextSize = 16
        leftArrow.BackgroundColor3 = ColorPalette.soft_grey
        leftArrow.TextColor3 = ColorPalette.dark_grey
        leftArrow.BorderSizePixel = 0
        
        local leftCorner = Instance.new("UICorner", leftArrow)
        leftCorner.CornerRadius = UDim.new(0, 6)
        
        local leftStroke = Instance.new("UIStroke", leftArrow)
        leftStroke.Color = ColorPalette.medium_grey
        leftStroke.Thickness = 1
        leftStroke.Transparency = 0.5

        -- Right Arrow Button
        local rightArrow = Instance.new("TextButton", controlContainer)
        rightArrow.Name = "RightArrow"
        rightArrow.Size = UDim2.new(0, 28, 0, 28)
        rightArrow.Position = UDim2.new(1, -28, 0, 22)
        rightArrow.Text = "+"
        rightArrow.Font = Enum.Font.GothamBold
        rightArrow.TextSize = 16
        rightArrow.BackgroundColor3 = ColorPalette.soft_grey
        rightArrow.TextColor3 = ColorPalette.dark_grey
        rightArrow.BorderSizePixel = 0
        
        local rightCorner = Instance.new("UICorner", rightArrow)
        rightCorner.CornerRadius = UDim.new(0, 6)
        
        local rightStroke = Instance.new("UIStroke", rightArrow)
        rightStroke.Color = ColorPalette.medium_grey
        rightStroke.Thickness = 1
        rightStroke.Transparency = 0.5

        -- Hover effects for left arrow
        leftArrow.MouseEnter:Connect(function()
            game:GetService("TweenService"):Create(
                leftArrow,
                TweenInfo.new(0.2),
                {BackgroundColor3 = ColorPalette.medium_grey}
            ):Play()
        end)
        
        leftArrow.MouseLeave:Connect(function()
            game:GetService("TweenService"):Create(
                leftArrow,
                TweenInfo.new(0.2),
                {BackgroundColor3 = ColorPalette.soft_grey}
            ):Play()
        end)

        -- Hover effects for right arrow
        rightArrow.MouseEnter:Connect(function()
            game:GetService("TweenService"):Create(
                rightArrow,
                TweenInfo.new(0.2),
                {BackgroundColor3 = ColorPalette.medium_grey}
            ):Play()
        end)
        
        rightArrow.MouseLeave:Connect(function()
            game:GetService("TweenService"):Create(
                rightArrow,
                TweenInfo.new(0.2),
                {BackgroundColor3 = ColorPalette.soft_grey}
            ):Play()
        end)

        local function UpdateValue(change)
            value = math.clamp(value + change, 1, 100)
            label.Text = labelText .. value
            if isMin then minLen = value else maxLen = value end
            UpdateSuggestions()
        end

        leftArrow.MouseButton1Click:Connect(function() UpdateValue(-1) end)
        rightArrow.MouseButton1Click:Connect(function() UpdateValue(1) end)
    end

    -- Place Min and Max side-by-side under the suggestions (left panel)
    CreateArrowControl(leftPanel, 0, "Min: ", true, minLen)
    CreateArrowControl(leftPanel, 120, "Max: ", false, maxLen)

    -- =========================================================
    -- Typing / AutoType (VirtualInputManager safe mapping)
    -- =========================================================

    -- map digits to Enum names
    local digitMap = { ["0"]="Zero", ["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four",
                    ["5"]="Five", ["6"]="Six", ["7"]="Seven", ["8"]="Eight", ["9"]="Nine" }

    -- map some punctuation to Enum names (common ones)
    local punctMap = {
        [","] = "Comma",
        ["."] = "Period",
        [";"] = "Semicolon",
        [":"] = "Colon",
        ["-"] = "Minus",
        ["="] = "Equals",
        ["/"] = "Slash",
        ["\\"] = "BackSlash",
        ["'"] = "Apostrophe",
        ['"'] = "Quote",
        ["["] = "LeftBracket",
        ["]"] = "RightBracket"
    }

    local function PressKey(keyEnum)
        if not keyEnum then return end
        -- press down
        pcall(function()
            VIM:SendKeyEvent(true, keyEnum, false, game)
        end)
        task.wait(0.02)
        -- release
        pcall(function()
            VIM:SendKeyEvent(false, keyEnum, false, game)
        end)
    end

    local function TypeLikePlayer(word, perCharDelay)
        perCharDelay = perCharDelay or 0.05
        for i = 1, #word do
            local ch = word:sub(i,i)
            local keyName = nil

            if ch:match("%a") then
                keyName = ch:upper() -- letters -> "A", "B", ...
            elseif ch == " " then
                keyName = "Space"
            elseif ch:match("%d") then
                keyName = digitMap[ch]
            else
                keyName = punctMap[ch] -- might be nil if unsupported
            end

            if keyName and Enum.KeyCode[keyName] then
                PressKey(Enum.KeyCode[keyName])
            end

            task.wait(perCharDelay)
        end
    end

    -- Separate small typing GUI (optional) - still kept for manual typing
    local TypingGui = Instance.new("ScreenGui")
    TypingGui.Name = "TypingBotGUI"
    TypingGui.Parent = LP:WaitForChild("PlayerGui")
    TypingGui.ResetOnSpawn = false

    local Main = Instance.new("Frame")
    Main.Parent = TypingGui
    -- widen small typing GUI so matches list can sit to the right
    Main.Size = UDim2.new(0, 420, 0, 160)
    Main.Position = UDim2.new(0.5, -210, 0.5, -80)
    Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true

    local Title = Instance.new("TextLabel")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Title.BorderSizePixel = 0
    Title.Font = Enum.Font.GothamBold
    Title.Text = "complate the word"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 17

    local Input = Instance.new("TextBox")
    Input.Parent = Main
    -- left column input, fixed width to leave room on the right
    Input.Size = UDim2.new(0, 260, 0, 40)
    Input.Position = UDim2.new(0, 10, 0, 50)
    Input.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Input.BorderSizePixel = 0
    Input.Text = ""
    Input.PlaceholderText = "Masukkan kata..."
    Input.Font = Enum.Font.Gotham
    Input.TextSize = 16
    Input.TextColor3 = Color3.new(1,1,1)

    local Btn = Instance.new("TextButton")
    Btn.Parent = Main
    Btn.Size = UDim2.new(0, 120, 0, 40)
    Btn.Position = UDim2.new(0, 10, 0, 130)
    Btn.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
    Btn.BorderSizePixel = 0
    Btn.Font = Enum.Font.GothamBold
    Btn.Text = "Type"
    Btn.TextSize = 18
    Btn.TextColor3 = Color3.new(1,1,1)

    -- Special matches container: place it to the RIGHT of typing controls
    local SpecialContainer = Instance.new("Frame")
    SpecialContainer.Parent = Main
    SpecialContainer.Position = UDim2.new(0, 280, 0, 10)
    SpecialContainer.Size = UDim2.new(0, 130, 1, -20)
    SpecialContainer.BackgroundTransparency = 1

    local suffixLabel = Instance.new("TextLabel")
    suffixLabel.Parent = SpecialContainer
    suffixLabel.Size = UDim2.new(0, 48, 0, 24)
    suffixLabel.Position = UDim2.new(0, 0, 0, 0)
    suffixLabel.BackgroundTransparency = 1
    suffixLabel.Font = Enum.Font.GothamBold
    suffixLabel.TextSize = 12
    suffixLabel.TextColor3 = Color3.fromRGB(200,200,200)
    suffixLabel.Text = "Suffix:"
    suffixLabel.TextXAlignment = Enum.TextXAlignment.Left

    local suffixBox = Instance.new("TextBox")
    suffixBox.Parent = SpecialContainer
    suffixBox.Size = UDim2.new(0, 78, 0, 24)
    suffixBox.Position = UDim2.new(0, 52, 0, 0)
    suffixBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    suffixBox.BorderSizePixel = 0
    suffixBox.Text = specialSuffix
    suffixBox.PlaceholderText = "ex: nk"
    suffixBox.Font = Enum.Font.Gotham
    suffixBox.TextSize = 14
    suffixBox.TextColor3 = Color3.new(1,1,1)

    local matchesFrame = Instance.new("ScrollingFrame")
    matchesFrame.Parent = SpecialContainer
    matchesFrame.Size = UDim2.new(1, 0, 0, 60)
    matchesFrame.Position = UDim2.new(0, 0, 0, 30)
    matchesFrame.BackgroundTransparency = 1
    matchesFrame.BorderSizePixel = 0
    matchesFrame.ScrollBarThickness = 6
    matchesFrame.CanvasSize = UDim2.new(0,0,0,0)

    specialSuffixBox = suffixBox
    specialMatchesFrame = matchesFrame

    -- move the (compact) suffixPanel into this SpecialContainer now that it exists
    if suffixPanel then
        suffixPanel.Parent = SpecialContainer
    end

    suffixBox.Changed:Connect(function()
        pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
    end)

    Btn.MouseButton1Click:Connect(function()
        local word = Input.Text
        if word ~= "" then
            TypeLikePlayer(word)
        end
    end)

    -- Auto-type suffix button (placed to the right of Type in the left column)
    local AutoSuffixBtn = Instance.new("TextButton")
    AutoSuffixBtn.Parent = Main
    AutoSuffixBtn.Size = UDim2.new(0, 120, 0, 40)
    AutoSuffixBtn.Position = UDim2.new(0, 140, 0, 130)
    AutoSuffixBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
    AutoSuffixBtn.BorderSizePixel = 0
    AutoSuffixBtn.Font = Enum.Font.GothamBold
    AutoSuffixBtn.Text = "Auto-Type Suffix"
    AutoSuffixBtn.TextSize = 14
    AutoSuffixBtn.TextColor3 = Color3.new(1,1,1)

    AutoSuffixBtn.MouseButton1Click:Connect(function()
        -- Collect visible matches from the special matches frame and auto-type the first unused one
        if not specialMatchesFrame then
            if statusLabel then statusLabel.Text = "⚠ No matches frame available" end
            return
        end

        local suf = specialSuffix or (specialSuffixBox and specialSuffixBox.Text) or ""
        usedSuffixWords[suf] = usedSuffixWords[suf] or {}

        -- Find the first visible special match button that hasn't been used
        local firstMatch = nil
        for _, child in ipairs(specialMatchesFrame:GetChildren()) do
            if child:IsA("TextButton") then
                if not usedSuffixWords[suf][child.Text] then
                    firstMatch = child.Text
                    break
                end
            end
        end

        if not firstMatch or firstMatch == "" then
            if statusLabel then statusLabel.Text = "⚠ No unused matches to auto-type" end
            return
        end

        pcall(function()
            task.spawn(function()
                -- compute shown letters in game and type only remaining suffix
                local shown = 0
                pcall(function() shown = #ReadAllLetters() end)
                local toType = firstMatch:sub(shown + 1)
                if not toType or toType == "" then
                    if statusLabel then statusLabel.Text = "⚠ Nothing to type (all letters already shown)" end
                    -- mark as used since nothing remains
                    usedSuffixWords[suf] = usedSuffixWords[suf] or {}
                    usedSuffixWords[suf][firstMatch] = true
                    pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
                    return
                end
                if resultValue then resultValue.Text = toType end
                if statusLabel then statusLabel.Text = "⌛ Auto-typing: "..toType end
                TypeLikePlayer(toType)
                -- mark used and refresh UI
                usedSuffixWords[suf] = usedSuffixWords[suf] or {}
                usedSuffixWords[suf][firstMatch] = true
                pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
                if statusLabel then statusLabel.Text = "✓ Auto-typed match: "..toType end
            end)
        end)
    end)

    -- Reset used matches button (clears used list for current suffix)
    local ResetSuffixBtn = Instance.new("TextButton")
    ResetSuffixBtn.Parent = Main
    ResetSuffixBtn.Size = UDim2.new(0, 120, 0, 40)
    ResetSuffixBtn.Position = UDim2.new(0, 260, 0, 130)
    ResetSuffixBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    ResetSuffixBtn.BorderSizePixel = 0
    ResetSuffixBtn.Font = Enum.Font.GothamBold
    ResetSuffixBtn.Text = "Reset Used Matches"
    ResetSuffixBtn.TextSize = 12
    ResetSuffixBtn.TextColor3 = Color3.new(1,1,1)

    ResetSuffixBtn.MouseButton1Click:Connect(function()
        local suf = specialSuffix or (specialSuffixBox and specialSuffixBox.Text) or ""
        if suf == "" then
            if statusLabel then statusLabel.Text = "⚠ No suffix selected to reset" end
            return
        end
        usedSuffixWords[suf] = {}
        nextSuffixIndex[suf] = nil
        pcall(function() UpdateSpecialMatches(lastSuggestWords) end)
        if statusLabel then statusLabel.Text = "✓ Reset used matches for: "..suf end
    end)
    -- =========================================================
    -- Auto Input Random Word dari 50 Suggest List
    -- =========================================================

    local AUTO_INPUT_DELAY = 0.3 -- detik
    local autoInputEnabled = true

    -- Fungsi untuk mendapatkan 50 word list terbaru
    local function GetLatest50Words()
        if UpdateSuggestions and lastSuggestWords then
            -- lastSuggestWords diset di UpdateSuggestions()
            local list = {}
            for i = 1, math.min(50, #lastSuggestWords) do
                table.insert(list, lastSuggestWords[i])
            end
            return list
        end
        return {}
    end

    -- Loop auto input
    task.spawn(function()
        while true do
            task.wait(AUTO_INPUT_DELAY)

            if autoInputEnabled then

                -- Ambil 50 word list terbaru
                local currentList = GetLatest50Words()

                if #currentList > 0 then
                    local randomWord = currentList[math.random(1, #currentList)]
                    -- Hitung jumlah huruf di CurrentWord
                    local shownLetters = #ReadAllLetters()

                    -- Potong kata sesuai jumlah huruf yang sudah muncul
                    local trimmed = randomWord:sub(shownLetters + 1)

                    Input.Text = trimmed
                    pcall(function() UpdateSpecialMatches(currentList) end)

                end

            end
        end
    end)


