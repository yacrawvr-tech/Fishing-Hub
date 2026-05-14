--[[
╔══════════════════════════════════════════════════════════╗
║           AUTO STAR FISHING  •  v2.0                     ║
║           UI: Rayfield  •  Game: Star Fishing            ║
╚══════════════════════════════════════════════════════════╝

  Fitur Utama:
  • Auto Cast & Withdraw ke Galaxy pilihan
  • Galaxy Selector (7 area + Auto Terdekat)
  • Teleport ke Galaxy yang dipilih (+5 stud)
  • Auto Item Confirm otomatis
  • Auto Sell Timer dengan countdown live
  • Live Stats: Cast Counter & Uptime
  • Anti AFK (VirtualUser click setiap 60 detik)
  • Force Equip / Unequip Rod otomatis
  • Config Save / Load otomatis (Rayfield)
  • Toggle UI: tekan K

  GitHub : https://github.com/YOUR_USERNAME/AutoStarFishing
--]]

-- ─────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser      = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- ─────────────────────────────────────────────
--  RAYFIELD UI LIBRARY
-- ─────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ─────────────────────────────────────────────
--  WINDOW
-- ─────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name             = "Auto Star Fishing",
    Icon             = "fish",
    LoadingTitle     = "Auto Star Fishing",
    LoadingSubtitle  = "By Yacraw",
    ShowText         = "AutoFish",
    Theme            = "Amethyst",
    ToggleUIKeybind  = "K",

    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = false,

    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "AutoStarFishing",
        FileName   = "Config",
    },

    Discord = {
        Enabled      = true,
        Invite       = "https://discord.gg/avcug4Df5k",
        RememberJoins = false,
    },

      KeySystem = true, -- Set this to true to use our key system
      KeySettings = {
      Title = "Key System",
      Subtitle = "Sorry I Just Need Members😛",
      Note = "Join The Discord To Get The Key", -- Use this to tell the user how to get a key
      FileName = "Le Key System", -- It is recommended to use something unique, as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"giggles"} -- List of keys that the system will accept, can be RAW file links (pastebin, github, etc.) or simple strings ("hello", "key22")
})

-- ─────────────────────────────────────────────
--  TABS
-- ─────────────────────────────────────────────
local TabFishing  = Window:CreateTab("Fishing",  "fish")
local TabStats    = Window:CreateTab("Stats",    "bar-chart-2")
local TabSettings = Window:CreateTab("Settings", "settings")

-- ─────────────────────────────────────────────
--  STATE VARIABLES
-- ─────────────────────────────────────────────
local autoFishing        = false
local castDelay          = 0.5
local selling            = false
local totalCasts         = 0
local sessionStart       = os.time()

local autoSellEnabled    = false
local sellInterval       = 120
local sellCountdown      = 120
local sellMode           = "Timer"    -- mode dipilih: "Timer" / "Kapasitas"

local autoSellCapacity   = false
local sellCapThreshold   = 400

local antiAfkEnabled     = false
local selectedGalaxy     = "Auto (Terdekat)"

-- ─────────────────────────────────────────────
--  BACKPACK CAPACITY READER
--  Baca TextLabel "50/500" → return angka kiri (current stars)
-- ─────────────────────────────────────────────
local function getStarCount()
    local ok, result = pcall(function()
        local label = player.PlayerGui
            :WaitForChild("Main", 1)
            :WaitForChild("Canvas", 1)
            :WaitForChild("HUD", 1)
            :WaitForChild("ClientBackpack", 1)
            :WaitForChild("InsideFrame", 1)
            :WaitForChild("Tabs", 1)
            :WaitForChild("Stars", 1)
            :WaitForChild("Container", 1)
            :WaitForChild("1_TopBar", 1)
            :WaitForChild("B_QuantityFrame", 1)
            :WaitForChild("QuantityTextLabel", 1)
        local text = label.Text  -- contoh: "50/500"
        local current = text:match("^(%d+)/")
        return current and tonumber(current) or 0
    end)
    return ok and result or 0
end
local GALAXIES = {
    "Auto (Terdekat)",
    "Andromeda",
    "Centaurus A",
    "Hoag's Object",
    "Milky Way",
    "Negative Galaxy",
    "Spore Galaxy",
    "The Eye",
}

