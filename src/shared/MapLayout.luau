--!strict
--[[
	Single 1:1 grid blueprint (ADR-002) driving:
	1. Modular Studio geometry assembly via MCP
	2. Server Tile Adjacency Graph BFS/A* entity navigation
	3. Safe Room Wall Blueprint & Sector Fault LEDs
	4. Randomized active repair node spawns
]]

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

export type Direction = "N" | "S" | "W" | "E"
export type TileType = "Straight" | "Corner" | "TJunction" | "Cross" | "Alcove" | "DropShaft"
export type SectorId = "A" | "B" | "C" | "D" | "HUB"

export type SectorDef = {
	id: SectorId,
	name: string,
	color: Color3,
}

export type TileDef = {
	gx: number,
	gz: number,
	sector: SectorId,
	tileType: TileType,
	open: { [Direction]: boolean },
	hasGrate: boolean?,
	repairNode: string?,
	hasBulkheadLight: boolean?,
}

export type RepairNodeSlot = {
	nodeId: string,
	sector: SectorId,
	gx: number,
	gz: number,
	tileKey: string,
	isAlcove: boolean,
}

local MapLayout = {}

MapLayout.CELL_SIZE = GameConfig.VentKit.CellSize
MapLayout.FLOOR_Y = GameConfig.VentKit.FloorY
MapLayout.DROP_TILE_KEY = "0,0"

MapLayout.Sectors = {
	A = { id = "A", name = "BOILER", color = Color3.fromRGB(220, 58, 52) },
	B = { id = "B", name = "COOLANT", color = Color3.fromRGB(62, 145, 245) },
	C = { id = "C", name = "EXHAUST", color = Color3.fromRGB(240, 168, 48) },
	D = { id = "D", name = "POWER", color = Color3.fromRGB(64, 200, 108) },
	HUB = { id = "HUB", name = "SPINE", color = Color3.fromRGB(165, 175, 188) },
} :: { [SectorId]: SectorDef }

local DIR_OFFSETS: { [Direction]: { dx: number, dz: number, opposite: Direction } } = {
	N = { dx = 0, dz = -1, opposite = "S" },
	S = { dx = 0, dz = 1, opposite = "N" },
	W = { dx = -1, dz = 0, opposite = "E" },
	E = { dx = 1, dz = 0, opposite = "W" },
}

local ORDERED_DIRS: { Direction } = { "N", "S", "W", "E" }

