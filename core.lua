local bdlc, l, f = select(2, ...):unpack()

local AceComm = LibStub:GetLibrary("AceComm-3.0")

----------------------------------------
-- StartSession
----------------------------------------
function bdlc:startSession(itemLink,num)
	local itemString = string.match(itemLink, "item[%-?%d:]+")
	if (not itemString) then return end
	local itemType, itemID, enchant, gem1, gem2, gem3, gem4, suffixID, uniqueID, level, specializationID, upgradeId, instanceDifficultyID, numBonusIDs, bonusID1, bonusID2, upgradeValue = strsplit(":", itemString)
	
	if (GetItemInfo(itemLink)) then
		local itemUID = bdlc:GetItemUID(itemLink)
		bdlc.itemMap[itemUID] = itemLink

		bdlc.item_drops[itemLink] = bdlc.item_drops[itemLink] or num
		if (not num) then num = bdlc.item_drops[itemLink] or 1 end
	
		local isTier = bdlc:IsTier(itemLink)
		local equipSlot = select(9, GetItemInfo(itemLink))
		local isRelic = bdlc:IsRelic(itemLink)
		
		if (not bdlc.loot_sessions[itemUID] and ((equipSlot and string.len(equipSlot) > 0) or isTier or isRelic)) then
			bdlc:debug("Starting session for "..itemLink)
			bdlc.loot_sessions[itemUID] = itemUID 
			bdlc.loot_want[itemUID] = {} -- will be used to track loot log and also refresh sessions if someone relogs

			if (bdlc:inLC()) then
				bdlc.loot_council_votes[itemUID] = {}
				bdlc:createVoteWindow(itemUID, num)
				f.voteFrame.enchanters:Show()
			end

			bdlc:createRollWindow(itemUID,num)
		end
	else
		bdlc.items_waiting[itemID] = {itemLink,num}
		local name = GetItemInfo(itemLink)
	end
end
----------------------------------------
-- EndSession
----------------------------------------
function bdlc:endSession(itemUID)
	local itemLink = bdlc.itemMap[itemUID]

	if not itemLink then return end

	bdlc:endTab(itemUID)
	bdlc:endRoll(itemUID)

	bdlc.item_drops[itemLink] = nil
	bdlc.loot_sessions[itemUID] = nil
	bdlc.loot_council_votes[itemUID] = nil
	bdlc.loot_want[itemUID] = nil
	
	bdlc:repositionFrames()
end

