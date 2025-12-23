-- =========================================================
--  BITKI
--  Autor: Klakier
--  Wersja: 1.0.0
-- =========================================================

ESX = nil
TriggerEvent('FineeaszKrul:getIqDogHahaha', function(o) ESX = o end)

local SessionStorage = {
    UserStates = {},
    Scoreboard = {},
    Assassins = {},
    ActiveWarriors = {}
}

local Utils = {
    UpdateStatus = function(id, k, v)
        if not SessionStorage.UserStates[id] then SessionStorage.UserStates[id] = {} end
        SessionStorage.UserStates[id][k] = v
    end,
    
    FetchStatus = function(id, k)
        return SessionStorage.UserStates[id] and SessionStorage.UserStates[id][k] or nil
    end,

    SyncDimension = function(target, dim)
        SetPlayerRoutingBucket(target, dim)
        local car = GetVehiclePedIsIn(GetPlayerPed(target), false)
        if car ~= 0 then SetEntityRoutingBucket(car, dim) end
    end
}

RegisterNetEvent('bitki:enter', function(zoneId)
    Utils.UpdateStatus(source, 'currentSphere', zoneId)
end)

RegisterNetEvent('bitki:exit', function()
    Utils.UpdateStatus(source, 'currentSphere', 0)
end)

ESX.RegisterServerCallback('bitki:getAvailableOrgs', function(source, cb, _)
    local list = {}
    local clients = ESX.GetPlayers()
    local myOrg = ESX.GetPlayerFromId(source).hiddenjob.name
    local targetSphere = Utils.FetchStatus(source, 'currentSphere') or 0

    for i=1, #clients do
        local xObj = ESX.GetPlayerFromId(clients[i])
        local job = xObj.hiddenjob
        local loc = Utils.FetchStatus(clients[i], 'currentSphere')

        if loc == targetSphere then
            if not list[job.name] then
                list[job.name] = { name = job.name, label = job.label, players = {}, playerCount = 21 }
            end
            table.insert(list[job.name].players, { label = xObj.name, value = xObj.source })
        end
    end

    local output = {}
    for _, data in pairs(list) do table.insert(output, data) end
    cb(output)
end)

RegisterServerEvent('bitki:inviteToBitka', function(data)
    if data and data.receiverPlayers and data.receiverPlayers[1] then
        TriggerClientEvent("bitki:inviteToBitka", data.receiverPlayers[1].value, data)
    end
end)

RegisterServerEvent('bitki:startBitka', function(bundle)
    local matchKey = math.random(222222, 888888)
    local area = tonumber(bundle.currentZone)
    
    SessionStorage.Scoreboard[matchKey] = {
        [bundle.initiator] = 0,
        [bundle.receiver] = 0
    }

    SessionStorage.ActiveWarriors[matchKey] = {
        [bundle.initiator] = bundle.initiatorPlayers,
        [bundle.receiver] = bundle.receiverPlayers
    }

    local function PrepareTeam(team, pos)
        for _, p in ipairs(team) do
            Utils.SyncDimension(p.value, matchKey)
            Utils.UpdateStatus(p.value, 'currentBitka', matchKey)
            TriggerClientEvent('bitki:TP', p.value, area, pos)
            TriggerClientEvent("bitki:startBitka", p.value, bundle)
        end
    end

    PrepareTeam(bundle.receiverPlayers, "team1Position")
    PrepareTeam(bundle.initiatorPlayers, "team2Position")
end)

RegisterServerEvent('bitki:kill', function(context, killerId)
    local victimId = source
    local victimObj = ESX.GetPlayerFromId(victimId)
    local isAggressor = true

    for _, v in pairs(context.receiverPlayers) do
        if v.name == victimObj.name then isAggressor = false break end
    end

    if not killerId then
        killerId = isAggressor and context.receiverPlayers[math.random(1, #context.receiverPlayers)].value 
                                or context.initiatorPlayers[math.random(1, #context.initiatorPlayers)].value
    end

    local slayer = ESX.GetPlayerFromId(killerId)
    local battleId = Utils.FetchStatus(killerId, "currentBitka")
    if not battleId or not SessionStorage.Scoreboard[battleId] then return end

    local slayerOrg = slayer and slayer.hiddenjob.name or (isAggressor and context.receiver or context.initiator)

    if not SessionStorage.Assassins[battleId] then SessionStorage.Assassins[battleId] = {} end
    local found = false
    for _, stat in ipairs(SessionStorage.Assassins[battleId]) do
        if stat.name == slayer.name then
            stat.kills = stat.kills + 1
            found = true; break
        end
    end
    if not found then
        table.insert(SessionStorage.Assassins[battleId], { name = slayer.name, kills = 1, org = slayerOrg })
    end

    SessionStorage.Scoreboard[battleId][slayerOrg] = (SessionStorage.Scoreboard[battleId][slayerOrg] or 0) + 1

    local allVehs = GetAllVehicles()
    for _, veh in ipairs(allVehs) do
        if GetEntityRoutingBucket(veh) == battleId then SetEntityRoutingBucket(veh, 0) end
    end

    local killsToWin = #SessionStorage.ActiveWarriors[battleId][isAggressor and context.receiver or context.initiator]
    if SessionStorage.Scoreboard[battleId][slayerOrg] >= killsToWin then
        
        local winner = slayerOrg
        local allParticipants = { table.unpack(context.initiatorPlayers), table.unpack(context.receiverPlayers) }

        for _, p in ipairs(allParticipants) do
            TriggerClientEvent('chatMessage', p.value, string.format("^3^*👑 Zwycięstwo: %s", winner))
            local isWinner = (winner == (ESX.GetPlayerFromId(p.value).hiddenjob.name))
            
            TriggerClientEvent("bitki:lootingTime", p.value, isWinner)
            SetPlayerRoutingBucket(p.value, 0)
            TriggerEvent('fineeaszkruljebacpsy:reviveson', p.value, true)
            Utils.UpdateStatus(p.value, 'currentBitka', nil)
        end

        SessionStorage.Scoreboard[battleId] = nil
        SessionStorage.ActiveWarriors[battleId] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    SessionStorage.UserStates[source] = nil
end)
