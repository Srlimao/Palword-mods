-- Scanners Facade Module for HUDLocator
local scanPlayers = require("HUDLocator.scanners.scan_players")
local scanRelics = require("HUDLocator.scanners.scan_relics")
local scanChests = require("HUDLocator.scanners.scan_chests")
local scanEggs = require("HUDLocator.scanners.scan_eggs")
local scanCaves = require("HUDLocator.scanners.scan_caves")
local scanLoot = require("HUDLocator.scanners.scan_loot")
local scanNotes = require("HUDLocator.scanners.scan_notes")
local scanPals = require("HUDLocator.scanners.scan_pals")

local M = {}

function M.ScanPlayers(localPlayerState, playerPos)
    return scanPlayers.Scan(localPlayerState, playerPos)
end

function M.ScanRelics(playerPos, maxDistSq)
    return scanRelics.Scan(playerPos, maxDistSq)
end

function M.ScanChests(playerPos, maxDistSq)
    return scanChests.Scan(playerPos, maxDistSq)
end

function M.ScanEggs(playerPos, maxDistSq, eggFilter, debug)
    return scanEggs.Scan(playerPos, maxDistSq, eggFilter)
end

function M.ScanCaves(playerPos, maxDistSq)
    return scanCaves.Scan(playerPos, maxDistSq)
end

function M.ScanLoot(playerPos, maxDistSq, filters)
    return scanLoot.Scan(playerPos, maxDistSq, filters)
end

function M.ScanNotes(playerPos, maxDistSq)
    return scanNotes.Scan(playerPos, maxDistSq)
end

function M.ScanPals(playerPos, maxDistSq, palConfig)
    return scanPals.Scan(playerPos, maxDistSq, palConfig)
end

return M
