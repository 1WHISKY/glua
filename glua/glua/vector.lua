if Vector then return end

local vm = {}
RegisterMetaTable("Vector", vm)


function vm.__tostring(v)
    return tostring(v._x) .. " " .. tostring(v._y) .. " " .. tostring(v._z)
end

function vm.__newindex(v, i, val)
    local num = tonumber(val or nil)

    if !num then error("bad argument #3 to '__newindex' (number expected, got " .. type(val) .. ")") end

    if i == 1 then v._x = num return end
    if i == 2 then v._y = num return end
    if i == 3 then v._z = num return end

    if i == "x" then v._x = num return end
    if i == "y" then v._y = num return end
    if i == "z" then v._z = num return end
end

function vm.__index(v, i)
    if i == 1 then return v._x end
    if i == 2 then return v._y end
    if i == 3 then return v._z end

    if i == "x" then return v._x end
    if i == "y" then return v._y end
    if i == "z" then return v._z end

    return vm[i]
end

function vm.__add(v1, v2)
    if getmetatable(v2) != vm then error("bad argument #2 to '__add' (Vector expected, got " .. type(v2) .. ")") end

    return Vector(v1._x + v2._x, v1._y + v2._y, v1._z + v2._z)
end

function vm.__sub(v1, v2)
    if getmetatable(v2) != vm then error("bad argument #2 to '__sub' (Vector expected, got " .. type(v2) .. ")") end

    return Vector(v1._x - v2._x, v1._y - v2._y, v1._z - v2._z)
end

function vm.__div(v1, v2)
    if getmetatable(v2) != vm and !isnumber(v2) then error("bad argument #2 to '__div' (number expected, got " .. type(v2) .. ")") end

    if isnumber(v2) then
       return Vector(v1._x / v2, v1._y / v2, v1._z / v2)
    end

    return Vector(v1._x / v2._x, v1._y / v2._y, v1._z / v2._z)
end

function vm.__mul(v1, v2)
    if getmetatable(v2) != vm and !isnumber(v2) then error("bad argument #2 to '__mul' (number expected, got " .. type(v2) .. ")") end

    if isnumber(v2) then
       return Vector(v1._x * v2, v1._y * v2, v1._z * v2)
    end

    return Vector(v1._x * v2._x, v1._y * v2._y, v1._z * v2._z)
end

function vm.__eq(v1, v2)
    if getmetatable(v2) != vm then return false end

    return v1._x == v2._x and v1._y == v2._y and v1._z == v2._z
end

function vm.__unm(v1)
    return Vector(-v1._x, -v1._y, -v1._z)
end


