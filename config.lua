Config = Config or {}

-- 'auto' will try QB first, then ESX
Config.Framework = 'auto' -- 'qb' | 'esx' | 'auto'

Config.Debug = false

-- Time handling
-- Uses UTC day key by default. If you want “UK midnight” or similar, use an offset.
Config.UtcDay = true
Config.TimeOffsetMinutes = 0 -- applies if UtcDay = false (offset from server local time)

-- How players open UI (UI not included yet; this just triggers the flow)
Config.OpenCommand = 'daily'
Config.OpenKey = '' -- optional: e.g. 'F7' (leave blank to disable key mapping)

-- Reward rules
Config.AllowLateStreak = false  -- if false: missing a day resets streak
Config.MaxStreak = 30           -- cap streak growth
Config.OneClaimPerDay = true

-- Reward table by day index (streak day).
-- If streak exceeds table length, it will use the last entry.
-- reward entries support:
--   type = 'money'  -> account = 'cash'|'bank' (QB) / 'money'|'bank' (ESX)
--   type = 'item'   -> item, amount
--   type = 'weapon' -> weapon, ammo
Config.Rewards = {
    [1] = {
        label = 'Welcome Gift',
        rewards = {
            { type = 'money', account = 'cash', amount = 500 },
            { type = 'item', item = 'water', amount = 2 },
        }
    },
    [2] = {
        label = 'Daily Boost',
        rewards = {
            { type = 'money', account = 'bank', amount = 1000 },
            { type = 'item', item = 'radio', amount = 2 },
        }
    },
    [3] = {
        label = 'Utility Pack',
        rewards = {
            { type = 'item', item = 'lockpick', amount = 1 },
            { type = 'money', account = 'cash', amount = 750 },
        }
    },
    [4] = {
        label = 'Big Day',
        rewards = {
            { type = 'money', account = 'bank', amount = 2500 },
        }
    },
    [5] = {
        label = 'Lucky Pull',
        rewards = {
            { type = 'item', item = 'radio', amount = 1 },
        }
    },
}

Config.Notify = {
    success = 'Daily gift claimed!',
    already = 'You already claimed today.',
    notReady = 'Not ready yet.',
    error = 'Something went wrong.',
}

Config.UseOxInventoryIfFound = false
