local type_o = type

function type(...)
    if select('#', ...) == 0 then
        return "no value"
    else
        return type_o(...)
    end
end

isnumber = isnumber or function(variable)
    return type(variable) == "number"
end

isstring = isstring or function(variable)
    return type(variable) == "string"
end

isfunction = isfunction or function(variable)
    return type(variable) == "function"
end

istable = istable or function(variable)
    return type(variable) == "table"
end

isbool = isbool or function(variable)
    return type(variable) == "boolean"
end
