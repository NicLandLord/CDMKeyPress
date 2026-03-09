local _, NS = ...

NS.L = NS.L or {}

setmetatable(NS.L, {
    __index = function(_, key)
        return key
    end,
})
