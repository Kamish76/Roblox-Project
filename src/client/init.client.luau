--!strict
local CrawlController = require(script:WaitForChild("CrawlController"))
local HeadlampController = require(script:WaitForChild("HeadlampController"))

CrawlController.init()
HeadlampController.init()

print("[Client] M1 CrawlController & HeadlampController ready")
