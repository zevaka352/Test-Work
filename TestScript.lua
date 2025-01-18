
--
--		this script adds chests that can be broken into and get rewards. It also provides a database that stores all the items.
--


-- Creating metatables --

local ChestMetatable 				= {}
ChestMetatable.__index				= ChestMetatable
ChestMetatable.ClassName			= "ChestMetatable"

local CachedStore 					= {}
CachedStore.__index 				= CachedStore
CachedStore.ClassName 				= "CachedStore"

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

-- Config --
local HOLD_DURATION_TIME = 6
local TWEEN_TIME_ANIMATION = 0.3
local CHEST_OPEN_TWEEN_TIME = 1
--

local itemsStore

local ItemsTable = {}

for _,v in pairs(Tools:GetChildren()) do
	table.insert(ItemsTable, v)
end

function CreateEffect(effect, part, emit)
	
	-- Creating effects for chest --

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
	
	-- Getting Random tool --

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
	-- Creating Data store function
	local self 				= setmetatable({}, CachedStore)
	self.store 				= store
	self.cache 				= {}
	self.saveRequests 		= {}
	self.removeRequests 	= {}
	return self
end

function CachedStore:Save(player, value)
	
	-- Save value in data table -- self.cache[player] --
	
	player 						= tostring(player.userId)

	self.cache[player] 			= value

	self.saveRequests[player] 	= value
	self.removeRequests[player] = nil
end

function CachedStore:Get(player)
	
	-- Get data table -- self.cache[player] --
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

function CachedStore:PushPlayerRequests(player)
	
	-- Push data table in DataStore -- self.cache[player] --
	
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
	
	-- this function getting player data store into CachedStore
	local playerStore = ItemsStore:Get(player)

	return playerStore

end

function ChestMetatable.new(model) -- Create chest metatable

	local self 						= setmetatable({}, ChestMetatable)

	local Top 						= model:WaitForChild("Top")
	local Chest 					= model:WaitForChild("Chest")

	local ProximityPromt 					= Instance.new("ProximityPrompt") -- Create Proximity
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

	self.connections = { -- Create Chest connnections

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

function ChestMetatable:ChestPromptButtonHoldBegan(player) -- Chest Proximity Hold began 

	if self.HackingStarted then
		return
	end

	self.HackingStarted = true

	-- check character --
	if player.Character then
		if player.Character:FindFirstChild("Humanoid") then
			if player.Character.Humanoid:FindFirstChild("Animator") then
				
				if self.HackingAnim then
					self.HackingAnim = nil
				end

				self.HackingAnim = player.Character.Humanoid:LoadAnimation(Animation) -- Load animation
				self.HackingAnim:Play(TWEEN_TIME_ANIMATION, true)

			end
		end
	end

	if not self.HackingSound.IsPlaying then
		self.HackingSound:Play()
	end

end

function ChestMetatable:ChestPromptButtonHoldEnded(player) -- Chest Proximity Hold ended 

	self.HackingStarted = false

	if self.HackingAnim then
		self.HackingAnim:Stop()
	end

	if self.HackingSound.IsPlaying then
		self.HackingSound:Stop()
	end

end

function ChestMetatable:ChestTriggerEnded(player) -- Chest Proximity trigger ended 

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

	for _,v in pairs(Effects:GetChildren()) do -- Create chest effects
		CreateEffect(v, self.Chest, 5)
	end

	local WinnerItem = ToolDropped():Clone() -- Random tool

	WinnerItem.Parent = player.Backpack

	local DataPlayerTable = ChestMetatable.GetPlayerStore(player) -- Get data store

	if not DataPlayerTable then

		local Tab = {}
		table.insert(Tab, WinnerItem.Name)

		ItemsStore:Save(player, Tab) -- save data store

	else

		table.insert(DataPlayerTable, WinnerItem.Name)
		ItemsStore:Save(player, DataPlayerTable)

	end

	ItemsStore:PushPlayerRequests(player) -- Push data store
	
	spawn(function() -- Destroy chest
		task.wait(CHEST_OPEN_TWEEN_TIME)
		self:Destroy()
	end)

end

function ChestMetatable:Destroy() -- Destroy chest

	for i, connection in next, self.connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	
	self.model:Destroy()
	
	setmetatable(self, nil)
	table.clear(self)
	
end

for _,v in pairs(workspace:WaitForChild("Chests"):GetChildren()) do -- Create Chests
	ChestMetatable.new(v)
end


local playerConnections = {}

Players.PlayerAdded:Connect(function(player: Player)

	playerConnections[player] = player.CharacterAdded:Connect(function() -- Create Character connections

		local PlayerTable = ChestMetatable.GetPlayerStore(player)

		if not PlayerTable then
			return
		end

		for _,v in next, PlayerTable do

			if Tools:FindFirstChild(v) then

				local tool = Tools[v]:Clone() -- Create a tool from the name of the item
				tool.Parent = player.Backpack

			end

		end
	end)

end)

Players.PlayerRemoving:Connect(function(player: Player) -- Clear Character connections
	
	if playerConnections[player] then
		
		if playerConnections[player].Connected then
			playerConnections[player]:Disconnect()
		end
		
		playerConnections[player] = nil
	end
	
end)