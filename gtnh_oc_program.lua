-- GTNH OpenComputers starter program
-- This template is for GregTech New Horizons OC machines.
-- Customize the actions below for your own automation needs.

local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")

local gpu = component.gpu
local screen = component.screen
local filesystem = component.filesystem
local modem = component.modem
local redstone = component.redstone

local width, height = gpu.getResolution()

local function clear()
  term.clear()
  term.setCursor(1, 1)
end

local function drawHeader()
  clear()
  gpu.set(1, 1, "GTNH OC Program")
  gpu.set(1, 2, string.rep("-", math.min(width, 80)))
end

local function waitKey()
  repeat
    local _, _, _, _, key = event.pull("key_down")
    if key then
      return key
    end
  until false
end

local function getSystemInfo()
  local info = {
    ["Uptime"] = tostring(computer.uptime()) .. "s",
    ["Free Memory"] = tostring(computer.freeMemory()) .. " bytes",
    ["Total Memory"] = tostring(computer.totalMemory()) .. " bytes",
    ["Filesystem"] = filesystem.getLabel("/") or "root",
    ["GPU"] = component.isAvailable("gpu") and component.gpu.address or "none",
    ["Screen"] = component.isAvailable("screen") and component.screen.address or "none",
  }
  return info
end

local function showSystemInfo()
  drawHeader()
  local info = getSystemInfo()
  local row = 4
  for k, v in pairs(info) do
    gpu.set(2, row, string.format("%s: %s", k, v))
    row = row + 1
  end
  gpu.set(2, row + 1, "Press any key to return to menu...")
  waitKey()
end

local function redstoneTest()
  drawHeader()
  gpu.set(2, 4, "Redstone output test on all sides...")
  for side = 0, 5 do
    pcall(function()
      redstone.setOutput(side, 15)
      redstone.setOutput(side, 0)
    end)
  end
  gpu.set(2, 6, "Done. Press any key to continue.")
  waitKey()
end

local function showMenu()
  drawHeader()
  gpu.set(2, 4, "1) Show system info")
  gpu.set(2, 5, "2) Redstone test")
  gpu.set(2, 6, "3) Exit")
  gpu.set(2, 8, "Choose an option:")
  local choice = nil
  repeat
    local _, _, _, _, key = event.pull("key_down")
    if key == 2 or key == 49 then choice = 1 end
    if key == 3 or key == 50 then choice = 2 end
    if key == 4 or key == 51 then choice = 3 end
  until choice
  return choice
end

local function main()
  while true do
    local choice = showMenu()
    if choice == 1 then
      showSystemInfo()
    elseif choice == 2 then
      redstoneTest()
    elseif choice == 3 then
      clear()
      return
    end
  end
end

main()
