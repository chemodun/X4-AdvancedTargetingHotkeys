--[[
  Advanced Targeting Hotkeys - targeting bridge and settings.

  Two jobs, both of them support work for md/advanced_targeting_hotkeys.xml, which
  owns all of the actual target *selection* logic and registers every hotkey itself:

  1. Applying the chosen target. MD's own <set_player_target>/<clear_player_target>
     are not confirmed to work for surface elements (components rather than objects),
     which the four surface-element modes depend on. C.SetSofttarget is what vanilla
     itself uses for exactly this (menu_map.lua:5567, menu_interactmenu.lua:2204/:2233
     - the latter on a component slot, i.e. surface elements included), so it is the
     safe path for every mode. MD picks the path via $config.$targetingBackend ('lua'
     by default); with 'md' it never raises these events and this half simply idles.

  2. Owning the mod's settings: the config store itself (a userdata savedvariable),
     the rows shown for it in the Options menu, and the one-way mirror MD reads.
     See the two block comments further down.
]]

local PAGE_ID = 1972092437

local ffi = require("ffi")
local C = ffi.C

-- All of these are already declared by ego_detailmonitor/ego_interactmenu (vanilla
-- itself repeats the UniverseID typedef in 26 of its own UI files, so redeclaring
-- is normal here) - pcall'd anyway so a redeclaration cannot error out this file,
-- and so a missing declaration is still self-served. One pcall per declaration
-- rather than one for the block: if any single line ever did fail, it must not take
-- the others down with it.
pcall(ffi.cdef, [[ typedef uint64_t UniverseID; ]])
pcall(ffi.cdef, [[ UniverseID GetPlayerID(void); ]])
pcall(ffi.cdef, [[ bool SetSofttarget(UniverseID componentid, const char*const connectionname); ]])

local advTargeting = {}

-- *** Debug logging ***
--
-- This mod has no debug setting of its own. Every consumer of hotkey_api shares
-- its single "debug logging" toggle (Options > Hotkey Management), which the API
-- publishes to the blackboard var below - the same one md.HotkeyApi.GetDebugChance
-- reads, and therefore the same one gating every debug_text call in this mod's MD
-- script. Read fresh on each call rather than cached, so flipping the toggle takes
-- effect immediately without a reload.
local BLACKBOARD_DEBUG_ENABLED = "$hotkey_api_debug_enabled"

local playerId = nil

local function GetPlayerId()
  if not playerId then
    playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  end
  return playerId
end

-- MD-written booleans arrive as 1/0 rather than true/false (the API's own
-- GetDebugChance library checks for both, for the same reason), so anything
-- crossing the blackboard is normalised through this rather than tested directly.
local function Truthy(value)
  return not ((value == nil) or (value == false) or (value == 0))
end

local function IsDebugEnabled()
  return Truthy(GetNPCBlackboard(GetPlayerId(), BLACKBOARD_DEBUG_ENABLED))
end

-- Errors are reported regardless of the debug toggle - they mean something the
-- player asked for did not happen.
local function errorLog(fmt, ...)
  if select("#", ...) > 0 then
    DebugError("Advanced Targeting Hotkeys: " .. string.format(fmt, ...))
  else
    DebugError("Advanced Targeting Hotkeys: " .. fmt)
  end
end

local function debugLog(fmt, ...)
  if not IsDebugEnabled() then
    return
  end
  errorLog(fmt, ...)
end

-- *** Config store ***
--
-- Authoritative storage is __ADVANCED_TARGETING_HOTKEYS_DATA, a <savedvariable
-- storage="userdata"/> declared in ui.xml - the same pattern hotkey_api uses for
-- __NATIVE_HOTKEY_API_DATA and simple_hotkeys for __SIMPLE_HOTKEYS_DATA. It must
-- be a genuine global (not a local), since the engine's userdata persistence looks
-- it up by name. Mutating the table in place *is* the persistence; there is no
-- separate commit call.
--
-- player.entity.$AdvancedTargetingHotkeysConfig is a one-way mirror for MD's
-- benefit only - SyncConfigToBlackboard() pushes to it after the defaults are
-- established and after every settings change, so the MD script (which reads it on
-- every key press and when registering the hotkeys) always sees current values.
-- Nothing ever reads settings back out of it.
__ADVANCED_TARGETING_HOTKEYS_DATA = __ADVANCED_TARGETING_HOTKEYS_DATA or {}

