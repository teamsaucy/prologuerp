Config = {}

-----------------------------------------------------------
-- General
-----------------------------------------------------------
Config.PedModel = `s_m_y_valet_01`   -- Default ped at each garage
Config.SpawnCheck = true              -- Check if spawn point is blocked
Config.SpawnCheckRadius = 3.0         -- Radius to check for blocking vehicles
Config.StoreDistance = 50.0           -- Max distance from a garage to store via vehicle third-eye

-----------------------------------------------------------
-- Impound Settings
-----------------------------------------------------------
Config.Impounds = {
    {
        Label       = 'Bighorn Impound',
        Fee         = 250,
        Blip        = true,
        PedCoords   = vec4(495.7437, -1340.2141, 29.3140, 345.4031),
        SpawnCoords = vec4(493.1656, -1332.0089, 29.3375, 342.8277),
    },
    {
        Label       = 'Paleto Impound',
        Fee         = 250,
        Blip        = true,
        PedCoords   = vec4(-456.3851, 6017.8359, 31.4901, 44.8372),
        SpawnCoords = vec4(-459.9325, 6023.1787, 31.3406, 307.4375),
    },
    {
        Label       = 'Rockford Impound',
        Fee         = 250,
        Blip        = true,
        PedCoords   = vec4(-578.9381, -150.5773, 38.0918, 204.7228),
        SpawnCoords = vec4(-576.0179, -148.5452, 37.8627, 200.9310),
    },
}

-----------------------------------------------------------
-- Blip Settings
-----------------------------------------------------------
Config.Blips = {
    car     = { sprite = 357, color = 3, scale = 0.6, name = 'Garage' },
    boat    = { sprite = 356, color = 3, scale = 0.6, name = 'Boat Garage' },
    air     = { sprite = 360, color = 3, scale = 0.6, name = 'Air Garage' },
    impound = { sprite = 68,  color = 1, scale = 0.7, name = 'Impound Lot' },
}

-----------------------------------------------------------
-- GARAGES
-----------------------------------------------------------
-- PedCoords    = where the attendant stands (vec4: x, y, z, heading)
-- SpawnCoords  = where vehicles spawn when taken out (vec4: x, y, z, heading)
-- Type         = 'car', 'boat', or 'air'
-- Label        = name shown on blip and in the menu
-- Blip         = show map blip (true/false)
-- Job          = nil for public, or 'police' / {'police','mechanic'}
-- PedModel     = optional override for the ped model at this garage
-----------------------------------------------------------

