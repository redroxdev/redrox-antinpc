local insideAnyZone = false
local nearAnyZone = false
local currentActiveZones = {}
local debugEnabled = Config.Debug
local protectedEntities = {} -- Entidades protegidas explícitamente vía export
local playerVehicles = {} -- Vehículos que el jugador ya ocupó (handle -> modelo): nunca se borran

-- Registra un vehículo como del jugador para que la barrida no lo elimine
local function RememberPlayerVehicle(veh)
    if not veh or veh == 0 then return end
    if not DoesEntityExist(veh) then return end
    if playerVehicles[veh] then return end
    playerVehicles[veh] = GetEntityModel(veh)
end

-- Limpia handles borrados o reciclados por el motor (otra entidad reutilizó el handle)
local function PruneRememberedVehicles()
    for handle, model in pairs(playerVehicles) do
        if not DoesEntityExist(handle) or GetEntityModel(handle) ~= model then
            playerVehicles[handle] = nil
        end
    end
end

-- Preprocesamiento de Zonas (Cálculo de centroides, bounding boxes y radios de optimización)
local function InitializeZones()
    for _, zone in ipairs(Config.Zones) do
        if zone.points and #zone.points >= 3 then
            local minX, maxX = zone.points[1].x, zone.points[1].x
            local minY, maxY = zone.points[1].y, zone.points[1].y
            local minZ, maxZ = zone.points[1].z, zone.points[1].z
            local sumX, sumY, sumZ = 0.0, 0.0, 0.0
            local count = #zone.points

            for _, p in ipairs(zone.points) do
                if p.x < minX then minX = p.x end
                if p.x > maxX then maxX = p.x end
                if p.y < minY then minY = p.y end
                if p.y > maxY then maxY = p.y end
                if p.z < minZ then minZ = p.z end
                if p.z > maxZ then maxZ = p.z end
                sumX = sumX + p.x
                sumY = sumY + p.y
                sumZ = sumZ + p.z
            end

            local center = vector3(sumX / count, sumY / count, sumZ / count)
            local maxRadius = 0.0
            for _, p in ipairs(zone.points) do
                local dist = #(center.xy - p.xy)
                if dist > maxRadius then maxRadius = dist end
            end

            zone._meta = {
                type = 'poly',
                minX = minX,
                maxX = maxX,
                minY = minY,
                maxY = maxY,
                minZ = zone.minZ or (minZ - 10.0),
                maxZ = zone.maxZ or (maxZ + 25.0),
                center = center,
                boundingRadius = maxRadius
            }
        elseif zone.coords and zone.radius then
            zone._meta = {
                type = 'circle',
                center = zone.coords,
                radius = zone.radius,
                minX = zone.coords.x - zone.radius,
                maxX = zone.coords.x + zone.radius,
                minY = zone.coords.y - zone.radius,
                maxY = zone.coords.y + zone.radius,
                minZ = zone.coords.z - (zone.radius / 2),
                maxZ = zone.coords.z + (zone.radius / 2),
                boundingRadius = zone.radius
            }
        end
    end
end

InitializeZones()

