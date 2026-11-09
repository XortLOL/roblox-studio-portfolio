--Services
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")
const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")


--Folders
const Remotes = ReplicatedStorage:WaitForChild("Remotes")
const Modules = ReplicatedStorage:WaitForChild("Modules")
const Configs = Modules:WaitForChild("Configs")
const Tools = ServerStorage:WaitForChild("Tools")

--Modules
const ShopGunConfig = require(Configs:WaitForChild("ShopGunConfig"))
const Data = require(script.Parent.Data)

--Remotes
const ToggleWeapon = Remotes:WaitForChild("ToggleWeapon")
const BuyGun = Remotes:WaitForChild("BuyGun")
const GetOwnedGuns = Remotes:WaitForChild("GetOwnedGuns")



local GunShop = {}

local function getGunInfo(name: string)
	for _, info in ShopGunConfig do
		if info.gunName == name then
			return info
		end
	end
	return nil
end

local function ownsGun(player: Player, name: string): boolean
	local inventory = Data:Get(player, "inventory") or {}
	if table.find(inventory, name) then
		return true
	end

	local info = getGunInfo(name)
	if info and info.gamePassId then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.gamePassId)
		if ok and owns then
			return true
		end
	end

	return false
end

local function giveSavedGuns(player: Player, character: Model)
	
	task.wait(0.5) 
	if not player or not player:IsDescendantOf(Players) then return end

	local inventory = Data:Get(player, "inventory") or {}
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	for _, gunName in inventory do
		local tool = Tools:FindFirstChild(gunName)
		if tool and not backpack:FindFirstChild(gunName) and not character:FindFirstChild(gunName) then
			local clone = tool:Clone()
			clone.Parent = backpack
		end
	end
end

function GunShop:Init()


	GetOwnedGuns.OnServerInvoke = function(player: Player)
		return Data:Get(player, "inventory") or {}
	end

	ToggleWeapon.OnServerEvent:Connect(function(player: Player, name: string)
		if not ownsGun(player, name) then return end

		local backpack = player.Backpack
		local character = player.Character

		local existingTool = backpack:FindFirstChild(name) or (character and character:FindFirstChild(name))

		if existingTool then
			existingTool:Destroy()
			return
		end

		local tool = Tools:FindFirstChild(name)
		if not tool then return end

		local clone = tool:Clone()
		clone.Parent = backpack
	end)

	BuyGun.OnServerEvent:Connect(function(player: Player, name: string)
		local info = getGunInfo(name)
		if not info then return end
		if ownsGun(player, name) then return end

		local currentMoney = Data:Get(player, "Money") or 0

		if currentMoney >= info.gunPrice then
			Data:UpdateNumber(player, {"Money"}, -info.gunPrice)

			
			Data:Update(player, {"inventory"}, function(currentInventory)
				local inv = currentInventory or {}
				if not table.find(inv, name) then
					table.insert(inv, name)
				end
				return inv
			end)

			BuyGun:FireClient(player, name)
		end
	end)	

end

return GunShop
