-- SaveDataEditor/MonsterHuntNum.lua
-- モンスター狩猟数関連のデータ編集ロジックを担当するモジュール
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

-- 必須モジュールの読み込み
local Localized = require("SaveDataEditor/Localized")
local Constants = require("SaveDataEditor/Constants")
local Utils = require("SaveDataEditor/Utils") -- get_array_element_by_invoke を使用
local SaveDataAccess = require("SaveDataEditor/SaveDataAccess")

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_MONSTER_HUNT

-- UI表示用のモンスター狩猟情報データ一時保管テーブル
-- キー: モンスターのFixedId
-- 値: { SlayingNum, CaptureNum, MixSize, MaxSize, localized_name, original_array_index, min_size_lower_bound, max_size_upper_bound }
M.ui_state_monster_hunt = {}
-- UI表示順を管理するためのFixedIdのリスト
M.display_order_monster_hunt = {}

--- モンスター狩猟数UIの状態を初期化する
function M.reset_monster_hunt_ui_state()
    M.ui_state_monster_hunt = {}
    M.display_order_monster_hunt = {}
    log.info(LOG_PREFIX .. "Monster hunt UI state has been reset.")
end

M.reset_monster_hunt_ui_state() -- モジュールロード時に初期化

--- セーブデータからモンスターの狩猟数関連情報を読み込む
-- @return 読み込み成功時はtrue、失敗時はfalse
function M.load_monster_hunt_counts_from_save()
    M.reset_monster_hunt_ui_state() -- 読み込み前に状態をリセット
    local load_success = false
    local error_message = "Unknown error during monster hunt data load."

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object.") end

        local enemy_report_object = current_save_data:get_field(Constants.FIELD_SAVE_ENEMY_REPORT)
        if not enemy_report_object then error("'_EnemyReport' field not found in save data.") end

        local boss_array_object = enemy_report_object:get_field(Constants.FIELD_SAVE_BOSS_ARRAY)
        if not boss_array_object then error("'_Boss' array field not found in _EnemyReport.") end

        local boss_array_size = boss_array_object:get_size()
        if type(boss_array_size) ~= "number" then
            error("Failed to get a valid size for _Boss array. Type: " .. type(boss_array_size))
        end

        log.info(LOG_PREFIX .. "Processing _Boss array with size: " .. boss_array_size)

        for i = 0, boss_array_size - 1 do
            local boss_entry_object, err_get_elem = Utils.get_array_element_by_invoke(boss_array_object, i)
            if not boss_entry_object then
                log.warn(LOG_PREFIX ..
                "Failed to get boss entry at index " .. i .. ": " .. (err_get_elem or "Unknown reason"))
                goto continue_loop -- gotoでループの次のイテレーションへ (Lua 5.2以降)
            end

            local fixed_id_value = boss_entry_object:get_field(Constants.FIELD_MONSTER_FIXED_ID)
            if type(fixed_id_value) == "number" and fixed_id_value ~= 0 then
                local monster_definition = nil
                local localized_monster_name = Localized.T.unknown_monster_name_prefix .. fixed_id_value

                -- Localized.game_data からモンスター定義を検索
                for _, m_def in ipairs(Localized.game_data.monster_list) do
                    if m_def.FixedId == fixed_id_value then
                        monster_definition = m_def
                        localized_monster_name = m_def.localized_name -- ローカライズ済みの名前を使用
                        break
                    end
                end

                if monster_definition then
                    local slaying_num = boss_entry_object:get_field(Constants.FIELD_MONSTER_SLAYING_NUM)
                    local capture_num = boss_entry_object:get_field(Constants.FIELD_MONSTER_CAPTURE_NUM)
                    local min_size_val = boss_entry_object:get_field(Constants.FIELD_MONSTER_MIN_SIZE)
                    local max_size_val = boss_entry_object:get_field(Constants.FIELD_MONSTER_MAX_SIZE)

                    M.ui_state_monster_hunt[fixed_id_value] = {
                        SlayingNum           = (type(slaying_num) == "number") and slaying_num or
                        Constants.DEFAULT_NUMBER,
                        CaptureNum           = (type(capture_num) == "number") and capture_num or
                        Constants.DEFAULT_NUMBER,
                        MixSize              = (type(min_size_val) == "number") and min_size_val or
                        Constants.DEFAULT_NUMBER,                                                                   -- 0 or 9999?
                        MaxSize              = (type(max_size_val) == "number") and max_size_val or
                        Constants.DEFAULT_NUMBER,                                                                   -- 0?
                        localized_name       = localized_monster_name,
                        original_array_index = i,                                                                   -- 元の配列インデックスを保存 (書き込み時に使用)
                        min_size_lower_bound = monster_definition.min_size_lower_bound or
                        Constants.MIN_SIZE_LOWER_BOUND_DEFAULT,
                        max_size_upper_bound = monster_definition.max_size_upper_bound or
                        Constants.MAX_SIZE_UPPER_BOUND_DEFAULT
                    }
                    table.insert(M.display_order_monster_hunt, fixed_id_value)
                end
            end
            ::continue_loop::
        end
        load_success = true
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX .. "Load monster hunt data failed (pcall error): " .. error_message)
        load_success = false
    elseif not load_success then
        log.error(LOG_PREFIX .. "Load monster hunt data failed (internal logic): " .. error_message)
    else
        log.info(LOG_PREFIX ..
        "Monster hunt data loaded successfully. " .. #M.display_order_monster_hunt .. " monsters processed.")
    end
    return load_success
end

--- 指定されたモンスターの特定の統計情報をセーブデータに書き込む
-- @param monster_fixed_id 対象モンスターのFixedId
-- @param stat_field_name 書き込む統計情報のフィールド名 (例: "SlayingNum")
-- @param new_value 新しい値
-- @return 書き込み成功時はtrue、失敗時はfalse
function M.write_monster_hunt_stat_to_save(monster_fixed_id, stat_field_name, new_value)
    local write_success = false
    local error_message = "Unknown error during monster hunt stat write."

    local monster_hunt_entry_for_ui = M.ui_state_monster_hunt[monster_fixed_id]
    if not monster_hunt_entry_for_ui or monster_hunt_entry_for_ui.original_array_index == nil then
        log.error(LOG_PREFIX ..
        "Write error: Invalid FixedId or missing original array index for FixedId: " .. tostring(monster_fixed_id))
        return false
    end
    local original_array_index = monster_hunt_entry_for_ui.original_array_index

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object for writing.") end

        local enemy_report_object = current_save_data:get_field(Constants.FIELD_SAVE_ENEMY_REPORT)
        if not enemy_report_object then error("'_EnemyReport' field not found for writing.") end

        local boss_array_object = enemy_report_object:get_field(Constants.FIELD_SAVE_BOSS_ARRAY)
        if not boss_array_object then error("'_Boss' array field not found in _EnemyReport for writing.") end

        if boss_array_object:get_size() <= original_array_index then
            error("Original array index (" ..
            original_array_index .. ") is out of bounds for _Boss array (size: " .. boss_array_object:get_size() .. ").")
        end

        local boss_entry_object, err_get_elem = Utils.get_array_element_by_invoke(boss_array_object, original_array_index)
        if not boss_entry_object then
            error("Failed to get boss entry object at original index " ..
            original_array_index .. " for writing: " .. (err_get_elem or "Unknown reason"))
        end

        -- REFrameworkはManagedObjectのフィールドへの直接代入をサポートする場合がある
        local assign_pcall_success, assign_pcall_error = pcall(function()
            boss_entry_object[stat_field_name] = new_value
        end)
        if not assign_pcall_success then
            error("Failed to assign value to field '" .. stat_field_name .. "': " .. tostring(assign_pcall_error))
        end
        write_success = true
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX ..
        "Write monster stat '" ..
        stat_field_name .. "' for ID " .. monster_fixed_id .. " failed (pcall error): " .. error_message)
        write_success = false
    elseif not write_success then
        log.error(LOG_PREFIX ..
        "Write monster stat '" ..
        stat_field_name .. "' for ID " .. monster_fixed_id .. " failed (internal logic): " .. error_message)
    else
        log.info(LOG_PREFIX ..
        "Successfully wrote monster stat '" ..
        stat_field_name .. "' for ID " .. monster_fixed_id .. " with value " .. tostring(new_value))
    end
    return write_success
