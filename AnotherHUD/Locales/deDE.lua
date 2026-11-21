local ADDON, ns = ...

-- German texts. The key is the English text (see Core/Locale.lua); a missing
-- entry shows the English text. Each module adds its entries here.
ns.Locale.register("deDE", {
  -- Edit Mode panel buttons (EditMode/Glue.lua)
  ["Settings"] = "Einstellungen",
  ["Reset Settings"] = "Werte zurücksetzen",
  ["Reset To Default Position"] = "Standardposition",
  ["Settings window comes later"] = "Das Einstellungsfenster kommt später",
  -- Checklist toggles (EditMode/Checklist.lua)
  ["Type /reload to apply"] = "Mit /reload übernehmen",
  -- Action Bar 1 spike setting (EditMode/SystemSettings.lua)
  ["AnotherHUD look"] = "AnotherHUD-Optik",
  ["Test setting, changes nothing yet."] = "Testoption, ändert noch nichts.",
  ["on"] = "an",
  ["off"] = "aus",
  -- Spike test frame (Spike/SpikeModule.lua)
  ["AnotherHUD Test"] = "AnotherHUD-Test",
  ["Size"] = "Größe",
  ["Look"] = "Aussehen",
  ["Width"] = "Breite",
  ["Height"] = "Höhe",
  ["Show border"] = "Rahmen zeigen",
  ["Width of the test frame."] = "Breite des Testrahmens.",
  ["Height of the test frame."] = "Höhe des Testrahmens.",
  ["Draw the frame's border."] = "Zeichnet den Rahmen.",
})
