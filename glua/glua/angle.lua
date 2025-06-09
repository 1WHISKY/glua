if Angle then return end

local am = {}
RegisterMetaTable("Angle", am)


function am.__tostring(a)
    return tostring(a._p) .. " " .. tostring(a._y) .. " " .. tostring(a._r)
end

function am.__newindex(a, i, val)
    local num = tonumber(val or nil)

    if !num then error("bad argument #3 to '__newindex' (number expected, got " .. type(val) .. ")") end

    if i == 1 or i == "pitch" or i == "p" or i == "x" then a._p = num return end
    if i == 2 or i == "yaw" or i == "y" then a._y = num return end
    if i == 3 or i == "roll" or i == "r" or i == "z" then a._r = num return end

end

function am.__index(a, i)
    if i == 1 or i == "pitch" or i == "p"  or i == "x" then return a._p end
    if i == 2 or i == "yaw" or i == "y" then return a._y end
    if i == 3 or i == "roll" or i == "r"  or i == "z" then return a._r end


    return am[i]
end

function am.__add(a1, a2)
    if getmetatable(a2) != am then error("bad argument #2 to '__add' (Angle expected, got " .. type(a2) .. ")") end

    return Angle(a1._p + a2._p, a1._y + a2._y, a1._r + a2._r)
end

function am.__sub(a1, a2)
    if getmetatable(a2) != am then error("bad argument #2 to '__sub' (Angle expected, got " .. type(a2) .. ")") end

    return Angle(a1._p - a2._p, a1._y - a2._y, a1._r - a2._r)
end

function am.__div(a1, a2)
    if !isnumber(a2) then error("bad argument #2 to '__div' (number expected, got " .. type(a2) .. ")") end

    return Angle(a1._p / a2, a1._y / a2, a1._r / a2)
end

function am.__mul(a1, a2)
    if !isnumber(a2) then error("bad argument #2 to '__mul' (number expected, got " .. type(a2) .. ")") end

    return Angle(a1._p * a2, a1._y * a2, a1._r * a2)
end

function am.__eq(a1, a2)
    if getmetatable(a2) != am then return false end

    return a1._p == a2._p and a1._y == a2._y and a1._r == a2._r
end

function am.__unm(a1)
    return Angle(-a1._p, -a1._y, -a1._r)
end


function am:Add(a)
    if getmetatable(a) != am then error("bad argument #1 to 'Add' (Angle expected, got " .. type(a) .. ")") end

    self._p = self._p + a._p
    self._y = self._y + a._y
    self._r = self._r + a._r
end

function am:Div(a)
    if !isnumber(a) then error("bad argument #1 to 'Div' (number expected, got " .. type(a) .. ")") end

    self._p = self._p / a
    self._y = self._y / a
    self._r = self._r / a
end

function am:GetNegated()
    return Angle(-self._p, -self._y, -self._r)
end

function am:IsEqualTol(a, tolerance)
    if getmetatable(a) != am then error("bad argument #1 to 'IsEqualTol' (Angle expected, got " .. type(a) .. ")") end
    if !isnumber(tolerance) then error("bad argument #2 to 'IsEqualTol' (number expected, got " .. type(tolerance) .. ")") end

    if math.abs(self._p - a._p) > tolerance then return false end
    if math.abs(self._y - a._y) > tolerance then return false end
    if math.abs(self._r - a._r) > tolerance then return false end

    return true
end

function am:IsZero()
    return self._p == 0 and self._y == 0 and self._r == 0
end

function am:Mul(a)
    if !isnumber(a) then error("bad argument #1 to 'Mul' (number expected, got " .. type(a) .. ")") end

    self._p = self._p * a
    self._y = self._y * a
    self._r = self._r * a
end

function am:Negate()
    self._p = -self._p
    self._y = -self._y
    self._r = -self._r
end