-- ─────────────────────────────────────────────
--  UTILITIES
-- ─────────────────────────────────────────────
local function fmtTime(sec)
    sec = math.max(sec, 0)
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function notify(title, content, icon, duration)
    Rayfield:Notify({
        Title    = title,
        Content  = content,
        Duration = duration or 3,
        Image    = icon or "info",
    })
end

-- ─────────────────────────────────────────────
--  ROD SYSTEM
-- ─────────────────────────────────────────────
local function findRod()
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == "Rod" then return tool end
    end
    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Rod" then return tool end
        end
    end
    return nil
end

local function equipRod()
    local rod = findRod()
    if rod and player.Character then
        rod.Parent = player.Character
    end
end

local function unequipRod()
    local rod = findRod()
    if rod then
        rod.Parent = player.Backpack
    end
end

-- Auto re-equip jika rod lepas saat fishing aktif
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoFishing then
            local char = player.Character
            if char then
                local equipped = char:FindFirstChildOfClass("Tool")
                if not equipped or equipped.Name ~= "Rod" then
                    equipRod()
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────
--  GALAXY SYSTEM
-- ─────────────────────────────────────────────
local function getNearestGalaxy()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    local galaxiesFolder = workspace:FindFirstChild("Galaxies")
    if not galaxiesFolder then return nil end

    local nearest, minDist = nil, math.huge
    local hrpPos = char.HumanoidRootPart.Position

    for _, v in ipairs(galaxiesFolder:GetChildren()) do
        local ok, dist = pcall(function()
            return (v:GetPivot().Position - hrpPos).Magnitude
        end)
        if ok and dist < minDist then
            minDist = dist
            nearest = v
        end
    end
    return nearest
end

local function getTargetGalaxy()
    local galaxiesFolder = workspace:FindFirstChild("Galaxies")
    if not galaxiesFolder then return nil end

    if selectedGalaxy ~= "Auto (Terdekat)" then
        local found = galaxiesFolder:FindFirstChild(selectedGalaxy)
        if found then return found end
    end

    return getNearestGalaxy()
end

-- ─────────────────────────────────────────────
--  ITEM AUTO-CONFIRM
-- ─────────────────────────────────────────────
ReplicatedStorage.Events.Global.ClientRecieveItems.OnClientEvent:Connect(
    function(_, _, _, catchData, _, waitData)
        if not catchData then return end
        for idx, fishData in pairs(catchData) do
            local fishId = fishData["id"]
            if fishId then
                task.wait(waitData and waitData[idx] or 3)
                ReplicatedStorage.Events.Global.ClientItemConfirm:FireServer(fishId)
            end
        end
    end
)

-- ─────────────────────────────────────────────
--  AUTO FISH LOOP
-- ─────────────────────────────────────────────
local function startFishing()
    while autoFishing do
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local rod = char:FindFirstChildOfClass("Tool")
            if rod and rod.Name == "Rod" and rod:FindFirstChild("Model") then
                local galaxy = getTargetGalaxy()
                if galaxy then
                    local hrp     = char.HumanoidRootPart
                    local castPos = galaxy:GetPivot().Position + Vector3.new(0, 5, 0)
                    local castDir = (castPos - hrp.Position).Unit
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    local tip      = rod.Model.Nodes.RodTip.Attachment

                    pcall(function()
                        ReplicatedStorage.Events.Global.Cast:FireServer(
                            humanoid, castPos, castDir, tip
                        )
                    end)

                    task.wait(0.1)

                    pcall(function()
                        ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(humanoid)
                    end)

                    totalCasts += 1
                end
            end
        end
        task.wait(castDelay)
    end
end

-- ─────────────────────────────────────────────
--  AUTO SELL
-- ─────────────────────────────────────────────
local function doSell()
    if selling then return end
    selling = true

    local ok, err = pcall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local hrp      = char.HumanoidRootPart
        local savedPos = hrp.CFrame

        hrp.CFrame = CFrame.new(14, 37, -263)
        task.wait(0.5)

        ReplicatedStorage.Dialogue.Events.Global.ClientChoosesDialogueOption:FireServer({
            id   = "sell-all",
            text = "Sell all of my stars.",
            npc  = "Star Merchant",
        })

        task.wait(2)
        hrp.CFrame = savedPos
    end)

    if not ok then
        warn("[AutoStarFishing] doSell error:", err)
    end

    selling = false
