-- =========================================================
--  BITKI
--  Autor: Klakier
--  Wersja: 1.0.0
-- =========================================================

local ActiveZones = {}
local UserData = {}
local UserInGang = false
local InsideAnyZone = false
local PendingInvite = nil
local ActiveMatch = nil
local MapBlips = {}
local IsCharacterDead = false
local SafeState = false

local function CheckProximity(target, origin)
    return #(target.coords - origin) < target.radius
end

local function ToggleGhostMode()
    CreateThread(function()
        if not SafeState then
            SafeState = true
            while SafeState do
                Wait(1000)
                SetLocalPlayerAsGhost(not ActiveMatch)
            end
            SetLocalPlayerAsGhost(false)
        end
    end)
end

local function HandleZoneEnter(zone)
    ToggleGhostMode()
    if not UserInGang then return end
    TriggerServerEvent('bitki:enter', zone.id)
    LocalPlayer.state:set('currentSphere', zone.id, true)
end

local function HandleZoneExit(zone)
    SafeState = false
    if not UserInGang then return end
    InsideAnyZone = false
    LocalPlayer.state:set('currentSphere', nil, true)
    TriggerServerEvent('bitki:exit', zone.id)
    
    if ESX.UI.Menu.GetOpened('default', GetCurrentResourceName(), 'bitki_menu') then
        ESX.UI.Menu.CloseAll()
    end

    if ActiveMatch and not LocalPlayer.state.dead then
        SetEntityHealth(PlayerPedId(), 0)
    end
end

CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())

        for id, data in pairs(ActiveZones) do
            local dist = #(data.coords - pCoords)
            local isInside = dist < data.radius

            if isInside and not data.active then
                data.active = true
                HandleZoneEnter(data)
            elseif not isInside and data.active then
                data.active = false
                HandleZoneExit(data)
            end
        end
        Wait(400)
    end
end)

local ZoneManager = {
    register = function(payload)
        payload.id = #ActiveZones + 1
        payload.radius = (payload.radius or 2.0) + 0.0
        payload.active = false
        ActiveZones[payload.id] = payload
        return payload
    end
}

local function UpdateMapIcons()
    for _, blip in pairs(MapBlips) do RemoveBlip(blip) end
    MapBlips = {}
    
    if UserInGang then
        for i, bitka in ipairs(Config.Bitki) do
            local b = AddBlipForRadius(bitka.coords.x, bitka.coords.y, bitka.coords.z, bitka.radius)
            SetBlipColour(b, 1)
            SetBlipAlpha(b, 100)
            MapBlips[i] = b
        end
    end
end

ESX = nil

CreateThread(function()
    while ESX == nil do
        TriggerEvent('FineeaszKrul:getIqDogHahaha', function(obj) ESX = obj end)
        Wait(250)
    end

    while not ESX.IsPlayerLoaded() do Wait(100) end
    
    UserData = ESX.GetPlayerData()
    LocalPlayer.state:set('currentSphere', nil, true)
    LocalPlayer.state:set('inBitka', nil, true)
    
    for _, info in ipairs(Config.Bitki) do
        ZoneManager.register(info)
    end

    UserInGang = (UserData.hiddenjob and UserData.hiddenjob.name:find("org")) ~= nil
    UpdateMapIcons()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    UserData = xPlayer
    UserInGang = (UserData.hiddenjob and UserData.hiddenjob.name:find("org")) ~= nil
    UpdateMapIcons()
end)

RegisterNetEvent('esx:setHiddenJob', function(job)
    UserData.hiddenjob = job
    UserInGang = (UserData.hiddenjob and UserData.hiddenjob.name:find("org")) ~= nil
    UpdateMapIcons()
    
    if InsideAnyZone and UserInGang and LocalPlayer.state.currentSphere then
        TriggerServerEvent('bitki:exit', LocalPlayer.state.currentSphere)
        Wait(200)
        TriggerServerEvent('bitki:enter', LocalPlayer.state.currentSphere)
    end
end)

