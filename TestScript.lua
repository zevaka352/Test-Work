
--
-- I created two meta tables. 
-- The first one creates chests and keeps them running. 
-- The second one is needed to create a datastore where information about tools will be stored.
--

local ChestMetatable 				= {}
ChestMetatable.__index				= ChestMetatable
ChestMetatable.ClassName			= "ChestMetatable"

local CachedStore 					= {}
CachedStore.__index 				= CachedStore
CachedStore.ClassName 				= "CachedStore"

--
-- This is a list of all variables that will be needed in the future.
--

local Debris 						= game:GetService("Debris")
local TweenService 					= game:GetService("TweenService")
local ReplicatedStorage 			= game:GetService("ReplicatedStorage")
local Players 						= game:GetService("Players")
local DataStoreService 				= game:GetService("DataStoreService")

local Animation 					= script.Animation

local Sounds 						= script.Sounds
local Effects 						= script.Effects
local Tools 						= script.Tools

local eChestOpenEvent 				= ReplicatedStorage:WaitForChild("ChestOpenEvent")

local HOLD_DURATION_TIME = 6
local TWEEN_TIME_ANIMATION = 0.3
local CHEST_OPEN_TWEEN_TIME = 1

local itemsStore

--
-- CreateEffect function creates customizable effects. It is used to create effects for a chest. 
-- Needed for convenience and code optimization.
--

function CreateEffect(effect, part, emit)

	local Attachment				= Instance.new("Attachment")
	Attachment.CFrame 				= part.CFrame
	Attachment.Parent				= workspace.Terrain

	local NewEffect = effect:Clone()
	NewEffect.Enabled = false
	NewEffect.Parent = Attachment

	if emit then
		NewEffect:Emit(emit)
	else
		NewEffect:Emit(1)
	end

	Debris:AddItem(Attachment, effect.Lifetime.Max)

end

--
-- ToolDropped is a feature that works like a wheel of fortune. 
-- The result is a tool that should drop
--