-- Comprobar si un punto está dentro de un polígono 2D (Algoritmo Ray-Casting PnPoly)
local function IsPointInsideZone(point, zone)
    local meta = zone._meta
    if not meta then return false end

    -- 1. Verificación en eje Z
    if point.z < meta.minZ or point.z > meta.maxZ then
        return false
    end

    -- 2. Verificación rápida por Bounding Box 2D
    if point.x < meta.minX or point.x > meta.maxX or point.y < meta.minY or point.y > meta.maxY then
        return false
    end

    -- Si es zona circular clásica
    if meta.type == 'circle' then
        return #(point - meta.center) <= meta.radius
    end

    -- 3. Ray-casting para Polígono
    local pts = zone.points
    local n = #pts
    local inside = false
    local j = n

    for i = 1, n do
        local pi = pts[i]
        local pj = pts[j]
        if ((pi.y > point.y) ~= (pj.y > point.y)) and
           (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end

    return inside
end

-- Export para que cualquier otro script pueda registrar una entidad protegida
exports('ProtectEntity', function(entity)
    if DoesEntityExist(entity) then
        protectedEntities[entity] = true
        return true
    end
    return false
end)

exports('UnprotectEntity', function(entity)
    if protectedEntities[entity] then
        protectedEntities[entity] = nil
        return true
    end
    return false
end)

-- Tipos de población que NO son tráfico ambiental (enum ePopulationType de GTA V):
-- 0 UNKNOWN, 7 MISSION (creado con CreatePed/CreateVehicle), 8 REPLAY, 9 CACHE, 10 TOOL.
-- El tráfico/peatones del juego devuelven 1-6 y son los únicos que este script elimina.
local PROTECTED_POP_TYPES = {
    [0] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
}

-- ¿La entidad la puso un script (adorno, misión, prop, preview) en vez del population manager?
local function IsScriptEntity(entity)
    -- IsEntityAMissionEntity puede llegar como booleano o como 1/0 según el runtime:
    -- en Lua el 0 es truthy, así que se normaliza a mano antes de usarlo como condición.
    local mission = IsEntityAMissionEntity(entity)
    if mission == true or mission == 1 then return true end
    return PROTECTED_POP_TYPES[GetEntityPopulationType(entity)] == true
end

-- Comprobar si un Ped es jugador o está protegido
local function IsPedProtected(ped)
    if not DoesEntityExist(ped) then return true end
    if IsPedAPlayer(ped) then return true end
    if protectedEntities[ped] then return true end
    if IsScriptEntity(ped) then return true end -- NPC de adorno/misión de otro script

    local entState = Entity(ped).state
    if entState and (entState.ignoreAntiNpc or entState.isScriptPed) then
        return true
    end

    -- Si el ped está subido a un vehículo con algún jugador, no se toca
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            local occupant = GetPedInVehicleSeat(veh, seat)
            if occupant ~= 0 and IsPedAPlayer(occupant) then
                return true
            end
        end
    end

    return false
end

-- Comprobar si un Vehículo pertenece a un jugador o está protegido
local function IsVehicleProtected(veh)
    if not DoesEntityExist(veh) then return true end

    -- Vehículo que el jugador ya condujo/ocupó: se queda aunque esté vacío ahora
    local knownModel = playerVehicles[veh]
    if knownModel then
        if GetEntityModel(veh) == knownModel then return true end
        playerVehicles[veh] = nil -- handle reciclado por otra entidad
    end

    if protectedEntities[veh] then return true end
    if IsScriptEntity(veh) then return true end -- Vehículo de adorno/misión de otro script

    local entState = Entity(veh).state
    if entState and entState.ignoreAntiNpc then
        return true
    end

    -- Si tiene a algún jugador dentro (conductor o pasajero), está 100% protegido
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local occupant = GetPedInVehicleSeat(veh, seat)
        if occupant ~= 0 and IsPedAPlayer(occupant) then
            RememberPlayerVehicle(veh)
            return true
        end
    end

    return false
end

-- Eliminación forzada y segura de una entidad
local function ForceDeleteEntity(entity)
    if not DoesEntityExist(entity) then return end
    
    if IsEntityAPed(entity) then
        ClearPedTasksImmediately(entity)
    end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then
            DeletePed(entity)
        elseif IsEntityAVehicle(entity) then
            DeleteVehicle(entity)
        end
    end
end

-- Limpieza y control de generadores de la zona
local function CleanZoneEntities(zone)
    local meta = zone._meta
    if not meta then return end

    -- 1. Deshabilitar generadores automáticos del motor de GTA V en el área
    SetPedNonCreationArea(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ)
    SetAllVehicleGeneratorsActiveInArea(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ, false, false)
    RemoveVehiclesFromGeneratorsInArea(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ)

    local disablePedPaths = zone.disablePedPaths
    if disablePedPaths == nil then disablePedPaths = Config.Defaults.disablePedPaths end
    if disablePedPaths then
        SetPedPathsInArea(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ, false)
    end

    local disableRoadNodes = zone.disableRoadNodes
    if disableRoadNodes == nil then disableRoadNodes = Config.Defaults.disableRoadNodes end
    if disableRoadNodes then
        SetRoadsInArea(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ, false, false)
    end

    local allowEntering = zone.allowEnteringNPCs
    if allowEntering == nil then
        allowEntering = Config.Defaults.allowEnteringNPCs
    end

    -- REGLA DE LIMPIEZA: solo se eliminan (1) NPCs a pie y (2) vehículos con NPC dentro.
    -- Todo lo demás se queda: vehículos vacíos/estacionados, del jugador y de otros scripts.

    -- 1. "NPC con el coche": se borra el vehículo junto a sus ocupantes (antes que los peds,
    --    así el conductor no muere primero y el coche quede vacío e indistinguible)
    if not allowEntering then
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) and not IsVehicleProtected(veh) then
                local vehCoords = GetEntityCoords(veh)
                if IsPointInsideZone(vehCoords, zone) then
                    local occupants = {}
                    local blocked = false

                    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                        local ped = GetPedInVehicleSeat(veh, seat)
                        if ped ~= 0 and DoesEntityExist(ped) then
                            if IsPedProtected(ped) then
                                blocked = true -- ocupante protegido: el vehículo también se queda
                                break
                            end
                            occupants[#occupants + 1] = ped
                        end
                    end

                    -- Vacío o con ocupantes protegidos: no se toca
                    if not blocked and #occupants > 0 then
                        for i = 1, #occupants do
                            ForceDeleteEntity(occupants[i])
                        end
                        ForceDeleteEntity(veh)
                    end
                end
            end
        end
    end

    -- 2. Opcional (apagado por defecto): vehículos vacíos estacionados dentro de la zona
    local deleteParked = zone.disableParkedVehicles
    if deleteParked == nil then deleteParked = Config.Defaults.disableParkedVehicles end

    if deleteParked then
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) and not IsVehicleProtected(veh) then
                local vehCoords = GetEntityCoords(veh)
                if IsPointInsideZone(vehCoords, zone) then
                    local driver = GetPedInVehicleSeat(veh, -1)
                    if driver == 0 and GetEntitySpeed(veh) < 0.1 then
                        ForceDeleteEntity(veh)
                    end
                end
            end
        end
    end

    -- 3. "NPC andando": peatones ambientales dentro de la zona (solo modo drástico)
    if not allowEntering then
        local peds = GetGamePool('CPed')
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and not IsPedProtected(ped) then
                -- Si va en un vehículo que se mantiene, el NPC a bordo se mantiene también
                local pedVeh = GetVehiclePedIsIn(ped, false)
                if pedVeh == 0 or not IsVehicleProtected(pedVeh) then
                    local pedCoords = GetEntityCoords(ped)
                    if IsPointInsideZone(pedCoords, zone) then
                        ForceDeleteEntity(ped)
                    end
                end
            end
        end
    end

    -- Despacho de policías y emergencias en el área
    local disableCops = zone.disableCops
    if disableCops == nil then disableCops = Config.Defaults.disableCops end
    if disableCops then
        ClearAreaOfCops(meta.center.x, meta.center.y, meta.center.z, meta.boundingRadius, 0)
    end
