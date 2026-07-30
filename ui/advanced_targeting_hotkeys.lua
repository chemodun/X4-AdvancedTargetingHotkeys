--[[
  Advanced Targeting Hotkeys - targeting bridge and settings store. All target
  selection lives in md/advanced_targeting_hotkeys.xml, which also registers the
  hotkeys; this file applies the chosen target and owns the config.

  C.SetSofttarget is used because MD's <set_player_target> is unconfirmed for surface
  elements, which four of the modes need. MD picks the path via $config.$targetingBackend;
  with 'md' these events are never raised.
]]

local PAGE_ID = 1972092437

local ffi = require("ffi")
local C = ffi.C

-- Already declared by ego_detailmonitor/ego_interactmenu; pcall'd per line so a
-- redeclaration cannot error out this file and a missing one is still self-served.
pcall(ffi.cdef, [[ typedef uint64_t UniverseID; ]])
pcall(ffi.cdef, [[ UniverseID GetPlayerID(void); ]])
pcall(ffi.cdef, [[ bool SetSofttarget(UniverseID componentid, const char*const connectionname); ]])

local advTargeting = {}

-- Debug logging follows hotkey_api's single toggle, which the API publishes to this
-- blackboard var. Read fresh per call, so flipping it takes effect without a reload.
local BLACKBOARD_DEBUG_ENABLED = "$hotkey_api_debug_enabled"

local playerId = nil

local function GetPlayerId()
  if not playerId then
    playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  end
  return playerId
end

-- MD-written booleans arrive as 1/0, so anything crossing the blackboard is normalised
-- here rather than tested directly.
local function Truthy(value)
  return not ((value == nil) or (value == false) or (value == 0))
end

local function IsDebugEnabled()
  return Truthy(GetNPCBlackboard(GetPlayerId(), BLACKBOARD_DEBUG_ENABLED))
end

-- Errors are reported regardless of the debug toggle.
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

-- Authoritative storage is __ADVANCED_TARGETING_HOTKEYS_DATA, a userdata savedvariable
-- declared in ui.xml. It has to be a real global - the engine's persistence looks it up
-- by name - and mutating the table in place is the commit.
--
-- player.entity.$AdvancedTargetingHotkeysConfig is a one-way mirror for MD, which reads
-- config on every key press. Nothing reads settings back out of it.
__ADVANCED_TARGETING_HOTKEYS_DATA = __ADVANCED_TARGETING_HOTKEYS_DATA or {}

local optionsConfig = nil

-- Kept identical to LoadConfig's defaults in the MD script. $targetingBackend is a
-- troubleshooting switch, so it has no Options row but still lives here.
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

-- Only these gate whether a hotkey id is registered at all.
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

-- Pushes config to the mirror MD reads, and returns true if the mirror held a different
-- set of group flags. The mirror lives in the savegame while the config is per-profile
-- userdata, so a save can start stale - and MD has already registered by the time we get
-- here, off the Reloaded cue hotkey_api signals just before Register_Request.
local function SyncConfigToBlackboard()
  -- No mirror yet means MD fell back to its own defaults, so compare against those.
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

-- raise_lua_event's param arrives as an id string. A single component marshals fine that
-- way; a nested table would not.
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

-- Settings live on their own page, reached from one row on hotkey_api's Hotkey Management
-- page, through the same displayOptions_modifyOptions hook the API itself uses. The engine's
-- sub-menu support is generic: any key in config.optionDefinitions becomes a page, any row
-- with submenu = "<page id>" opens it, and back arrow, history and preselect come free.
--
-- Two constraints: the nav row must have no callback, which onSelectElement tests first and
-- would let it shadow submenu; and SETTINGS_PAGE_ID must not collide with a page name
-- submenuHandler matches before its optionDefinitions fallback.
--
-- HotkeyApi.OnDisplayOptions is called here first because the shared callback list is
-- dispatched with pairs(), so ordering is not reliable. It is idempotent.
--
-- Booleans are "button" rows flipping vanilla's Enabled/Disabled strings, the generic
-- renderer having no checkbox; the two numeric settings are "slidercell" rows.

