-- SaveDataEditor.lua
-- SaveDataEditor MOD のメイン制御ファイル
local re = re -- REFramework API
local log = log
local imgui = imgui
local os = os -- os.time() などで使用する可能性 (現在は未使用)
local ipairs = ipairs
local table = table
local tostring = tostring

-- モジュールの読み込み (パスを確認してください)
local Localized = require("SaveDataEditor/Localized")
local Constants = require("SaveDataEditor/Constants")
local WeaponUseNum = require("SaveDataEditor/WeaponUseNum")
local MonsterHuntNum = require("SaveDataEditor/MonsterHuntNum")
local BasicData = require("SaveDataEditor/BasicData")
local CharmEditor = require("SaveDataEditor/CharmEditor")
-- Utils と SaveDataAccess は各モジュールが内部で require するので、ここでは不要な場合も

local LOG_PREFIX = Constants.LOG_PREFIX_MAIN

-- データロード状態フラグ
local basic_data_successfully_loaded = false
local weapon_use_data_successfully_loaded = false
local monster_hunt_data_successfully_loaded = false
local critical_save_data_access_error_occurred = false -- 重大なアクセスエラー

-- 現在選択されている言語のインデックス (Localized.available_languages 内)
local current_language_combo_index = 1 -- デフォルトはリストの最初の言語
for i, lang_data_entry in ipairs(Localized.available_languages) do
    if lang_data_entry.code == Localized.display_language then
        current_language_combo_index = i
        break
    end
end

