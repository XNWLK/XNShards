--[[ XNShards ]]--

-- Destroys Soul Shards beyond the number you want to keep (2 by default).
--
-- WoW: Forever only lets addons delete items right after a key press, so XNShards deletes during
-- one: the next key you press out of combat (moving counts) destroys the extras, and /shards does
-- it on demand. Only a bag slot that surely holds a Soul Shard is ever deleted.
--
-- Shards are deleted straight from their bag slot (C_Item.DeleteItem), never through the cursor:
-- picking an item up runs Blizzard's bag bar and action bar code inside XNShards' call, which can
-- leave those frames blocked for later clicks (seen with action bar addons that take them over).

local SOUL_SHARD = 6265
-- the backpack, the 4 bag slots and the fifth slot after them (bag 5, where a soul bag can go too)
local FIRST_BAG, LAST_BAG = 0, math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 4, 5)

local DEFAULTS = {
	keep = 2,
	auto = true, -- destroy the extras on your next key press
}

local db
local keyWatcher -- created further down
local extraShards = 0 -- shards above db.keep, counted when the bags change
local busy = false
local pending = {} -- [item GUID] = true: delete sent, waiting for the bags to update
local refused = false -- the game blocked a delete (ADDON_ACTION_BLOCKED)
local destroyedByKeys = 0 -- shards destroyed by key presses since the last chat line

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9XNShards|r " .. message)
end

local function Plural(n)
	return n .. " Soul Shard" .. (n == 1 and "" or "s")
end

-- every bag slot holding a Soul Shard, soul bags first so the shards kept are the ones in them
local function ShardSlots()
	local soulBagSlots, otherSlots = {}, {}
	for bag = FIRST_BAG, LAST_BAG do
		local _, bagType = C_Container.GetContainerNumFreeSlots(bag)
		local list = (bag ~= 0 and bagType and bagType ~= 0) and soulBagSlots or otherSlots
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			if C_Container.GetContainerItemID(bag, slot) == SOUL_SHARD then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				table.insert(list, {bag = bag, slot = slot, count = info and info.stackCount or 1,
					locked = info and info.isLocked})
			end
		end
	end
	for _, entry in ipairs(otherSlots) do
		table.insert(soulBagSlots, entry)
	end
	return soulBagSlots
end

local function CountShards()
	local total = 0
	for _, entry in ipairs(ShardSlots()) do
		total = total + entry.count
	end
	return total
end

local function UpdateCount()
	if db then
		extraShards = math.max(CountShards() - db.keep, 0)
	end
end

-- the key watcher only listens while it has work
local function UpdateWatcher()
	if keyWatcher then
		keyWatcher:SetShown(db and db.auto and keyWatcher.watching and extraShards > 0 or false)
	end
end

-- deletes the shard in this bag slot (without the cursor);
-- returns "deleted" (sent to the server), "blocked" (the game refused) or "skipped"
local function DeleteSlot(entry)
	if C_Container.GetContainerItemID(entry.bag, entry.slot) ~= SOUL_SHARD then
		return "skipped"
	end
	local location = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
	if not (location and location:IsValid() and C_Item.DoesItemExist(location)) then
		return "skipped"
	end
	local guid = C_Item.GetItemGUID(location)
	if not guid or pending[guid] then
		return "skipped" -- already on its way out
	end
	refused = false
	local ok = pcall(C_Item.DeleteItem, guid)
	if not ok or refused then
		return "blocked"
	end
	pending[guid] = true
	C_Timer.After(3, function() pending[guid] = nil end) -- in case the bags never update
	return "deleted"
end

-- deletes one extra shard: deleting straight from the bag is allowed once per key press, and a second
-- try in the same press is blocked (ADDON_ACTION_BLOCKED); returns how many were deleted, how many extras
-- are left, and whether the game refused it
local function DestroyExtras()
	if busy or InCombatLockdown() or not db then
		return 0, 0, false
	end
	if next(pending) then
		-- deletes still on their way: the bags count them until they update, so wait for that
		return 0, extraShards, false
	end
	local slots = ShardSlots()
	local total = 0
	for _, entry in ipairs(slots) do
		total = total + entry.count
	end
	local extra = total - db.keep
	local deleted, blocked = 0, false
	busy = true
	-- from the back of the list, so the first shards (soul bags first) are the ones kept
	for i = #slots, 1, -1 do
		local entry = slots[i]
		if extra <= 0 or deleted >= 1 then
			break
		end
		if not entry.locked and entry.count <= extra then
			local okCall, result = pcall(DeleteSlot, entry)
			if not okCall then result = "skipped" end
			if result == "deleted" then
				extra = extra - entry.count
				deleted = deleted + entry.count
			elseif result == "blocked" then
				blocked = true
				break
			end
		end
	end
	busy = false
	extraShards = math.max(extra, 0)
	return deleted, extraShards, blocked
