--[[ XNShards ]]--

-- Destroys Soul Shards beyond the number you want to keep (2 by default).
--
-- WoW: Forever only lets addons delete items right after a key press, so XNShards deletes during
-- one: the next key you press out of combat (moving counts) destroys the extras, and /shards does
-- it on demand. Only an item on the cursor that is surely a Soul Shard is ever deleted.

local SOUL_SHARD = 6265
local FIRST_BAG, LAST_BAG = 0, NUM_BAG_SLOTS or 4

local DEFAULTS = {
	keep = 2,
	auto = true, -- destroy the extras on your next key press
	onePerPress = false, -- set if the client allows only one delete per key press
}

local db
local extraShards = 0 -- shards above db.keep, counted when the bags change
local busy = false

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

-- picks up the slot and deletes it if the cursor then holds a Soul Shard;
-- returns "deleted", "blocked" (the client refused) or "skipped"
local function DeleteSlot(entry)
	if CursorHasItem() or GetCursorInfo() then
		return "skipped" -- you're holding something: leave the cursor alone
	end
	C_Container.PickupContainerItem(entry.bag, entry.slot)
	local kind, itemID = GetCursorInfo()
	if kind ~= "item" or itemID ~= SOUL_SHARD then
		ClearCursor()
		return "skipped"
	end
	DeleteCursorItem()
	if CursorHasItem() then
		ClearCursor() -- the delete was refused: put the shard back
		return "blocked"
	end
	return "deleted"
end

-- deletes extra shards, all of them or one when the client allows only one per key press;
-- returns how many were deleted, how many extras are left, and whether the client refused one
local function DestroyExtras()
	if busy or InCombatLockdown() or not db then
		return 0, 0, false
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
		if extra <= 0 or (db.onePerPress and deleted >= 1) then
			break
		end
		if not entry.locked and entry.count <= extra then
			local result = DeleteSlot(entry)
			if result == "deleted" then
				extra = extra - entry.count
				deleted = deleted + entry.count
			elseif result == "blocked" then
				blocked = true
				if deleted > 0 and not db.onePerPress then
					db.onePerPress = true -- the first went through, the next didn't
				end
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
		Print("destroyed " .. Plural(deleted) ..
			(left > 0 and (", " .. left .. " more: press again") or (", keeping " .. db.keep)))
	elseif blocked then
		Print("the game refused to destroy the shard")
	elseif CountShards() <= db.keep then
		Print("you have " .. Plural(CountShards()) .. ", nothing to destroy (keeping " .. db.keep .. ")")
	else
		Print("couldn't destroy any: empty your cursor and try again")
	end
end

-- the next key press out of combat destroys the extras (the key itself still works as usual)
local keyWatcher = CreateFrame("Frame", "XNShardsKeyWatcher", UIParent)
keyWatcher:SetScript("OnKeyDown", function()
	if not (db and db.auto) or extraShards <= 0 or InCombatLockdown() then
		return
	end
	local deleted, left, blocked = DestroyExtras()
	if deleted > 0 then
		Print("destroyed " .. Plural(deleted) .. (left > 0 and "" or (", keeping " .. db.keep)))
	elseif blocked then
		db.auto = false
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
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == "XNShards" then
		XNShardsDB = XNShardsDB or {}
		db = XNShardsDB
		db.needsKeyPress = nil -- from version 1.0
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then
				db[key] = value
			end
		end
	elseif event == "PLAYER_LOGIN" then
		WatchKeys()
		UpdateCount()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not keyWatcher.watching then
			WatchKeys()
		end
		UpdateCount()
	elseif event == "BAG_UPDATE_DELAYED" then
		UpdateCount()
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

SLASH_XNSHARDS1 = "/shards"
SLASH_XNSHARDS2 = "/xnshards"
SlashCmdList.XNSHARDS = function(input)
	local command, value = strsplit(" ", strtrim(input or ""):lower(), 2)
	if command == "keep" and tonumber(value) then
		db.keep = math.max(0, math.floor(tonumber(value)))
		UpdateCount()
		Print("keeping " .. Plural(db.keep))
	elseif command == "auto" then
		db.auto = not db.auto
		Print("destroying on your next key press: " .. (db.auto and "on" or "off"))
	elseif command == "reset" then
		db.onePerPress = false
		db.auto = true
		Print("trying several per press and the key press destroying again")
	elseif command == "help" then
		Print("/shards - destroy the extra shards now")
		Print("/shards keep <number> - how many to keep (now " .. db.keep .. ")")
		Print("/shards auto - destroy them on your next key press (now " .. (db.auto and "on" or "off") .. ")")
		Print("/shards reset - try several per press and the key press destroying again")
	else
		RunNow()
	end
end
