local ADDON, ns = ...

-- Loaded last. Waits for this addon's ADDON_LOADED (saved variables are in
-- place then) and starts it. Outside the client (tests load every .toc file)
-- there is no CreateFrame and nothing happens.
local function boot()
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    ns.Core.init()
  end)
end

if type(CreateFrame) == "function" then boot() end
