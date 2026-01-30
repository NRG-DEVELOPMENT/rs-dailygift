local ESX, QBCore = nil, nil
local FRAMEWORK = nil

local function dprint(...)
  if Config.Debug then print('[rs_dailygift]', ...) end
end

local function DetectFramework()
  if Config.Framework ~= 'auto' then
    FRAMEWORK = Config.Framework
  else
    if GetResourceState('qb-core') == 'started' then
      FRAMEWORK = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
      FRAMEWORK = 'esx'
    end
  end

  if FRAMEWORK == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
    dprint('Framework: QBCore')
  elseif FRAMEWORK == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
    dprint('Framework: ESX')
  else
    print('[rs_dailygift] ERROR: No supported framework found (qb-core / es_extended).')
  end
end

local function SecondsUntilNextDay()
  local now = os.time()

  if Config.UtcDay then
    local utc = os.date('!*t', now)
    local secLeft = (23 - utc.hour) * 3600 + (59 - utc.min) * 60 + (60 - (utc.sec or 0))
    if secLeft < 0 then secLeft = 0 end
    return secLeft
  end

  local offsetSec = (Config.TimeOffsetMinutes or 0) * 60
  local adjNow = now + offsetSec
  local t = os.date('*t', adjNow)
  local secLeft = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - (t.sec or 0))
  if secLeft < 0 then secLeft = 0 end
  return secLeft
end

local function GetIdentifier(src)
  local license = GetPlayerIdentifierByType(src, 'license')
  if license and license ~= '' then return license end
  local ids = GetPlayerIdentifiers(src)
  return ids and ids[1] or tostring(src)
end

local function GetDayKey()
  if Config.UtcDay then
    return os.date('!%Y-%m-%d')
  end
  local now = os.time() + ((Config.TimeOffsetMinutes or 0) * 60)
  return os.date('%Y-%m-%d', now)
end

local function DayDiff(prevDay, nowDay)
  if not prevDay or prevDay == '' then return nil end
  local py, pm, pd = prevDay:match('^(%d+)%-(%d+)%-(%d+)$')
  local ny, nm, nd = nowDay:match('^(%d+)%-(%d+)%-(%d+)$')
  if not py or not ny then return nil end

  local prev = os.time({ year = tonumber(py), month = tonumber(pm), day = tonumber(pd), hour = 0 })
  local now  = os.time({ year = tonumber(ny), month = tonumber(nm), day = tonumber(nd), hour = 0 })
  return math.floor((now - prev) / 86400)
end

local function GetMaxRewardIndex()
  local maxIndex = 0
  for k in pairs(Config.Rewards) do
    if type(k) == 'number' and k > maxIndex then maxIndex = k end
  end
  return maxIndex
end

local function RewardForStreak(streak)
  local maxIndex = GetMaxRewardIndex()
  if maxIndex <= 0 then return nil end
  local idx = streak
  if idx < 1 then idx = 1 end
  if idx > maxIndex then idx = maxIndex end
  return Config.Rewards[idx], idx
end

local function DBFetch(identifier)
  return MySQL.single.await('SELECT * FROM rs_dailygift WHERE identifier = ?', { identifier })
end

local function DBUpsert(identifier, lastDay, streak, totalClaims)
  MySQL.insert.await([[
    INSERT INTO rs_dailygift (identifier, last_claim_day, streak, total_claims)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      last_claim_day = VALUES(last_claim_day),
      streak = VALUES(streak),
      total_claims = VALUES(total_claims)
  ]], { identifier, lastDay, streak, totalClaims })
end