end

-- ═══════════════════════════════════════════════════════
--  UI  ·  TAB: FISHING
-- ═══════════════════════════════════════════════════════

TabFishing:CreateSection("⚙️  Auto Fishing")

local lblFishStatus   = TabFishing:CreateLabel("Status  :  ⛔ Nonaktif", "activity")
local lblGalaxyActive = TabFishing:CreateLabel("🌌 Galaxy  :  Auto (Terdekat)", "map-pin")

TabFishing:CreateToggle({
    Name         = "Auto Fishing",
    CurrentValue = false,
    Flag         = "AutoFishingToggle",
    Callback     = function(val)
        autoFishing = val
        if val then
            equipRod()
            task.spawn(startFishing)
            notify("Auto Fishing", "Aktif! Galaxy: " .. selectedGalaxy, "fish")
        else
            unequipRod()
            notify("Auto Fishing", "Dinonaktifkan.", "x-circle")
        end
    end,
})

TabFishing:CreateInput({
    Name            = "Cast Delay (detik)",
    PlaceholderText = "0.5",
    NumbersOnly     = true,
    Flag            = "CastDelayInput",
    Callback        = function(val)
        local n = tonumber(val)
        if n and n > 0 then
            castDelay = n
            notify("Cast Delay", "Diset ke " .. n .. " detik.", "timer", 2)
        end
    end,
})

TabFishing:CreateDivider()

-- ── Galaxy Selector ──────────────────────────
TabFishing:CreateSection("🌌  Galaxy Selector")

TabFishing:CreateDropdown({
    Name            = "Pilih Area Galaxy",
    Options         = GALAXIES,
    CurrentOption   = {"Auto (Terdekat)"},
    MultipleOptions = false,
    Flag            = "GalaxyDropdown",
    Callback        = function(opts)
        selectedGalaxy = opts[1]
        pcall(function() lblGalaxyActive:Set("🌌 Galaxy  :  " .. selectedGalaxy, "map-pin") end)
        notify("Galaxy Dipilih", "Area: " .. selectedGalaxy, "map-pin")
    end,
})

TabFishing:CreateButton({
    Name     = "🚀  Teleport ke Galaxy",
    Callback = function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            notify("Teleport Gagal", "Karakter tidak ditemukan!", "x-circle")
            return
        end
        local target
        if selectedGalaxy == "Auto (Terdekat)" then
            target = getNearestGalaxy()
        else
            local folder = workspace:FindFirstChild("Galaxies")
            if folder then target = folder:FindFirstChild(selectedGalaxy) end
        end
        if not target then
            notify("Teleport Gagal", "Galaxy '" .. selectedGalaxy .. "' tidak ditemukan!", "x-circle")
            return
        end
        local pos = target:GetPivot().Position
        char.HumanoidRootPart.CFrame = CFrame.new(pos.X, pos.Y + 5, pos.Z)
        notify("Teleport Berhasil!", "Kamu di area: " .. target.Name, "map-pin")
    end,
})

TabFishing:CreateDivider()

-- ── Auto Sell ─────────────────────────────────
TabFishing:CreateSection("💰  Auto Sell")

local lblStarCount    = TabFishing:CreateLabel("⭐  Stars        :  0",      "star")
local lblSellStatus   = TabFishing:CreateLabel("🔔  Mode         :  Nonaktif", "bell")
local lblSellCountdown = TabFishing:CreateLabel("⏱️  Countdown  :  --:--",   "timer")

-- Tombol sell manual
TabFishing:CreateButton({
    Name     = "💸  Sell Semua Bintang Sekarang",
    Callback = function()
        task.spawn(doSell)
        notify("Sell", "Menjual semua bintang...", "dollar-sign")
    end,
})

-- Pilih mode (hanya pilih, tidak langsung aktif)
local sellMode = "Timer"  -- default mode yang dipilih

