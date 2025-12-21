local BlockedBinds = {}
local KeyMapRegistry = {}

local MOUSE_CONTROLS = {
    ['MOUSE_LEFT'] = true, 
    ['MOUSE_RIGHT'] = true,
    ['MOUSE_MIDDLE'] = true,
    ['MOUSE_EXTRABTN1'] = true,
    ['MOUSE_EXTRABTN2'] = true,
    ['IOM_WHEEL_UP'] = true,
    ['IOM_WHEEL_DOWN'] = true,
}

RegisterNetEvent("klakier-keybinds:KeyStart")
RegisterNetEvent("klakier-keybinds:KeyEnd")

function IsKeyMapped(key)
    return KeyMapRegistry[key] ~= nil
end
exports("IsKeyMapped", IsKeyMapped)

function MapKeyHandler(key)
    if IsKeyMapped(key) then
        return
    end

    local isMouseInput = MOUSE_CONTROLS[key]
    local bindCategory = isMouseInput and "MOUSE_BUTTON" or "keyboard"
    local commandBase = ("kmgr_bind_" .. (isMouseInput and "m" or "k") .. "_" .. key) 
    local commandLabel = string.format("KeyBind: %s (%s)", key, bindCategory)

    RegisterCommand('+' .. commandBase, function()
        if BlockedBinds[key] then return end
        TriggerEvent("klakier-keybinds:KeyStart", key)
    end, false)

    RegisterCommand('-' .. commandBase, function()
        if BlockedBinds[key] then return end
        TriggerEvent("klakier-keybinds:KeyEnd", key)
    end, false)

    RegisterKeyMapping('+' .. commandBase, commandLabel, bindCategory, key)
    KeyMapRegistry[key] = true
end
exports("MapKeyHandler", MapKeyHandler)

function ApplyRestriction(keys, restrictState)
    if type(keys) == "table" then
        for _, k in ipairs(keys) do
            BlockedBinds[k] = restrictState
        end
    else
        BlockedBinds[keys] = restrictState
    end
end
exports("ApplyRestriction", ApplyRestriction)

function RemoteInitializer()
    local invoker = GetInvokingResource()
    if not invoker then
        print("Keybind resource cannot be initialized remotely.")
        return
    end

    local sharedFile = LoadResourceFile(GetCurrentResourceName(), "lib.lua")
    return sharedFile
end
exports("Initialize", RemoteInitializer)