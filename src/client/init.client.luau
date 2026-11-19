--!strict
local CrawlController = require(script:WaitForChild("CrawlController"))
local HeadlampController = require(script:WaitForChild("HeadlampController"))
local SafeRoomUI = require(script:WaitForChild("SafeRoomUI"))

CrawlController.init()
HeadlampController.init()
SafeRoomUI.init()

print("[Client] M3 CrawlController, HeadlampController & SafeRoomUI ready")
