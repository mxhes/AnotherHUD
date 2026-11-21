local h = ...

h.test("every .toc file exists", function()
  local files = h.toc()
  h.eq(#files > 0, true, "toc lists files")
  for _, path in ipairs(files) do
    local f = io.open("AnotherHUD/" .. path, "r")
    h.eq(f ~= nil, true, path .. " exists")
    if f then f:close() end
  end
end)

h.test("Boot.lua is last", function()
  local files = h.toc()
  h.eq(files[#files], "Boot.lua")
end)
