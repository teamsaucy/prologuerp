Config = {}

Config.Framework = 'ESX'
Config.Locale = 'en'
Config.Sound = true
Config.Measurement = true          -- true = km, false = miles
Config.ShootingAlerts = true
Config.ShootingCooldown = 5        -- seconds
Config.BlipDeletion = 30           -- seconds
Config.AlertDismissTime = 5        -- seconds before alert auto-dismisses from HUD

Config.DispatcherJob = 'police'
Config.Jobs = {'police', 'ambulance'}
Config.DefaultDispatchNumber = '0A-00'

Config.AllowedJobs = {
    ["police"] = {
        name = 'police',
        label = 'LSPD',
        command = 'alert',
        descriptcommand = 'Send an alert to LSPD',
        panic = true
    },
    ["ambulance"] = {
        name = 'ambulance',
        label = 'EMS',
        command = 'alertems',
        descriptcommand = 'Send an alert to EMS',
        panic = true
    }
}