function ToolDropped()

	local ItemsTable = {}

	for _,v in pairs(Tools:GetChildren()) do
		table.insert(ItemsTable, v)
	end

	while true do

		local tool = ItemsTable[math.random(1, #ItemsTable)]

		if tool.Percents.Value <= math.random(1, 100) then
			return tool
		end

	end

end

---
--- DataStoreMetatable
---

--
-- The functions below represent a DataStore that has the ability to store information, load it into roblox databases and manage this database
--

-- Warning: Not all functions in the DataStore are actually used in the script. These functions were written to show experience with databases and metatables

-- CachedStore.new(store) creates a new datastore
function CachedStore.new(store)
	local self 				= setmetatable({}, CachedStore)
	self.store 				= store
	self.cache 				= {}
	self.saveRequests 		= {}
	self.removeRequests 	= {}
	return self
end

-- CachedStore:Remove(player) removes a player's date
function CachedStore:Remove(player)
	player 						= tostring(player.userId)

	self.cache[player] 			= nil
	self.removeRequests[player] = true
	self.saveRequests[player] 	= nil
end

-- CachedStore:Save(player, value) save the player's date
function CachedStore:Save(player, value)
	player 						= tostring(player.userId)

	self.cache[player] 			= value

	self.saveRequests[player] 	= value
	self.removeRequests[player] = nil
end

-- CachedStore:Get(player) gets the date of the player
function CachedStore:Get(player)
	player = tostring(player.userId)

	if not self.cache[player] then
		local success, result = pcall(self.store.GetAsync, self.store, player)
		if success then
			self.cache[player] = result
			return result
		end
	end
	return self.cache[player]
end

-- CachedStore:PushRequests() saves the entire date
function CachedStore:PushRequests()
	for player, remove in pairs(self.removeRequests) do
		pcall(self.store.RemoveAsync, self.store, player)
		self.removeRequests[player] = nil
	end
	for player, value in pairs(self.saveRequests) do
		pcall(self.store.SetAsync, self.store, player, value)
		self.saveRequests[player] = nil
	end
end

-- CachedStore:ClearCache() clears the date table
function CachedStore:ClearCache()
	table.clear(self.cache)
end

-- CachedStore:PushPlayerRequests(player) saves the player's date
function CachedStore:PushPlayerRequests(player)
	player = tostring(player.userId)

	if self.saveRequests[player] then
		pcall(self.store.SetAsync, self.store, player, self.saveRequests[player])
	elseif self.removeRequests[player] then
		pcall(self.store.RemoveAsync, self.store, player)
	end
end


-- Create DataStore

itemsStore 							= DataStoreService:GetDataStore("Items")
ItemsStore							= CachedStore.new(itemsStore)

---
--- ChestMetatable
---

-- GetPlayerStore function that gets the date about the player that was saved in the DataStore.

function GetPlayerStore(player)

	local playerStore = ItemsStore:Get(player)

	return playerStore

end

--
-- The functions below represent a meta-table of chests, which actually creates a class by which all chests work autonomously.
--

-- ChestMetatable.new(model) function that creates a new chest and insists it for further work

function ChestMetatable.new(model)

	local self 						= setmetatable({}, ChestMetatable)

	local Top 						= model:WaitForChild("Top")
	local Chest 					= model:WaitForChild("Chest")

	local ProximityPromt 					= Instance.new("ProximityPrompt")
	ProximityPromt.HoldDuration 			= HOLD_DURATION_TIME
	ProximityPromt.RequiresLineOfSight 		= false
	ProximityPromt.ActionText 				= "Open"
	ProximityPromt.Parent 					= Chest

	local HackingSound 				= Sounds.LockPickSound:Clone()
	HackingSound.Parent 			= Chest

	local WinSound 					= Sounds.WinSound:Clone()
	WinSound.Parent 				= Chest


	self.model 						= model

	self.Top 						= Top
	self.Chest 						= Chest

	self.ProximityPromt 			= ProximityPromt

	self.HackingSound 				= HackingSound
	self.WinSound 					= WinSound

	self.HackingStarted 			= false
	self.HackingAnim 				= nil

	self.connections = {

		self.ProximityPromt.PromptButtonHoldBegan:Connect(function(player)
			self:ChestPromptButtonHoldBegan(player)
		end),

		self.ProximityPromt.PromptButtonHoldEnded:Connect(function(player)
			self:ChestPromptButtonHoldEnded(player)
		end),

		self.ProximityPromt.TriggerEnded:Connect(function(player)
			self:ChestTriggerEnded(player)
		end)

	}

	return self

end

-- The ChestMetatable:ChestPromptButtonHoldBegan(player) function loads animations and sounds if those are not loaded

function ChestMetatable:ChestPromptButtonHoldBegan(player)

	if self.HackingStarted then
		return
	end

	self.HackingStarted = true

	if player.Character then
		if player.Character:FindFirstChild("Humanoid") then

			local humanoid = player.Character:FindFirstChild("Humanoid")

			if self.HackingAnim then
				self.HackingAnim = nil
			end

			self.HackingAnim = humanoid:LoadAnimation(Animation)
			self.HackingAnim:Play(TWEEN_TIME_ANIMATION, true)

		end
	end

	if not self.HackingSound.IsPlaying then
		self.HackingSound:Play()
	end

end

-- ChestMetatable:ChestPromptButtonHoldEnded(player) turns off animations and sounds and stops hacking

function ChestMetatable:ChestPromptButtonHoldEnded(player)

	self.HackingStarted = false

	if self.HackingAnim then
		self.HackingAnim:Stop()
	end

	if self.HackingSound.IsPlaying then
		self.HackingSound:Stop()
	end

end

-- ChestMetatable:ChestTriggerEnded(player) stops and ends all sounds and animations and gives the player a reward 

function ChestMetatable:ChestTriggerEnded(player)

	if self.HackingAnim then
		self.HackingAnim:Stop()
	end

	if self.HackingSound.IsPlaying then
		self.HackingSound:Stop()
	end

	self.HackingStarted = false
	self.ProximityPromt.Enabled = false

	self.WinSound:Play()

	TweenService:Create(self.Top, TweenInfo.new(CHEST_OPEN_TWEEN_TIME), {CFrame = self.model.OpenTop.CFrame}):Play()

	for _,v in pairs(Effects:GetChildren()) do
		CreateEffect(v, self.Chest, 5)
	end

	local WinnerItem = ToolDropped():Clone()

	WinnerItem.Parent = player.Backpack

	local DataPlayerTable = GetPlayerStore(player)

	if not DataPlayerTable then

		local Tab = {}
		table.insert(Tab, WinnerItem.Name)

		ItemsStore:Save(player, Tab)

	else

		table.insert(DataPlayerTable, WinnerItem.Name)
		ItemsStore:Save(player, DataPlayerTable)

	end

	ItemsStore:PushPlayerRequests(player)

	eChestOpenEvent:FireClient(player, WinnerItem.Name)

end

-- searches for all Childrens and activates the function ChestMetatable.new(v)
for _,v in pairs(workspace:WaitForChild("Chests"):GetChildren()) do
	ChestMetatable.new(v)
end

-- function that implements date loading when a player enters and Character appears
Players.PlayerAdded:Connect(function(player: Player)

	player.CharacterAdded:Connect(function()

		local PlayerTable = GetPlayerStore(player)

		if not PlayerTable then
			return
		end

		for _,v in next, PlayerTable do

			if Tools:FindFirstChild(v) then

				local tool = Tools[v]:Clone()
				tool.Parent = player.Backpack

			end

		end
	end)

end)

--[[

comments:

for this particular task, the code could have been cut in half. For example, remove metatables for date and implement them with more primitive metadata. 
But I wanted to show the maximum of my experience in the minimum of lines.

Thank you for watching this. :)

]]--