local optionsConfig = nil

-- Defaults, kept identical to LoadConfig's own in md/advanced_targeting_hotkeys.xml
-- (which needs them for the one first-pass moment before the mirror exists).
-- $targetingBackend is deliberately absent from the Options rows - it is a
-- troubleshooting switch, not a preference - but it lives here so a player can set
-- it, and so the mirror always carries it.
local DEFAULTS = {
  groupCombatEnabled     = true,
  groupFleetEnabled      = true,
  groupNavigationEnabled = true,
  groupResourcesEnabled  = true,
  groupSurfaceEnabled    = true,
  groupMissionEnabled    = true,
  stickyModeEnabled      = true,
  soundEnabled           = true,
  notifyOnFailure        = true,
  rangeMultiplier        = 2,
  dockableScanLimit      = 12,
  targetingBackend       = "lua",
}

-- Only these gate whether a hotkey id is registered at all, so only these can make
-- an already-completed registration pass wrong (see SyncConfigToBlackboard).
local GROUP_KEYS = {
  "groupCombatEnabled",
  "groupFleetEnabled",
  "groupNavigationEnabled",
  "groupResourcesEnabled",
  "groupSurfaceEnabled",
  "groupMissionEnabled",
}

local function LoadOptionsConfig()
  if optionsConfig then
    return optionsConfig
  end
  optionsConfig = __ADVANCED_TARGETING_HOTKEYS_DATA
  for key, default in pairs(DEFAULTS) do
    if optionsConfig[key] == nil then
      optionsConfig[key] = default
    end
  end
  return optionsConfig
end

-- Pushes the current config to the mirror MD reads. Returns true if the mirror was
-- previously holding a *different* set of group flags.
--
-- That return value matters on load: the mirror is stored in the savegame while the
-- config itself is per-profile userdata, so a save last played with other settings
-- (or one made before this mod was installed) starts the session with a stale
-- mirror. MD registers its hotkeys off the Reloaded cue, which hotkey_api signals
-- immediately *before* raising the Register_Request event this file listens to, so
-- that registration pass has already run against the stale values by the time we
-- get here. Comparing lets the caller re-broadcast Reloaded exactly when it would
-- actually change something, instead of on every single load.
local function SyncConfigToBlackboard()
  -- No mirror yet (first run on this save) means MD fell back to its own copy of
  -- the defaults, so those are what the comparison has to be against.
  local previous = GetNPCBlackboard(GetPlayerId(), "$AdvancedTargetingHotkeysConfig")
  if type(previous) ~= "table" then
    previous = DEFAULTS
  end

  local groupsChanged = false
  for _, key in ipairs(GROUP_KEYS) do
    if Truthy(previous[key]) ~= Truthy(optionsConfig[key]) then
      groupsChanged = true
      break
    end
  end

  SetNPCBlackboard(GetPlayerId(), "$AdvancedTargetingHotkeysConfig", optionsConfig)
  return groupsChanged
end

-- MD sends the component through raise_lua_event's param, which arrives as its
-- id string. A single component reference marshals fine this way (unlike a
-- nested table, which is why hotkey_api itself uses a blackboard list instead).
function advTargeting.OnSetTarget(_, object)
  if (object == nil) or (object == 0) then
    return
  end

  local componentId = ConvertStringTo64Bit(tostring(object))
  if componentId == 0 then
    errorLog("could not convert '%s' to a component id", tostring(object))
    return
  end

  if not C.SetSofttarget(componentId, "") then
    errorLog("SetSofttarget failed for %s", tostring(object))
  end
end