TabFishing:CreateDropdown({
    Name            = "Mode Auto Sell",
    Options         = {"Timer", "Kapasitas"},
    CurrentOption   = {"Timer"},
    MultipleOptions = false,
    Flag            = "SellModeDropdown",
    Callback        = function(opts)
        sellMode = opts[1]
        -- Update state tanpa mengaktifkan — ikuti toggle
        if autoSellEnabled or autoSellCapacity then
            autoSellEnabled  = (sellMode == "Timer")
            autoSellCapacity = (sellMode == "Kapasitas")
            if sellMode == "Timer" then sellCountdown = sellInterval end
        end
        notify("Mode Dipilih", "Mode: " .. sellMode .. " (toggle untuk aktifkan)", "settings", 2)
    end,
})

-- Toggle on/off auto sell
TabFishing:CreateToggle({
    Name         = "Auto Sell",
    CurrentValue = false,
    Flag         = "AutoSellToggle",
    Callback     = function(val)
        autoSellEnabled  = false
        autoSellCapacity = false
        if val then
            if sellMode == "Timer" then
                autoSellEnabled = true
                sellCountdown   = sellInterval
                notify("Auto Sell", "Aktif! Mode Timer — tiap " .. sellInterval .. " detik.", "timer")
            elseif sellMode == "Kapasitas" then
                autoSellCapacity = true
                notify("Auto Sell", "Aktif! Mode Kapasitas — threshold " .. sellCapThreshold .. " stars.", "package")
            end
        else
            notify("Auto Sell", "Dinonaktifkan.", "x-circle", 2)
        end
    end,
})

-- Input: interval waktu (untuk mode Timer)
TabFishing:CreateInput({
    Name            = "Interval Waktu (detik)",
    PlaceholderText = "120",
    NumbersOnly     = true,
    Flag            = "SellIntervalInput",
    Callback        = function(val)
        local n = tonumber(val)
        if n and n >= 10 then
            sellInterval  = n
            sellCountdown = n
            notify("Interval Sell", "Diset ke " .. n .. " detik.", "timer", 2)
        else
            notify("Input Salah", "Minimal 10 detik.", "alert-triangle", 2)
        end
    end,
})

-- Input: threshold kapasitas (untuk mode Kapasitas)
TabFishing:CreateInput({
    Name            = "Threshold Kapasitas (Stars)",
    PlaceholderText = "400",
    NumbersOnly     = true,
    Flag            = "SellCapInput",
    Callback        = function(val)
        local n = tonumber(val)
        if n and n >= 1 then
            sellCapThreshold = n
            notify("Threshold", "Diset ke " .. n .. " stars.", "package", 2)
        else
            notify("Input Salah", "Masukkan angka valid.", "alert-triangle", 2)
        end
    end,
})

-- ═══════════════════════════════════════════════════════
--  FLOATING STATS GUI
-- ═══════════════════════════════════════════════════════
local statsGuiVisible = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "AutoFishStatsOverlay"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = player.PlayerGui

-- ── Main frame ────────────────────────────────
local statsFrame = Instance.new("Frame", screenGui)
statsFrame.Name               = "StatsFrame"
statsFrame.Size               = UDim2.new(0, 230, 0, 0)  -- height auto dari AutomaticSize
statsFrame.Position           = UDim2.new(0, 14, 0, 14)
statsFrame.BackgroundColor3   = Color3.fromRGB(18, 18, 26)
statsFrame.BorderSizePixel    = 0
statsFrame.Visible            = false
statsFrame.Active             = true
statsFrame.Draggable          = true
statsFrame.AutomaticSize      = Enum.AutomaticSize.Y
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke", statsFrame)
mainStroke.Color        = Color3.fromRGB(80, 130, 255)
mainStroke.Thickness    = 1.5
mainStroke.Transparency = 0.5

-- ── Title bar ─────────────────────────────────
local titleBar = Instance.new("Frame", statsFrame)
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0, 34)
titleBar.Position         = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 2
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

-- flatten bottom corners of title bar
local flatBottom = Instance.new("Frame", titleBar)
flatBottom.Size             = UDim2.new(1, 0, 0.5, 0)
flatBottom.Position         = UDim2.new(0, 0, 0.5, 0)
flatBottom.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
flatBottom.BorderSizePixel  = 0
flatBottom.ZIndex           = 2

local titleIcon = Instance.new("TextLabel", titleBar)
titleIcon.Size                = UDim2.new(0, 24, 1, 0)
titleIcon.Position            = UDim2.new(0, 10, 0, 0)
titleIcon.Text                = "📊"
titleIcon.TextSize            = 14
titleIcon.Font                = Enum.Font.GothamBold
titleIcon.BackgroundTransparency = 1
titleIcon.ZIndex              = 3

