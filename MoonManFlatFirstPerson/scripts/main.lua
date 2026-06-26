-- MoonManFlatFirstPerson - experimental non-VR first-person toggle for Deliver Us The Moon
-- Loader: UE4SS Lua mod. Place this folder under UE4SS/Mods and enable it in Mods/mods.txt.
-- Goal: reuse the same native pawn.bFirstPerson flag the UEVR profile uses, but without VR rendering.

local UEHelpers = require("UEHelpers")

local MOD_NAME = "MoonManFlatFirstPerson"
local ENABLED = true
local HIDE_BODY_IN_FIRST_PERSON = true
local KEEP_CUTSCENES_AND_CLIMBING_THIRD_PERSON = true
local TICK_MS = 50

local last_state = ""

local function log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg) .. "\n")
end

local function ok_index(obj, key)
    if obj == nil then return nil end
    local ok, val = pcall(function() return obj[key] end)
    if ok then return val end
    return nil
end

local function ok_set(obj, key, val)
    if obj == nil then return false end
    local ok = pcall(function() obj[key] = val end)
    if ok then return true end
    ok = pcall(function() obj:SetPropertyValue(key, val) end)
    return ok
end

local function ok_call(obj, name, ...)
    if obj == nil then return false end
    local fn = nil
    local ok = pcall(function() fn = obj[name] end)
    if not ok or fn == nil then return false end
    ok = pcall(function(...) fn(obj, ...) end, ...)
    return ok
end

local function str_contains(s, needle)
    return s ~= nil and string.find(tostring(s), needle, 1, true) ~= nil
end

local function obj_name(obj)
    if obj == nil then return "nil" end
    local ok, name = pcall(function() return obj:GetFullName() end)
    if ok and name ~= nil then return tostring(name) end
    ok, name = pcall(function() return obj:get_full_name() end)
    if ok and name ~= nil then return tostring(name) end
    return tostring(obj)
end

local function get_pawn()
    local pc = nil
    local ok = pcall(function() pc = UEHelpers:GetPlayerController() end)
    if ok and pc ~= nil then
        local pawn = ok_index(pc, "Pawn")
        if pawn ~= nil then return pawn end
    end

    -- Fallbacks, in case UEHelpers cannot resolve the current pawn in this title.
    local candidates = { "BP_Astronaut_C", "BP_Astronaut_Frozen_C", "BP_ASE_C" }
    for _, cls in ipairs(candidates) do
        local found = nil
        ok = pcall(function() found = FindFirstOf(cls) end)
        if ok and found ~= nil then return found end
    end
    return nil
end

local function set_mesh_render(mesh, enabled)
    if mesh == nil then return end
    ok_call(mesh, "SetRenderInMainPass", enabled)
    ok_call(mesh, "SetRenderCustomDepth", enabled)
end

local function apply_camera_state()
    if not ENABLED then return false end

    local pawn = get_pawn()
    if pawn == nil then return false end

    local name = obj_name(pawn)
    local is_ase = str_contains(name, "BP_ASE_C")
    local is_frozen = str_contains(name, "BP_Astronaut_Frozen_C")

    local mesh = ok_index(pawn, "Mesh")
    local anim = ok_index(mesh, "AnimScriptInstance")
    local is_cinematic = ok_index(anim, "bIsCinematic") == true
    local is_climbing = ok_index(anim, "bClimbing") == true

    if is_ase or is_frozen then
        -- Do not force first-person when the current pawn is the ASE robot or frozen/cinematic astronaut pawn.
        return false
    end

    if KEEP_CUTSCENES_AND_CLIMBING_THIRD_PERSON and (is_cinematic or is_climbing) then
        ok_set(pawn, "bFirstPerson", false)
        set_mesh_render(mesh, true)
        if last_state ~= "third" then
            log("third-person state: cinematic=" .. tostring(is_cinematic) .. " climbing=" .. tostring(is_climbing))
            last_state = "third"
        end
        return false
    end

    ok_set(pawn, "bFirstPerson", true)
    if HIDE_BODY_IN_FIRST_PERSON then
        set_mesh_render(mesh, false)
    end

    if last_state ~= "first" then
        log("forcing first-person on pawn: " .. name)
        last_state = "first"
    end
    return false
end

RegisterKeyBind(Key.F8, function()
    ENABLED = not ENABLED
    log("enabled = " .. tostring(ENABLED))
end)

-- Optional console commands once UE4SS console is available:
--   dutm_fp_on
--   dutm_fp_off
--   dutm_fp_toggle
RegisterConsoleCommandGlobalHandler("dutm_fp_on", function(Cmd, CommandParts, Ar)
    ENABLED = true
    log("enabled = true")
    return true
end)

RegisterConsoleCommandGlobalHandler("dutm_fp_off", function(Cmd, CommandParts, Ar)
    ENABLED = false
    log("enabled = false")
    return true
end)

RegisterConsoleCommandGlobalHandler("dutm_fp_toggle", function(Cmd, CommandParts, Ar)
    ENABLED = not ENABLED
    log("enabled = " .. tostring(ENABLED))
    return true
end)

LoopAsync(TICK_MS, function()
    ExecuteInGameThread(function()
        apply_camera_state()
    end)
    return false -- keep looping
end)

log("loaded. F8 toggles the first-person patch. Console: dutm_fp_on / dutm_fp_off / dutm_fp_toggle")