function advTargeting.OnClearTarget()
  RemoveSofttarget()
end

-- *** Extension Options: nested inside hotkey_api's own Management page ***
--
-- This mod's settings are appended directly into hotkey_api's native "Hotkey
-- Management" Options page (config.optionDefinitions[HotkeyApi.managementPageId]),
-- via the same displayOptions_modifyOptions UIX hook (gameoptions.xpl) hotkey_api
-- itself uses - the same arrangement simple_hotkeys uses. Everything this mod does
-- is hotkey_api-specific, so its settings belong next to the bindings they affect
-- rather than on a separate Extensions page; sn_mod_support_apis and options_helper
-- are not dependencies of this mod at all.
--
-- Row-append ordering: gameoptions.xpl dispatches every registered
-- "displayOptions_modifyOptions" callback via pairs() over a hash-keyed table, not
-- in insertion order, so which mod's callback fires first on a given render is not
-- reliably tied to load/dependency order. To guarantee hotkey_api's own page and
-- rows exist before this mod appends to them, this file calls
-- HotkeyApi.OnDisplayOptions(options, config) itself first - it is idempotent
-- (guarded by "only create if the page doesn't already exist"), so calling it here
-- is safe even when the shared callback list invokes it again in the same render.
--
-- Row types are whatever menu.displayOption's generic renderer supports: there is
-- no real checkbox valuetype outside a fully custom-rendered page (hotkey_api's own
-- debug toggle documents the same limitation), so every boolean is a "button" row
-- flipping between vanilla's own Enabled/Disabled strings ({1001,4825}/{1001,8942},
-- no new translation), and the two numeric settings are "slidercell" rows.

local FIRST_ROW_ID = "ath_group_combat_toggle"

local function ToggleRow(id, nameTextId, configKey, reregister)
  return {
    id = id,
    name = function() return ReadText(PAGE_ID, nameTextId) end,
    value = function() return LoadOptionsConfig()[configKey] and ReadText(1001, 4825) or ReadText(1001, 8942) end,
    valuetype = "button",
    callback = function()
      local cfg = LoadOptionsConfig()
      cfg[configKey] = not cfg[configKey]
      SyncConfigToBlackboard()
      debugLog("options: %s set to %s", configKey, tostring(cfg[configKey]))
      -- Group toggles gate registration itself, so a group switched ON has to
      -- re-run the registration pass to become bindable. Switching one OFF cannot
      -- reclaim its slot this way - hotkey_api's registry has no unregister path;
      -- its own Hotkey Requests page is what frees a slot immediately.
      if reregister then
        HotkeyApi.BroadcastReloaded()
      end
    end,
  }
end

local function SliderRow(id, nameTextId, configKey, min, max, step)
  return {
    id = id,
    name = function() return ReadText(PAGE_ID, nameTextId) end,
    value = function()
      return {
        min            = min,
        max            = max,
        start          = LoadOptionsConfig()[configKey] or DEFAULTS[configKey],
        step           = step,
        suffix         = "",
        exceedMaxValue = false,
        hideMaxValue   = true,
      }
    end,
    valuetype = "slidercell",
    callback = function(value)
      if not value then
        return
      end
      LoadOptionsConfig()[configKey] = value
      SyncConfigToBlackboard()
      debugLog("options: %s set to %s", configKey, tostring(value))
    end,
  }
end

