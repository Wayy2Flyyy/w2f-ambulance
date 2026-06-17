W2F.Shared.Utils = {}
function W2F.Shared.Utils.clamp(v,min,max) return math.max(min, math.min(max, v)) end
function W2F.Shared.Utils.includes(t,val) for i=1,#t do if t[i]==val then return true end end return false end
