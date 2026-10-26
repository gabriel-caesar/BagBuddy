local function printm(arg)
  ChatFrame1:AddMessage(tostring(arg))
end

-- ############### INITIALIZE ###############
local function BagBuddy_Initialize()
  MAX_BAG_SLOT_NUM = 24
  BB = getglobal("BagBuddy") -- Main Frame table
  BB.next = getglobal("BagBuddy_NextButton") -- Pagination
  BB.prev = getglobal("BagBuddy_PrevButton") -- Pagination
  BB.itemsCountText = getglobal("BagBuddy_ItemsCount")
  BB.statusText = getglobal("BagBuddy_Status")
  BB.input = getglobal("BagBuddy_Input")
  BB.inputPlaceholder = getglobal("BagBuddy_Placeholder")
  BB.icon = getglobal("BagBuddy_Icon")

  -- Showing and hiding the search input placeholder accordingly
  BB.input:SetScript("OnEditFocusGained", function()
    BB.inputPlaceholder:Hide()
  end)
  BB.input:SetScript("OnEditFocusLost", function()
    if string.len(BB.input:GetText()) == 0 then 
      BB.inputPlaceholder:Show()
    end
  end)

  BB.page = 1 -- Setting the pagination variable to one initially
  BB.filters = {} -- Table for filter buttons
  BB.bagCounts = {} -- Helps with BagBuddy's update function when picking up new items

  BB:RegisterEvent("BAG_UPDATE") -- Register the bag update event to BagBuddy main frame
  BB:RegisterEvent("ADDON_LOADED") -- Whenever the addon finishes loading 

  -- UIPanelWindows is a special global table that contains definitions 
  -- of the various panels that are controlled by the user interface
  UIPanelWindows["BagBuddy"] = {
    area = "left",
    pushable = 1,
    whileDead = 1
  }
end
-- ############### ########## ###############

