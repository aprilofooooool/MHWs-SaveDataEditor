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
for i, lang_data in ipairs(Localized.available_languages) do
    if lang_data.code == Localized.display_language then
        current_language_index = i
        break
    end
end

re.on_draw_ui(function()
    local T = Localized.T

    if imgui.tree_node(T.profile_editor or "SaveDataEditor") then
        imgui.begin_disabled(save_data_access_error)
            imgui.push_item_width(120)
            local lang_chg, new_idx = imgui.combo(" ", current_language_index, Localized.language_names_for_combo)
            imgui.pop_item_width()
            if lang_chg then
                local new_code = Localized.available_languages[new_idx].code
                if Localized.display_language ~= new_code then
                    Localized.display_language = new_code
                    Localized.initialize_localization()
                    T = Localized.T
                    MonsterHuntNum.update_monster_names_localization()
                end
                current_language_index = new_idx
            end
        imgui.end_disabled()
        imgui.separator()

        local status_parts = {}
        table.insert(status_parts, "Basic:" .. (basic_data_loaded and "OK" or "NG"))
        table.insert(status_parts, "WpnUse:" .. (weapon_use_data_loaded and "OK" or "NG"))
        table.insert(status_parts, "MonHunt:" .. (monster_hunt_data_loaded and "OK" or "NG"))
        local all_loaded = basic_data_loaded and weapon_use_data_loaded and monster_hunt_data_loaded
        local status_color = all_loaded and 0xFF00FF00 or 0xFFFF0000
        local status_text = "Status: " .. table.concat(status_parts, ", ")
        if save_data_access_error then
            status_text = status_text .. " - ACCESS ERROR!"
            status_color = 0xFFFF0000
        end
        imgui.text_colored(status_text, status_color)
        imgui.separator()

        if imgui.button(T.load_button or "Load Data", {120, 0}) then
            local b_ok = BasicData.load_basic_data_from_save()
            local w_ok = WeaponUseNum.load_all_weapon_counts_from_save()
            local m_ok = MonsterHuntNum.load_monster_hunt_counts_from_save()
            basic_data_loaded = b_ok; weapon_use_data_loaded = w_ok; monster_hunt_data_loaded = m_ok
            if not b_ok and not w_ok and not m_ok then
                save_data_access_error = true
                log.error(LOG_PREFIX .. "All load functions failed.")
                re.msg("Critical Error: Failed to access save data structure.")
            else
                save_data_access_error = false
                if b_ok and w_ok and m_ok then re.msg("Load Complete!")
                else re.msg("Some data failed to load. Check log.") end
            end
        end
        imgui.separator()

        imgui.begin_disabled(save_data_access_error)
            if imgui.button(T.save_changes or "Save Changes", {120, 0}) then
                 if not basic_data_loaded and not weapon_use_data_loaded and not monster_hunt_data_loaded then
                     re.msg("Please load data first.")
                 else
                    local save_results = {}; local overall_save_success = true
                    if basic_data_loaded then save_results.basic = BasicData.write_basic_data_to_save(); if not save_results.basic then overall_save_success = false end else save_results.basic = nil end
                    if weapon_use_data_loaded then
                        local wpn_ok = true; local wpn_attempt = false
                        for _, defined_category_data in ipairs(Localized.quest_categories_data) do
                            local category_key = defined_category_data.key
                            local category_fixed_id_to_use = defined_category_data.category_fixed_id
                            if WeaponUseNum.ui_state_weapon_use[category_key] and category_fixed_id_to_use ~= 0 then
                                wpn_attempt = true
                                local ui_data_for_cat = WeaponUseNum.ui_state_weapon_use[category_key]
                                for _, wd in ipairs(Localized.weapon_types_data) do
                                    local wi = wd.id
                                    if not WeaponUseNum.write_weapon_use_count_to_save(category_fixed_id_to_use, "Main", wi, ui_data_for_cat.Main[wi]) then wpn_ok = false end
                                    if not WeaponUseNum.write_weapon_use_count_to_save(category_fixed_id_to_use, "Sub", wi, ui_data_for_cat.Sub[wi]) then wpn_ok = false end
                                end
                                if not WeaponUseNum.write_category_total_to_num_field_in_save(category_fixed_id_to_use, ui_data_for_cat.TotalMain) then wpn_ok = false end
                            end
                        end
                        save_results.weapon = wpn_attempt and wpn_ok; if not wpn_ok then overall_save_success = false end
                    else save_results.weapon = nil end
                    if monster_hunt_data_loaded then
                        local mon_ok = true; local mon_attempt = false
                        for fixed_id, hunt_stat in pairs(MonsterHuntNum.ui_state_monster_hunt) do
                            mon_attempt = true
                            if not MonsterHuntNum.write_monster_hunt_stat_to_save(fixed_id, "SlayingNum", hunt_stat.SlayingNum) then mon_ok = false end
                            if not MonsterHuntNum.write_monster_hunt_stat_to_save(fixed_id, "CaptureNum", hunt_stat.CaptureNum) then mon_ok = false end
                            if not MonsterHuntNum.write_monster_hunt_stat_to_save(fixed_id, "MixSize", hunt_stat.MixSize) then mon_ok = false end
                            if not MonsterHuntNum.write_monster_hunt_stat_to_save(fixed_id, "MaxSize", hunt_stat.MaxSize) then mon_ok = false end
                        end
                        save_results.monster = mon_attempt and mon_ok; if not mon_ok then overall_save_success = false end
                    else save_results.monster = nil end

                    local final_msg_parts = {}
                    if save_results.basic == false then table.insert(final_msg_parts, "Basic fail.") end
                    if save_results.weapon == false then table.insert(final_msg_parts, "WpnUse fail.") end
                    if save_results.monster == false then table.insert(final_msg_parts, "MonHunt fail.") end
                    if #final_msg_parts == 0 then
                        if save_results.basic == nil and save_results.weapon == nil and save_results.monster == nil then re.msg("No data to save.")
                        else re.msg("Update Complete! Please restart the game after saving.") end
                    else re.msg("Save fail:" .. table.concat(final_msg_parts, " ") .. " Check log.") end
                 end
            end
            imgui.separator()

            if imgui.tree_node(T.basic_data or "Basic Info") then
                if basic_data_loaded then BasicData.draw_basic_data_ui(true)
                else imgui.text_colored(T.load_needed_for_basic or "Load data.", 0xFFAAAAAA) end
                imgui.tree_pop()
            end
            if imgui.tree_node(T.weapon_use_count or "Weapon Use") then
                if weapon_use_data_loaded then
                    for _, category_data_item_from_def in ipairs(Localized.quest_categories_data) do
                         WeaponUseNum.draw_weapon_use_category_ui(category_data_item_from_def)
                    end
                else imgui.text_colored(T.load_needed_for_weapon or "Load data.", 0xFFAAAAAA) end
                imgui.tree_pop()
            end
            if imgui.tree_node(T.monster_hunt_count or "Monster Hunt") then
                if monster_hunt_data_loaded then MonsterHuntNum.draw_monster_hunt_table_ui()
                else imgui.text_colored(T.load_needed_for_monster or "Load data.", 0xFFAAAAAA) end
                imgui.tree_pop()
            end
        imgui.end_disabled()
        imgui.tree_pop()
    end
end)