function vm:Add(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Add' (Vector expected, got " .. type(v) .. ")") end

    self._x = self._x + v._x
    self._y = self._y + v._y
    self._z = self._z + v._z
end

function vm:Angle()
    local yaw = math.atan2(self._y, self._x)
    local pitch = -math.asin(self._z)

    return Angle(math.deg(pitch), math.deg(yaw), 0)
end


function vm:AngleEx(up)
    if getmetatable(up) != vm then error("bad argument #1 to 'AngleEx' (Vector expected, got " .. type(up) .. ")") end

    local yaw = math.atan2(self._y, self._x)
    local pitch = -math.asin(self._z)

    local local_up = Vector(
        math.sin(pitch) * math.cos(yaw),
        math.sin(pitch) * math.sin(yaw),
        math.cos(pitch)
    )

    local dot_roll = local_up:Dot(up)
    if dot_roll > 1 then dot_roll = 1 end
    if dot_roll < -1 then dot_roll = -1 end

    local roll = math.acos(dot_roll)
    local cross_roll = local_up:Cross(up)

    if cross_roll:Dot(self) < 0 then
        roll = -roll
    end


    return Angle(math.deg(pitch), math.deg(yaw), math.deg(roll))
end

function vm:Cross(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Cross' (Vector expected, got " .. type(v) .. ")") end

    return Vector(
        self._y * v._z - self._z * v._y,
        self._z * v._x - self._x * v._z,
        self._x * v._y - self._y * v._x
    )
end

function vm:Distance(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Distance' (Vector expected, got " .. type(v) .. ")") end

    return math.sqrt( math.pow(self._x - v._x, 2) + math.pow(self._y - v._y, 2) + math.pow(self._z - v._z, 2))
end

function vm:Distance2D(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Distance2D' (Vector expected, got " .. type(v) .. ")") end

    return math.sqrt( math.pow(self._x - v._x, 2) + math.pow(self._y - v._y, 2))
end

function vm:Distance2DSqr(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Distance2DSqr' (Vector expected, got " .. type(v) .. ")") end

    return math.pow(self._x - v._x, 2) + math.pow(self._y - v._y, 2)
end

function vm:DistToSqr(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'DistToSqr' (Vector expected, got " .. type(v) .. ")") end

    return math.pow(self._x - v._x, 2) + math.pow(self._y - v._y, 2) + math.pow(self._z - v._z, 2)
end

function vm:Div(v)
    if getmetatable(v) != vm and !isnumber(v) then error("bad argument #1 to 'Div' (number expected, got " .. type(v) .. ")") end

    if isnumber(v) then
        self._x = self._x / v
        self._y = self._y / v
        self._z = self._z / v
        return
    end

    self._x = self._x / v._x
    self._y = self._y / v._y
    self._z = self._z / v._z
end

function vm:Dot(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Dot' (Vector expected, got " .. type(v) .. ")") end

    return self._x * v._x + self._y * v._y + self._z * v._z
end

function vm:DotProduct(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'DotProduct' (Vector expected, got " .. type(v) .. ")") end

    return self:Dot(v)
end

function vm:GetNegated()
    return Vector(-self._x, -self._y, -self._z)
end

function vm:GetNormalized()
    local mag = self:Length()
    if mag == 0 then return Vector(0, 0, 0) end

    return Vector(self._x / mag, self._y / mag, self._z / mag)
end

function vm:GetNormal()
    return self:GetNormalized()
end

function vm:IsEqualTol(v, tolerance)
    if getmetatable(v) != vm then error("bad argument #1 to 'IsEqualTol' (Vector expected, got " .. type(v) .. ")") end
    if !isnumber(tolerance) then error("bad argument #2 to 'IsEqualTol' (number expected, got " .. type(tolerance) .. ")") end

    if math.abs(self._x - v._x) > tolerance then return false end
    if math.abs(self._y - v._y) > tolerance then return false end
    if math.abs(self._z - v._z) > tolerance then return false end

    return true
end

function vm:IsZero()
    return self._x == 0 and self._y == 0 and self._z == 0
end

function vm:Length()
    return math.sqrt( math.pow(self._x, 2) + math.pow(self._y, 2) + math.pow(self._z, 2) )
end

function vm:LengthSqr()
    return math.pow(self._x, 2) + math.pow(self._y, 2) + math.pow(self._z, 2)
end

function vm:Length2D()
    return math.sqrt( math.pow(self._x, 2) + math.pow(self._y, 2) )
end

function vm:Length2DSqr()
    return math.pow(self._x, 2) + math.pow(self._y, 2)
end

function vm:Mul(v)
    if getmetatable(v) != vm and !isnumber(v) then error("bad argument #1 to 'Mul' (number expected, got " .. type(v) .. ")") end

    if isnumber(v) then
        self._x = self._x * v
        self._y = self._y * v
        self._z = self._z * v
        return
    end

    self._x = self._x * v._x
    self._y = self._y * v._y
    self._z = self._z * v._z
end

function vm:Negate()
    self._x = -self._x
    self._y = -self._y
    self._z = -self._z
end

function vm:Normalize()
    local mag = self:Length()
    if mag == 0 then
        self:Zero()
        return
    end

    self._x = self._x / mag
    self._y = self._y / mag
    self._z = self._z / mag
end

function vm:Random(min, max)
    if !isnumber(min) and min != nil then error("bad argument #1 to 'Random' (number expected, got " .. type(min) .. ")") end
    if !isnumber(max) and max != nil then error("bad argument #2 to 'Random' (number expected, got " .. type(max) .. ")") end
    min = min or -1
    max = max or 1

    self._x = math.Rand(min, max)
    self._y = math.Rand(min, max)
    self._z = math.Rand(min, max)
end

function vm:Rotate(ang)
    local mt = getmetatable(ang)
    if !mt or mt.MetaName != "Angle" then error("bad argument #1 to 'Rotate' (Angle expected, got " .. type(ang) .. ")") end

    local pitch_rad = math.rad(ang.pitch)
    local yaw_rad   = math.rad(ang.yaw)
    local roll_rad  = math.rad(ang.roll)

    local y1 = self._y * math.cos(roll_rad) - self._z * math.sin(roll_rad)
    local z1 = self._y * math.sin(roll_rad) + self._z * math.cos(roll_rad)

    local x2 = self._x * math.cos(pitch_rad) + z1 * math.sin(pitch_rad)

    self._z = -self._x * math.sin(pitch_rad) + z1 * math.cos(pitch_rad)
    self._x = x2 * math.cos(yaw_rad) - y1 * math.sin(yaw_rad)
    self._y = x2 * math.sin(yaw_rad) + y1 * math.cos(yaw_rad)

end

function vm:Set(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Set' (Vector expected, got " .. type(v) .. ")") end

    self._x = v._x
    self._y = v._y
    self._z = v._z
end

function vm:SetUnpacked(x, y, z)
    if !isnumber(x) then error("bad argument #1 to 'SetUnpacked' (number expected, got " .. type(x) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'SetUnpacked' (number expected, got " .. type(y) .. ")") end
    if !isnumber(z) then error("bad argument #3 to 'SetUnpacked' (number expected, got " .. type(z) .. ")") end

    self._x = x
    self._y = y
    self._z = z
end

function vm:Sub(v)
    if getmetatable(v) != vm then error("bad argument #1 to 'Sub' (Vector expected, got " .. type(v) .. ")") end

    self._x = self._x - v._x
    self._y = self._y - v._y
    self._z = self._z - v._z
end

function vm:ToColor()
    local r = self._x * 255
    local g = self._y * 255
    local b = self._z * 255

    return Color( math.min(r, 255), math.min(g, 255), math.min(b, 255) )
end

function vm:ToScreen()
    return {x = 0, y = 0, visible = false}    //placeholder
end

function vm:Unpack()
    return self._x, self._y, self._z
end

function vm:ToTable()
    return {self._x, self._y, self._z}
end

function vm:WithinAABox(start, end1)
    if getmetatable(start) != vm then error("bad argument #1 to 'WithinAABox' (Vector expected, got " .. type(start) .. ")") end
    if getmetatable(end1) != vm then error("bad argument #2 to 'WithinAABox' (Vector expected, got " .. type(end1) .. ")") end

    return self._x >= math.min(start._x, end1._x) and self._x <= math.max(start._x, end1._x) and
           self._y >= math.min(start._y, end1._y) and self._y <= math.max(start._y, end1._y) and
           self._z >= math.min(start._z, end1._z) and self._z <= math.max(start._z, end1._z)
end

function vm:Zero()
    self._x = 0
    self._y = 0
    self._z = 0
end


function Vector(x, y, z)
    local v = {_x = 0, _y = 0, _z = 0}
    setmetatable(v, vm)

    if getmetatable(x) == vm then
        v._x = x._x
        v._y = x._y
        v._z = x._z
        return v
    end

    if isstring(x) then
        local val = string.Split(x, " ")

        if #val >= 3 then
            local a = tonumber(val[1])
            local b = tonumber(val[2])
            local c = tonumber(val[3])

            if a and b and c then
                v._x = a
                v._y = b
                v._z = c
                return v
            end
        end

        local num = tonumber(x)
        if num then v._x = num end
    end

    if isnumber(x) then
       v._x = x
    end

    if isnumber(y) then
       v._y = y
    end

    if isstring(y) then
        local num = tonumber(y)
        if num then v._y = num end
    end

    if isnumber(z) then
       v._z = z
    end

    if isstring(z) then
        local num = tonumber(z)
        if num then v._z = num end
    end

    return v
end
