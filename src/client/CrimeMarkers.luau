-- Fills in the distance under each crime's red "!" marker, a few times a second.

local Players = game:GetService("Players")

local CrimeMarkers = {}

function CrimeMarkers.Start()
	local crimes = workspace:WaitForChild("Crimes")
	task.spawn(function()
		while true do
			task.wait(0.25)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				for _, marker in crimes:GetDescendants() do
					if marker.Name == "CrimeMarker" and marker:IsA("BasePart") then
						local label = marker:FindFirstChild("Distance", true)
						if label and label:IsA("TextLabel") then
							label.Text = `{math.floor((marker.Position - root.Position).Magnitude)} studs`
						end
					end
				end
			end
		end
	end)
end

return CrimeMarkers