MapLayout.Tiles = {
	-- Row Z = 0 (South Spine & DropShaft)
	{ gx = -2, gz = 0, sector = "A", tileType = "Corner", open = { N = true, E = true } },
	{ gx = -1, gz = 0, sector = "A", tileType = "Straight", open = { W = true, E = true }, repairNode = "A2" },
	{ gx = 0, gz = 0, sector = "HUB", tileType = "DropShaft", open = { N = true, W = true, E = true } },
	{ gx = 1, gz = 0, sector = "B", tileType = "Straight", open = { W = true, E = true }, repairNode = "B2" },
	{ gx = 2, gz = 0, sector = "B", tileType = "Corner", open = { N = true, W = true } },

	-- Row Z = -1
	{ gx = -2, gz = -1, sector = "A", tileType = "Straight", open = { N = true, S = true }, hasGrate = true },
	{ gx = 0, gz = -1, sector = "HUB", tileType = "Straight", open = { N = true, S = true } },
	{ gx = 2, gz = -1, sector = "B", tileType = "Straight", open = { N = true, S = true }, hasGrate = true },

	-- Row Z = -2 (South Hubs & Recessed Alcoves A1, B1)
	{ gx = -3, gz = -2, sector = "A", tileType = "Alcove", open = { E = true }, repairNode = "A1", hasBulkheadLight = true },
	{ gx = -2, gz = -2, sector = "A", tileType = "Cross", open = { N = true, S = true, W = true, E = true } },
	{ gx = -1, gz = -2, sector = "A", tileType = "Straight", open = { W = true, E = true } },
	{ gx = 0, gz = -2, sector = "HUB", tileType = "Cross", open = { N = true, S = true, W = true, E = true }, hasGrate = true },
	{ gx = 1, gz = -2, sector = "B", tileType = "Straight", open = { W = true, E = true } },
	{ gx = 2, gz = -2, sector = "B", tileType = "Cross", open = { N = true, S = true, W = true, E = true } },
	{ gx = 3, gz = -2, sector = "B", tileType = "Alcove", open = { W = true }, repairNode = "B1", hasBulkheadLight = true },

	-- Row Z = -3 (Mid Connector)
	{ gx = -2, gz = -3, sector = "A", tileType = "Straight", open = { N = true, S = true } },
	{ gx = 0, gz = -3, sector = "HUB", tileType = "Straight", open = { N = true, S = true } },
	{ gx = 2, gz = -3, sector = "B", tileType = "Straight", open = { N = true, S = true } },

	-- Row Z = -4 (North-Mid Cross & Peepholes)
	{ gx = -2, gz = -4, sector = "C", tileType = "TJunction", open = { N = true, S = true, E = true }, hasGrate = true },
	{ gx = -1, gz = -4, sector = "C", tileType = "Straight", open = { W = true, E = true } },
	{ gx = 0, gz = -4, sector = "HUB", tileType = "Cross", open = { N = true, S = true, W = true, E = true } },
	{ gx = 1, gz = -4, sector = "D", tileType = "Straight", open = { W = true, E = true } },
	{ gx = 2, gz = -4, sector = "D", tileType = "TJunction", open = { N = true, S = true, W = true }, hasGrate = true },

	-- Row Z = -5 (North Recessed Alcoves C1, D1)
	{ gx = -3, gz = -5, sector = "C", tileType = "Alcove", open = { E = true }, repairNode = "C1", hasBulkheadLight = true },
	{ gx = -2, gz = -5, sector = "C", tileType = "TJunction", open = { N = true, S = true, W = true } },
	{ gx = 0, gz = -5, sector = "HUB", tileType = "Straight", open = { N = true, S = true } },
	{ gx = 2, gz = -5, sector = "D", tileType = "TJunction", open = { N = true, S = true, E = true } },
	{ gx = 3, gz = -5, sector = "D", tileType = "Alcove", open = { W = true }, repairNode = "D1", hasBulkheadLight = true },

	-- Row Z = -6 (Far North Loop)
	{ gx = -2, gz = -6, sector = "C", tileType = "Corner", open = { S = true, E = true } },
	{ gx = -1, gz = -6, sector = "C", tileType = "Straight", open = { W = true, E = true }, repairNode = "C2" },
	{ gx = 0, gz = -6, sector = "HUB", tileType = "TJunction", open = { S = true, W = true, E = true } },
	{ gx = 1, gz = -6, sector = "D", tileType = "Straight", open = { W = true, E = true }, repairNode = "D2" },
	{ gx = 2, gz = -6, sector = "D", tileType = "Corner", open = { S = true, W = true } },
} :: { TileDef }

local tilesByKey: { [string]: TileDef } = {}
local adjacency: { [string]: { string } } = {}
local repairSlots: { RepairNodeSlot } = {}

function MapLayout.key(gx: number, gz: number): string
	return string.format("%d,%d", gx, gz)
end

for _, tile in ipairs(MapLayout.Tiles) do
	local k = MapLayout.key(tile.gx, tile.gz)
	tilesByKey[k] = tile
	if tile.repairNode then
		table.insert(repairSlots, {
			nodeId = tile.repairNode,
			sector = tile.sector,
			gx = tile.gx,
			gz = tile.gz,
			tileKey = k,
			isAlcove = tile.tileType == "Alcove",
		})
	end
end

for _, tile in ipairs(MapLayout.Tiles) do
	local k = MapLayout.key(tile.gx, tile.gz)
	local neighbors: { string } = {}
	for _, dir in ipairs(ORDERED_DIRS) do
		if tile.open[dir] then
			local offset = DIR_OFFSETS[dir]
			local neighborKey = MapLayout.key(tile.gx + offset.dx, tile.gz + offset.dz)
			if tilesByKey[neighborKey] then
				table.insert(neighbors, neighborKey)
			end
		end
	end
	adjacency[k] = neighbors
end

function MapLayout.getTile(gx: number, gz: number): TileDef?
	return tilesByKey[MapLayout.key(gx, gz)]
end

function MapLayout.getTileByKey(tileKey: string): TileDef?
	return tilesByKey[tileKey]
end

function MapLayout.getRepairSlots(): { RepairNodeSlot }
	return repairSlots
end

function MapLayout.tileToWorld(gx: number, gz: number): Vector3
	return Vector3.new(gx * MapLayout.CELL_SIZE, MapLayout.FLOOR_Y, gz * MapLayout.CELL_SIZE)
