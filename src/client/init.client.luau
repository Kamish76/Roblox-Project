--!strict
local AudioController = require(script:WaitForChild("AudioController"))
local CrawlController = require(script:WaitForChild("CrawlController"))
local HeadlampController = require(script:WaitForChild("HeadlampController"))
local PanicController = require(script:WaitForChild("PanicController"))
local SafeRoomUI = require(script:WaitForChild("SafeRoomUI"))

CrawlController.init()
HeadlampController.init()
PanicController.init()
SafeRoomUI.init()
AudioController.init()

print("[Client] M5 CrawlController, HeadlampController, PanicController, SafeRoomUI & AudioController ready")
