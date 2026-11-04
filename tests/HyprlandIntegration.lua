-- Execute the real integration with a recording public API. Startup callbacks
-- and compositor dispatchers are recorded, never run in the user's session.
local submap = ""
hl = {
    on = function() end,
    version = function() return "test" end,
    config = function() end,
    plugin = { load = function() end },
    dsp = setmetatable({}, {
        __index = function(_, name)
            return function(value) return { name = name, value = value } end
        end,
    }),
    bind = function(key, action)
        if submap == "" and type(action) == "table" and action.name == "global"
            and action.value == "shell:taskManager" then
            print("taskManager " .. key)
        end
    end,
    define_submap = function(name, body)
        submap = name
        body()
        submap = ""
    end,
    layer_rule = function(rule)
        if rule.name == "shell-auth" then
            print("auth " .. rule.match.namespace .. " " .. tostring(rule.order) .. " " .. tostring(rule.no_anim))
        end
    end,
}
dofile(arg[1])
