local component = require("component")
local sides = require("sides")
local os = require("os")
local computer = require("computer")

local mec = component.me_controller
local transposer = component.transposer
local redstone = component.redstone


-- ================= 配置 =================
local TARGET_AMOUNT = 114514
local CACHE_TTL = 5
local TIMEOUT = 120

local redstoneSide = sides.up
local inputSide = sides.up
local outputSide = sides.down
local brkSide = sides.west -- 方块破坏器的方向

-- ================= 日志系统 =================
local function log(level, msg)
  print(string.format("[%s][%f] %s", level, computer.uptime(), msg))
  --print(string.format("[%s] %s", level, msg))
end

-- ================= 缓存 =================
local cache = {}
local lastUpdate = 0

-- 用于存储世界加速器组件
local gtmAccelerator = {}

-- 初始化世界加速器
local function initAccelerators()
  for address, type in pairs(component.list()) do
    if type == "gt_machine" then
      table.insert(gtmAccelerator, component.proxy(address))
    end
  end
end

-- 设置所有加速器状态
local function setAccelerator(state)
  for _, accelerator in ipairs(gtmAccelerator) do
    if accelerator.isMachineActive() ~= state then
      accelerator.setWorkAllowed(state)
    end
  end
end

local function refreshCache(force)
  local now = computer.uptime()
  if not force and (now - lastUpdate < CACHE_TTL) then
    return cache
  end

  local newMap = {}
  local list = mec.getEssentiaInNetwork()

  if list then
    for _, e in ipairs(list) do
      local name = string.sub(e.name, 8, #e.name - 8)
      if name then
        newMap[string.lower(name)] = e.amount
      end
    end
  end

  cache = newMap
  lastUpdate = now
  return cache
end

-- ================= 工具函数 =================
local function pulse(side)
  redstone.setOutput(side, 15)
  os.sleep(0.5)
  redstone.setOutput(side, 0)
end

local function safeTransfer(from, to, slot)
  local moved = transposer.transferItem(from, to, 1, slot)
  return moved and moved > 0
end

-- ================= 扫描需求 =================
local function scanDemand()
  local demand = {}

  local size = transposer.getInventorySize(inputSide) or 0
  for slot = 1, size do
    local stack = transposer.getStackInSlot(inputSide, slot)

    if stack and stack.aspects then
      for _, aspect in pairs(stack.aspects) do
        local name = string.lower(aspect.name)
        demand[name] = (demand[name] or 0) + aspect.amount
      end
    end
  end

  return demand
end

-- ================= 选目标 =================
local function pickTarget(demand, cacheMap)
  local best = nil
  local maxDeficit = 0

  for name, _ in pairs(demand) do
    local current = cacheMap[name] or 0
    local deficit = TARGET_AMOUNT - current

    if deficit > maxDeficit then
      maxDeficit = deficit
      best = name
    end
  end

  return best, maxDeficit
end

-- ================= 等待（不会卡死） =================
local function waitFor(target, baseline)
  local start = computer.uptime()
  local last = baseline or 0
  local stagnate = 0
  local progressed = false

  repeat
    os.sleep(3)

    local map = refreshCache(true)
    local val = map[target] or 0

    if val > last then
      log("DEBUG", target .. " 增长: " .. last .. " -> " .. val)
      last = val
      progressed = true
      stagnate = 0

      if val >= TARGET_AMOUNT then
        return true, true
      end
    elseif val == last then
      stagnate = stagnate + 1
    else
      last = val
      stagnate = 0
    end
  until computer.uptime() - start > TIMEOUT or stagnate >= 3

  if progressed then
    log("INFO", target .. " 本轮结束，当前=" .. last)
    return true, last >= TARGET_AMOUNT
  end

  log("WARN", target .. " 无明显变化")
  return false, false
end

initAccelerators()
setAccelerator(true)

local currentTarget = nil

-- ================= 主循环 =================
while true do
  local cacheMap = refreshCache(false)
  local demand = scanDemand()

  if currentTarget then
    if not demand[currentTarget] then
      log("DEBUG", "释放目标（已无需求）：" .. currentTarget)
      currentTarget = nil
    elseif (cacheMap[currentTarget] or 0) >= TARGET_AMOUNT then
      log("DEBUG", "释放目标（已补满）：" .. currentTarget)
      currentTarget = nil
    end
  end

  local target, deficit
  if currentTarget then
    target = currentTarget
    deficit = TARGET_AMOUNT - (cacheMap[target] or 0)
  else
    target, deficit = pickTarget(demand, cacheMap)
    currentTarget = target
  end

  if target and deficit > 0 then
    log("INFO", "补充源质：" .. target .. " 缺口=" .. deficit)

    local size = transposer.getInventorySize(inputSide) or 0
    local triggered = false

    for slot = 1, size do
      local stack = transposer.getStackInSlot(inputSide, slot)

      if stack and stack.aspects then
        for _, aspect in pairs(stack.aspects) do
          if string.lower(aspect.name) == target then
            if safeTransfer(inputSide, outputSide, slot) then
              pulse(brkSide)
              pulse(redstoneSide)
              transposer.transferItem(outputSide, inputSide, 1)

              triggered = true
              break
            end
          end
        end
      end

      if triggered then break end
    end

    if triggered then
      setAccelerator(true)

      local ok, filled = waitFor(target, cacheMap[target] or 0)

      if ok then
        if filled then
          currentTarget = nil
        else
          currentTarget = target
        end
        os.sleep(1)
      else
        --setAccelerator(false)
        currentTarget = nil
      end
    else
      log("ERROR", "未找到可触发物品: " .. target)
      currentTarget = nil
      setAccelerator(false)
      os.sleep(2)
    end
  else
    currentTarget = nil
    setAccelerator(false)

    log("DEBUG", "所有源质已满足")
    os.sleep(5)
  end
end