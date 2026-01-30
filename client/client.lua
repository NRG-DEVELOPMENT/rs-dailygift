local ESX = nil
local isOpen = false

local function Notify(msg, nType)
  msg = tostring(msg or '')
  if msg == '' then return end

  if lib and lib.notify then
    lib.notify({
      title = 'Daily Gift',
      description = msg,
      type = nType or 'inform', 
      position = 'top-right'
    })
    return
  end

  TriggerEvent('chat:addMessage', { args = { '^5Daily Gift', msg } })
end

RegisterNetEvent('rs_dailygift:client:notify', function(msg, nType)
  Notify(msg, nType)
end)

RegisterNetEvent('rs_dailygift:client:notify', function(msg)
  Notify(msg)
end)

local function IsQB()
  return GetResourceState('qb-core') == 'started'
end

local function GetState(cb)
  if IsQB() then
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.TriggerCallback('rs_dailygift:server:getState', cb)
  else
    ESX = ESX or exports['es_extended']:getSharedObject()
    ESX.TriggerServerCallback('rs_dailygift:server:getState', cb)
  end
end

local function Claim(cb)
  if IsQB() then
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.TriggerCallback('rs_dailygift:server:claim', cb)
  else
    ESX = ESX or exports['es_extended']:getSharedObject()
    ESX.TriggerServerCallback('rs_dailygift:server:claim', cb)
  end
end

local function Open()
  if isOpen then return end
  GetState(function(state)
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', state = state })
  end)
end

local function Close()
  if not isOpen then return end
  isOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.OpenCommand or 'daily', function()
  Open()
end, false)

if Config.OpenKey and Config.OpenKey ~= '' then
  RegisterKeyMapping(Config.OpenCommand or 'daily', 'Open Daily Gift', 'keyboard', Config.OpenKey)
end

RegisterNUICallback('close', function(_, cb)
  Close()
  cb({ ok = true })
end)

RegisterNUICallback('getState', function(_, cb)
  GetState(function(state) cb(state) end)
end)

RegisterNUICallback('claim', function(_, cb)
  Claim(function(result)
    if result and result.message then
      local nType = (result.ok and 'success') or 'error'
      if result.message == Config.Notify.already or result.message == Config.Notify.notReady then
        nType = 'inform'
      end
      Notify(result.message, nType)
    end
    cb(result)
  end)
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    Close()
  end
end)
