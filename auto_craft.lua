local component = require("component")

local me = component.me_controller

local c = me.getCraftables({
    label = "电路板"
})

local job = c[1].request(1)

print(job)
print(type(job))