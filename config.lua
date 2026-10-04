Config = {}

-- Modo depuración: dibuja las líneas perimetrales de los polígonos en el juego
Config.Debug = false
Config.DebugCommand = 'antinpc_debug' -- Comando para activar/desactivar visualización de zonas en cliente (/antinpc_debug)

-- Intervalos de comprobación (en ms) para optimizar el consumo a 0.00ms cuando estás lejos
Config.Intervals = {
    Far = 1000,        -- Cuando el jugador está lejos de cualquier zona
    Near = 200,        -- Cuando el jugador está cerca del perímetro de una zona (a menos de 80m)
    ClearSweep = 250   -- Intervalo de barrido drástico de entidades dentro de la zona
}

-- Opciones por defecto aplicadas a todas las zonas
Config.Defaults = {
    disablePeds = true,            -- Desactivar generación de peatones dentro de la zona
    disableVehicles = true,        -- Desactivar generación de tráfico dentro de la zona
    disableParkedVehicles = false, -- true: además elimina vehículos VACÍOS estacionados dentro de la zona (false = solo se borran NPCs a pie y vehículos con NPC a bordo)
    disableScenarios = true,       -- Desactivar peds en puntos de escenario
    disableCops = true,            -- Desactivar generación aleatoria de policías/servicios de emergencia
    disablePedPaths = true,        -- Cortar rutas de navegación peatonal (la IA no puede caminar hacia la zona)
    disableRoadNodes = true,       -- Cortar nodos de carretera (el tráfico no puede circular hacia la zona)
    
    -- false: MODO DRÁSTICO (Elimina de raíz a TODOS los NPCs y vehículos ambientales que pisen o estén en la zona)
    -- true: Deja pasar a los NPCs que vengan desde afuera de la zona hacia adentro (no recomendado si querés la zona 100% limpia)
    allowEnteringNPCs = false,
}

-- Lista de Zonas / Polígonos delimitados
Config.Zones = {
    {
        name = "MECANICO SAKURA MISHU",
        minZ = 20.0,
        maxZ = 60.0,
        points = {
            vector3(-160.7131, -1379.4072, 29.7304),
            vector3(-178.3182, -1350.0455, 31.1279),
            vector3(-178.1164, -1299.9580, 31.0739),
            vector3(-259.3757, -1299.7760, 31.1284),
            vector3(-258.7410, -1416.3396, 31.1155),
            vector3(-226.7830, -1415.0912, 30.9609),
            vector3(-207.0217, -1407.8690, 31.1108),
            vector3(-180.0735, -1391.8466, 30.5292),
        }
    },
    {
        name = "Cardealer S4VAGEE",
        minZ = 0.0,
        maxZ = 40.0,
        points = {
            vector3(-1631.4086, -788.7123, 10.1315),
            vector3(-1731.6818, -703.5717, 9.9405),
            vector3(-1786.9301, -770.8130, 8.7776),
            vector3(-1685.1559, -855.2253, 8.6911),
        }
    }
}
