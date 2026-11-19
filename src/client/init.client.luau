--!strict
local CrawlController = require(script:WaitForChild("CrawlController"))
local HeadlampController = require(script:WaitForChild("HeadlampController"))
local PanicController = require(script:WaitForChild("PanicController"))
local SafeRoomUI = require(script:WaitForChild("SafeRoomUI"))

CrawlController.init()
HeadlampController.init()
PanicController.init()
SafeRoomUI.init()

print("[Client] M4 CrawlController, HeadlampController, PanicController & SafeRoomUI ready")