local function AddMoney(src, account, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end

  if FRAMEWORK == 'qb' then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    Player.Functions.AddMoney(account or 'cash', amount, 'rs_dailygift')
    return true
  elseif FRAMEWORK == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local acc = account
    if acc == 'cash' then acc = 'money' end
    xPlayer.addAccountMoney(acc or 'money', amount)
    return true
  end

  return false
end

local function AddItem(src, item, amount)
  amount = tonumber(amount) or 1
  if not item or item == '' or amount <= 0 then return true end

  if Config.UseOxInventoryIfFound and GetResourceState('ox_inventory') == 'started' then
    return exports.ox_inventory:AddItem(src, item, amount) == true
  end

  if FRAMEWORK == 'qb' then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddItem(item, amount, false, nil, 'rs_dailygift') == true
  elseif FRAMEWORK == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.addInventoryItem(item, amount)
    return true
  end

  return false
end

local function AddWeapon(src, weapon, ammo)
  ammo = tonumber(ammo) or 0
  if not weapon or weapon == '' then return true end

  if FRAMEWORK == 'qb' then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddItem(weapon, 1, false, { ammo = ammo }, 'rs_dailygift') == true
  elseif FRAMEWORK == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.addWeapon(weapon, ammo)
    return true
  end

  return false
end


local function BuildSchedule()
  local maxIndex = GetMaxRewardIndex()
  local schedule = {}
  for i = 1, maxIndex do
    local pack = Config.Rewards[i]
    schedule[i] = {
      label = pack and pack.label or ('Day ' .. i),
      rewards = pack and pack.rewards or {},
    }
  end
  return schedule
end

local function GetState(src)
  local identifier = GetIdentifier(src)
  local today = GetDayKey()

  local row = DBFetch(identifier)
  local lastDay = row and row.last_claim_day or nil
  local streak = row and tonumber(row.streak) or 0
  local totalClaims = row and tonumber(row.total_claims) or 0

  local claimedToday = (lastDay == today)
  local canClaim = not claimedToday

  local diff = DayDiff(lastDay, today)
  local nextStreak

  if not lastDay or lastDay == '' then
    nextStreak = 1
  elseif diff == 0 then
    nextStreak = streak
  elseif diff == 1 then
    nextStreak = math.min((streak or 0) + 1, Config.MaxStreak or 9999)
  else
    nextStreak = Config.AllowLateStreak and math.min((streak or 0) + 1, Config.MaxStreak or 9999) or 1
  end

  local rewardPack, rewardIndex = RewardForStreak(nextStreak)
  local nextRewardIn = claimedToday and SecondsUntilNextDay() or 0

  return {
    playerName = GetPlayerName(src) or 'Citizen',
    today = today,
    lastClaimDay = lastDay,
    streak = streak,
    totalClaims = totalClaims,
    claimedToday = claimedToday,
    canClaim = canClaim,
    nextStreak = nextStreak,
    rewardIndex = rewardIndex,
    rewardPack = rewardPack,
    schedule = BuildSchedule(),
    nextRewardIn = nextRewardIn,
  }

end

local CLAIM_COOLDOWN = {}
local function Claim(src)
  local now = os.clock()
  if CLAIM_COOLDOWN[src] and (now - CLAIM_COOLDOWN[src]) < 1.0 then
    return false, Config.Notify.notReady
  end
  CLAIM_COOLDOWN[src] = now

  local state = GetState(src)
  if not state or not state.rewardPack then
    return false, Config.Notify.error
  end
  if not state.canClaim then
    return false, Config.Notify.already
  end

  for _, r in ipairs(state.rewardPack.rewards or {}) do
    if r.type == 'money' then
      if not AddMoney(src, r.account, r.amount) then return false, Config.Notify.error end
    elseif r.type == 'item' then
      if not AddItem(src, r.item, r.amount) then return false, Config.Notify.error end
    elseif r.type == 'weapon' then
      if not AddWeapon(src, r.weapon, r.ammo) then return false, Config.Notify.error end
    end
  end

  DBUpsert(GetIdentifier(src), state.today, state.nextStreak or 1, (state.totalClaims or 0) + 1)
  return true, Config.Notify.success
end

local function RegisterCallback(name, fn)
  if FRAMEWORK == 'qb' then
    QBCore.Functions.CreateCallback(name, fn)
  elseif FRAMEWORK == 'esx' then
    ESX.RegisterServerCallback(name, fn)
  else
    print(('[rs_dailygift] ERROR: cannot register callback %s (no framework)'):format(name))
  end
end

AddEventHandler('playerDropped', function()
  CLAIM_COOLDOWN[source] = nil
end)

CreateThread(function()
  if GetResourceState('oxmysql') ~= 'started' then
    print('[rs_dailygift] ERROR: oxmysql must be started.')
    return
  end

  DetectFramework()
  if not FRAMEWORK then return end

  RegisterCallback('rs_dailygift:server:getState', function(src, cb)
    cb(GetState(src))
  end)

  RegisterCallback('rs_dailygift:server:claim', function(src, cb)
    local ok, msg = Claim(src)
    cb({ ok = ok, message = msg, state = GetState(src) })
  end)

  dprint('Ready: callbacks registered')
end)
