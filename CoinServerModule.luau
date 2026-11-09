const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Remotes = ReplicatedStorage:WaitForChild("Remotes")
const CoinDropEvent = Remotes:WaitForChild("CoinDropEvent")
const CoinPickupEvent = Remotes:WaitForChild("CoinPickupEvent")
const Data = require(script.Parent.Data)

const LifeTime = 30 
const Distance = 150 

type DropData = {
	owner: Player,
	coinsLeft: number,
	rewardLeft: number,
	deathPosition: Vector3,
}

const activeDrops: { [string]: DropData } = {}

local CoinServerModule = {}
local initialized = false


function CoinServerModule.DropCoins(player: Player, originCFrame: CFrame, amountOfCoins: number, totalReward: number)
	if not player or not originCFrame then return end

	const coinCount = math.floor(amountOfCoins)
	if coinCount <= 0 or totalReward <= 0 then return end 

	const dropId = HttpService:GenerateGUID(false)

	activeDrops[dropId] = {
		owner = player,
		coinsLeft = coinCount,
		rewardLeft = totalReward,
		deathPosition = originCFrame.Position,
	}

	CoinDropEvent:FireClient(player, originCFrame, coinCount, dropId)

	task.delay(LifeTime, function()
		activeDrops[dropId] = nil
	end)
end

local function onCoinPickup(player: Player, claimedDropId: unknown)
	if typeof(claimedDropId) ~= "string" then return end

	const dropData = activeDrops[claimedDropId]
	if not dropData or dropData.owner ~= player then return end

	const character = player.Character
	const rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then return end

	if (rootPart.Position - dropData.deathPosition).Magnitude > Distance then return end

	
	const reward = math.floor(dropData.rewardLeft / dropData.coinsLeft)
	dropData.coinsLeft -= 1
	dropData.rewardLeft -= reward

	if dropData.coinsLeft <= 0 then
		activeDrops[claimedDropId] = nil
	end

	Data:UpdateNumber(player, { "Money" }, reward)
end

function CoinServerModule.Init()
	if initialized then return end 
	initialized = true

	CoinPickupEvent.OnServerEvent:Connect(onCoinPickup)

	Players.PlayerRemoving:Connect(function(player)
		for dropId, dropData in activeDrops do
			if dropData.owner == player then
				activeDrops[dropId] = nil
			end
		end
	end)
end

return CoinServerModule