-- REFramework の UI描画コールバック
re.on_draw_ui(function()
    local T = Localized.T -- 現在の言語テキストをローカル変数に (言語変更時に更新される)

    -- メインウィンドウ (ツリーノードとして)
    if imgui.tree_node(T.profile_editor or "SaveDataEditor MOD") then
        -- === 言語選択 ===
        imgui.begin_disabled(critical_save_data_access_error_occurred) -- エラー時は操作不能に
        imgui.push_item_width(150)                                     -- コンボボックスの幅
        local language_changed_by_combo, new_selected_language_index = imgui.combo(
            " ",                             -- ラベル (非表示になることが多いが念のため)
            current_language_combo_index,
            Localized.language_names_for_combo                         -- ["English", "Japanese", ...]
        )
        imgui.pop_item_width()
        if language_changed_by_combo then
            local new_language_code = Localized.available_languages[new_selected_language_index].code
            if Localized.display_language ~= new_language_code then
                Localized.display_language = new_language_code
                Localized.initialize_localization() 
                T = Localized.T 
                MonsterHuntNum.update_monster_names_localization()
                -- CharmEditor.update_charm_names_localization() -- 呼び出し削除
                log.info(LOG_PREFIX .. "Language changed to: " .. new_language_code)
            end
            current_language_combo_index = new_selected_language_index
        end
        imgui.end_disabled()
        imgui.separator()

        -- === データロードステータス表示 ===
        local status_message_parts = {}
        table.insert(status_message_parts,
            T.status_basic_ok and (basic_data_successfully_loaded and T.status_basic_ok or T.status_basic_ng) or
            "Basic:N/A")
        table.insert(status_message_parts,
            T.status_wpn_use_ok and (weapon_use_data_successfully_loaded and T.status_wpn_use_ok or T.status_wpn_use_ng) or
            "Wpn:N/A")
        table.insert(status_message_parts,
            T.status_mon_hunt_ok and
            (monster_hunt_data_successfully_loaded and T.status_mon_hunt_ok or T.status_mon_hunt_ng) or "Hunt:N/A")

        local all_data_loaded_successfully = basic_data_successfully_loaded and weapon_use_data_successfully_loaded and
        monster_hunt_data_successfully_loaded
        local status_text_color = all_data_loaded_successfully and not critical_save_data_access_error_occurred and
        0xFF00FF00 or 0xFFFF0000                                                                                                             -- 緑 or 赤

        local full_status_text = (T.status_prefix or "Status: ") .. table.concat(status_message_parts, ", ")
        if critical_save_data_access_error_occurred then
            full_status_text = full_status_text .. (T.status_access_error or " - ACCESS ERROR!")
            status_text_color = 0xFFFF0000 -- 強制的に赤
        end
        imgui.text_colored(full_status_text, status_text_color)
        imgui.separator()

        -- === データロードボタン ===
        if imgui.button(T.load_button or "Load Data", { 120, 0 }) then
            log.info(LOG_PREFIX .. "'Load Data' button pressed.")
            critical_save_data_access_error_occurred = false -- ロード試行前にリセット

            basic_data_successfully_loaded = BasicData.load_basic_data_from_save()
            weapon_use_data_successfully_loaded = WeaponUseNum.load_all_weapon_counts_from_save()
            monster_hunt_data_successfully_loaded = MonsterHuntNum.load_monster_hunt_counts_from_save()

            if not basic_data_successfully_loaded and not weapon_use_data_successfully_loaded and not monster_hunt_data_successfully_loaded then
                critical_save_data_access_error_occurred = true
                log.error(LOG_PREFIX .. "All data load functions failed. Marked as critical access error.")
                re.msg(T.msg_load_all_fail or "Critical Error: Failed to access save data structure.")
            else
                if basic_data_successfully_loaded and weapon_use_data_successfully_loaded and monster_hunt_data_successfully_loaded then
                    re.msg(T.msg_load_complete or "Load Complete!")
                else
                    re.msg(T.msg_load_partial_fail or "Some data failed to load. Check log.")
                end
            end
        end
        imgui.separator()

        -- === データセーブボタンと編集セクション (アクセスエラー時は無効化) ===
        imgui.begin_disabled(critical_save_data_access_error_occurred)
        if imgui.button(T.save_changes_button or "Save Changes", { 120, 0 }) then
            log.info(LOG_PREFIX .. "'Save Changes' button pressed.")
            
            -- チャーム機能はロード状態に依存しないため、このチェックは主要3機能のみを対象とする
            local main_features_not_loaded = not basic_data_successfully_loaded and 
                                             not weapon_use_data_successfully_loaded and 
                                             not monster_hunt_data_successfully_loaded
            
            -- チャームのチェック状態を取得 (保存ボタン押下時の状態)
            local charm_checkbox_is_checked_on_save = CharmEditor.ui_state_set_all_non_dlc_charms_owned

            if main_features_not_loaded and not charm_checkbox_is_checked_on_save then
                re.msg(T.msg_save_please_load_first or "Please load data or check an option to save.")
            else
                local save_operation_results = {}
                local overall_save_process_success = true 

                -- 基本情報の保存
                if basic_data_successfully_loaded then
                    save_operation_results.basic = BasicData.write_basic_data_to_save()
                    if not save_operation_results.basic then overall_save_process_success = false end
                else
                    save_operation_results.basic = nil 
                end

                -- 武器使用回数の保存
                if weapon_use_data_successfully_loaded then
                    local weapon_save_attempted = false
                    local weapon_save_all_ok = true
                    for _, defined_category_data_entry in ipairs(Localized.game_data.quest_categories) do
                        local category_key_from_def = defined_category_data_entry.key
                        local category_fixed_id_to_use_for_write = defined_category_data_entry.category_fixed_id

                        if WeaponUseNum.ui_state_weapon_use[category_key_from_def] and category_fixed_id_to_use_for_write ~= 0 then
                            weapon_save_attempted = true
                            local ui_data_for_category = WeaponUseNum.ui_state_weapon_use[category_key_from_def]
                            for _, weapon_type_def_entry in ipairs(Localized.game_data.weapon_types) do
                                local weapon_id = weapon_type_def_entry.id
                                if not WeaponUseNum.write_weapon_use_count_to_save(category_fixed_id_to_use_for_write, "Main", weapon_id, ui_data_for_category.Main[weapon_id]) then weapon_save_all_ok = false end
                                if not WeaponUseNum.write_weapon_use_count_to_save(category_fixed_id_to_use_for_write, "Sub", weapon_id, ui_data_for_category.Sub[weapon_id]) then weapon_save_all_ok = false end
                            end
                            if not WeaponUseNum.write_category_total_quest_count_to_save(category_fixed_id_to_use_for_write, ui_data_for_category.TotalMain) then weapon_save_all_ok = false end
                        end
                    end
                    save_operation_results.weapon = weapon_save_attempted and weapon_save_all_ok
                    if not weapon_save_all_ok then overall_save_process_success = false end
                else
                    save_operation_results.weapon = nil
                end

                -- モンスター狩猟数の保存
                if monster_hunt_data_successfully_loaded then
                    local monster_save_attempted = false
                    local monster_save_all_ok = true
                    for monster_fixed_id, hunt_stat_data_in_ui in pairs(MonsterHuntNum.ui_state_monster_hunt) do
                        monster_save_attempted = true
                        if not MonsterHuntNum.write_monster_hunt_stat_to_save(monster_fixed_id, Constants.FIELD_MONSTER_SLAYING_NUM, hunt_stat_data_in_ui.SlayingNum) then monster_save_all_ok = false end
                        if not MonsterHuntNum.write_monster_hunt_stat_to_save(monster_fixed_id, Constants.FIELD_MONSTER_CAPTURE_NUM, hunt_stat_data_in_ui.CaptureNum) then monster_save_all_ok = false end
                        if not MonsterHuntNum.write_monster_hunt_stat_to_save(monster_fixed_id, Constants.FIELD_MONSTER_MIN_SIZE, hunt_stat_data_in_ui.MixSize) then monster_save_all_ok = false end
                        if not MonsterHuntNum.write_monster_hunt_stat_to_save(monster_fixed_id, Constants.FIELD_MONSTER_MAX_SIZE, hunt_stat_data_in_ui.MaxSize) then monster_save_all_ok = false end
                    end
                    save_operation_results.monster = monster_save_attempted and monster_save_all_ok
                    if not monster_save_all_ok then overall_save_process_success = false end
                else
                    save_operation_results.monster = nil
                end

                -- チャームデータの保存
                save_operation_results.charm = CharmEditor.apply_charm_ownership_settings()
                if not save_operation_results.charm then 
                    overall_save_process_success = false 
                    log.warn(LOG_PREFIX .. "Charm settings save operation returned false.")
                end
    
                -- 最終的な保存結果メッセージの組み立て
                local final_save_message_parts = {}
                if save_operation_results.basic == false then table.insert(final_save_message_parts,
                        T.msg_save_fail_basic or "BasicInfo fail.") end
                if save_operation_results.weapon == false then table.insert(final_save_message_parts,
                        T.msg_save_fail_wpn_use or "WeaponUse fail.") end
                if save_operation_results.monster == false then table.insert(final_save_message_parts,
                        T.msg_save_fail_mon_hunt or "MonsterHunt fail.") end
                -- チャーム処理がfalseを返した場合 (明確なエラー) は、overall_save_process_success が false になるので、
                -- 下の分岐で「一部失敗」系のメッセージが出る。個別のチャームエラーメッセージはここでは追加しない。
    
                if #final_save_message_parts == 0 and overall_save_process_success then
                    -- 全ての処理が成功 (または何も処理するものがなかったがエラーでもない)
                    local no_main_features_saved = save_operation_results.basic == nil and 
                                                   save_operation_results.weapon == nil and 
                                                   save_operation_results.monster == nil
                    
                    if no_main_features_saved and (save_operation_results.charm == true and not charm_checkbox_is_checked_on_save) then 
                        -- 主要3機能がロードされておらず (保存対象外)、かつチャームもチェックされていなかった (保存対象外) 場合
                        re.msg(T.msg_save_no_data_to_save or "No data loaded or changed to save.")
                    else
                        re.msg(T.msg_save_complete or "Update Complete! Please save in-game and restart.")
                    end
                else
                    -- 何らかのエラーがあった、または一部の処理が失敗した場合
                    local error_intro = T.msg_save_fail_prefix or "Save fail:"
                    if #final_save_message_parts == 0 then
                        -- final_save_message_parts に具体的なエラーがないが、overall_save_process_success が false の場合
                        -- (例: チャーム処理のみ失敗し、他は成功または未処理)
                        re.msg(error_intro .. " " .. (T.msg_save_partial_fail or "Some operations failed.") .. " Check log.")
                    else
                         re.msg(error_intro .. " " .. table.concat(final_save_message_parts, " ") .. " Check log.")
                    end
                end
            end
        end
        imgui.separator()

        -- === 各編集セクション ===
        -- 基本情報セクション
        if imgui.tree_node(T.section_title_basic_data or "Basic Info") then
            if basic_data_successfully_loaded then
                BasicData.draw_basic_data_ui(true)
            else
                imgui.text_colored(T.load_needed_for_basic or "Load data to edit Basic Info.", 0xFFAAAAAA)
            end
            imgui.tree_pop()
        end

        -- 武器使用回数セクション
        if imgui.tree_node(T.section_title_weapon_use or "Weapon Use Counts") then
            if weapon_use_data_successfully_loaded then
                for _, category_def_entry in ipairs(Localized.game_data.quest_categories) do
                    WeaponUseNum.draw_weapon_use_table_for_category(category_def_entry)
                end
            else
                imgui.text_colored(T.load_needed_for_weapon or "Load data to edit Weapon Use Counts.", 0xFFAAAAAA)
            end
            imgui.tree_pop()
        end

        -- モンスター狩猟数セクション
        if imgui.tree_node(T.section_title_monster_hunt or "Monster Hunt Counts") then
            if monster_hunt_data_successfully_loaded then
                MonsterHuntNum.draw_monster_hunt_table_ui()
            else
                imgui.text_colored(T.load_needed_for_monster or "Load data to edit Monster Hunt Counts.", 0xFFAAAAAA)
            end
            imgui.tree_pop()
        end
        
        -- === チャーム取得セクション===
        if imgui.tree_node(T.section_title_charm_editor or "Charm Acquisition") then
            CharmEditor.draw_charm_editor_ui()
            imgui.tree_pop()
        end

        imgui.end_disabled() 
        imgui.tree_pop()     
    end
end)

log.info(LOG_PREFIX .. "SaveDataEditor MOD (v1.1.0 with refactoring and charm update) main script initialized.")