local ADDON, ns = ...

-- Snapping (pure). Rects are { x, y, w, h }: bottom-left corner and size in
-- UIParent units. Glue passes the screen as one target rect, so its edges
-- and centre lines count like any other frame's.
ns.EditMode = ns.EditMode or {}
local Snap = {}

local DEFAULT_THRESHOLD = 8

-- The shift (or nil) that puts one of our three lines (low edge, centre,
-- high edge) onto the nearest line of a target, within `threshold`.
local function axisShift(lo, size, lines, threshold)
  local best
  local ours = { lo, lo + size / 2, lo + size }
  for _, own in ipairs(ours) do
    for _, line in ipairs(lines) do
      local d = line - own
      if math.abs(d) <= threshold and (best == nil or math.abs(d) < math.abs(best)) then best = d end
    end
  end
  return best
end

local function onGrid(v, grid)
  return math.floor(v / grid + 0.5) * grid
end

-- New x, y for `rect`: each axis snaps an edge or the centre to the nearest
-- target edge or centre line within opts.threshold (default 8); failing
-- that, the low edge goes to the nearest multiple of opts.grid when set;
-- else it stays.
function Snap.snap(rect, targets, opts)
  opts = opts or {}
  local threshold = opts.threshold or DEFAULT_THRESHOLD
  local xs, ys = {}, {}
  local function add(lines, lo, size)
    lines[#lines + 1] = lo
    lines[#lines + 1] = lo + size / 2
    lines[#lines + 1] = lo + size
  end
  for _, t in ipairs(targets or {}) do
    add(xs, t.x, t.w)
    add(ys, t.y, t.h)
  end
  local grid = opts.grid
  local function axis(lo, size, lines)
    local d = axisShift(lo, size, lines, threshold)
    if d then return lo + d end
    if grid and grid > 0 then return onGrid(lo, grid) end
    return lo
  end
  return axis(rect.x, rect.w, xs), axis(rect.y, rect.h, ys)
end

ns.EditMode.Snap = Snap