local titleText = Instance.new("TextLabel", titleBar)
titleText.Size                = UDim2.new(1, -44, 1, 0)
titleText.Position            = UDim2.new(0, 34, 0, 0)
titleText.Text                = "Auto Star Fishing — Stats"
titleText.TextColor3          = Color3.fromRGB(210, 220, 255)
titleText.TextSize            = 12
titleText.Font                = Enum.Font.GothamBold
titleText.BackgroundTransparency = 1
titleText.TextXAlignment      = Enum.TextXAlignment.Left
titleText.ZIndex              = 3

-- ── Content frame (auto height) ───────────────
local contentFrame = Instance.new("Frame", statsFrame)
contentFrame.Name             = "Content"
contentFrame.Size             = UDim2.new(1, 0, 0, 0)
contentFrame.Position         = UDim2.new(0, 0, 0, 34)  -- tepat di bawah title
contentFrame.BackgroundTransparency = 1
contentFrame.AutomaticSize    = Enum.AutomaticSize.Y
contentFrame.BorderSizePixel  = 0

local contentPad = Instance.new("UIPadding", contentFrame)
contentPad.PaddingTop    = UDim.new(0, 8)
contentPad.PaddingBottom = UDim.new(0, 10)
contentPad.PaddingLeft   = UDim.new(0, 12)
contentPad.PaddingRight  = UDim.new(0, 12)

local contentLayout = Instance.new("UIListLayout", contentFrame)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding   = UDim.new(0, 5)

-- ── Row factory ───────────────────────────────
local function makeRow(defaultText, order, isHeader)
    local row = Instance.new("TextLabel", contentFrame)
    row.Name                  = "Row_" .. order
    row.Size                  = UDim2.new(1, 0, 0, 18)
    row.Text                  = defaultText
    row.TextColor3            = isHeader
        and Color3.fromRGB(140, 160, 255)
        or  Color3.fromRGB(200, 208, 235)
    row.TextSize              = isHeader and 11 or 12
    row.Font                  = isHeader and Enum.Font.GothamBold or Enum.Font.Gotham
    row.BackgroundTransparency = 1
    row.TextXAlignment        = Enum.TextXAlignment.Left
    row.LayoutOrder           = order
    return row
end

-- ── Divider factory ───────────────────────────
local function makeDivider(order)
    local div = Instance.new("Frame", contentFrame)
    div.Size             = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = Color3.fromRGB(55, 65, 100)
    div.BorderSizePixel  = 0
    div.LayoutOrder      = order
end

-- ── Rows ──────────────────────────────────────
makeRow("FISHING", 1, true)
local ovFishing   = makeRow("🔴  Status      :  Nonaktif",    2)
local ovTotalCast = makeRow("🎣  Total Cast  :  0",           3)
local ovUptime    = makeRow("⏰  Uptime      :  00:00",        4)
local ovGalaxy    = makeRow("🌌  Galaxy      :  Auto",         5)

makeDivider(6)

makeRow("STARS & SELL", 7, true)
local ovStars      = makeRow("⭐  Stars       :  0",           8)
local ovSellToggle = makeRow("🔴  Auto Sell   :  OFF",         9)
local ovSellMode   = makeRow("🔔  Mode        :  Nonaktif",    10)
local ovCountdown  = makeRow("⏱️  Countdown   :  --:--",       11)
local ovSellLast   = makeRow("💸  Last Sell   :  --",          12)


-- ═══════════════════════════════════════════════════════
--  UI  ·  TAB: STATS
-- ═══════════════════════════════════════════════════════

TabStats:CreateSection("📊  Live Stats")

local lblTotalCast  = TabStats:CreateLabel("🎣  Total Cast       :  0",              "hash")
local lblUptime     = TabStats:CreateLabel("⏰  Uptime           :  00:00",           "clock")
local lblFishLive   = TabStats:CreateLabel("🔴  Fishing          :  Nonaktif",        "activity")
local lblSellLive   = TabStats:CreateLabel("💤  Sell             :  Nonaktif",        "timer")
local lblGalaxyStat = TabStats:CreateLabel("🌌  Galaxy Aktif     :  Auto (Terdekat)", "map-pin")