----------------------------------------
-- StartMockSession
----------------------------------------
function bdlc:startMockSession()
	bdlc:debug("Starting mock session")

	local demo_samples = {
		classes = {"HUNTER","WARLOCK","PRIEST","PALADIN","MAGE","ROGUE","DRUID","WARRIOR","DEATHKNIGHT","MONK","DEMONHUNTER"},
		ranks = {"Officer","Raider","Trial","Social","Alt","Officer Alt","Guild Idiot", "King"},
		names = {"OReilly", "Billy", "Tìncan", "Mango", "Ugh", "Onebutton", "Thor", "Deadpool", "Atlas", "Edgelord", "Yeah", "Arranum", "Witts"}
	}
	
	local function rando_name()
		return demo_samples.names[math.random(#demo_samples.names)]
	end
	local function rando_ilvl()
		return math.random(900, 980)
	end
	local function rando_rank()
		return demo_samples.ranks[math.random(#demo_samples.ranks)]
	end
	local function rando_class()
		return demo_samples.classes[math.random(#demo_samples.classes)]
	end
	
	-- add random people, up to a whole raid worth of fakers
	local demo_players = {}
	for i = 5, math.random(6, 30) do
		demo_players[rando_name()] = {rando_ilvl(), rando_rank(), rando_class()}
	end
	
	-- fake build an LC
	bdlc:buildLC()
	local itemslots = {1,2,3,5,8,9,10,11,12,13,14,15}
	bdlc.item_drops = {}
	for i = 1, 4 do
		local index = itemslots[math.random(#itemslots)]
		bdlc.item_drops[GetInventoryItemLink("player", index)] = math.random(1,4)
		table.remove(itemslots,index)
	end

	-- now lets start fake sessions
	for k, v in pairs(bdlc.item_drops) do
		local itemUID = bdlc:GetItemUID(k)
		bdlc:sendAction("startSession", k, v);

		-- add our demo players in 
		for name, data in pairs(demo_players) do
			bdlc:sendAction("addUserConsidering", itemUID, name, unpack(data));
		end

		-- send a random "want" after 2-5s, something like a real person
		C_Timer.After(math.random(2, 5), function()
			for name, data in pairs(demo_players) do
				bdlc:sendAction("addUserWant", itemUID, name, math.random(1, 4), 0, 0);
			end
		end)
	end
end

----------------------------------------
-- CreateVoteWindow
----------------------------------------
function bdlc:createVoteWindow(itemUID,num)
	local itemLink = bdlc.itemMap[itemUID]
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
	
	f.voteFrame:Show()
	
	local currenttab = bdlc:getTab(itemUID)
	
	-- Set Up tab and item info
	currenttab:Show()
	currenttab.icon:SetTexture(texture)
	currenttab.table.item.itemtext:SetText(itemLink)
	if (num > 1) then
		currenttab.table.item.num_items:SetText("x"..num)
		currenttab.table.item.num_items:SetTextColor(0,1,0)
	else
		currenttab.table.item.num_items:SetText("")
		currenttab.table.item.num_items:SetTextColor(1,1,1)
	end
	currenttab.table.item.icon.tex:SetTexture(texture)

	local ilvl, wf_tf, socket, infostr = bdlc:GetItemValue(itemLink)
	currenttab.wfsock:SetText(infostr)
	currenttab.table.item.wfsock:SetText(infostr)

	bdlc:updateVotesRemaining(itemUID, FetchUnitName('player'))
	--[[if (wf_tf or socket) then
		currenttab.wfsock:SetText(infostr)
		currenttab:SetBackdropBorderColor(0,.7,0,1)
		currenttab.table.item.wfsock:SetText(infostr)
		currenttab.table.item.icon:SetBackdropBorderColor(0,.7,0,1)
	else
		currenttab.wfsock:SetText("")
		currenttab:SetBackdropBorderColor(0,0,0,1)
		currenttab.table.item.wfsock:SetText("")
		currenttab.table.item.icon:SetBackdropBorderColor(0,0,0,1)
	end--]]
	local slotname = string.lower(string.gsub(equipSlot, "INVTYPE_", ""));
	slotname = slotname:gsub("^%l", string.upper)
	currenttab.table.item.itemdetail:SetText("ilvl: "..iLevel.."    "..subclass..", "..slotname);
	currenttab.table.item:SetScript("OnEnter", function()
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end)
	currenttab.table.item:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	
	
	bdlc:repositionFrames()
end

----------------------------------------
-- CreateRollWindow
----------------------------------------
function bdlc:createRollWindow(itemUID,num)
	local itemLink = bdlc.itemMap[itemUID]
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
	rollFrame:Show()
	
	local currentroll = bdlc:getRoll(itemUID)

	currentroll:Show()
	currentroll.item.icon.tex:SetTexture(texture)
	currentroll.item.item_text:SetText(itemLink)
	if (num > 1) then
		currentroll.item.num_items:SetText("x"..num)
		currentroll.item.num_items:SetTextColor(0,1,0)
	else
		currentroll.item.num_items:SetText("")
		currentroll.item.num_items:SetTextColor(1,1,1)
	end
	--currentroll.item.item_ilvl:SetText("ilvl: "..iLevel)
	
	-- custom quick notes
	for i = 1, 10 do
		currentroll.buttons.note.quicknotes[i]:SetText("")
		currentroll.buttons.note.quicknotes[i]:Hide()
		currentroll.buttons.note.quicknotes[i]:SetAlpha(0.6)
		currentroll.buttons.note.quicknotes[i].selected = false
	end
	local ml_qn = {}
	for k, v in pairs(bdlc.master_looter_qn) do
		table.insert(ml_qn, k)
	end
	table.sort(ml_qn)
	for k, v in pairs(ml_qn) do
		local qn
		for i = 1, 10 do
			local rqn = currentroll.buttons.note.quicknotes[i]
			if (not rqn:IsShown()) then
				qn = rqn
				break
			end
		end
		qn:Show()
		qn:SetText(v)
		bdlc:skinButton(qn,false)
	end

	local ilvl, wf_tf, socket, infostr = bdlc:GetItemValue(itemLink)
	currentroll.item.icon.wfsock:SetText(infostr)

	currentroll.item:SetScript("OnEnter", function()
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end)
	currentroll.item:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	
	local guildRank = select(2,GetGuildInfo("player")) or ""
	local player_itemlvl = math.floor(select(2, GetAverageItemLevel()))
	
	if bdlc:itemEquippable(itemUID) then
		bdlc:debug("turns out I can use this, doing nothing.")
		bdlc:sendAction("addUserConsidering", itemUID, bdlc.local_player, player_itemlvl, guildRank);
	else
		bdlc:debug("I guess I can't use this, autopassing")
		local itemLink1, itemLink2 = bdlc:fetchUserGear("player", itemLink)
		
		--bdlc:sendAction("removeUserConsidering", itemUID, bdlc.local_player);
		bdlc:endRoll(itemUID)
	end
	bdlc:repositionFrames()
	
end

----------------------------------------
-- RemoveUserRoll
----------------------------------------
function bdlc:removeUserRoll(itemUID, playerName)
	local playerName = FetchUnitName(playerName)
	if (FetchUnitName('player') == playerName) then
		bdlc:endRoll(itemUID)
		bdlc:repositionFrames()
	end
end

----------------------------------------
-- AddUserConsidering
----------------------------------------
function bdlc:addUserConsidering(itemUID, playerName, iLvL, guildRank, playerClass)
	local playerName = FetchUnitName(playerName)
	local itemLink = bdlc.itemMap[itemUID]
	
	if not bdlc:inLC() then return false end
	if (not bdlc.loot_sessions[itemUID]) then return false end

	local currententry = bdlc:getEntry(itemUID, playerName)
	if (not currententry) then return end

	currententry.wantLevel = 15
	currententry.notes = ""
	
	local itemName, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
	local name, server = strsplit("-", playerName)

	local classFileName = select(2, UnitClass(name)) or select(2, UnitClass(playerName)) or playerClass or demo_samples.classes[math.random(#demo_samples.classes)]
	local color = RAID_CLASS_COLORS[classFileName]
	name = GetUnitName(name, true) or name
	
	currententry:Show()
	currententry.name:SetText(name)
	currententry.server = server
	currententry.name:SetTextColor(color.r,color.g,color.b);
	currententry.interest:SetText("considering...");
	currententry.interest:SetTextColor(.5,.5,.5);
	currententry.rank:SetText(guildRank)
	currententry.ilvl:SetText(iLvL)
	currententry.gear1:Hide()
	currententry.gear2:Hide()
	
	if (IsMasterLooter() or not IsInRaid()) then
		currententry.removeUser:Show()
	else
		currententry.removeUser:Hide()
	end

	bdlc:repositionFrames()
end

----------------------------------------
-- RemoveUserConsidering
----------------------------------------
function bdlc:removeUserConsidering(itemUID, playerName)
	local playerName = FetchUnitName(playerName)

	if (not bdlc:inLC()) then return end
	-- reset frame
	bdlc:endEntry(itemUID, playerName)

	-- stop if no session exists
	if (not bdlc.loot_sessions[itemUID]) then return false end

	-- reset votes
	if (bdlc.loot_council_votes[itemUID]) then
		for council, tab in pairs(bdlc.loot_council_votes[itemUID]) do
			for v = 1, #bdlc.loot_council_votes[itemUID][council] do
				if (bdlc.loot_council_votes[itemUID][council][v] == playerName) then
					bdlc.loot_council_votes[itemUID][council][v] = false
				end
			end
		end

		bdlc:updateVotesRemaining(itemUID, FetchUnitName("player"))
	end

	-- tell that user to kill their roll window
	bdlc.overrideChannel = "WHISPER"
	bdlc.overrideSemder = playerName
	bdlc:sendAction("removeUserRoll", itemUID, playerName);
	bdlc.loot_want[itemUID][playerName] = nil
	
	bdlc:repositionFrames()

	--local itemLink = bdlc.itemMap[itemUID]
	--if (not itemLink) then return end
	
	bdlc:debug("removed "..playerName.." considering "..itemUID)
end

--[[
function bdlc:addUserItem(itemUID, playerName, itemLink)
	local currententry = bdlc:getEntry(itemUID, playerName)
	if (not currententry) then return end

	
end--]]

----------------------------------------
-- AddUserWant
----------------------------------------
function bdlc:addUserWant(itemUID, playerName, want, itemLink1, itemLink2, notes)
	local playerName = FetchUnitName(playerName)
	if (not notes) then notes = false end
	local itemLink = bdlc.itemMap[itemUID]

	if (not bdlc.loot_sessions[itemUID]) then bdlc:debug(playerName.." rolled on an item with no session") return end
	if (not bdlc:inLC()) then return false end
	
	-- actual want text
	local currententry = bdlc:getEntry(itemUID, playerName)
	if (not currententry) then return end

	bdlc.loot_want[itemUID][playerName] = {itemUID, playerName, want, itemLink1, itemLink2, notes}
	
	local wantText = bdlc.wantTable[want][1]
	local wantColor = bdlc.wantTable[want][2]
	
	bdlc:debug(playerName.." needs "..itemLink.." "..wantText)
	
	currententry.interest:SetText(wantText);
	currententry.interest:SetTextColor(unpack(wantColor));
	currententry.voteUser:Show()
	currententry.wantLevel = want

	-- player items
	if (GetItemInfo(itemLink1)) then
		local itemName, link1, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture1, vendorPrice = GetItemInfo(itemLink1)
		currententry.gear1:Show()
		currententry.gear1.tex:SetTexture(texture1)
		currententry.gear1:SetScript("OnEnter", function()
			ShowUIPanel(GameTooltip)
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link1)
			GameTooltip:Show()
		end)
		currententry.gear1:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		local itemID = select(2, strsplit(":", itemLink1))
		if (itemID) then
			bdlc.player_items_waiting[itemID] = {itemLink1, currententry.gear1}
		end
	end

	if (GetItemInfo(itemLink2)) then
		local itemName, link1, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture1, vendorPrice = GetItemInfo(itemLink2)
		currententry.gear2:Show()
		currententry.gear2.tex:SetTexture(texture1)
		currententry.gear2:SetScript("OnEnter", function()
			ShowUIPanel(GameTooltip)
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link1)
			GameTooltip:Show()
		end)
		currententry.gear2:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		local itemID = select(2, strsplit(":", itemLink2))
		if (itemID) then
			bdlc.player_items_waiting[itemID] = {itemLink2, currententry.gear2}
		end
	end
	
	bdlc:repositionFrames()

	-- notes
	bdlc:debug("Add "..playerName.." notes")

	if (notes and string.len(notes) > 0) then
		currententry.notes = notes
		currententry.user_notes:Show()
	end
end

----------------------------------------
-- AddUserNotes
----------------------------------------
--[[
function bdlc:addUserNotes(itemUID, playerName, notes)
	local playerName = FetchUnitName(playerName)

	bdlc:debug("Add "..playerName.." notes")

	if (not bdlc.loot_sessions[itemUID]) then return end
	if not bdlc:inLC() then return end
	
	local currententry = bdlc:getEntry(itemUID, playerName)

	if (not currententry) then return end
	
	currententry.notes = notes
	currententry.user_notes:Show()
end--]]

----------------------------------------
-- UpdateUserItem
----------------------------------------
function bdlc:updateUserItem(itemLink, frame)
	local texture = select(10, GetItemInfo(itemLink))
	frame:Show()
	frame.tex:SetTexture(texture)
	frame:SetScript("OnEnter", function()
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

----------------------------------------
-- TakeWhisperEntry
----------------------------------------

function bdlc:takeWhisperEntry(msg, sender)
	--[[msg = string.lower(msg)
	if (string.find(msg, "!bdlc")) then
		local itemLink = string.match(msg,"(\124c%x+\124Hitem:.-\124h\124r)")
		local s2, e2 = string.find(msg,"(\124c%x+\124Hitem:.-\124h\124r)")
		local wantlevel = strtrim(string.sub(msg, e2+2))
		local raidIndex = 0
		local name, server = strsplit("-", sender)
		--local findserver = select(1, string.find(sender, "-"))
		--sender = string.sub(sender, 0, findserver-1)
	
		if (bdlc.loot_sessions[itemLink]) then
			for r = 1, GetNumGroupMembers() do
				local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(r)
				if (name == sender) then
					raidIndex = r
				end
			end
			
			local wantTable = {
				["need"] = 1,
				["bis"] = 1,
				["mainspec"] = 1,
				["main"] = 1,
				["minor"] = 2,
				["sidegrade"] = 2,
				["off"] = 3,
				["offspec"] = 3,
				["rr"] = 4,
				["reroll"] = 4,
				["transmog"] = 5,
				["xmog"] = 5,
				["mog"] = 5,
			}
			local want = wantTable[wantLevel]
		
			local itemID = select(2, strsplit(":", itemLink))
			
			NotifyInspect("raid"..raidIndex)
			InspectUnit("raid"..raidIndex)
			local itemLink1, itemLink2 = bdlc:fetchUserGear("raid"..raidIndex, itemLink)
			local guildRank = select(2, GetGuildInfo("raid"..raidIndex))
			local ilvl = getUnitItemLevel("raid"..raidIndex)
			local inspectwait = CreateFrame("frame", nil)
			local total = 0
			inspectwait:SetScript("OnUpdate", function(self, elapsed)
				total = total + elapsed
				if (total > 1) then
					total = 0
					inspectwait:SetScript("OnUpdate", function() return end)
					guildRank = select(2, GetGuildInfo(sender)) or ""
					itemLink1, itemLink2 = bdlc:fetchUserGear("raid"..raidIndex, itemLink)
					ilvl = getUnitItemLevel("raid"..raidIndex)
					
					print(itemLink1)
					print(itemLink2)
					
					bdlc:sendAction("addUserConsidering", itemLink, raidIndex, ilvl, guildRank);
					bdlc:sendAction("addUserWant", itemID, raidIndex, 1, itemLink1, itemLink2);
					
					ClearInspectPlayer()
				end
			end)
			
			
		end
	end--]]
end

----------------------------------------
--[[ VoteForUser
	voting for multiple users... hmmm

	why is this so hard to wrap my head around
--]]
----------------------------------------
function bdlc:updateVotesRemaining(itemUID, councilName)
	if (councilName ~= FetchUnitName('player')) then return end

	local itemLink = bdlc.itemMap[itemUID]
	local numvotes = bdlc.item_drops[itemLink]
	local currentvotes = 0;
	local color = "|cff00FF00"
	local tab = bdlc:getTab(itemUID)

	if (bdlc.loot_council_votes[itemUID][councilName]) then
		for v = 1, numvotes do
			if (bdlc.loot_council_votes[itemUID][councilName][v]) then
				currentvotes = currentvotes + 1
			end
		end
		
		if (numvotes-currentvotes == 0) then
			color = "|cffFF0000"
		end
	end
	tab.table.numvotes:SetText("Your Votes Remaining: "..color..(numvotes-currentvotes).."|r")
	for t = 1, #f.tabs do
		if (f.tabs[t].itemUID == itemUID) then
			local tab = f.tabs[t]

			for e = 1, #f.entries[t] do
				local entry = f.entries[t][e]
				if (numvotes-currentvotes == 0) then
					if (entry.voteUser:GetText() == l['frameVote']) then
						bdlc:skinButton(entry.voteUser,true,'dark')
					else
						bdlc:skinButton(entry.voteUser,true,'blue')
					end
				else
					bdlc:skinButton(entry.voteUser,true,'blue')
				end
			end

			break
		end
	end

end
function bdlc:voteForUser(councilName, itemUID, playerName, lcl)
	if (not bdlc.loot_sessions[itemUID]) then return false end
	if (not bdlc.loot_council_votes[itemUID]) then return false end
	if not bdlc:inLC() then return false end

	local playerName = FetchUnitName(playerName)

	if (not lcl and FetchUnitName('player') == councilName) then return end
	local itemLink = bdlc.itemMap[itemUID]
	local numvotes = bdlc.item_drops[itemLink]
	local votes = bdlc.loot_council_votes[itemUID]

	-- if they haven't voted yet, then give them # votes
	if (not votes[councilName]) then
		votes[councilName] = {}
		for v = 1, numvotes do
			votes[councilName][v] = false
		end
	end

	-- only let them vote for each player once
	local hasVotedForPlayer = false
	for v = 1, numvotes do
		if (votes[councilName][v] == playerName) then hasVotedForPlayer = v break end
	end
		
	if (hasVotedForPlayer) then
		votes[councilName][hasVotedForPlayer] = false
		if (FetchUnitName('player') == councilName) then
			local entry = bdlc:getEntry(itemUID, playerName)
			entry.voteUser:SetText(l["frameVote"])
		end
	else
		-- disable rolling votes? limit at # here
		local currentvotes = 0;
		for v = 1, numvotes do
			if (votes[councilName][v]) then
				currentvotes = currentvotes + 1
			end
		end

		if (currentvotes < numvotes) then
			-- reset the table
			local new = {}
			new[1] = false -- reserve pos 1
			for v = 1, numvotes do
				if (votes[councilName][v]) then -- correct any table key gaps
					new[#new+1] = votes[councilName][v]
				end
			end
			votes[councilName] = new -- reset the tables keys

			-- remove the least recent vote
			if (FetchUnitName('player') == councilName) then
				local entry = bdlc:getEntry(itemUID, votes[councilName][numvotes+1])
				entry.voteUser:SetText(l["frameVote"])
			end
			votes[councilName][numvotes+1] = nil 

			votes[councilName][1] = playerName -- prepend the vote
			if (FetchUnitName('player') == councilName) then
				local entry = bdlc:getEntry(itemUID, playerName)
				entry.voteUser:SetText(l["frameVoted"])
			end
		end

	end
	bdlc:updateVotesRemaining(itemUID, councilName)

	-- now loop through and tally
	for itemUID, un in pairs(bdlc.loot_sessions) do
		for t = 1, #f.tabs do
			if (f.tabs[t].itemUID == itemUID) then
				for e = 1, #f.entries[t] do
					local entry = f.entries[t][e]
					if (entry.itemUID) then
						local votes = 0
						for council, v in pairs(bdlc.loot_council_votes[itemUID]) do
							for v = 1, numvotes do
								if bdlc.loot_council_votes[itemUID][council][v] == entry.playerName then
									votes = votes + 1
								end
							end
						end
						entry.votes.text:SetText(votes)
					end

				end
			end
		end
	end

end

--[[
function bdlc:fetchSessions()
	if (IsMasterLooter()) then
		if (GetNumLootItems() > 0) then
			bdlc:parseLoot()
		else
			for itemUID, v in pairs(bdlc.loot_sessions) do
				local itemLink = bdlc.itemMap[itemUID]
				local num = bdlc.item_drops[itemLink]
				
				if (not num) then return end
				
				bdlc:sendAction("startSession", itemLink, num);
				
				for playerName, data in pairs(bdlc.loot_want[itemUID]) do
					bdlc:sendAction("addUserWant", data[1], data[2], data[3], data[4], data[5]);
				end
				
				for playerName, data in pairs(bdlc.loot_considering[itemUID]) do
					bdlc:sendAction("addUserConsidering", data[1], data[2], data[3], data[4]);
				end
			end
		end
	end
end--]]

function bdlc:parseLoot()
	f.voteFrame.enchanters:Show()
	bdlc.loot_slots = {}
	bdlc.item_drops = {}
	for slot = 1, GetNumLootItems() do
		local texture, item, quantity, quality, locked = GetLootSlotInfo(slot)

		if (quality and quality > 3) then
			local itemLink = GetLootSlotLink(slot)
			bdlc.loot_slots[slot] = itemLink

			bdlc.item_drops[itemLink] = bdlc.item_drops[itemLink] or 0
			bdlc.item_drops[itemLink] = bdlc.item_drops[itemLink] + 1
		end
	end
	for k, v in pairs(bdlc.item_drops) do
		bdlc:sendAction("startSession", k, v);
	end
end


-- logging where loot has gone
function bdlc:addLootHistory(itemUID, playerName, enchanter)
	local playerName = FetchUnitName(playerName)
	if not(playerName) then return end

	-- fetch some data
	local itemUID, playerName, want, itemLink1, itemLink2, notes = unpack(bdlc.loot_want[itemUID][playerName])
	local itemLink = bdlc.itemMap(itemUID)

	-- compile the entry
	local data = {itemLink, itemUID, playerName, want, itemLink1, itemLink2, notes, time(), enchanter}
	
	-- get unqiue index of day/time
	local today = date("%m/%d/%Y")
	local hour, minute = GetGameTime()
	local t = hour..":"..minute

	-- setup our tables
	bdlc_history[today] = bdlc_history[today] or {}
	bdlc_history[today][t] = bdlc_history[today][t] or {}
	
	-- log the history
	table.insert(bdlc_history[today][t], data)
end

function bdlc:mainCallback(data)

	local method, partyMaster, raidMaster = GetLootMethod()
	if (method == "master" or not IsInRaid()) then
		
		local param = bdlc:split(data,"><")
		local action = param[0] or data
		if (param[0]) then param[0] = nil end

		-- the numbers were made strings by the chat_msg_addon, lets find our numbers and convert them tonumbers
		for p = 0, #param do
			local test = param[p]
			if (tonumber(test)) then
				param[p] = tonumber(param[p])
			end
			if (test == nil or test == "") then
				param[p] = ""
			end
		end

		-- auto methods have to force a self param
		if (bdlc[action]) then
			if (param and unpack(param)) then -- if params arne't blank
				bdlc[action](self, unpack(param))
			else
				bdlc[action](self)
			end
		else
			--bdlc.print("Can't find any function for "..action.." - this usually means someone is out of date");
		end
	end
end

bdlc:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
	if (event == "ADDON_LOADED" and (arg1 == "BigDumbLootCouncil" or arg1 == "bigdumblootcouncil")) then
		bdlc:UnregisterEvent("ADDON_LOADED")
		-------------------------------------------------------
		--- Register necessary events
		-------------------------------------------------------
		bdlc:RegisterEvent("LOOT_SLOT_CLEARED");
		bdlc:RegisterEvent("LOOT_OPENED");
		bdlc:RegisterEvent("LOOT_CLOSED");
		bdlc:RegisterEvent('GET_ITEM_INFO_RECEIVED')
		bdlc:RegisterEvent('CHAT_MSG_ADDON')
		bdlc:RegisterEvent('GROUP_ROSTER_UPDATE')
		bdlc:RegisterEvent('CHAT_MSG_WHISPER')
		bdlc:RegisterEvent('PARTY_LOOT_METHOD_CHANGED')
		bdlc:RegisterEvent('PLAYER_ENTERING_WORLD')
		
		LoadAddOn("Blizzard_ArtifactUI")
		
		-- force load player items
		for i = 1, 19 do
			local link = GetInventoryItemLink("player", i)
		end
		SocketInventoryItem(17)
		SocketInventoryItem(16)
		HideUIPanel(ArtifactFrame)
		
		--------------------------------------------------------------------------------
		-- Load configuration or set bdlc.defaults
		--------------------------------------------------------------------------------
		print("|cff3399FFBig Dumb Loot Council|r loaded. /bdlc for options")
		--RegisterAddonMessagePrefix(bdlc.message_prefix);
		AceComm:RegisterComm(bdlc.message_prefix, function(prefix, text, channel, sender) bdlc:mainCallback(text) end)

		bdlc_config = bdlc_config or bdlc.defaults
		bdlc_history = bdlc_history or {}
		for k, v in pairs(bdlc.defaults) do
			if (bdlc_config[k] == nil) then
				bdlc_config[k] = v
			end
		end
		
		--------------------------------------------------------------------------------
		-- Set up slash commands
		--------------------------------------------------------------------------------
		SLASH_BDLC1 = "/bdlc"
		bdlc_config_toggle = false
		SlashCmdList["BDLC"] = function(origmsg, editbox)
			origmsg = strtrim(origmsg)
			local param = bdlc:split(origmsg," ")
			local msg = param[0] or origmsg;
			if (msg == "" or msg == " ") then
				bdlc.print("Options:")
				print("  /bdlc test - Tests the addon (must be in raid)")
				print("  /bdlc config - Shows the configuration window")
				print("  /bdlc show - Shows the vote window (if you're in the LC)")
				print("  /bdlc hide - Hides the vote window (if you're in the LC)")
				print("  /bdlc version - Check the bdlc versions that the raid is using")
				print("  /bdlc addtolc playername - Adds a player to the loot council (if you're the Masterlooter)")
				print("  /bdlc removefromlc playername - Adds a player to the loot council (if you're the Masterlooter)")
			elseif (msg == "version") then
				bdlc:checkVersions()
			elseif (msg == "reset") then
				bdlc_config = bdlc.defaults
				ReloadUI()
			elseif (msg == "start") then
				local s, e = string.find(origmsg, msg)
				local newmsg = strtrim(string.sub(origmsg, e+1))
				
				if (IsMasterLooter() or IsRaidLeader() or not IsInRaid() and strlen(newmsg) > 1) then
					bdlc:debug(newmsg)
					bdlc:sendAction("startSession", newmsg, 1);
				else
					bdlc.print("You must be in the loot council and be either the loot master or the raid leader to do that");
				end
			elseif (msg == "addtolc" or msg == "removefromlc") then
				bdlc:addremoveLC(msg, param[1])
			elseif (msg == "config") then
				if (bdlc_config_toggle) then
					bdlc_config_toggle = false
					bdlcconfig:Hide()
				else
					bdlc_config_toggle = true
					bdlcconfig:Show()
					
				end
			elseif (msg == "test") then
				bdlc:startMockSession()
			elseif (msg == "show" and bdlc:inLC()) then
				f.voteFrame:Show()
			elseif (msg == "hide" and bdlc:inLC()) then
				f.voteFrame:Hide()
			else
				print("/bdlc "..msg.." command not recognized")
			end
		end
	
		bdlc:Config()
	end
	if (IsMasterLooter() or IsRaidLeader() or not IsInRaid()) then
		if (event == "PLAYER_ENTERING_WORLD") then
			bdlc:sendAction("buildLC");
		end
		if (event == "ENCOUNTER_END") then
			bdlc:sendAction("buildLC");
		end
		if (event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LOOT_METHOD_CHANGED") then
			bdlc:sendAction("buildLC");
		end
	end
	
	if (IsMasterLooter() and event == "LOOT_OPENED") then
		bdlc:parseLoot()
	end
	
	-- Auto close sessions when loot is awarded from the body
	if (event == "LOOT_SLOT_CLEARED" and arg1 == bdlc.award_slot) then
		local itemlink = bdlc.loot_slots[arg1]
		if not itemLink then return false end
		
		bdlc.item_drops[itemLink] = bdlc.item_drops[itemLink] - 1
		
		for i = 1, #f.tabs do
			if (f.tabs[i].itemLink == itemLink) then
				f.tabs[i].table.item.num_items:SetText("x"..bdlc.item_drops[itemLink])
			end
		end
		--[[if (bdlc.item_drops[itemLink] == 0) then
			local itemUID = bdlc:GetItemUID(itemLink)
		
			bdlc:sendAction("endSession", itemUID);
			bdlc:endSession(itemUID)
		end--]]
		
		bdlc.award_slot = {}
		bdlc.loot_slots[arg1] = nil
	end
		
	
	-- THIS IS FINISHED DONT TOUCH
	if (event == "GET_ITEM_INFO_RECEIVED") then	
		-- Queue items that are starting sessions
		for k, v in pairs(bdlc.items_waiting) do
			local num1 = tonumber(arg1)
			local num2 = tonumber(k)
			if (num1 == num2) then
				bdlc:startSession(v[1],v[2])
				bdlc.items_waiting[k] = nil
			end
		end
		
		-- Queue items that are showing user's current gear
		for itemID, v in pairs(bdlc.player_items_waiting) do
			local num1 = tonumber(arg1)
			local num2 = tonumber(itemID)
			if (num1 == num2) then
				bdlc:updateUserItem(v[1], v[2])
				bdlc.player_items_waiting[itemID] = nil
			end
		end
	end
end)