end

--- 言語変更時にUI上のモンスター名を更新する
function M.update_monster_names_localization()
    if not Localized or not Localized.T or not Localized.game_data or not Localized.game_data.monster_list then
        log.warn(LOG_PREFIX .. "Localization data not fully available for monster name update.")
        return
    end

    local current_language_code = Localized.display_language
    for fixed_id_key, hunt_data_entry_in_ui in pairs(M.ui_state_monster_hunt) do
        local updated_monster_name = Localized.T.unknown_monster_name_prefix .. fixed_id_key
        local monster_definition_found = nil

        for _, m_data_def_from_localized in ipairs(Localized.game_data.monster_list) do
            if m_data_def_from_localized.FixedId == fixed_id_key then
                monster_definition_found = m_data_def_from_localized
                -- ローカライズ済みの名前を使用 (Localized.initialize_localization で設定されているはず)
                updated_monster_name = m_data_def_from_localized.localized_name or m_data_def_from_localized.name_en
                break
            end
        end

        M.ui_state_monster_hunt[fixed_id_key].localized_name = updated_monster_name
        if monster_definition_found then
            M.ui_state_monster_hunt[fixed_id_key].min_size_lower_bound = monster_definition_found.min_size_lower_bound or
            Constants.MIN_SIZE_LOWER_BOUND_DEFAULT
            M.ui_state_monster_hunt[fixed_id_key].max_size_upper_bound = monster_definition_found.max_size_upper_bound or
            Constants.MAX_SIZE_UPPER_BOUND_DEFAULT
        end
    end
    log.info(LOG_PREFIX .. "Monster names updated for language: " .. current_language_code)