Config.Garages = {

    -- ═══════════════════════════════════════════════════════
    -- Los Santos — Central
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'Spanish Ave',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(68.0727, 13.3646, 69.2144, 161.6792),
        SpawnCoords = vec4(68.6556, 22.6428, 69.4390, 250.8813),
    },
    {
        Label       = 'Legion Square Garage',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(213.7567, -808.8260, 31.0149, 157.4752),
        SpawnCoords = vec4(230.2162, -799.7570, 30.5670, 161.8764),
    },
    {
        Label       = 'Strawberry Ave',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(70.7330, -1567.2759, 29.5979, 60.8249),
        SpawnCoords = vec4(63.6212, -1554.7516, 29.4602, 141.6209),
    },

    -- ═══════════════════════════════════════════════════════
    -- Los Santos — West
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'Caesars Auto Parking',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-450.6230, -794.0045, 30.5406, 87.3950),
        SpawnCoords = vec4(-472.5199, -806.8965, 30.5387, 179.5600),
    },
    {
        Label       = 'San Andreas Ave',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-1160.3854, -741.1343, 19.6710, 138.0449),
        SpawnCoords = vec4(-1147.8677, -755.4274, 18.9593, 219.9625),
    },
    {
        Label       = 'Vespucci Beach Parking',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-1185.1196, -1508.1355, 4.3797, 34.3307),
        SpawnCoords = vec4(-1190.5188, -1494.5371, 4.3797, 221.2348),
    },
    {
        Label       = 'Jetty',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-1985.9463, -314.4799, 48.1063, 44.2962),
        SpawnCoords = vec4(-1980.0868, -329.1452, 47.4404, 236.4167),
    },

    -- ═══════════════════════════════════════════════════════
    -- Los Santos — North / Vinewood / Richman
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'The Richman Hotel',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-1282.2830, 295.9264, 64.9376, 157.7719),
        SpawnCoords = vec4(-1305.0089, 298.0337, 64.8351, 94.0749),
    },
    {
        Label       = 'Mirror Park',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(1035.9967, -763.6611, 57.9930, 324.3495),
        SpawnCoords = vec4(1040.6975, -777.0587, 58.0229, 356.3682),
    },

    -- ═══════════════════════════════════════════════════════
    -- Los Santos — Airport / South
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'Airport',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-984.4181, -2690.2324, 14.0127, 158.4820),
        SpawnCoords = vec4(-984.6629, -2697.1704, 13.8307, 59.3452),
    },

    -- ═══════════════════════════════════════════════════════
    -- Blaine County
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'Prison',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(1899.1682, 2604.2361, 45.9662, 181.4703),
        SpawnCoords = vec4(1892.2452, 2600.8965, 45.7176, 266.9300),
    },
    {
        Label       = 'Sandy Shores',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(1977.5800, 3753.6965, 32.1797, 218.9584),
        SpawnCoords = vec4(1983.3213, 3750.1589, 32.1733, 184.3461),
    },
    {
        Label       = 'Grapeseed',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(1954.8661, 4648.1133, 40.7084, 245.0754),
        SpawnCoords = vec4(1962.9180, 4642.8716, 40.7472, 294.4872),
    },
    {
        Label       = 'Paleto Bay',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(97.5457, 6368.3853, 31.3759, 9.3714),
        SpawnCoords = vec4(87.9748, 6367.6460, 31.2272, 6.1835),
    },
    {
        Label       = 'Chumash',
        Type        = 'car',
        Blip        = true,
        Job         = nil,
        PedCoords   = vec4(-3061.6125, 598.9788, 7.4620, 289.0407),
        SpawnCoords = vec4(-3041.0007, 602.1985, 7.5292, 290.7835),
    },

    -- ═══════════════════════════════════════════════════════
    -- Job Garages (no blip, custom ped)
    -- ═══════════════════════════════════════════════════════

    {
        Label       = 'Vespucci PD',
        Type        = 'car',
        Blip        = false,
        Job         = 'police',
        PedModel    = `s_m_y_cop_01`,
        PedCoords   = vec4(-1083.0912, -806.9584, 10.7802, 138.0405),
        SpawnCoords = vec4(-1098.4841, -816.0894, 11.0200, 128.7443),
    },
    {
        Label       = 'Ocean Med',
        Type        = 'car',
        Blip        = false,
        Job         = 'ambulance',
        PedModel    = `s_m_m_paramedic_01`,
        PedCoords   = vec4(-1834.7611, -380.0323, 40.7105, 46.6166),
        SpawnCoords = vec4(-1825.4946, -395.8384, 40.6171, 46.7658),
    },
    {
        Label       = 'Richman FD',
        Type        = 'car',
        Blip        = false,
        Job         = nil,
        PedModel    = `s_m_y_fireman_01`,
        PedCoords   = vec4(-1674.5879, 71.9915, 63.8507, 233.8722),
        SpawnCoords = vec4(-1668.1697, 65.5954, 63.5036, 275.3520),
    },
    {
        Label       = 'Mosleys Mechanic',
        Type        = 'car',
        Blip        = false,
        Job         = 'mechanic',
        PedModel    = `s_m_y_xmech_02`,
        PedCoords   = vec4(-34.6869, -1677.5381, 29.4773, 277.7912),
        SpawnCoords = vec4(-26.5244, -1679.8850, 29.4515, 110.6411),
    },
}

-----------------------------------------------------------
-- Society Vehicles (job vehicles available at job garages)
-----------------------------------------------------------
-- Key = job name, Value = list of vehicles available
-- label = display name, model = spawn code
-----------------------------------------------------------

Config.SocietyVehicles = {
    mechanic = {
        plate = 'MECHANIC',
        vehicles = {
            { label = 'Flatbed',  model = 'flatbed' },
        },
    },
    -- police = {
    --     plate = 'LSPD',
    --     vehicles = {
    --         { label = 'Police Cruiser',  model = 'police' },
    --         { label = 'Police Charger',  model = 'police2' },
    --     },
    -- },
    -- ambulance = {
    --     plate = 'EMS',
    --     vehicles = {
    --         { label = 'Ambulance',  model = 'ambulance' },
    --     },
    -- },
}