function am:Random(min, max)
    if !isnumber(min) and min != nil then error("bad argument #1 to 'Random' (number expected, got " .. type(min) .. ")") end
    if !isnumber(max) and max != nil then error("bad argument #2 to 'Random' (number expected, got " .. type(max) .. ")") end
    min = min or -360
    max = max or 360

    self._p = math.Rand(min, max)
    self._y = math.Rand(min, max)
    self._r = math.Rand(min, max)
end

function am:Set(a)
    if getmetatable(a) != am then error("bad argument #1 to 'Set' (Angle expected, got " .. type(a) .. ")") end

    self._p = a._p
    self._y = a._y
    self._r = a._r
end

function am:SetUnpacked(p, y, r)
    if !isnumber(p) then error("bad argument #1 to 'SetUnpacked' (number expected, got " .. type(p) .. ")") end
    if !isnumber(y) then error("bad argument #2 to 'SetUnpacked' (number expected, got " .. type(y) .. ")") end
    if !isnumber(r) then error("bad argument #3 to 'SetUnpacked' (number expected, got " .. type(r) .. ")") end

    self._p = p
    self._y = y
    self._r = r
end

function am:Sub(a)
    if getmetatable(a) != am then error("bad argument #1 to 'Sub' (Angle expected, got " .. type(a) .. ")") end

    self._p = self._p - a._p
    self._y = self._y - a._y
    self._r = self._r - a._r
end

function am:Unpack()
    return self._p, self._y, self._r
end

function am:Zero()
    self._p = 0
    self._y = 0
    self._r = 0
end

function am:Forward()
    local rp = math.rad(self._p)
    local ry = math.rad(self._y)

    local forward = Vector(
        math.cos(rp) * math.cos(ry),
        math.cos(rp) * math.sin(ry),
        -math.sin(rp)
    )

    return forward
end

function am:Right()
    local rp = math.rad(self._p)
    local ry = math.rad(self._y)
    local rr = math.rad(self._r)

    local cp = math.cos(rp)
    local sp = math.sin(rp)
    local cy = math.cos(ry)
    local sy = math.sin(ry)
    local cr = math.cos(rr)
    local sr = math.sin(rr)

    local right = Vector(
        sy * cr - sp * cy * sr,
        -cy * cr - sp * sy * sr,
        -cp * sr
    )

    return right
end

function am:Up()
    local rp = math.rad(self._p)
    local ry   = math.rad(self._y)
    local rr  = math.rad(self._r)

    local cp = math.cos(rp)
    local sp = math.sin(rp)
    local cy = math.cos(ry)
    local sy = math.sin(ry)
    local cr = math.cos(rr)
    local sr = math.sin(rr)

    local up = Vector(
        sy * sr + sp * cy * cr,
        -cy * sr + sp * sy * cr,
        cp * cr
    )

    return up
end

function am:RotateAroundAxis(axis, rotation)
    error("RotateAroundAxis is not implemented")
end

function am:Normalize()
    self._p = math.NormalizeAngle(self._p)
    self._y = math.NormalizeAngle(self._y)
    self._r = math.NormalizeAngle(self._r)
end

function am:ToTable()
    return {self._p, self._y, self._r}
end


function Angle(p, y, r)
    local a = {_p = 0, _y = 0, _r = 0}
    setmetatable(a, am)

    if getmetatable(p) == am then
        a._p = p._p
        a._y = p._y
        a._r = p._r
        return a
    end

    if isstring(p) then
        local val = string.Split(p, " ")

        if #val >= 3 then
            local a1 = tonumber(val[1])
            local b1 = tonumber(val[2])
            local c1 = tonumber(val[3])

            if a1 and b1 and c1 then
                a._p = a1
                a._y = b1
                a._r = c1
                return a
            end
        end

        local num = tonumber(p)
        if num then a._p = num end
    end

    if isnumber(p) then
       a._p = p
    end

    if isnumber(y) then
       a._y = y
    end

    if isstring(y) then
        local num = tonumber(y)
        if num then a._y = num end
    end

    if isnumber(r) then
       a._r = r
    end

    if isstring(r) then
        local num = tonumber(r)
        if num then a._r = num end
    end

    return a
end
