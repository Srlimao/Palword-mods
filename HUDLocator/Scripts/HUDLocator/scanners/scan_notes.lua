local configMod = require("HUDLocator.config")
local utils = require("HUDLocator.utils")
local logger = require("HUDLocator.logger")

local M = {}
M.hasLoggedNotes = false

function M.Scan(playerPos, maxDistSq)
    local newNotes = {}
    local notes = FindAllOf("PalLevelObjectNote") or {}
    for _, note in ipairs(notes) do
        if note:IsValid() then
            pcall(function()
                local ueNotePos = note:K2_GetActorLocation()
                if ueNotePos then
                    local within, distSq = utils.IsWithinDistanceSq(ueNotePos, playerPos, maxDistSq)
                    -- ⚡ Bolt Performance Optimization: Defer expensive C++ state reflection check until after fast spatial distance check
                    if within and not utils.IsNotePicked(note) then
                        local name = nil
                        local statusName, noteKey = pcall(function() return note.NoteRowName.Key end)
                        if statusName and noteKey then
                            local trans = utils.GetTranslatedNoteName(noteKey)
                            if trans then
                                name = trans
                            else
                                name = configMod.GetTranslation("Note", "Journal")
                            end
                        else
                            name = configMod.GetTranslation("Note", "Journal")
                        end
                        local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                        table.insert(newNotes, { X = ueNotePos.X, Y = ueNotePos.Y, Z = ueNotePos.Z, Name = name, DistStr = distStr })
                    end
                end
            end)
        end
    end
    
    if not M.hasLoggedNotes and #newNotes > 0 then
        M.hasLoggedNotes = true
        logger.log("Note Scan (Initial detection): Found " .. tostring(#newNotes) .. " journals.")
    end
    return newNotes
end

return M
