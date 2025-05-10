local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local tostring = tostring
local type = type
local string = string
local table = table

local Localized = require("SaveDataEditor/Localized")
local WeaponUseNum = require("SaveDataEditor/WeaponUseNum")

local M = {}

local LOG_PREFIX = "[SaveDataEditor-MonsterHuntNum] "

M.ui_state_monster_hunt = {}
M.display_order_monster_hunt = {}

function M.setup_monster_hunt_ui_state()
    M.ui_state_monster_hunt = {}
    M.display_order_monster_hunt = {}
    -- log.info(LOG_PREFIX .. "UI state and display order initialized.") -- Release: Remove info log
end

M.setup_monster_hunt_ui_state()

function M.load_monster_hunt_counts_from_save()
    -- log.info(LOG_PREFIX .. "Loading monster hunt counts from save...") -- Release: Remove info log
    M.setup_monster_hunt_ui_state()
    local success_flag = false
    local last_error = "Unknown load error"
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager"); if not sdManager then error(
            "SaveDataManager not found") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData"); if not getCurMeth then
            error("getCurrentUserSaveData method not found") end
        local get_s, res = pcall(getCurMeth.call, getCurMeth, sdManager); if not get_s or not res then error(
            "Failed to call getCurrentUserSaveData") end
        local curSave; if type(res) == "userdata" then curSave = res elseif type(res) == "number" and res ~= 0 then curSave =
            sdk.to_managed_object(res) end; if not curSave then error("Failed to get managed save data object") end
        local enemyReport = curSave:get_field("_EnemyReport"); if not enemyReport then error(
            "_EnemyReport field not found") end
        local bossArray = enemyReport:get_field("_Boss"); if not bossArray then error("_Boss array field not found") end
        local boss_array_size = bossArray:get_size()
        -- log.info(LOG_PREFIX .. "Found _Boss array with size: " .. boss_array_size) -- Release: Remove info log
        for i = 0, boss_array_size - 1 do
            local boss_entry_obj, err_boss = WeaponUseNum.get_array_element_by_invoke(bossArray, i)
            if boss_entry_obj then
                local fixed_id_val = boss_entry_obj:get_field("FixedId")
                if type(fixed_id_val) == "number" and fixed_id_val ~= 0 then
                    local monster_name = nil; local name_found = false
                    for _, m_data in ipairs(Localized.monster_data_list) do if m_data.FixedId == fixed_id_val then
                            monster_name = m_data.localized_name; name_found = true; break
                        end end
                    if name_found then
                        local slaying_num_val = boss_entry_obj:get_field("SlayingNum"); local capture_num_val =
                        boss_entry_obj:get_field("CaptureNum")
                        local slaying_num = (type(slaying_num_val) == "number") and slaying_num_val or 0; local capture_num = (type(capture_num_val) == "number") and
                        capture_num_val or 0
                        M.ui_state_monster_hunt[fixed_id_val] = { SlayingNum = slaying_num, CaptureNum = capture_num, localized_name =
                        monster_name, original_array_index = i }
                        table.insert(M.display_order_monster_hunt, fixed_id_val)
                        -- else log.info(LOG_PREFIX .. string.format("Skipping monster with FixedId %d: Name not found.", fixed_id_val)) -- Release: Remove info log
                    end
                end
                -- else log.warn(LOG_PREFIX .. string.format("Failed to get _Boss[%d] element: %s", i, err_boss)) -- Release: Remove warn log
            end
        end
        success_flag = true
    end)
    if not ok then
        log.error(LOG_PREFIX .. "Load failed during pcall: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then
        log.error(LOG_PREFIX .. "Load failed due to internal error: " .. last_error)
    end
    -- else log.info(LOG_PREFIX .. "Finished loading monster hunt counts.") -- Release: Remove info log
    return success_flag
end

function M.write_monster_hunt_stat_to_save(fixed_id, stat_field_name, new_value)
    local success_flag = false
    local last_error = "Unknown write error"
    local hunt_data = M.ui_state_monster_hunt[fixed_id]
    if not hunt_data or hunt_data.original_array_index == nil then
        log.error(LOG_PREFIX .. "Write error: Invalid FixedId or missing index: " .. tostring(fixed_id)); return false
    end
    local original_array_index = hunt_data.original_array_index
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager"); if not sdManager then error(
            "SaveDataManager not found") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData"); if not getCurMeth then
            error("getCurrentUserSaveData method not found") end
        local get_s, res = pcall(getCurMeth.call, getCurMeth, sdManager); if not get_s or not res then error(
            "Failed to call getCurrentUserSaveData") end
        local curSave; if type(res) == "userdata" then curSave = res elseif type(res) == "number" and res ~= 0 then curSave =
            sdk.to_managed_object(res) end; if not curSave then error("Failed to get managed save data object") end
        local enemyReport = curSave:get_field("_EnemyReport"); if not enemyReport then error(
            "_EnemyReport field not found") end
        local bossArray = enemyReport:get_field("_Boss"); if not bossArray then error("_Boss array field not found") end
        if bossArray:get_size() <= original_array_index then error("Original index out of bounds") end
        local boss_entry_obj, err_boss = WeaponUseNum.get_array_element_by_invoke(bossArray, original_array_index); if not boss_entry_obj then
            error("Failed to get boss entry: " .. tostring(err_boss)) end
        local assign_s, assign_e = pcall(function() boss_entry_obj[stat_field_name] = new_value end); if not assign_s then
            error("Direct assignment failed for " .. stat_field_name .. ": " .. tostring(assign_e)) end
        success_flag = true
    end)
    if not ok then
        log.error(LOG_PREFIX .. "Write failed during pcall: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then
        log.error(LOG_PREFIX .. "Write failed due to internal error: " .. last_error)
    end
    return success_flag
end

function M.update_monster_names_localization()
    -- log.info(LOG_PREFIX .. "Updating monster name localization in UI state...") -- Release: Remove info log
    local current_lang = Localized.display_language
    for fixed_id, hunt_data in pairs(M.ui_state_monster_hunt) do
        local monster_name_updated = "Unknown ID: " .. fixed_id
        for _, m_data in ipairs(Localized.monster_data_list) do if m_data.FixedId == fixed_id then
                monster_name_updated = m_data.localized_name or m_data.name_en or m_data.name_ja; break
            end end
        M.ui_state_monster_hunt[fixed_id].localized_name = monster_name_updated
    end
    -- log.info(LOG_PREFIX .. "Monster name localization updated for language: " .. current_lang) -- Release: Remove info log
end

function M.draw_monster_hunt_table_ui()
    local T = Localized.T
    local table_flags = imgui.TableFlags.Borders | imgui.TableFlags.RowBg | imgui.TableFlags.Resizable
    if imgui.begin_table("MonsterHuntTable", 3, table_flags, { 300, 0 }, 300) then
        imgui.table_setup_column(T.monster_name or "Name", 0, 100.0); imgui.table_setup_column(
        T.slaying_num or "Slaying", 0, 80.0); imgui.table_setup_column(T.capture_num or "Capture", 0, 80.0)
        imgui.table_headers_row()
        for _, fixed_id_key in ipairs(M.display_order_monster_hunt) do
            local hunt_data = M.ui_state_monster_hunt[fixed_id_key]
            if hunt_data then
                imgui.table_next_row()
                imgui.table_next_column(); imgui.text(hunt_data.localized_name or "N/A")
                imgui.table_next_column(); imgui.push_item_width(-1); local dsid = "##Slay" .. fixed_id_key; local sc, ns =
                imgui.drag_int(dsid, hunt_data.SlayingNum, 1, 0, 9999); if sc then M.ui_state_monster_hunt[fixed_id_key].SlayingNum =
                    ns end; imgui.pop_item_width()
                imgui.table_next_column(); imgui.push_item_width(-1); local dcid = "##Capt" .. fixed_id_key; local cc, nc =
                imgui.drag_int(dcid, hunt_data.CaptureNum, 1, 0, 9999); if cc then M.ui_state_monster_hunt[fixed_id_key].CaptureNum =
                    nc end; imgui.pop_item_width()
            end
        end
        imgui.end_table()
    end
end

return M
