-- Addon folder name as the client reports it in ADDON_LOADED (lootbooster, LootBooster, ...)
local ADDON_NAME = ...
-- The packager writes the release tag into the TOC; a git checkout still has the token and calls itself "dev"
local MOD_VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
if (string.sub(MOD_VERSION, 1, 1) == "@") then
    MOD_VERSION = "dev"
end
local GAME_VERSION = (GetBuildInfo())
-- sound/character/gnome/gnomevocalfemale/gnomefemalecheer01.ogg (game files play by FileDataID only)
local DEFAULT_ALERT_SOUND = 540434



LBooster = CreateFrame("Frame", "LBooster")
LBooster:SetScript("OnEvent", function(self, event, ...)
    self[event](self, event, ...)
    end)
LBooster:RegisterEvent("ADDON_LOADED")





local print = function(sOutput)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800<|cff0088ffLootBooster|cffff8800>|r "..sOutput)
end
local eprint = function(sOutput)
    print("|cffff0000"..sOutput.."|r")
end
local hprint = function(sCommand, sOptions, sDescription)
    local sMsg = ""
    
    sCommand = string.gsub(sCommand, "/", "|cff808080/|cffffff00")
    sMsg = "|cffffff00"..sCommand
    
    if (sOptions ~= "") then
        sOptions = string.gsub(sOptions, "/", "|cff808080/|cffffbb44")
        sMsg = sMsg.." |cffff8800<|cffffbb44"..sOptions.."|cffff8800>"
    end
    
    sMsg = sMsg.."|r : "..sDescription
    print(sMsg)
end

local OnOff = function(bToggle)
    if (bToggle) then
        return "|cff00ff00On|r"
    end
    return "|cffff0000Off|r"
end

local AlertSoundOn = function()
    return (LootBoosterDB.AlertSound ~= "") and (LootBoosterDB.AlertSound ~= "off")
end

-- Resolves an item name or link to its item name; nil (with an error) when the client does not know it
local ItemName = function(sTitle)
    local sName = (sTitle ~= "") and C_Item.GetItemInfo(sTitle)
    if (not sName) then
        eprint("Unknown Item '"..sTitle.."' (use an item link)")
        return nil
    end
    return sName
end




function LBooster.ADDON_LOADED(self, event, arg1)
    if (arg1 ~= ADDON_NAME) then return end
	
    LootBoosterDB = LootBoosterDB or {}
    LootBoosterDB.Items = LootBoosterDB.Items or {}
    LootBoosterDB.Ignore = LootBoosterDB.Ignore or {}
    LootBoosterDB.Alert = LootBoosterDB.Alert or {}
    LootBoosterDB.Enable = (LootBoosterDB.Enable == nil) and true or LootBoosterDB.Enable
    LootBoosterDB.Printout = (LootBoosterDB.Printout == nil) and true or LootBoosterDB.Printout
    LootBoosterDB.LootAll = (LootBoosterDB.LootAll == nil) and false or LootBoosterDB.LootAll
    if (not LootBoosterDB.Rarity) then
        LootBoosterDB.Rarity = 2
    end
    if (not LootBoosterDB.Price) then
        LootBoosterDB.Price = 10000
    end
    -- Game sound paths stopped playing in 8.2; reset old saved paths to the FileDataID default
    if (not LootBoosterDB.AlertSound) or ((type(LootBoosterDB.AlertSound) == "string") and string.find(string.lower(LootBoosterDB.AlertSound), "^sound[\\/]")) then
        LootBoosterDB.AlertSound = DEFAULT_ALERT_SOUND
    end
    LBooster:UnregisterEvent("ADDON_LOADED")
    
    if (LootBoosterDB.Enable) then
        LBooster:RegisterEvent("LOOT_READY")
    end
    -- Bindings are loaded after addons; UPDATE_BINDINGS fires once they are in place
    LBooster:RegisterEvent("UPDATE_BINDINGS")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffff77aaTia|cffffffff:|cff0088ff LootBooster |cff808080: |cffffff00g|cffffffff"..GAME_VERSION.." |cffffff00v|cffffffff"..MOD_VERSION.." |cff808080: |cff00ff00/lootbooster|r")
