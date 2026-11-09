const ReplicatedStorage = game:GetService("ReplicatedStorage")
const MarketplaceService = game:GetService("MarketplaceService")
const TweenService = game:GetService("TweenService")
const Players = game:GetService("Players")

const Modules = ReplicatedStorage:WaitForChild("Modules")
const Configs = Modules:WaitForChild("Configs") 
const Utils = Modules:WaitForChild("Utils")
const Remotes = ReplicatedStorage:WaitForChild("Remotes")
const UI = ReplicatedStorage:WaitForChild("UI")

const ShopGunConfig = require(Configs:WaitForChild("ShopGunConfig"))
const UiFx = require(Utils:WaitForChild("UiFx"))

const Player = Players.LocalPlayer
const playerGui = Player:WaitForChild("PlayerGui")

const Main = playerGui:WaitForChild("Main") :: ScreenGui
const gunShopFrame = Main:WaitForChild("GunShop") :: Frame
const CloseButton = gunShopFrame:WaitForChild("X") :: ImageButton
const ScrollingFrame = gunShopFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame
const Template = UI:WaitForChild("TemplateGun") :: Frame

const ToggleWeapon = Remotes:WaitForChild("ToggleWeapon")
const BuyGun = Remotes:WaitForChild("BuyGun")
const GetOwnedGuns = Remotes:WaitForChild("GetOwnedGuns")
const ResetButtons = Remotes:WaitForChild("ResetButtons")
const CloseUI = Remotes:WaitForChild("CloseUI") :: BindableEvent

local ShopUI = {}
local closeToken = 0
local ownedGuns = {}
local pendingPurchases: { [string]: boolean } = {}

local function setState(gunFrame: Frame, state: "Buy" | "Equip" | "Unequip")
	local BuyBtn = gunFrame.Buttons.Buy
	local RobuxBtn = gunFrame.Buttons.BuyForRobux

	BuyBtn:SetAttribute("State", state)

	if state == "Buy" then
		RobuxBtn.Visible = true
	elseif state == "Equip" then
		RobuxBtn.Visible = false
		BuyBtn.TextLabel.Text = "EQUIP"
	elseif state == "Unequip" then
		RobuxBtn.Visible = false
		BuyBtn.TextLabel.Text = "UNEQUIP"
	end
end

local function setVisible(visible: boolean)
	if not gunShopFrame then return end

	closeToken += 1
	local token = closeToken

	if visible then
		local wasVisible = gunShopFrame.Visible
		gunShopFrame.Visible = true
		if not wasVisible then
			CloseUI:Fire("Open", "GunShop")
			UiFx.popIn(gunShopFrame, 0.4, 0.28)
		end
	else
		if not gunShopFrame.Visible then return end

		local scale = gunShopFrame:FindFirstChild("UiFxScale")
		if scale then
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.4 }
			)
			tween.Completed:Once(function()
				if token == closeToken then
					gunShopFrame.Visible = false
					CloseUI:Fire("Closed", "GunShop")
				end
			end)
			tween:Play()
		else
			gunShopFrame.Visible = false
			CloseUI:Fire("Closed", "GunShop")
		end
	end
end

local function setupButtons()
	local serverInventory = GetOwnedGuns:InvokeServer()
	for _, gunName in serverInventory do
		ownedGuns[gunName] = true
	end

	for _, info in ShopGunConfig do
		local gunFrame = Template:Clone()
		gunFrame.Name = info.gunName
		gunFrame.TextLabel.Text = info.gunName
		gunFrame.Icon.Image = info.icon
		gunFrame.Buttons.Buy.TextLabel.Text = (info.gunPrice or 0).."$" 
		gunFrame.Parent = ScrollingFrame

		if ownedGuns[info.gunName] then
			setState(gunFrame, "Equip")
		else
			setState(gunFrame, "Buy")
		end

		task.spawn(function()
			if ownedGuns[info.gunName] then return end

			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfoAsync(info.gamePassId, Enum.InfoType.GamePass)
			end)
			if ok and result.PriceInRobux then
				gunFrame.Buttons.BuyForRobux.TextLabel.Text = (result.PriceInRobux or 0)..gunFrame.Buttons.BuyForRobux.TextLabel.Text
			end

			local okOwns, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, info.gamePassId)
			if okOwns and owns then
				setState(gunFrame, "Equip")
			end
		end)

		UiFx.bindButton(gunFrame.Buttons.BuyForRobux)
		UiFx.bindButton(gunFrame.Buttons.Buy)

		gunFrame.Buttons.BuyForRobux.Activated:Connect(function()
			if not info.gamePassId then return end
			MarketplaceService:PromptGamePassPurchase(Player, info.gamePassId)
		end)

		gunFrame.Buttons.Buy.Activated:Connect(function()
			local currentState = gunFrame.Buttons.Buy:GetAttribute("State")
			if not currentState then return end
			if pendingPurchases[info.gunName] then return end

			if currentState == "Buy" then
				pendingPurchases[info.gunName] = true
				BuyGun:FireServer(info.gunName)
			elseif currentState == "Equip" then
				setState(gunFrame, "Unequip")
				ToggleWeapon:FireServer(info.gunName)
			elseif currentState == "Unequip" then
				setState(gunFrame, "Equip")
				ToggleWeapon:FireServer(info.gunName)
			end

			task.delay(3, function()
				pendingPurchases[info.gunName] = nil
			end)
		end)
	end
end

function ShopUI:Init()
	local openButton = Main:WaitForChild("LeftButtons"):WaitForChild("Guns") :: ImageButton

	if openButton then
		openButton.Activated:Connect(function()
			setVisible(not gunShopFrame.Visible)
		end)
	end

	if CloseButton then
		UiFx.bindButton(CloseButton)
		CloseButton.Activated:Connect(function()
			setVisible(false)
		end)
	end

	setupButtons()	

	CloseUI.Event:Connect(function(action: string, currentOpenFrameName: string)
		if action == "CloseOthers" and currentOpenFrameName ~= "GunShop" then
			setVisible(false)
		end
	end)

	task.spawn(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
			if player ~= Player then return end
			if not wasPurchased then return end

			for _, info in ShopGunConfig do
				if info.gamePassId == gamePassId then
					local button = ScrollingFrame:FindFirstChild(info.gunName)
					if button then
						setState(button, "Equip")
						ownedGuns[info.gunName] = true 
					end
					break
				end
			end
		end)
	end)

	BuyGun.OnClientEvent:Connect(function(name: string)
		local button = ScrollingFrame:FindFirstChild(name)
		if not button then return end
		setState(button, "Equip")
		ownedGuns[name] = true 
		pendingPurchases[name] = nil
	end)

	ResetButtons.OnClientEvent:Connect(function()
		for _, v in ScrollingFrame:GetChildren() do
			if v:IsA("Frame") and v:FindFirstChild("Buttons"):FindFirstChild("Buy"):GetAttribute("State") ~= "Buy" then 
				setState(v, "Equip")
			end
		end
	end)
end

return ShopUI