local function StartMatchSetup(zoneIdx)
    if openCooldown then 
        ESX.ShowNotification('Zwolnij tempo!')
        return 
    end
    
    openCooldown = true
    SetTimeout(3000, function() openCooldown = false end)

    ESX.TriggerServerCallback('bitki:getAvailableOrgs', function(results)
        if not results then return ESX.ShowNotification('Brak wrogich grup w okolicy') end
        
        local menuOptions = {}
        for _, org in pairs(results) do
            local isSelf = UserData.hiddenjob.name == org.name
            if isSelf and org.playerCount < 5 then
                return ESX.ShowNotification('Potrzebujesz min. 5 osób')
            elseif org.playerCount >= 5 then
                table.insert(menuOptions, {
                    label = org.label .. (isSelf and ' [TY]' or ''), 
                    value = org.name, 
                    players = org.players, 
                    own = isSelf 
                })
            end
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_main', {
            title = 'Wybierz przeciwnika',
            align = 'left',
            elements = menuOptions
        }, function(d1, m1)
            if d1.current.own then return end
            
            local config = { loot = false, extraTime = false }

            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_cfg', {
                title = 'Zasady starcia',
                align = 'left',
                elements = {
                    {label = 'Łupienie: NIE', value = 'loot', status = false},
                    {label = 'Dodatkowy czas: NIE', value = 'ext', status = false},
                    {label = 'WYŚLIJ WYZWANIE', value = 'go'}
                }
            }, function(d2, m2)
                if d2.current.value == 'loot' then
                    config.loot = not config.loot
                    d2.current.label = 'Łupienie: ' .. (config.loot and 'TAK' or 'NIE')
                    m2.update({value = 'loot'}, d2.current)
                elseif d2.current.value == 'ext' then
                    config.extraTime = not config.extraTime
                    d2.current.label = 'Dodatkowy czas: ' .. (config.extraTime and 'TAK' or 'NIE')
                    m2.update({value = 'ext'}, d2.current)
                elseif d2.current.value == 'go' then
                    local myTeam, enemyTeam = {}, d1.current.players
                    for _, v in ipairs(menuOptions) do
                        if v.own then myTeam = v.players break end
                    end

                    TriggerServerEvent('bitki:inviteToBitka', {
                        isLooting = config.loot,
                        addonLooting = config.extraTime,
                        initiator = UserData.hiddenjob.name,
                        initiatorLabel = UserData.hiddenjob.label,
                        initiatorPlayers = myTeam,
                        receiver = d1.current.value,
                        receiverLabel = d1.current.label,
                        receiverPlayers = enemyTeam,
                        currentZone = zoneIdx
                    })
                    ESX.UI.Menu.CloseAll()
                end
                m2.refresh()
            end, function(d2, m2) m2.close() end)
        end, function(d1, m1) m1.close() end)
    end, LocalPlayer.state.currentSphere)
end

RegisterNetEvent('bitki:inviteToBitka', function(data)
    if ActiveMatch or IsCharacterDead or invitedThrottle then return end
    
    if LocalPlayer.state.currentSphere == data.currentZone then
        invitedThrottle = true
        PendingInvite = data
        
        ESX.ShowNotification('Wyzwanie od: ' .. data.initiatorLabel)
        
        local options = {
            {label = '-- TWOJA EKIPA --'},
        }
        for _, p in ipairs(data.receiverPlayers) do table.insert(options, p) end
        table.insert(options, {label = '-- PRZECIWNIK --'})
        for _, p in ipairs(data.initiatorPlayers) do table.insert(options, p) end
        table.insert(options, {label = 'ODRZUĆ', value = 'no'})
        table.insert(options, {label = 'AKCEPTUJ', value = 'yes'})

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_req', {
            title = 'Zaproszenie: ' .. data.initiatorLabel,
            align = 'left',
            elements = options
        }, function(d, m)
            if d.current.value == 'yes' then
                TriggerServerEvent("bitki:startBitka", PendingInvite)
            end
            m.close()
            PendingInvite = nil
            invitedThrottle = false
        end, function(d, m)
            m.close()
            PendingInvite = nil
            invitedThrottle = false
        end)

        SetTimeout(15000, function()
            ESX.UI.Menu.CloseAll()
            PendingInvite = nil
            invitedThrottle = false
        end)
    end
