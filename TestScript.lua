
local ChestMetatable 				= {}
ChestMetatable.__index				= ChestMetatable
ChestMetatable.ClassName			= "ChestMetatable"

local CachedStore 					= {}
CachedStore.__index 				= CachedStore
CachedStore.ClassName 				= "CachedStore"

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

function CachedStore.new(store)
	local self 				= setmetatable({}, CachedStore)
	self.store 				= store
	self.cache 				= {}
	self.saveRequests 		= {}
	self.removeRequests 	= {}
	return self
end


function CachedStore:Remove(player)
	player 						= tostring(player.userId)

	self.cache[player] 			= nil
	self.removeRequests[player] = true
	self.saveRequests[player] 	= nil
end

function CachedStore:Save(player, value)
	player 						= tostring(player.userId)

	self.cache[player] 			= value

	self.saveRequests[player] 	= value
	self.removeRequests[player] = nil
end

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

function CachedStore:ClearCache()
	table.clear(self.cache)
end

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

function ChestMetatable.GetPlayerStore(player)

	local playerStore = ItemsStore:Get(player)

	return playerStore

end

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

function ChestMetatable:ChestPromptButtonHoldEnded(player)

	self.HackingStarted = false

	if self.HackingAnim then
		self.HackingAnim:Stop()
	end

	if self.HackingSound.IsPlaying then
		self.HackingSound:Stop()
	end

end

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

	local DataPlayerTable = ChestMetatable.GetPlayerStore(player)

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

for _,v in pairs(workspace:WaitForChild("Chests"):GetChildren()) do
	ChestMetatable.new(v)
end

Players.PlayerAdded:Connect(function(player: Player)

	player.CharacterAdded:Connect(function()

		local PlayerTable = ChestMetatable.GetPlayerStore(player)

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