TabStats:CreateDivider()

TabStats:CreateButton({
    Name     = "🔄  Reset Semua Stats",
    Callback = function()
        totalCasts   = 0
        sessionStart = os.time()
        notify("Reset Stats", "Semua statistik berhasil direset!", "rotate-ccw", 2)
    end,
})

TabStats:CreateDivider()
TabStats:CreateSection("🖥️  Stats Overlay")

TabStats:CreateToggle({
    Name         = "Tampilkan Stats Overlay",
    CurrentValue = false,
    Flag         = "StatsOverlayToggle",
    Callback     = function(val)
        statsGuiVisible    = val
        statsFrame.Visible = val
        if val then
            notify("Stats Overlay", "Overlay aktif! Bisa digeser sesuka hati.", "layout", 2)
        else
            notify("Stats Overlay", "Overlay disembunyikan.", "eye-off", 2)
        end
    end,
})

TabStats:CreateDivider()

-- ── Anti AFK ─────────────────────────────────
TabStats:CreateSection("🛡️  Anti AFK")

TabStats:CreateToggle({
    Name         = "Anti AFK",
    CurrentValue = false,
    Flag         = "AntiAfkToggle",
    Callback     = function(val)
        antiAfkEnabled = val
        if val then
            notify("Anti AFK", "Aktif! Kamu tidak akan di-kick server.", "shield")
        else
            notify("Anti AFK", "Dinonaktifkan.", "shield-off")
        end
    end,
})

TabStats:CreateParagraph({
    Title   = "ℹ️  Cara Kerja Anti AFK",
    Content = "Script melakukan klik virtual (VirtualUser) setiap 60 detik agar server tidak menganggap kamu idle dan tidak men-kick akun kamu.",
})

-- ═══════════════════════════════════════════════════════
--  UI  ·  TAB: SETTINGS
-- ═══════════════════════════════════════════════════════

TabSettings:CreateSection("🎣  Rod Settings")

TabSettings:CreateToggle({
    Name         = "Auto Equip Rod",
    CurrentValue = true,
    Flag         = "AutoEquipToggle",
    Callback     = function(val)
        notify("Auto Equip Rod", val and "Aktif." or "Nonaktif.", "zap", 2)
    end,
})

TabSettings:CreateToggle({
    Name         = "Auto Unequip Saat Berhenti",
    CurrentValue = true,
    Flag         = "AutoUnequipToggle",
    Callback     = function(val)
        notify("Auto Unequip", val and "Aktif." or "Nonaktif.", "zap-off", 2)
    end,
})

TabSettings:CreateDivider()

TabSettings:CreateSection("📋  Informasi Script")

TabSettings:CreateParagraph({
    Title   = "📜  Auto Star Fishing v2.0",
    Content =
        "UI Library  : Rayfield\n" ..
        "Game        : Star Fishing\n\n" ..
        "Fitur Lengkap:\n" ..
        "• Auto Cast & Withdraw\n" ..
        "• Galaxy Selector (7 area)\n" ..
        "• Teleport ke Galaxy (+5 stud)\n" ..
        "• Auto Item Confirm\n" ..
        "• Auto Sell Timer (30–600 dtk)\n" ..
        "• Live Cast Counter & Uptime\n" ..
        "• Anti AFK (VirtualUser)\n" ..
        "• Force Equip/Unequip Rod\n" ..
        "• Config tersimpan otomatis\n\n" ..
        "Toggle UI: tekan  K"
})

TabSettings:CreateLabel("⚠️  Gunakan dengan bijak dan tanggung jawab!", "alert-triangle")
TabSettings:CreateLabel("🎮  Selamat bermain & semoga dapat banyak stars!", "gamepad-2")

-- ─────────────────────────────────────────────
--  LOAD SAVED CONFIG  (selalu di paling bawah)
-- ─────────────────────────────────────────────
Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════════
--  BACKGROUND LOOPS
-- ═══════════════════════════════════════════════════════

-- Loop 1 · Live updater (setiap 1 detik)
local lastSellTime = "--"