-- Page key, and the id of the row on hotkey_api's page that opens it.
local SETTINGS_PAGE_ID = "ath_settings"
local NAV_ROW_ID = "ath_settings_nav"

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
      -- A group switched ON has to re-run registration to become bindable. Switching one OFF
      -- cannot reclaim its slot: hotkey_api's registry has no unregister path.
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

-- "name" is the page title, the positional entries are the rows. Only "line" and "header"
-- are special-cased by menu.displayOption; any other id renders as a selectable row.
local function BuildSettingsPage()
  return {
    name = function() return ReadText(PAGE_ID, 1) end,

    { id = "header", name = function() return ReadText(PAGE_ID, 90100) end },
    ToggleRow("ath_group_combat_toggle", 90101, "groupCombatEnabled", true),
    ToggleRow("ath_group_fleet_toggle", 90102, "groupFleetEnabled", true),
    ToggleRow("ath_group_navigation_toggle", 90103, "groupNavigationEnabled", true),
    ToggleRow("ath_group_resources_toggle", 90104, "groupResourcesEnabled", true),
    ToggleRow("ath_group_surface_toggle", 90105, "groupSurfaceEnabled", true),
    ToggleRow("ath_group_mission_toggle", 90106, "groupMissionEnabled", true),

    { id = "line" },
    { id = "header", name = function() return ReadText(PAGE_ID, 90120) end },
    ToggleRow("ath_sticky_mode_toggle", 90121, "stickyModeEnabled", false),
    SliderRow("ath_range_multiplier", 90122, "rangeMultiplier", 1, 5, 1),
    SliderRow("ath_dockable_scan_limit", 90123, "dockableScanLimit", 1, 50, 1),

    { id = "line" },
    { id = "header", name = function() return ReadText(PAGE_ID, 90140) end },
    ToggleRow("ath_sound_toggle", 90141, "soundEnabled", false),
    ToggleRow("ath_notify_toggle", 90142, "notifyOnFailure", false),
  }
end

local function OnDisplayOptions(options, config)
  if not (HotkeyApi and HotkeyApi.OnDisplayOptions and HotkeyApi.managementPageId) then
    return options
  end

  options = HotkeyApi.OnDisplayOptions(options, config)

  local optionDefinitions = config and config.optionDefinitions
  if not optionDefinitions then
    return options
  end

  local page = optionDefinitions[HotkeyApi.managementPageId]
  if not page then
    -- hotkey_api has no page this render, so there is nothing safe to hang ours off.
    return options
  end

  -- config.optionDefinitions persists for the whole UI session, so this is create-once. It
  -- has to happen before the nav row below, or clicking that row silently does nothing.
  if not optionDefinitions[SETTINGS_PAGE_ID] then
    optionDefinitions[SETTINGS_PAGE_ID] = BuildSettingsPage()
    debugLog("OnDisplayOptions: created config.optionDefinitions['%s']", SETTINGS_PAGE_ID)
  end

  for _, row in ipairs(page) do
    if (type(row) == "table") and (row.id == NAV_ROW_ID) then
      return options -- already inserted on a previous render
    end
  end

  table.insert(page, { id = "line" })
  table.insert(page, {
    id = NAV_ROW_ID,
    name = function() return ReadText(PAGE_ID, 1) end,
    submenu = SETTINGS_PAGE_ID,
    -- No callback, deliberately: onSelectElement tests it first and would shadow submenu.
  })

  debugLog("OnDisplayOptions: inserted the '%s' row into hotkey_api's management page", NAV_ROW_ID)
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

-- Piggybacks on hotkey_api's registration event purely as proven-safe init timing; this
-- mod registers its hotkeys from MD.
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
