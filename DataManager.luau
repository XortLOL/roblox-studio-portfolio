--Services 
const Players = game:GetService("Players")
const HttpService = game:GetService("HttpService")

--Modules
const ProfileStore = require(script.ProfileStore)
const Signal = require(script.Signal)

--Module start
local DataManager = {} 

DataManager.ChangeCashEvent = Signal.new()

--Types
export type Item = {
	ID: string,
	Name: string,
	Type: string,
}
export type Inventory = {
	{Item}
}

--Settings Values
const ProfileTemplate = {
	Cash = 0 :: number, -- number
	Inv = {} :: Inventory, -- will add something here later
	Another = {} :: any,
}

type ProfileData = typeof(ProfileTemplate)

--KeyName
local PlayerStore = ProfileStore.New("data_v1", ProfileTemplate)

--Sessions
local Profiles: {[Player]: ProfileStore.Profile<ProfileData>} = {}

const function ValidNun(number: number): boolean
	if not number then return false end
	return typeof(number) == "number"
		and number == number
		and number ~= math.huge
		and number ~= -math.huge
		and number == math.floor(number)
		and number >= 0
	
end

const function PlayerAdded(player: Player)
	const ProfileKey = "Player_"..player.UserId :: string
	
	local Profile = PlayerStore:StartSessionAsync(ProfileKey, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	
	if Profile ~= nil then
		Profile:AddUserId(player.UserId)
		Profile:Reconcile()
		
		Profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick("Error with session, please restart the game")
		end)
		
		if player.Parent == Players then
			Profiles[player] = Profile
		else
			Profile:EndSession()
		end
	else
		player:Kick("Game can't load the data, please restart the game")
	end
end

const function PlayerRemoving(player: Player)
	const Profile = Profiles[player]
	
	if Profile ~= nil then
		Profile:EndSession()
		Profiles[player] = nil
	end
end

function DataManager:AddCash(player: Player, amount: number?)
	if not ValidNun(amount) then return end
	
	const Profile = Profiles[player]
	if not Profile then return end
	
	Profile.Data.Cash += amount
	
	DataManager.ChangeCashEvent:Fire(player, amount)
end

function DataManager:SubCash(player: Player, amount: number?)
	if not ValidNun(amount) then return end
	
	const Profile = Profiles[player]
	if not Profile then return end

	Profile.Data.Cash -= amount
	
	DataManager.ChangeCashEvent:Fire(player, -amount)
	
	print(Profile.Data.Cash)
end

function DataManager:AddItem(player: Player, item: {}?): Item
	const Profile = Profiles[player]
	if not Profile then return end
	
	local ItemData = item or {}
	
	local NewItem: Item = {
		ID = HttpService:GenerateGUID(false) :: string,
		Name = (ItemData.Name or "Test") :: string,
		Type = (ItemData.Type or "Basic") :: string,
	}
	table.insert(Profile.Data.Inv, NewItem)
	print(Profile.Data.Inv)
	return NewItem
end

function DataManager:RemoveItem(player: Player, id: string)
	const Profile = Profiles[player]
	if not Profile then return end

	for index, item in Profile.Data.Inv do
		if item.ID == id then
			table.remove(Profile.Data.Inv, index)
			return
		end
	end
end

function DataManager:GetItem(player: Player, id: string): Item?
	const Profile = Profiles[player]
	if not Profile then return end
	
	for _, item in Profile.Data.Inv do
		if item.ID == id then
			return item
		end
	end
	
	return nil
end

function DataManager:BuyItem(player: Player, itemName: string, price: number): (boolean, Item?)
	if not ValidNun(price) then return false end
	
	const Profile = Profiles[player]
	if not Profile then return false end
	
	if Profile.Data.Cash < price then
		return false 
	end
	
	self:SubCash(player, price)
	
	local ok, Item = pcall(function()
		return self:AddItem(player, {Name = itemName})
	end)
	
	if not Item or not ok then
		self:AddCash(player, price)
		return false
	end
	
	return true, Item
end

function DataManager:AddInTable(player: Player, key: keyof<ProfileData>, value: any)
	const Profile = Profiles[player]
	if not Profile then return end
	if not key then error("There is no table", 2) return end
	
	local Table = Profile.Data[key]
	
	if typeof(Table) == "table" then
		table.insert(Table, value)
	else
		error("The table argument is invalid" , 2)
	end
end

function DataManager:RemoveInTable(player: Player, key: keyof<ProfileData>, value: any)
	const Profile = Profiles[player]
	if not Profile then return end
	if not key then error("There is no table", 2) return end
	
	local Table = Profile.Data[key]

	if typeof(Table) == "table" then
		local index = table.find(Table, value)
		if index then
			table.remove(Table, index)
		else
			return nil
		end
	else
		error("The table argument is invalid" , 2)
	end
end

function DataManager:GetData(player: Player): ProfileData?
	const Profile = Profiles[player]
	return if Profile then Profile.Data else nil
end


function DataManager:Init()
	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(PlayerAdded, player)
	end
	
	game:BindToClose(function()
		
		local Sessions = 0
		for player, profile in Profiles do
			Sessions +=1 
			task.spawn(function()
				if profile ~= nil then
					profile:EndSession()
					Profiles[player] = nil
					Sessions -= 1
				end
			end)
		end
		while Sessions > 0 do
			task.wait()
		end
	end)
end

return DataManager
