# 🛑 redrox-antinpc

Script optimizado y autónomo para **FiveM** que controla y elimina la aparición de NPCs ambientales y tráfico en polígonos/zonas delimitadas específicas.

## 🚀 Características Principales

* **Modo Drástico Activado por Defecto**: Elimina solo los **NPCs a pie** y los **vehículos con NPC a bordo** dentro del polígono. Los vehículos vacíos, estacionados, del jugador o de otros scripts **no se tocan**.
* **Bloqueo a Nivel de Motor (Nativo GTA V)**:
  * `SetPedNonCreationArea`: Impide que el motor de GTA intente generar peds en la zona.
  * `SetPedPathsInArea`: Bloquea las mallas de navegación para que los peatones de afuera no caminen hacia la zona.
  * `SetRoadsInArea`: Bloquea los nodos viales para que los vehículos no circulen hacia la zona.
  * `SetAllVehicleGeneratorsActiveInArea` & `RemoveVehiclesFromGeneratorsInArea`: Apagan generadores automáticos de vehículos.
* **Supresión Anticipada**: Aplica supresión por fotograma desde que el jugador se aproxima a la zona, evitando que aparezcan en el encuadre de la cámara.
* **Protección de Jugadores y Scripts**: Protege al 100% a los jugadores, a los vehículos que el jugador ya ocupó (incluso cuando se baja y queda vacío), vehículos con jugadores, y NPCs registrados vía exports o state bags (`ignoreAntiNpc`, `isScriptPed`).
* **Entidades de otros scripts intactas**: Cualquier ped o vehículo creado por otro recurso se ignora en la limpieza: adornos, guardias, previews y props de otros scripts **no desaparecen**.
* **Vehículos vacíos intactos**: Por defecto ningún coche sin NPC se elimina. Si querés que también barra los estacionados aleatorios, activá `disableParkedVehicles = true` en `config.lua`.
* **Soporte PolyZone Nativo**: Delimitación exacta por vértices/puntos 3D sin dependencias externas.

---

## 🗺️ Zonas Configuradas (`config.lua`)

Actualmente tenés configurados los dos mapeados por polígono:
1. **MECANICO SAKURA MISHU** (8 vértices)
2. **Cardealer S4VAGEE** (4 vértices)

```lua
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