end





function LBooster.Enable()
    LBooster:RegisterEvent("LOOT_READY")
    LootBoosterDB.Enable = true
    print("Enabled")
end

function LBooster.Disable()
    LBooster:UnregisterEvent("LOOT_READY")
    LootBoosterDB.Enable = false
    print("Disabled")
end

-- Blizzard's Auto Loot Key defaults to Shift, which autoloots everything while Shift is held.
-- Shift is LootBooster's skip key, so clear it. Ctrl/Alt picked by the user are left alone.
function LBooster.UPDATE_BINDINGS()
    if (GetModifiedClick("AUTOLOOTTOGGLE") ~= "SHIFT") then return end
    if (InCombatLockdown()) then
        LBooster:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    SetModifiedClick("AUTOLOOTTOGGLE", "NONE")
    SaveBindings(GetCurrentBindingSet())
    print("Cleared Blizzard Auto Loot Key (was Shift)")
end

function LBooster.PLAYER_REGEN_ENABLED()
    LBooster:UnregisterEvent("PLAYER_REGEN_ENABLED")
    LBooster.UPDATE_BINDINGS()
end





function LBooster.LOOT_READY(self, event, bAutoLoot)
    -- do not continue if autolooting, or while Shift is held (manual looting)
    if (bAutoLoot) or (IsShiftKeyDown()) then return end
    
    local srMoney = ""
    local srListed = ""
    local srRarity = ""
    local srPrice = ""
    local srAll = ""
    local srIgnore = ""
    local sResult = ""
    
    
    for nIndex = 1, GetNumLootItems() do
        local _, sTitle, _, _, nRarity, _, _, _, _, bCoin = GetLootSlotInfo(nIndex)
        if (sTitle) and (sTitle ~= "") then
            -- Loot money
            if (bCoin) then
                srMoney = sTitle
                srMoney = string.gsub(srMoney,"\n"," ")
                srMoney = string.gsub(srMoney," Gold", "g")
                srMoney = string.gsub(srMoney," Silver", "s")
                srMoney = string.gsub(srMoney," Copper", "c")
                LootSlot(nIndex)
            else
                -- Currencies can lack an item link; fall back to the name
                local sItemLink = GetLootSlotLink(nIndex)
                local sLink = sItemLink or sTitle
                -- Listed items always get looted
                if (LBooster.ItemExists(sTitle)) then
                    srListed = srListed..sLink
                    LBooster.DoAlert(sTitle, sLink)
                    LootSlot(nIndex)
                    ConfirmLootSlot(nIndex) --In case it's a BOP
                else
                    -- Is the item ignored?
                    if (LBooster.IgnoreExists(sTitle)) then
                        srIgnore = srIgnore..sLink
                    else
                        -- Loot if it meets our Rarity (Uncommon/Rare/Epic/Legendary/Artifact/Heirloom)
                        if (LootBoosterDB.Rarity > -1) and ((nRarity or Enum.ItemQuality.Common) >= LootBoosterDB.Rarity) then
                            srRarity = srRarity..sLink
                            LBooster.DoAlert(sTitle, sLink)
                            LootSlot(nIndex)
                            ConfirmLootSlot(nIndex) --In case it's a BOP
                        else
                            -- All other rubish is subjected to a Sell Price scan
                            local iPrice = sItemLink and select(11, C_Item.GetItemInfo(sItemLink))

                            -- Loot if it will vendor at or above our Price (or the price is unknown)
                            if (not iPrice) or ((LootBoosterDB.Price > 0) and (iPrice >= LootBoosterDB.Price)) then
                                srPrice = srPrice..sLink
                                LBooster.DoAlert(sTitle, sLink)
                                LootSlot(nIndex)
                                ConfirmLootSlot(nIndex) --In case it's a BOP
                            else
                                -- This would normally be left behind, but are we on AUTOLOOT?
                                if (LootBoosterDB.LootAll) then
                                    srAll = srAll..sLink
                                    LBooster.DoAlert(sTitle, sLink)
                                    LootSlot(nIndex)
                                    ConfirmLootSlot(nIndex) --In case it's a BOP
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if (LootBoosterDB.Printout) then
        if (srMoney ~= "") then sResult = sResult.."|cffffff99Coin|r:|cffffbb44["..srMoney.."]|r  " end
        if (srListed ~= "") then sResult = sResult.."|cff99ff99Listed|r:"..srListed.."  " end 
        if (srRarity ~= "") then sResult = sResult.."|cffff99ffRarity|r:"..srRarity.."  " end
        if (srPrice ~= "") then sResult = sResult.."|cff99bbffPrice|r:"..srPrice.."  " end
        if (srAll ~= "") then sResult = sResult.."|cff999999All|r:"..srAll.." " end
        if (srIgnore ~= "") then sResult = sResult.."|cffff0000Ignored|r:"..srIgnore.." " end
        if (sResult ~= "") then print(sResult) end
    end
