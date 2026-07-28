--[[
  Advanced Targeting Hotkeys - targeting bridge.

  All the actual target *selection* logic lives in md/advanced_targeting_hotkeys.xml.
  This file exists only to apply the chosen target, because MD's own
  <set_player_target>/<clear_player_target> are not confirmed to work for surface
  elements (components rather than objects), which the four surface-element modes
  depend on. C.SetSofttarget is what vanilla itself uses for exactly this
  (menu_map.lua:5567, menu_interactmenu.lua:2204/:2233 - the latter on a component
  slot, i.e. surface elements included), so it is the safe path for every mode.

  MD picks which path to use via $config.$targetingBackend ('lua' by default);
  with 'md' it never raises these events at all and this file simply idles.
]]

local ffi = require("ffi")
local C = ffi.C

-- Already declared by ego_detailmonitor/ego_interactmenu, which load as part of
-- the same Lua state - pcall'd so an identical redeclaration cannot error out
-- this file, and so a missing declaration is still self-served.
pcall(ffi.cdef, [[
	bool SetSofttarget(UniverseID componentid, const char*const connectionname);
]])

local advTargeting = {}

-- MD sends the component through raise_lua_event's param, which arrives as its
-- id string. A single component reference marshals fine this way (unlike a
-- nested table, which is why hotkey_api itself uses a blackboard list instead).
function advTargeting.OnSetTarget(_, object)
  if (object == nil) or (object == 0) then
    return
  end

  local componentId = ConvertStringTo64Bit(tostring(object))
  if componentId == 0 then
    DebugError("Advanced Targeting Hotkeys: could not convert '" .. tostring(object) .. "' to a component id")
    return
  end

  if not C.SetSofttarget(componentId, "") then
    DebugError("Advanced Targeting Hotkeys: SetSofttarget failed for " .. tostring(object))
  end
end

function advTargeting.OnClearTarget()
  RemoveSofttarget()
end

local function Init()
  RegisterEvent("AdvancedTargetingHotkeys.SetTarget", advTargeting.OnSetTarget)
  RegisterEvent("AdvancedTargetingHotkeys.ClearTarget", advTargeting.OnClearTarget)
end

Init()