end)

RegisterNetEvent('bitki:startBitka', function(matchData)
    if UserData.hiddenjob.name ~= matchData.receiver and UserData.hiddenjob.name ~= matchData.initiator then return end
    
    ActiveMatch = matchData
    IsCharacterDead = false
    LocalPlayer.state:set('inBitka', matchData.id, true)
    
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    FreezeEntityPosition(ped, true)
    if veh ~= 0 then FreezeEntityPosition(veh, true) end
    
    for i = 3, 1, -1 do
        ESX.Scaleform.ShowFreemodeMessage(tostring(i), '', 1)
    end
    
    FreezeEntityPosition(ped, false)
    if veh ~= 0 then FreezeEntityPosition(veh, false) end
    ESX.Scaleform.ShowFreemodeMessage('START!', '', 3)
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    if not IsCharacterDead and ActiveMatch then
        IsCharacterDead = true
        TriggerServerEvent('bitki:kill', ActiveMatch, data.killerServerId)
    end
end)

RegisterNetEvent('bitki:lootingTime', function(won)
    local duration = ActiveMatch.addonLooting and 120 or 60
    local msg = won and 'WYGRANA' or 'PRZEGRANA'
    local sub = (won and ActiveMatch.isLooting) and 'Czas łupienia: ' .. duration .. 's' or ''
    
    ESX.Scaleform.ShowFreemodeMessage(msg, sub, 3)
    
    if ActiveMatch.isLooting then
        exports["hash_taskbar"]:taskBar(duration * 1000 - 2000, "Lootowanie...", true, function() end)
        Wait(duration * 1000 - 2000)
    end
    
    ActiveMatch = nil
    IsCharacterDead = false
    LocalPlayer.state:set('inBitka', nil, true)
    TriggerEvent('fineeaszkruljebacpsy:reviveson', true)
end)

RegisterNetEvent('bitki:exitCurrentBitka', function()
    ActiveMatch = nil
    IsCharacterDead = false
    LocalPlayer.state:set('inBitka', nil, true)
end)

RegisterNetEvent('bitki:killers', function(list)
    for _, k in ipairs(list) do
        TriggerEvent('chatMessage', string.format("^4%s ^7| ^1%s ^7zabił: ^2%s", k.org, k.name, k.kills), {255, 255, 255})
    end    
end)

RegisterNetEvent('bitki:TP', function(zId, team)
    local spawn = Config.Bitki[zId][team][math.random(1, 3)]
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local target = (veh ~= 0) and veh or ped

    SetEntityCoords(target, spawn.x, spawn.y, spawn.z)
    SetEntityHeading(target, spawn.w)
    IsCharacterDead = false
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if UserInGang then
            sleep = 0
            local pPos = GetEntityCoords(PlayerPedId())
            for idx, cfg in ipairs(Config.Bitki) do
                local gap = #(pPos - cfg.coords)
                if gap < 450.0 then
                    DrawMarker(28, cfg.coords.x, cfg.coords.y, cfg.coords.z, 0, 0, 0, 0, 0, 0, 400.0, 400.0, 400.0, 200, 0, 0, 80, false, false, 2, false, nil, nil, false)
                    
                    if not ActiveMatch and not LocalPlayer.state.isDead and gap < 400.0 then
                        ESX.ShowHelpNotification("~INPUT_PICKUP~ - Zarządzaj Bitką")
                        if IsControlJustReleased(0, 38) then
                            StartMatchSetup(idx)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