end


function LBooster.DoAlert(sTitle, sLink)
    if (LBooster.AlertExists(sTitle)) then
        if (AlertSoundOn()) then
            PlaySoundFile(LootBoosterDB.AlertSound)
        end
        RaidWarningUtil.AddMessage(sLink, ChatTypeInfo["RAID_WARNING"])
    end
end


function LBooster.ItemExists(sTitle)
    for i, dbTitle in ipairs(LootBoosterDB.Items) do
        if (sTitle == dbTitle) then
            return i
        end
    end
    return nil
end


function LBooster.IgnoreExists(sTitle)
    for i, dbTitle in ipairs(LootBoosterDB.Ignore) do
        if (sTitle == dbTitle) then
            return i
        end
    end
    return nil
end


function LBooster.AlertExists(sTitle)
    for i, dbTitle in ipairs(LootBoosterDB.Alert) do
        if (sTitle == dbTitle) then
            return i
        end
    end
    return nil
end



-- ========================================================================= --
-- Slash Commands
-- ========================================================================= --
SlashCmdList["LOOTBOOSTER_COMMANDLIST"] = function(sCmd)
    if (not sCmd) or (sCmd == "") then
        LBooster.ShowInfo()    
        return
    end
    
    local _, _, cmdFirst, cmdRemain = string.find(sCmd, "(%w+)(.*)")
    if (cmdRemain) then cmdRemain = string.trim(cmdRemain) end
    if (cmdFirst) then cmdFirst = string.trim(cmdFirst) end
    
    cmdFirst = string.lower(cmdFirst)
    if (cmdFirst == "list") then
        LBooster.List()
        return
    end
    
    if (cmdFirst == "add") then
        LBooster.Add(cmdRemain)
        return
    end
    
    if (cmdFirst == "rem") or (cmdFirst == "remove") then
        LBooster.Remove(cmdRemain)
        return
    end

    if (cmdFirst == "ignore") then
        LBooster.Ignore(cmdRemain)
        return
    end
    
    if (cmdFirst == "unignore") then
        LBooster.UnIgnore(cmdRemain)
        return
    end
    
    if (cmdFirst == "alert") then
        LBooster.Alert(cmdRemain)
        return
    end
    
    if (cmdFirst == "unalert") then
        LBooster.UnAlert(cmdRemain)
        return
    end
    
    if (cmdFirst == "alertsound") then
        LBooster.AlertSound(cmdRemain)
        return
    end
    
    if (cmdFirst == "clear") then
        LBooster.Clear(cmdRemain)
        return
    end
    
    if (cmdFirst == "rarity") then
        LBooster.Rarity(cmdRemain)
        return
    end
    
    if (cmdFirst == "price") then
        LBooster.Price(cmdRemain)
        return
    end
    
    if (cmdFirst == "printout") then
        LBooster.Printout(cmdRemain)
        return
    end
    
    if (cmdFirst == "all") then
        LBooster.All(cmdRemain)
        return
    end
    
    if (cmdFirst == "on") or (cmdFirst == "enable") then
        LBooster.Enable()
        return
    end
    
    if (cmdFirst == "off") or (cmdFirst == "disable") then
        LBooster.Disable()
        return
    end
    
    if (cmdFirst == "toggle") then
        if (LootBoosterDB.Enable) then
            LBooster.Disable()
        else
            LBooster.Enable()
        end
        return
    end
    
    
    if (cmdFirst == "help") then
        LBooster.ShowHelp()
        return
    end
    
    eprint("Unknown Command '"..cmdFirst.."'")