local function SetBagBuddyMinimapIcon()

  BB.icon:SetClampedToScreen(true)
  BB.icon:SetMovable(true)
  BB.icon:EnableMouse(true)

  BB.icon:SetScript("OnEnter", function() 
    GameTooltip:SetOwner(BB.icon, ANCHOR_BOTTOMLEFT) -- Anchor it on the top right of the button
    GameTooltip:SetText("BagBuddy", 1, 1, 1)
    GameTooltip:AddLine("Left click to open", NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b)
    GameTooltip:AddLine("Right click to drag", NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
   end)

  BB.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  BB.icon:SetScript("OnClick", function() 
    if BB:IsVisible() then HideUIPanel(BB) else ShowUIPanel(BB) end
  end)
  
end

-- Handles switching through tabs in the main frame of the AddOn
function BagBuddy_NextPage(this)
  BB.page = BB.page + 1
  BagBuddy_Update()
end

function BagBuddy_PrevPage(this)
  BB.page = BB.page - 1
  BagBuddy_Update()
end

-- Item hover tooltip
function BagBuddy_Button_OnEnter(this, motion)
  -- Check if the button is set to display an item
  if this.link then
    GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT") -- Anchor it on the top right of the button
    GameTooltip:SetHyperlink(this.link)
    GameTooltip:Show()
  end
end

-- Item hover tooltip
function BagBuddy_Button_OnLeave(this, motion)
  GameTooltip:Hide()
end

-- Filter button tooltip function
function BagBuddy_Filter_OnEnter(this, motion)
  -- Anchoring the tooltip accordingly
  GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT")
  -- Getting the RGB values for the current rarity
  local r, g, b = GetItemQualityColor(this.quality)
  -- Getting the global text for item quality and coloring it accordingly
  GameTooltip:SetText(getglobal("ITEM_QUALITY" .. this.quality .. "_DESC"), r, g, b)
  GameTooltip:Show()
end

-- Filter button hover tooltip
function BagBuddy_Filter_OnLeave(this, motion)
  GameTooltip:Hide()
end

-- Filters the character's bag relative to the rarity button clicked
function BagBuddy_Filter_OnClick(self, button)
  -- Navigate to the first page on filter click to not get the player stuck on blank pages after filtering the items
  BB.page = 1 

  -- Set the filter to false before the loop
  BB.qualityFilter = false
  local NUM_OF_FILTERS = 5

  for idx = 0, NUM_OF_FILTERS do
    -- Iterate through every filter button to see if any is checked
    local filterBtn = BB.filters[idx]
    if filterBtn:GetChecked() then
      -- If the current filter button is checked, set qualityFilter to true
      BB.qualityFilter = true
    end
  end
  BagBuddy_Update()
end

local function BagBuddy_CreateFrameIcon()
  -- Setting the Bagbuddy's icon
  local PFrameTexture = getglobal("BagBuddy_Portrait")
  -- Crops the texture to become a circle instead of a square shape
  SetPortraitToTexture(PFrameTexture, "Interface\\Icons\\inv_gizmo_02")
end

local function BagBuddy_CreateButtonItems()
  -- Creating every button for the BagBuddy main frame
  BB.items = {}
  for idx = 1, MAX_BAG_SLOT_NUM do
    local item = CreateFrame("Button", "BagBuddy_Item" .. idx, BB, "BagBuddyItemTemplate")
    BB.items[idx] = item
    item:RegisterForClicks("RightButtonUp")
    if idx == 1 then
      item:SetPoint("TOPLEFT", 40, -73)
    elseif idx == 7 or idx == 13 or idx == 19 then
      item:SetPoint("TOPLEFT", BB.items[idx-6], "BOTTOMLEFT", 0, -7)
    else
      item:SetPoint("TOPLEFT", BB.items[idx-1], "TOPRIGHT", 12, 0)
    end
  end
end


local function BagBuddy_CreateFilterButtons()
  -- Creating the filter buttons for the BagBuddy main frame
  for idx = 0, 5 do
    -- Virtually creating the check filter button
    local button = CreateFrame("CheckButton", "BagBuddyFilter" .. idx, BB, "BagBuddyFilterTemplate")
    -- Setting the check filter button icon to a custom pearl image
    SetItemButtonTexture(button, "Interface\\ICONS\\INV_Misc_Gem_Pearl_03")
    BB.filters[idx] = button

    -- Positioning the filter buttons to the bottom of the BagBuddy main frame
    if idx == 0 then
      button:SetPoint("BOTTOMLEFT", 40, 200)
    else
      button:SetPoint("TOPLEFT",BB.filters[idx-1],"TOPRIGHT",12,0)
    end

    -- Coloring the button icon and hide the button glow
    local buttonIcon = getglobal("BagBuddyFilter" .. idx .. "IconTexture")
    local buttonGlow = getglobal("BagBuddyFilter" .. idx .. "Glow")
    buttonIcon:SetVertexColor(GetItemQualityColor(idx))
    button:SetChecked(false) -- Unchecking every filter button
    button.quality = idx
    buttonGlow:Hide()
  end

  -- Finally, you set up a link between the -1 filter and the 0 filter. That’s due
  -- to the API that occasionally returns -1 rarity for some items.
  BB.filters[-1] = BB.filters[0]
end

local function itemTimeNameSort(a, b)
  -- If the two items were looted at the same time
  -- `BagBuddy_itemTimes` is a global table
  local aTime = BagBuddy_itemTimes[a.num] 
  local bTime = BagBuddy_itemTimes[b.num]
  if aTime == bTime then
    return a.name < b.name
  else
    return aTime >= bTime
  end
end

function BagBuddy_Item_OnClick()
  -- 1.12: `this` is the button, `arg1` is the mouse button
  if arg1 == "RightButton" and this.bag and this.slot then
    UseContainerItem(this.bag, this.slot) -- Will attempt to use whatever item contained in the slot
  end
end

function BagBuddy_OnEvent()

  -- Will update the bag items if some bag event fired
  if event == "BAG_UPDATE" then
    if BB:IsVisible() then
      BagBuddy_Update()
    end
  end
end

function BagBuddy_ScanBag(bag, initial)
  -- Checking if the current bag being scanned was already created
  if not BB.bagCounts[bag] then
    BB.bagCounts[bag] = {}
  end

  local itemsCount = {}
  for slot = 0, GetContainerNumSlots(bag) do -- Getting the number of slots in the specified bag
    -- Returns info for an item in a container slot
    local texture, count = GetContainerItemInfo(bag, slot)

    -- If an item is found
    if texture then 
      local link = GetContainerItemLink(bag, slot)
      local _, _, id = string.find(link or "", "|Hitem:(%d+):")
      local itemId = tonumber(id)

      -- Checking if itemId was retrieved correctly
      if not itemId then 
        printm("Item ID was not correctly provided, it has a value of " .. itemId)
        return
      end

      if not itemsCount[itemId] then 
        itemsCount[itemId] = count -- Create item count record from scratch
      else
        itemsCount[itemId] = itemsCount[itemId] + count -- Increment to the existing item count
      end
    end 
  end

  -- initial == will indicate whether the function is being called on the first scan of a session
  if initial then 
    for itemId, count in pairs(itemsCount) do 
      BagBuddy_itemTimes[itemId] = BagBuddy_itemTimes[itemId] or time()
    end

  else
    for itemId, count in pairs(itemsCount) do 
      local oldCount = BB.bagCounts[itemId] or 0
      if count > oldCount then 
        BagBuddy_itemTimes[itemId] = time()
      end
    end
  end

  BB.bagCounts[bag] = itemsCount
end

function BagBuddy_Update()
  local items = {}

  local nameFilter = string.lower(BB.input:GetText())

  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do -- Loop through every in-bag slot
      local texture, count, locked, quality, readable = GetContainerItemInfo(bag, slot)
      local rawItemLink = GetContainerItemLink(bag, slot) -- "|cff71d5ff|Hspell:2061:0|h[Flash Heal]|h|r"
      
      -- If a texture of an item was found in the bag slot
      if texture then
        local _, _, infoLink = string.find(rawItemLink, "|Hitem:(%d+):") -- Item ID formatted as "1234"
        local itemName = GetItemInfo(infoLink) -- Getting the item name
        local shown = true

        -- If there is a filter, check which quality it is under
        if BB.qualityFilter then
          -- The filtering occurs here:
          -- The program will try to see if the current item indexed's quality
          -- matches the quality filter button checked at the current moment.
          -- If its not, `shown` toggles to false, therefore not creating a record
          -- for the item that doesn't match the current quality filter.
          shown = shown and BB.filters[quality]:GetChecked()
        end

        -- Filter by search through BagBuddy's main text input
        if string.len(nameFilter) > 0 then
          local lowerItemName = string.lower(itemName)
          -- Get the start position of the match found by the `.find()` method.
          -- Since this search is done per keyboard stroke, the program checks
          -- for a match on every bag item per letter typed and adds to the 
          -- quality filter (if BB.qualityFilter == true) already existent in the moment.
          local startPos = string.find(lowerItemName, nameFilter, 1, true)
          shown = shown and startPos ~= nil
        end

        if shown then
          -- Item ID formatted as "item:1234:0:0:0:0" used for the GameTooltip
          local _, _, inspectLink = string.find(rawItemLink, "(item:%d+:%d+:%d+:%d+)")
          local itemNum = tonumber(infoLink) -- Turn Item ID to number

          if itemNum == nil then 
            printm("itemNum is nil. Stopped update function execution.")
            return
          end
  
          -- Create an item record from scratch, using its item ID as key
          if not items[itemNum] then 
            items[itemNum] = {
              texture = texture,
              count = count,
              quality = quality,
              name = itemName,
              link = inspectLink,
              num = itemNum,
              bag = bag,
              slot = slot
            }
          else
            -- Add one more to the count of the existent item record
            items[itemNum].count = items[itemNum].count + 1
          end
        end

      end
    end 
  end

  -- Create an array-table to sort the items found in the bag
  local sortTbl = {}
  for _link, entry in pairs(items) do
    table.insert(sortTbl, entry)
  end
  table.sort(sortTbl, function(a,b) return a.quality > b.quality end)

  -- Paging local variables
  local max = BB.page * MAX_BAG_SLOT_NUM
  local min = max - 23
  
  -- Example:
  -- Page 1: entries 1 to 24
  -- Page 2: entries 25 to 48
  -- Page 3: entries 49 to 72

  -- Display items in the BagBuddy frame
  for i = min, max do

    -- Idea:
    -- The loop walks i through the window, and btnIdx = i - min + 1 
    -- converts it to a screen slot. On page 2, min is 25, so entry 25
    -- goes to button 1, entry 26 to button 2, and entry 48 to button 24. 
    -- On page 1, min is 1, so the two numbers are identical, which is 
    -- why the bug only appeared on page 2.

    local buttonIdx = i - min + 1
    local button = BB.items[buttonIdx]
    local entry = sortTbl[i]

    if entry then
      -- There is an item in the bag slots
      button.link = entry.link
      button.bag = entry.bag
      button.slot = entry.slot

      -- Getting all the essential parts of the button
      local buttonGlow = getglobal("BagBuddy_Item" .. buttonIdx .. "Glow")
      local buttonIcon = getglobal("BagBuddy_Item" .. buttonIdx .. "IconTexture")
      local buttonCount = getglobal("BagBuddy_Item" .. buttonIdx .. "Count")

      -- Both of these functions set textures to a button
      -- SetItemButtonTexture(button, entry.texture)
      buttonIcon:SetTexture(entry.texture) -- Setting the item texture to the button icon texture

      if entry.count > 1 then
        buttonCount:SetText(entry.count) -- Enabling and showing the item count text
        buttonCount:Show()
      else
        buttonCount:Hide()
      end

      -- Adjusting the item color to match its rarity
      if entry.quality > 1 then
        -- Coloring and showing the rarity color of the item
        buttonGlow:SetVertexColor(GetItemQualityColor(entry.quality))
        buttonGlow:Show()
      else  
        buttonGlow:Hide()
      end

      button:Show() -- Finally, show the button
    else
      button.link = nil
      button.bag = nil
      button.slot = nil
      button:Hide() -- If there is no item in the bag slot, hide it
    end

  end

  -- If the first minimum item slot number is greater than 1, it means
  -- the player already navigated to the next BagBuddypage from the first,
  -- meaning going back to the previous tab is enabled, otherwise it is disabled.
  if min > 1 then BB.prev:Enable() else BB.prev:Disable() end
  -- If the max item slot number containing an item is smaller than the
  -- the total amount of items in the player's bags, then enable the "Next"
  -- navigation button through BagBuddy, otherwise, disable the it.
  if table.getn(sortTbl) > max then BB.next:Enable() else BB.next:Disable() end

  -- Text close to the Refresh button.
  -- Will choose the minimum between the maximum number of slots in the current
  -- page of the bag and the total number of items in the bag. If in the last page,
  -- total is the minimum since most of the times players have less items than the number
  -- of slots in the last page of their BagBuddy.
  local total = table.getn(sortTbl)
  if total > MAX_BAG_SLOT_NUM then
    BB.itemsCountText:SetText(msg)
  else
    BB.itemsCountText:SetText("Found " .. total .. " items")
  end

  -- Displays the total and current page numbers in between the navigation arrow buttons
  BB.statusText:SetText("Page " .. BB.page .. " of " .. math.ceil(table.getn(sortTbl) / MAX_BAG_SLOT_NUM))

  BB.bagItemCount = table.getn(sortTbl)
end

BagBuddy_Initialize()
BagBuddy_CreateFrameIcon()
BagBuddy_CreateButtonItems()
BagBuddy_CreateFilterButtons()
SetBagBuddyMinimapIcon()

local CloseBB_Button = CreateFrame("Button", "CloseBB_Button", BB, "UIPanelCloseButton")
CloseBB_Button:ClearAllPoints()
CloseBB_Button:SetScript("OnClick", function() HideUIPanel(BB) end)
CloseBB_Button:SetPoint("TOPRIGHT",-30,-8)

-- Handles what happens when BagBuddy's main frame hides
BB:SetScript("OnHide", function()
  BB.page = 1 -- Switching the BagBuddy to its first page
  BB.input:SetText("") -- Clear name search filter upon close the frame
end)

local RefreshButton = CreateFrame("Button", "RefreshButton", BB, "UIPanelButtonTemplate")
RefreshButton:SetText("Refresh")
RefreshButton:SetWidth(80)
RefreshButton:SetHeight(30)
RefreshButton:ClearAllPoints()
RefreshButton:SetScript("OnClick", function() BagBuddy_Update() end)
RefreshButton:SetPoint("TOPRIGHT",-57, -38)

local function SlashHandler()
  BagBuddy_Update()
  -- Special function that includes BB to a table of common
  -- rules, making it closeable by pressing escape
  ShowUIPanel(BB) 
  BB.inputPlaceholder:Show()
end

SLASH_BB1 = "/bagbuddy"
SLASH_BB2 = "/bb"
SLASH_BBRELOAD1 = '/bbreload'
SlashCmdList["BB"] = SlashHandler
SlashCmdList["BBRELOAD"] = BagBuddy_Update

-- 290