local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CharacterSpawner = require(script.CharacterSpawner)
local CityBuilder = require(script.CityBuilder)
local CrimeService = require(script.CrimeService)
local DataService = require(script.DataService)
local MotionRelay = require(script.MotionRelay)
local ShopService = require(script.ShopService)

Remotes.Setup()
CityBuilder.Build()
DataService.Start()
ShopService.Start()
MotionRelay.Start()
CrimeService.Start()
CharacterSpawner.Start()