end

-- Hilo 1: Verificación de distancias y polígonos (Optimizado)
CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- El jugador está subido a algo: protegemos ese vehículo antes de que se baje
        local currentVeh = GetVehiclePedIsIn(playerPed, false)
        if currentVeh ~= 0 then
            RememberPlayerVehicle(currentVeh)
        end

        local sleep = Config.Intervals.Far
        local newlyActive = {}
        local isInside = false
        local isNear = false

        for _, zone in ipairs(Config.Zones) do
            local meta = zone._meta
            if meta then
                local distToCenter = #(playerCoords.xy - meta.center.xy)
                local threshold = meta.boundingRadius + 100.0

                if distToCenter <= threshold then
                    isNear = true
                    table.insert(newlyActive, zone)

                    if IsPointInsideZone(playerCoords, zone) then
                        isInside = true
                        sleep = 0
                    else
                        if sleep > Config.Intervals.Near then
                            sleep = Config.Intervals.Near
                        end
                    end
                end
            end
        end

        insideAnyZone = isInside
        nearAnyZone = isNear
        currentActiveZones = newlyActive

        Wait(sleep)
    end
end)

-- Hilo 2: Supresión radical de densidad por fotograma cuando está cerca o dentro de la zona
CreateThread(function()
    while true do
        if insideAnyZone or nearAnyZone then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetAmbientVehicleRangeMultiplierThisFrame(0.0)
            SetAmbientPedRangeMultiplierThisFrame(0.0)

            SetGarbageTrucks(false)
            SetRandomBoats(false)
            SetRandomTrains(false)
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)
            SetDispatchCopsForPlayer(PlayerId(), false)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Hilo 3: Generadores y Barrido Drástico
CreateThread(function()
    while true do
        if (insideAnyZone or nearAnyZone) and #currentActiveZones > 0 then
            PruneRememberedVehicles()
            for _, zone in ipairs(currentActiveZones) do
                CleanZoneEntities(zone)
            end
            Wait(Config.Intervals.ClearSweep)
        else
            Wait(1000)
        end
    end
end)

-- Hilo 4: Dibujo 3D del Polígono en Modo Debug
CreateThread(function()
    while true do
        if debugEnabled then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, zone in ipairs(Config.Zones) do
                local meta = zone._meta
                if meta and zone.points then
                    local dist = #(playerCoords.xy - meta.center.xy)
                    if dist <= (meta.boundingRadius + 150.0) then
                        local pts = zone.points
                        local count = #pts
                        for i = 1, count do
                            local p1 = pts[i]
                            local p2 = pts[(i % count) + 1]

                            -- Línea inferior
                            DrawLine(p1.x, p1.y, meta.minZ, p2.x, p2.y, meta.minZ, 255, 0, 0, 255)
                            -- Línea superior
                            DrawLine(p1.x, p1.y, meta.maxZ, p2.x, p2.y, meta.maxZ, 255, 0, 0, 255)
                            -- Pilares verticales
                            DrawLine(p1.x, p1.y, meta.minZ, p1.x, p1.y, meta.maxZ, 255, 50, 50, 180)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(1500)
        end
    end
end)

-- Restauración al detener el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, zone in ipairs(Config.Zones) do
        local meta = zone._meta
        if meta then
            SetPedPathsBackToOriginal(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ)
            SetRoadsBackToOriginal(meta.minX, meta.minY, meta.minZ, meta.maxX, meta.maxY, meta.maxZ)
        end
    end
end)

-- Comando para alternar Debug
if Config.DebugCommand and Config.DebugCommand ~= '' then
    RegisterCommand(Config.DebugCommand, function()
        debugEnabled = not debugEnabled
        local status = debugEnabled and "^2ACTIVADO^0" or "^1DESACTIVADO^0"
        print(string.format("[redrox-antinpc] Modo Debug %s", status))
        TriggerEvent('chat:addMessage', {
            color = {255, 100, 100},
            multiline = true,
            args = {"Anti-NPC", string.format("Modo Debug %s (Polígonos 3D visibles en rojo)", debugEnabled and "Activado" or "Desactivado")}
        })
    end, false)
end