end

-- /shards
local function RunNow()
	if InCombatLockdown() then
		Print("not in combat")
		return
	end
	local deleted, left, blocked = DestroyExtras()
	if deleted > 0 then
		Print("destroyed " .. Plural(deleted) .. (left > 0 and (", " .. left .. " more: " ..
			(db.auto and "they go with your next key presses" or "type /shards again")) or (", keeping " .. db.keep)))
	elseif blocked then
		Print("the game refused to destroy the shard")
	elseif CountShards() <= db.keep then
		Print("you have " .. Plural(CountShards()) .. ", nothing to destroy (keeping " .. db.keep .. ")")
	else
		Print("couldn't destroy any right now, try again in a moment")
	end
end

-- the next key press out of combat destroys the extras (the key itself still works as usual)
keyWatcher = CreateFrame("Frame", "XNShardsKeyWatcher", UIParent)
keyWatcher:Hide() -- only shown while there are shards to destroy, so it sees no keys otherwise
keyWatcher:SetScript("OnKeyDown", function()
	if not (db and db.auto) or extraShards <= 0 or InCombatLockdown() then
		return
	end
	local deleted, left, blocked = DestroyExtras()
	if deleted > 0 then
		destroyedByKeys = destroyedByKeys + deleted
		if left <= 0 then
			Print("destroyed " .. Plural(destroyedByKeys) .. ", keeping " .. db.keep)
			destroyedByKeys = 0
		end
	end
	UpdateWatcher()
	if blocked then
		db.auto = false
		UpdateWatcher()
		Print("the game won't let XNShards destroy shards on a key press, so that's off now. Type /shards instead.")
	end
end)

local function WatchKeys()
	if InCombatLockdown() then
		return -- keyboard propagation can't be changed in combat: done after it
	end
	keyWatcher:EnableKeyboard(true)
	keyWatcher:SetPropagateKeyboardInput(true) -- every key still reaches the game
	keyWatcher.watching = true
	UpdateWatcher()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == "XNShards" then
		XNShardsDB = XNShardsDB or {}
		db = XNShardsDB
		db.needsKeyPress = nil -- from version 1.0
		db.onePerPress = nil -- from version 1.1
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then
				db[key] = value
			end
		end
	elseif event == "PLAYER_LOGIN" then
		UpdateCount()
		WatchKeys()
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCount()
		if not keyWatcher.watching then
			WatchKeys()
		end
		UpdateWatcher()
	elseif event == "BAG_UPDATE_DELAYED" then
		wipe(pending)
		UpdateCount()
		UpdateWatcher()
	elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and ... == "XNShards" then
		refused = true
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

SLASH_XNSHARDS1 = "/shards"
SLASH_XNSHARDS2 = "/xnshards"
SlashCmdList.XNSHARDS = function(input)
	local command, value = strsplit(" ", strtrim(input or ""):lower(), 2)
	if command == "keep" and tonumber(value) then
		db.keep = math.max(0, math.floor(tonumber(value)))
		UpdateCount()
		UpdateWatcher()
		Print("keeping " .. Plural(db.keep))
	elseif command == "auto" then
		db.auto = not db.auto
		UpdateWatcher()
		Print("destroying on your next key press: " .. (db.auto and "on" or "off"))
	elseif command == "reset" then
		db.onePerPress = nil -- from version 1.1
		db.auto = true
		UpdateWatcher()
		Print("destroying on your next key press: on again")
	elseif command == "help" then
		Print("/shards - destroy the extra shards now")
		Print("/shards keep <number> - how many to keep (now " .. db.keep .. ")")
		Print("/shards auto - destroy them on your next key press (now " .. (db.auto and "on" or "off") .. ")")
		Print("/shards reset - turn destroying on a key press back on after the game refused it")
	else
		RunNow()
	end
end