local function OnDisplayOptions(options, config)
  if not (HotkeyApi and HotkeyApi.OnDisplayOptions and HotkeyApi.managementPageId) then
    return options
  end

  options = HotkeyApi.OnDisplayOptions(options, config)

  local page = config and config.optionDefinitions and config.optionDefinitions[HotkeyApi.managementPageId]
  if not page then
    -- hotkey_api hasn't created its page this render (e.g. config not ready
    -- yet) - nothing safe to append to.
    return options
  end

  for _, row in ipairs(page) do
    if (type(row) == "table") and (row.id == FIRST_ROW_ID) then
      return options -- already appended on a previous render
    end
  end

  -- id "line" and id "header" are the two row ids menu.displayOption special-cases
  -- (a separator line and a sub-header); anything else would be rendered as a
  -- normal, selectable row - so a blank spacer row is not the way to separate
  -- sections here.
  table.insert(page, { id = "line" })
  table.insert(page, { id = "header", name = function() return ReadText(PAGE_ID, 1) end })
  table.insert(page, { id = "line" })

  table.insert(page, { id = "header", name = function() return ReadText(PAGE_ID, 90100) end })
  table.insert(page, ToggleRow(FIRST_ROW_ID, 90101, "groupCombatEnabled", true))
  table.insert(page, ToggleRow("ath_group_fleet_toggle", 90102, "groupFleetEnabled", true))
  table.insert(page, ToggleRow("ath_group_navigation_toggle", 90103, "groupNavigationEnabled", true))
  table.insert(page, ToggleRow("ath_group_resources_toggle", 90104, "groupResourcesEnabled", true))
  table.insert(page, ToggleRow("ath_group_surface_toggle", 90105, "groupSurfaceEnabled", true))
  table.insert(page, ToggleRow("ath_group_mission_toggle", 90106, "groupMissionEnabled", true))

  table.insert(page, { id = "line" })
  table.insert(page, { id = "header", name = function() return ReadText(PAGE_ID, 90120) end })
  table.insert(page, ToggleRow("ath_sticky_mode_toggle", 90121, "stickyModeEnabled", false))
  table.insert(page, SliderRow("ath_range_multiplier", 90122, "rangeMultiplier", 1, 5, 1))
  table.insert(page, SliderRow("ath_dockable_scan_limit", 90123, "dockableScanLimit", 1, 50, 1))

  table.insert(page, { id = "line" })
  table.insert(page, { id = "header", name = function() return ReadText(PAGE_ID, 90140) end })
  table.insert(page, ToggleRow("ath_sound_toggle", 90141, "soundEnabled", false))
  table.insert(page, ToggleRow("ath_notify_toggle", 90142, "notifyOnFailure", false))

  debugLog("OnDisplayOptions: appended settings rows to hotkey_api's management page")
  return options
end

local optionsMenuHooked = false

local function EnsureOptionsMenuHooked()
  if optionsMenuHooked then
    return
  end
  local optionsMenu = Helper.getMenu("OptionsMenu")
  if not (optionsMenu and (type(optionsMenu.registerCallback) == "function")) then
    debugLog("EnsureOptionsMenuHooked: OptionsMenu not available yet")
    return
  end
  optionsMenu.registerCallback("displayOptions_modifyOptions", OnDisplayOptions)
  optionsMenuHooked = true
  debugLog("EnsureOptionsMenuHooked: registered displayOptions_modifyOptions callback")
end

-- Piggybacks on hotkey_api's own registration event rather than needing a
-- game-loaded relay of our own: it only fires after the API's full game-loaded
-- sequence, i.e. at a point where the player entity, the menus and the API bridge
-- all exist. This mod registers its hotkeys from MD, so nothing is registered
-- here - the event is used purely as proven-safe init timing.
local function OnRegisterRequest()
  LoadOptionsConfig()
  local groupsChanged = SyncConfigToBlackboard()
  EnsureOptionsMenuHooked()

  if groupsChanged then
    if HotkeyApi and HotkeyApi.BroadcastReloaded then
      debugLog("OnRegisterRequest: mirrored config differed from the stored settings - re-broadcasting Reloaded")
      HotkeyApi.BroadcastReloaded()
    else
      errorLog("HotkeyApi.BroadcastReloaded not available - is hotkey_api loaded?")
    end
  end
end

local function Init()
  RegisterEvent("AdvancedTargetingHotkeys.SetTarget", advTargeting.OnSetTarget)
  RegisterEvent("AdvancedTargetingHotkeys.ClearTarget", advTargeting.OnClearTarget)
  RegisterEvent("HotkeyApi.Register_Request", OnRegisterRequest)
end

Init()