end

--- モンスター狩猟数編集用のUIテーブルを描画する
function M.draw_monster_hunt_table_ui()
    local T = Localized.T -- 現在の言語テキストを取得

    -- テーブル全体を子ウィンドウに入れて幅を固定
    -- imgui.begin_child_window("MonsterHuntTableChildWindow", { 650, 0 }, true, 0) -- 幅を少し広げた

    local table_flags = imgui.TableFlags.Borders | imgui.TableFlags.RowBg | imgui.TableFlags.Resizable
    if imgui.begin_table("MonsterHuntDataTable", 5, table_flags, { 650, 0 }) then
        -- テーブルヘッダーの設定
        imgui.table_setup_column(T.label_monster_name_header or "Name", 0, 220.0)
        imgui.table_setup_column(T.label_slaying_num_header or "Slay", 0, 80.0)
        imgui.table_setup_column(T.label_capture_num_header or "Cap", 0, 80.0)
        imgui.table_setup_column(T.label_min_size_header or "Min", 0, 80.0)
        imgui.table_setup_column(T.label_max_size_header or "Max", 0, 80.0)
        imgui.table_headers_row()

        -- テーブルデータ行の描画
        for _, monster_fixed_id_to_display in ipairs(M.display_order_monster_hunt) do
            local current_monster_hunt_data = M.ui_state_monster_hunt[monster_fixed_id_to_display]
            if current_monster_hunt_data then
                imgui.table_next_row()

                -- モンスター名
                imgui.table_next_column()
                imgui.text(current_monster_hunt_data.localized_name or
                (Localized.T.unknown_monster_name_prefix .. monster_fixed_id_to_display))

                -- 討伐数
                imgui.table_next_column()
                local disable_slay_capture_edit = (current_monster_hunt_data.SlayingNum == 0 and current_monster_hunt_data.CaptureNum == 0)
                imgui.begin_disabled(disable_slay_capture_edit)
                imgui.push_item_width(-1) -- カラム幅に合わせる
                local slay_drag_id = "##SlayDrag_" .. monster_fixed_id_to_display
                local slay_changed, new_slay_val = imgui.drag_int(slay_drag_id, current_monster_hunt_data.SlayingNum, 1,
                    0, Constants.MAX_GENERIC_COUNT)
                if slay_changed and not disable_slay_capture_edit then M.ui_state_monster_hunt[monster_fixed_id_to_display].SlayingNum =
                    new_slay_val end
                imgui.pop_item_width()
                imgui.end_disabled()

                -- 捕獲数
                imgui.table_next_column()
                imgui.begin_disabled(disable_slay_capture_edit)
                imgui.push_item_width(-1)
                local capt_drag_id = "##CaptDrag_" .. monster_fixed_id_to_display
                local capt_changed, new_capt_val = imgui.drag_int(capt_drag_id, current_monster_hunt_data.CaptureNum, 1,
                    0, Constants.MAX_GENERIC_COUNT)
                if capt_changed and not disable_slay_capture_edit then M.ui_state_monster_hunt[monster_fixed_id_to_display].CaptureNum =
                    new_capt_val end
                imgui.pop_item_width()
                imgui.end_disabled()

                -- 最小サイズ
                imgui.table_next_column()
                -- MixSizeが特定の値(例: 9999)の場合、未記録または編集不可を示す
                local disable_min_size_edit = (current_monster_hunt_data.MixSize == Constants.MONSTER_MIN_SIZE_UNRECORDED_VALUE)
                imgui.begin_disabled(disable_min_size_edit)
                imgui.push_item_width(-1)
                local min_size_drag_id = "##MinSizeDrag_" .. monster_fixed_id_to_display
                local min_lower_bound = current_monster_hunt_data.min_size_lower_bound
                local min_changed, new_min_size_val = imgui.drag_int(min_size_drag_id, current_monster_hunt_data.MixSize,
                    1, min_lower_bound, Constants.MONSTER_SIZE_CROWN_MIN_THRESHOLD)                                                                                                       -- 最大値は仮
                if min_changed and not disable_min_size_edit then
                    -- 値のバリデーション (範囲内に収める)
                    if new_min_size_val < min_lower_bound then
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MixSize = min_lower_bound
                    elseif new_min_size_val > Constants.MONSTER_SIZE_CROWN_MIN_THRESHOLD then
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MixSize = Constants
                        .MONSTER_SIZE_CROWN_MIN_THRESHOLD
                    else
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MixSize = new_min_size_val
                    end
                end
                imgui.pop_item_width()
                imgui.end_disabled()

                -- 最大サイズ
                imgui.table_next_column()
                -- MaxSizeが特定の値(例: 0)の場合、未記録または編集不可を示す
                local disable_max_size_edit = (current_monster_hunt_data.MaxSize == Constants.MONSTER_MAX_SIZE_UNRECORDED_VALUE)
                imgui.begin_disabled(disable_max_size_edit)
                imgui.push_item_width(-1)
                local max_size_drag_id = "##MaxSizeDrag_" .. monster_fixed_id_to_display
                local max_upper_bound = current_monster_hunt_data.max_size_upper_bound
                local max_changed, new_max_size_val = imgui.drag_int(max_size_drag_id, current_monster_hunt_data.MaxSize,
                    1, Constants.MONSTER_SIZE_CROWN_MIN_THRESHOLD, max_upper_bound)                                                                                                       -- 最小値は仮
                if max_changed and not disable_max_size_edit then
                    -- 値のバリデーション
                    if new_max_size_val < Constants.MONSTER_SIZE_CROWN_MIN_THRESHOLD then
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MaxSize = Constants
                        .MONSTER_SIZE_CROWN_MIN_THRESHOLD
                    elseif new_max_size_val > max_upper_bound then
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MaxSize = max_upper_bound
                    else
                        M.ui_state_monster_hunt[monster_fixed_id_to_display].MaxSize = new_max_size_val
                    end
                end
                imgui.pop_item_width()
                imgui.end_disabled()
            end
        end
        imgui.end_table()
    end
    -- imgui.end_child_window()
end

return M