end

function MapLayout.worldToTile(pos: Vector3): (number, number)
	local gx = math.round(pos.X / MapLayout.CELL_SIZE)
	local gz = math.round(pos.Z / MapLayout.CELL_SIZE)
	return gx, gz
end

function MapLayout.getNeighbors(tileKey: string): { string }
	return adjacency[tileKey] or {}
end

function MapLayout.findPath(startKey: string, goalKey: string): { string }
	if not tilesByKey[startKey] or not tilesByKey[goalKey] then
		return {}
	end
	if startKey == goalKey then
		return { startKey }
	end

	local queue: { string } = { startKey }
	local head = 1
	local cameFrom: { [string]: string } = {}
	local visited: { [string]: boolean } = { [startKey] = true }

	while head <= #queue do
		local current = queue[head]
		head += 1

		if current == goalKey then
			local reversed: { string } = {}
			local cursor: string? = goalKey
			while cursor do
				table.insert(reversed, cursor)
				if cursor == startKey then
					break
				end
				cursor = cameFrom[cursor]
			end
			local path: { string } = {}
			for i = #reversed, 1, -1 do
				table.insert(path, reversed[i])
			end
			return path
		end

		for _, neighborKey in ipairs(MapLayout.getNeighbors(current)) do
			if not visited[neighborKey] then
				visited[neighborKey] = true
				cameFrom[neighborKey] = current
				table.insert(queue, neighborKey)
			end
		end
	end

	return {}
end

function MapLayout.validate(): (boolean, { string })
	local errors: { string } = {}
	local sectorNodeCounts: { [string]: number } = { A = 0, B = 0, C = 0, D = 0 }

	for _, tile in ipairs(MapLayout.Tiles) do
		local k = MapLayout.key(tile.gx, tile.gz)
		local openCount = 0

		for _, dir in ipairs(ORDERED_DIRS) do
			if tile.open[dir] then
				openCount += 1
				local offset = DIR_OFFSETS[dir]
				local neighborKey = MapLayout.key(tile.gx + offset.dx, tile.gz + offset.dz)
				local neighbor = tilesByKey[neighborKey]
				if not neighbor then
					table.insert(errors, string.format("Tile %s opens %s into missing tile %s", k, dir, neighborKey))
				elseif not neighbor.open[offset.opposite] then
					table.insert(
						errors,
						string.format("Asymmetric seam: %s opens %s but %s does not open %s", k, dir, neighborKey, offset.opposite)
					)
				end
			end
		end

		if tile.tileType ~= "Alcove" and openCount < 2 then
			table.insert(errors, string.format("Non-alcove tile %s (%s) has dead-end degree %d", k, tile.tileType, openCount))
		end

		if tile.repairNode then
			if tile.sector == "HUB" then
				table.insert(errors, string.format("Repair node %s on %s cannot belong to HUB sector", tile.repairNode, k))
			else
				sectorNodeCounts[tile.sector] = (sectorNodeCounts[tile.sector] or 0) + 1
			end
		end
	end

	-- Verify 100% BFS reachability from DropShaft (0,0)
	local startTile = tilesByKey[MapLayout.DROP_TILE_KEY]
	if not startTile then
		table.insert(errors, "Missing DropShaft tile at " .. MapLayout.DROP_TILE_KEY)
	else
		local visited: { [string]: boolean } = { [MapLayout.DROP_TILE_KEY] = true }
		local queue: { string } = { MapLayout.DROP_TILE_KEY }
		local head = 1
		local reached = 0

		while head <= #queue do
			local current = queue[head]
			head += 1
			reached += 1
			for _, neighborKey in ipairs(MapLayout.getNeighbors(current)) do
				if not visited[neighborKey] then
					visited[neighborKey] = true
					table.insert(queue, neighborKey)
				end
			end
		end

		if reached ~= #MapLayout.Tiles then
			table.insert(errors, string.format("BFS reached %d/%d tiles from DropShaft", reached, #MapLayout.Tiles))
		end
	end

	for _, sec in ipairs({ "A", "B", "C", "D" }) do
		if (sectorNodeCounts[sec] or 0) ~= 2 then
			table.insert(errors, string.format("Sector %s has %d repair nodes (expected 2)", sec, sectorNodeCounts[sec] or 0))
		end
	end

	return #errors == 0, errors
end

return MapLayout