end
SLASH_LOOTBOOSTER_COMMANDLIST1 = "/lootbooster"
SLASH_LOOTBOOSTER_COMMANDLIST2 = "/lb"


function LBooster.ShowInfo()
    print("For a list of commands type|cffffff00 /lootbooster help|r")
    print("LootBooster Enabled: "..OnOff(LootBoosterDB.Enable))
    LBooster.All()
    LBooster.Rarity()
    LBooster.Price()
    LBooster.Printout()
end


function LBooster.ShowHelp()
    print("Usage: |cffff8800/lootbooster |cffffff00<command> |cffffbb44<options>")
    hprint("on/enable/off/disable/toggle", "", "Turn LootBooster On or Off")
    hprint("list", "", "Show a List of all Autoloot Items")
    hprint("add", "itemname/itemlink", "Add an Item to the list")
    hprint("rem", "itemname/itemlink", "Remove an Item from the list")
    hprint("ignore", "itemname/itemlink", "Never pick up these items")
    hprint("unignore", "itemname/itemlink", "Remove an item from the ignore list")
    hprint("alert", "itemname/itemlink", "Show an additional alert when you pick up these items")
    hprint("unalert", "itemname/itemlink", "Remove an item from the alert list")
    hprint("alertsound", "off/default/fileID/addonsoundfile", "Set the sound played with an alert")
    hprint("clear", "all/item/ignore/alert", "Completely clear a list")
    hprint("rarity", "off/junk/common/uncommon/rare/epic/#", "Show/Set Loot-by-Rarity level")
    hprint("price", "off/ammount", "Show/Set Loot-by-Price ammount (Ammount in Copper)")
    hprint("printout", "on/off", "Printout links of items looted by LootBooster")
    hprint("all", "on/off", "Loot everything (Like AutoLoot, but accept BOP automatically)")
    print("|cffb0b0b0Hold |cffe0e0e0Shift|cffb0b0b0 while looting to skip LootBooster")
    print("|cffb0b0b0Note: Use |cffe0e0e0/lb|cffb0b0b0 for short")
end


function LBooster.List()
    print("|cffff8800Automatically Looted Items")
    for i, sTitle in ipairs(LootBoosterDB.Items) do
        print("|cffffff00"..i.."|r) "..sTitle)
    end
    print("|cffff8800Ignored Items")
    for i, sTitle in ipairs(LootBoosterDB.Ignore) do
        print("|cffffff00"..i.."|r) "..sTitle)
    end
    print("|cffff8800Alert Looted Items")
    for i, sTitle in ipairs(LootBoosterDB.Alert) do
        print("|cffffff00"..i.."|r) "..sTitle)
    end
end


