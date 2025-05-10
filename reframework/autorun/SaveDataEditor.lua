local re = re
local log = log
local imgui = imgui
local os = os
local ipairs = ipairs
local table = table
local tostring = tostring

local Localized = require("SaveDataEditor/Localized")
local WeaponUseNum = require("SaveDataEditor/WeaponUseNum")
local MonsterHuntNum = require("SaveDataEditor/MonsterHuntNum")
local BasicData = require("SaveDataEditor/BasicData")

local LOG_PREFIX = "[SaveDataEditor-Main] "

local basic_data_loaded = false
local weapon_use_data_loaded = false
local monster_hunt_data_loaded = false
local save_data_access_error = false

local current_language_index = 1
for i, lang_data in ipairs(Localized.available_languages) do if lang_data.code == Localized.display_language then
        current_language_index = i; break
    end end

re.on_draw_ui(function()
    local T = Localized.T

    if imgui.tree_node(T.profile_editor or "SaveDataEditor") then
        imgui.begin_disabled(save_data_access_error) -- Disable most controls if access error occurred
        imgui.push_item_width(120); local lang_chg, new_idx = imgui.combo(" ", current_language_index,
            Localized.language_names_for_combo); imgui.pop_item_width()
        if lang_chg then
            local new_code = Localized.available_languages[new_idx].code; if Localized.display_language ~= new_code then
                Localized.display_language = new_code; Localized.initialize_localization(); T = Localized.T; MonsterHuntNum
                    .update_monster_names_localization()
            end; current_language_index = new_idx
        end
        imgui.end_disabled() -- Enable controls below if no access error
        imgui.separator()

        local status_parts = {}; table.insert(status_parts, "Basic:" .. (basic_data_loaded and "OK" or "NG")); table
            .insert(status_parts, "WpnUse:" .. (weapon_use_data_loaded and "OK" or "NG")); table.insert(status_parts,
            "MonHunt:" .. (monster_hunt_data_loaded and "OK" or "NG"))
        local all_ld = basic_data_loaded and weapon_use_data_loaded and monster_hunt_data_loaded; local scolor = all_ld and
        0xFF00FF00 or 0xFFFF0000;
        local status_text = "Status: " .. table.concat(status_parts, ", "); if save_data_access_error then
            status_text = status_text .. " - ACCESS ERROR!"; scolor = 0xFFFF0000
        end; imgui.text_colored(status_text, scolor); imgui.separator()

        if imgui.button(T.load_button or "Load Data", { 120, 0 }) then
            local b_ok = BasicData.load_basic_data_from_save(); local w_ok = WeaponUseNum
            .load_all_weapon_counts_from_save(); local m_ok = MonsterHuntNum.load_monster_hunt_counts_from_save()
            basic_data_loaded = b_ok; weapon_use_data_loaded = w_ok; monster_hunt_data_loaded = m_ok
            if not b_ok and not w_ok and not m_ok then
                save_data_access_error = true; log.error(LOG_PREFIX .. "All load functions failed."); re.msg(
                "Critical Error: Failed to access save data.")
            else
                save_data_access_error = false; if b_ok and w_ok and m_ok then
                    re.msg("Load Complete!")
                else
                    re.msg("Some data failed to load. Check log.") end
            end
        end; imgui.separator()

        imgui.begin_disabled(save_data_access_error) -- Disable save and edits if access error
        if imgui.button(T.save_changes or "Save Changes", { 120, 0 }) then
            if not basic_data_loaded and not weapon_use_data_loaded and not monster_hunt_data_loaded then
                re.msg("Please load data first.")
            else
                local s_res = {}; local all_ok = true
                if basic_data_loaded then
                    s_res.basic = BasicData.write_basic_data_to_save(); if not s_res.basic then all_ok = false end
                else s_res.basic = nil end
                if weapon_use_data_loaded then
                    local wo = true; local wa = false; for _, cd in ipairs(Localized.quest_categories_data) do
                        local ck = cd.key; local ci = cd.data_index; for _, wd in ipairs(Localized.weapon_types_data) do
                            wa = true; local wi = wd.id; if not WeaponUseNum.write_weapon_use_count_to_save(ci, "Main", wi, WeaponUseNum.ui_state_weapon_use[ck].Main[wi]) then wo = false end; if not WeaponUseNum.write_weapon_use_count_to_save(ci, "Sub", wi, WeaponUseNum.ui_state_weapon_use[ck].Sub[wi]) then wo = false end
                        end; if not WeaponUseNum.write_category_total_to_num_field_in_save(ci, WeaponUseNum.ui_state_weapon_use[ck].TotalMain) then wo = false end
                    end; s_res.weapon = wa and wo; if not wo then all_ok = false end
                else s_res.weapon = nil end
                if monster_hunt_data_loaded then
                    local mo = true; local ma = false; for fid, hstat in pairs(MonsterHuntNum.ui_state_monster_hunt) do
                        ma = true; if not MonsterHuntNum.write_monster_hunt_stat_to_save(fid, "SlayingNum", hstat.SlayingNum) then mo = false end; if not MonsterHuntNum.write_monster_hunt_stat_to_save(fid, "CaptureNum", hstat.CaptureNum) then mo = false end
                    end; s_res.monster = ma and mo; if not mo then all_ok = false end
                else s_res.monster = nil end
                local f_msg_p = {}; if s_res.basic == false then table.insert(f_msg_p, "Basic fail.") end; if s_res.weapon == false then
                    table.insert(f_msg_p, "WpnUse fail.") end; if s_res.monster == false then table.insert(f_msg_p,
                        "MonHunt fail.") end
                if #f_msg_p == 0 then if s_res.basic == nil and s_res.weapon == nil and s_res.monster == nil then re.msg(
                            "No data loaded to save.")
                    else
                        re.msg("Update Complete! Please restart the game after saving.")
                    end
                else
                    re.msg(
                    "Save fail:" .. table.concat(f_msg_p, " ") .. " Check log.") end
            end
        end; imgui.separator()

        if imgui.tree_node(T.basic_data or "Basic Info") then
            if basic_data_loaded then BasicData.draw_basic_data_ui(true) else imgui.text_colored(
                T.load_needed_for_basic or "Load data.", 0xFFAAAAAA) end; imgui.tree_pop()
        end
        if imgui.tree_node(T.weapon_use_count or "Weapon Use") then
            if weapon_use_data_loaded then for _, cdi in ipairs(Localized.quest_categories_data) do WeaponUseNum
                        .draw_weapon_use_category_ui(cdi) end else imgui.text_colored(
                T.load_needed_for_weapon or "Load data.", 0xFFAAAAAA) end; imgui.tree_pop()
        end
        if imgui.tree_node(T.monster_hunt_count or "Monster Hunt") then
            if monster_hunt_data_loaded then MonsterHuntNum.draw_monster_hunt_table_ui() else imgui.text_colored(
                T.load_needed_for_monster or "Load data.", 0xFFAAAAAA) end; imgui.tree_pop()
        end

        imgui.end_disabled() -- End disabling controls if access error

        imgui.tree_pop()
    end
end)
