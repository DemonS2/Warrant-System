Config = {}

-- Warrant settings
Config.AutoExpiryCheck = true -- Check for expired warrants automatically
Config.ExpiryCheckInterval = 60000 -- Check every minute (in ms)

-- Bounty settings
Config.MaxBounty = 100000 -- Maximum bounty amount
Config.MinBounty = 0 -- Minimum bounty amount

-- Permission settings
Config.AllowedJobs = {
    'police',
    'sheriff'
    -- Add other law enforcement jobs as needed
}

-- Treasury settings
Config.TreasuryAccount = 'police' -- Account name for treasury deductions

-- UI Settings
Config.TabletKey = 'F6' -- Key to open warrant tablet