task.spawn(function()
    while true do
        task.wait(1)

        local uptime       = fmtTime(os.time() - sessionStart)
        local currentStars = getStarCount()
        local isOn         = autoFishing

        -- ── Rayfield labels ──
        pcall(function() lblTotalCast:Set("🎣  Total Cast       :  " .. totalCasts,              "hash") end)
        pcall(function() lblUptime:Set("⏰  Uptime           :  " .. uptime,                     "clock") end)
        pcall(function()
            lblFishLive:Set(isOn and "🟢  Fishing          :  Aktif" or "🔴  Fishing          :  Nonaktif", "activity")
            lblFishStatus:Set(isOn and "Status  :  ✅ Aktif" or "Status  :  ⛔ Nonaktif", "activity")
        end)
        pcall(function() lblGalaxyStat:Set("🌌  Galaxy Aktif     :  " .. selectedGalaxy,         "map-pin") end)
        pcall(function() lblStarCount:Set("⭐  Stars        :  " .. currentStars,                "star") end)
        pcall(function()
            if autoSellEnabled then
                lblSellStatus:Set("🔔  Mode         :  ⏱️ Timer", "timer")
                lblSellCountdown:Set("⏱️  Countdown  :  " .. fmtTime(sellCountdown), "timer")
                lblSellLive:Set("⏱️  Sell Timer       :  " .. fmtTime(sellCountdown), "timer")
            elseif autoSellCapacity then
                lblSellStatus:Set("🔔  Mode         :  📦 Kapasitas (" .. sellCapThreshold .. ")", "package")
                lblSellCountdown:Set("⏱️  Countdown  :  --:--", "timer")
                lblSellLive:Set("📦  Sell Kapasitas   :  Aktif (" .. sellCapThreshold .. " stars)", "package")
            else
                lblSellStatus:Set("🔔  Mode         :  Nonaktif", "bell")
                lblSellCountdown:Set("⏱️  Countdown  :  --:--", "timer")
                lblSellLive:Set("💤  Sell             :  Nonaktif", "timer")
            end
        end)

        -- ── Overlay GUI update ──
        if statsGuiVisible then
            pcall(function()
                local sellIsOn = autoSellEnabled or autoSellCapacity

                ovTotalCast.Text  = "🎣  Total Cast  :  " .. totalCasts
                ovUptime.Text     = "⏰  Uptime      :  " .. uptime
                ovFishing.Text    = isOn and "🟢  Fishing     :  ON" or "🔴  Fishing     :  OFF"
                ovGalaxy.Text     = "🌌  Galaxy      :  " .. selectedGalaxy
                ovStars.Text      = "⭐  Stars       :  " .. currentStars
                ovSellToggle.Text = sellIsOn and "🟢  Auto Sell   :  ON" or "🔴  Auto Sell   :  OFF"
                ovSellLast.Text   = "💸  Last Sell   :  " .. lastSellTime

                if autoSellEnabled then
                    ovSellMode.Text  = "🔔  Mode        :  ⏱️ Timer"
                    ovCountdown.Text = "⏱️  Countdown   :  " .. fmtTime(sellCountdown)
                elseif autoSellCapacity then
                    ovSellMode.Text  = "🔔  Mode        :  📦 Kapasitas"
                    ovCountdown.Text = "📦  Threshold   :  " .. sellCapThreshold .. " stars"
                else
                    ovSellMode.Text  = "🔔  Mode        :  Nonaktif"
                    ovCountdown.Text = "⏱️  Countdown   :  --:--"
                end
            end)
        end

        -- ── Auto Sell by Capacity trigger ──
        if autoSellCapacity and currentStars >= sellCapThreshold and not selling then
            lastSellTime = fmtTime(os.time() - sessionStart)
            task.spawn(doSell)
            notify("Auto Sell Kapasitas", "Stars " .. currentStars .. " ≥ " .. sellCapThreshold .. "! Menjual...", "package", 3)
        end

        -- ── Sell timer countdown tick ──
        if autoSellEnabled then
            sellCountdown -= 1
            if sellCountdown <= 0 then
                sellCountdown = sellInterval
                lastSellTime  = fmtTime(os.time() - sessionStart)
                task.spawn(doSell)
                notify("Auto Sell Timer", "Menjual bintang otomatis!", "dollar-sign")
            end
        end
    end
end)

-- Loop 2 · Anti AFK (setiap 60 detik)
task.spawn(function()
    while true do
        task.wait(60)
        if antiAfkEnabled then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)