function LBooster.Add(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    if (LBooster.ItemExists(sName)) then
        print("Item is Already Listed |cffffff00"..sName)
        return
    end
    table.insert(LootBoosterDB.Items, sName)
    print("Added Item to List |cffffff00"..sName)
end


function LBooster.Remove(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    local qIndex = LBooster.ItemExists(sName)
    if (qIndex) then
        table.remove(LootBoosterDB.Items, qIndex)
        print("Removed Item from List |cffffff00"..sName)
        return
    end
    print("Item is Not Listed |cffffff00"..sName)
end


function LBooster.Ignore(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    if (LBooster.IgnoreExists(sName)) then
        print("Item is Already Ignored |cffffff00"..sName)
        return
    end
    table.insert(LootBoosterDB.Ignore, sName)
    print("Added Item to Ignore |cffffff00"..sName)
end


function LBooster.UnIgnore(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    local qIndex = LBooster.IgnoreExists(sName)
    if (qIndex) then
        table.remove(LootBoosterDB.Ignore, qIndex)
        print("Removed Item from Ignore List |cffffff00"..sName)
        return
    end
    print("Item is Not Ignored |cffffff00"..sName)
end


function LBooster.Alert(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    if (LBooster.AlertExists(sName)) then
        print("Item is Already in the Alert List |cffffff00"..sName)
        return
    end
    table.insert(LootBoosterDB.Alert, sName)
    print("Added Item to Alert List |cffffff00"..sName)
end


function LBooster.UnAlert(sTitle)
    local sName = ItemName(sTitle)
    if (not sName) then return end
    local qIndex = LBooster.AlertExists(sName)
    if (qIndex) then
        table.remove(LootBoosterDB.Alert, qIndex)
        print("Removed Item from Alert List |cffffff00"..sName)
        return
    end
    print("Item is Not Alerted |cffffff00"..sName)
end


function LBooster.AlertSound(sFile)
    if (sFile) then
        if (sFile ~= "") then
            if (sFile == "off") then
                LootBoosterDB.AlertSound = ""
            elseif (sFile == "default") then
                LootBoosterDB.AlertSound = DEFAULT_ALERT_SOUND
            else
                -- FileDataID, or a sound file shipped inside an addon folder
                LootBoosterDB.AlertSound = tonumber(sFile) or sFile
            end
        end
    end
    if (not AlertSoundOn()) then
        print("Alert Sound: "..OnOff(false))
    else
        print("Alert Sound File: |cffffff00"..LootBoosterDB.AlertSound)
        PlaySoundFile(LootBoosterDB.AlertSound)
    end
end


function LBooster.Clear(sList)
    local sResult = ""
    if (sList == "item") then
        LootBoosterDB.Items = {}
        print("Item List Cleared")
    elseif (sList == "ignore") then
        LootBoosterDB.Ignore = {}
        print("Ignore List Cleared")
    elseif (sList == "alert") then
        LootBoosterDB.Alert = {}
        print("Alert List Cleared")
    elseif (sList == "all") then
        LootBoosterDB.Items = {}
        LootBoosterDB.Ignore = {}
        LootBoosterDB.Alert = {}
        print("All Lists (Items, Ignores, Alerts) Cleared")
    else
        eprint("You must specify the list to be cleared")
    end
end

function LBooster.Rarity(nQuality)
    if (nQuality) then
        if (nQuality == "off") then
            nQuality = -1
        elseif (nQuality == "junk") then
            nQuality = 0
        elseif (nQuality == "common") then
            nQuality = 1
        elseif (nQuality == "uncommon") then
            nQuality = 2
        elseif (nQuality == "rare") then
            nQuality = 3
        elseif (nQuality == "epic") then
            nQuality = 4
        end
        nQuality = tonumber(nQuality)
        if (nQuality < -1) then nQuality = -1 end
        if (nQuality > 7) then nQuality = 7 end
        LootBoosterDB.Rarity = nQuality
    end
    if (LootBoosterDB.Rarity == -1) then
        print("Loot by Rarity: "..OnOff(false))
    else
        local nRarity = LootBoosterDB.Rarity
        print("Loot by Rarity: "..ColorManager.GetFormattedStringForItemQuality(_G["ITEM_QUALITY"..nRarity.."_DESC"], nRarity))
    end
end

function LBooster.Price(nPrice)
    if (nPrice) then
        if (nPrice == "off") then
            nPrice = 0
        end
        nPrice = tonumber(nPrice)
        if (nPrice < 0) then nPrice = 0 end
        if (nPrice > 1000000) then nPrice = 1000000 end
        LootBoosterDB.Price = nPrice
    end
    if (LootBoosterDB.Price == 0) then
        print("Loot by Price: "..OnOff(false))
    else
        print("Loot by Price: "..C_CurrencyInfo.GetCoinText(LootBoosterDB.Price, " "))
    end
end

function LBooster.Printout(sCmd)
    if (sCmd) then
        if (sCmd == "on") then
            LootBoosterDB.Printout = true
        elseif (sCmd == "off") then
            LootBoosterDB.Printout = false
        end
    end
    print("Printout: "..OnOff(LootBoosterDB.Printout))
end

function LBooster.All(sCmd)
    if (sCmd) then
        if (sCmd == "on") then
            LootBoosterDB.LootAll = true
        elseif (sCmd == "off") then
            LootBoosterDB.LootAll = false
        end
    end
    print("Loot All: "..OnOff(LootBoosterDB.LootAll))
end

