-- SaveDataEditor/WeaponUseNum.lua
-- 武器使用回数関連のデータ編集ロジックを担当するモジュール
local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
local pairs = pairs -- UI stateのイテレートにpairsを使うことがあるかもしれないので残す
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

local LOG_PREFIX = Constants.LOG_PREFIX_WEAPON_USE

-- UI表示用の武器使用回数データ一時保管テーブル
-- キー: クエストカテゴリの 'key' (Localized.game_data.quest_categories で定義)
-- 値: { Main = {[w_id]=count,...}, Sub = {[w_id]=count,...}, TotalMain, TotalSub, localized_name, category_fixed_id }
M.ui_state_weapon_use = {}

--- 武器使用回数UIの状態を初期化する
function M.reset_weapon_use_ui_state()
    M.ui_state_weapon_use = {}
    log.info(LOG_PREFIX .. "Weapon use UI state has been reset.")
end

M.reset_weapon_use_ui_state() -- モジュールロード時に初期化

--- セーブデータから全てのクエストカテゴリの武器使用回数を読み込む
-- @return 読み込み成功時はtrue、失敗時はfalse
function M.load_all_weapon_counts_from_save()
    M.reset_weapon_use_ui_state() -- 読み込み前に状態をリセット
    local load_success = false
    local error_message = "Unknown error during weapon use data load."

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object.") end

        local hunter_profile_object = current_save_data:get_field(Constants.FIELD_SAVE_HUNTER_PROFILE)
        if not hunter_profile_object then error("'_HunterProfile' field not found in save data.") end

        local quest_clear_counter_object = hunter_profile_object:get_field(Constants.FIELD_SAVE_QUEST_CLEAR_COUNTER)
        if not quest_clear_counter_object then error("'_QuestClearCounter' field not found in _HunterProfile.") end

        local clear_num_per_category_array = quest_clear_counter_object:get_field(Constants
        .FIELD_SAVE_CLEAR_NUM_PER_CATEGORY)
        if not clear_num_per_category_array then error(
            "'_ClearNumPerCategory' array field not found in _QuestClearCounter.") end

        local category_array_size = clear_num_per_category_array:get_size()
        if type(category_array_size) ~= "number" then
            error("Failed to get a valid size for _ClearNumPerCategory array. Type: " .. type(category_array_size))
        end
        log.info(LOG_PREFIX .. "Processing _ClearNumPerCategory array with size: " .. category_array_size)

        for i = 0, category_array_size - 1 do
            local category_clear_param_object, err_get_elem = Utils.get_array_element_by_invoke(
            clear_num_per_category_array, i)
            if not category_clear_param_object then
                log.warn(LOG_PREFIX ..
                "Failed to get category clear param at index " .. i .. ": " .. (err_get_elem or "Reason unknown"))
                goto continue_category_loop
            end

            local saved_category_fixed_id = category_clear_param_object:get_field(Constants.FIELD_CATEGORY_FIXED_ID)
            if type(saved_category_fixed_id) == "number" and saved_category_fixed_id ~= 0 then
                local target_category_definition_key = nil
                local localized_category_name_for_ui = (Localized.T.unknown_category_name_prefix or "UnkCat(ID:") ..
                saved_category_fixed_id .. ")"

                -- Localized.game_data.quest_categories から該当カテゴリを検索
                for _, defined_category_data_entry in ipairs(Localized.game_data.quest_categories) do
                    if defined_category_data_entry.category_fixed_id == saved_category_fixed_id then
                        target_category_definition_key = defined_category_data_entry.key
                        localized_category_name_for_ui = defined_category_data_entry.localized_name -- ローカライズ済みの名前
                        break
                    end
                end

                if target_category_definition_key then
                    local main_weapon_use_num_array = category_clear_param_object:get_field(Constants
                    .FIELD_CATEGORY_MAIN_WEAPON_USE_NUM)
                    local sub_weapon_use_num_array = category_clear_param_object:get_field(Constants
                    .FIELD_CATEGORY_SUB_WEAPON_USE_NUM)

                    if main_weapon_use_num_array and sub_weapon_use_num_array then
                        local total_main_count = 0
                        local total_sub_count = 0
                        local main_weapon_counts_for_ui = {}
                        local sub_weapon_counts_for_ui = {}

                        for _, weapon_type_def in ipairs(Localized.game_data.weapon_types) do
                            local weapon_id = weapon_type_def.id
                            local main_count_for_weapon = Constants.DEFAULT_NUMBER
                            local sub_count_for_weapon = Constants.DEFAULT_NUMBER

                            -- メイン武器使用回数の読み込み (System.Int32[] など、プリミティブ型の配列を想定)
                            if main_weapon_use_num_array:get_size() > weapon_id then
                                local element_wrapper = main_weapon_use_num_array:get_element(weapon_id)         -- get_elementはラッパーを返す
                                if element_wrapper then
                                    local value = element_wrapper:get_field(Constants.FIELD_ARRAY_ELEMENT_VALUE) -- ラッパーから実際の値を取得
                                    if type(value) == "number" then main_count_for_weapon = value end
                                end
                            end

                            -- サブ武器使用回数の読み込み
                            if sub_weapon_use_num_array:get_size() > weapon_id then
                                local element_wrapper = sub_weapon_use_num_array:get_element(weapon_id)
                                if element_wrapper then
                                    local value = element_wrapper:get_field(Constants.FIELD_ARRAY_ELEMENT_VALUE)
                                    if type(value) == "number" then sub_count_for_weapon = value end
                                end
                            end

                            main_weapon_counts_for_ui[weapon_id] = main_count_for_weapon
                            sub_weapon_counts_for_ui[weapon_id] = sub_count_for_weapon
                            total_main_count = total_main_count + main_count_for_weapon
                            total_sub_count = total_sub_count + sub_count_for_weapon
                        end

                        M.ui_state_weapon_use[target_category_definition_key] = {
                            Main = main_weapon_counts_for_ui,
                            Sub = sub_weapon_counts_for_ui,
                            TotalMain = total_main_count,
                            TotalSub = total_sub_count,
                            localized_name = localized_category_name_for_ui,
                            category_fixed_id = saved_category_fixed_id
                        }
                    else
                        log.warn(LOG_PREFIX ..
                        "Main or Sub weapon use array not found for category FixedId: " .. saved_category_fixed_id)
                    end
                else
                    log.warn(LOG_PREFIX ..
                    "Definition not found for category FixedId: " .. saved_category_fixed_id .. ". Skipping.")
                end
            end
            ::continue_category_loop::
        end
        load_success = true
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX .. "Load weapon use data failed (pcall error): " .. error_message)
        load_success = false
    elseif not load_success then
        log.error(LOG_PREFIX .. "Load weapon use data failed (internal logic): " .. error_message)
    else
        log.info(LOG_PREFIX .. "Weapon use data loaded successfully.")
    end
    return load_success
end

--- 指定されたカテゴリの特定武器の使用回数をセーブデータに書き込む
-- @param category_fixed_id_from_ui 対象カテゴリのFixedId
-- @param weapon_group "Main" または "Sub"
-- @param weapon_id 対象武器のID
-- @param new_count 新しい使用回数
-- @return 書き込み成功時はtrue、失敗時はfalse
function M.write_weapon_use_count_to_save(category_fixed_id_from_ui, weapon_group_str, weapon_id, new_count)
    if category_fixed_id_from_ui == 0 then -- category_fixed_idが0の場合は特殊なケースとして処理しないことがある
        log.info(LOG_PREFIX .. "Skipping write for category_fixed_id 0.")
        return true
    end

    local write_success = false
    local error_message = "Unknown error during weapon use count write."

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object for writing.") end

        local hunter_profile_obj = current_save_data:get_field(Constants.FIELD_SAVE_HUNTER_PROFILE)
        if not hunter_profile_obj then error("'_HunterProfile' field not found for writing.") end
        local q_clear_counter_obj = hunter_profile_obj:get_field(Constants.FIELD_SAVE_QUEST_CLEAR_COUNTER)
        if not q_clear_counter_obj then error("'_QuestClearCounter' field not found for writing.") end
        local cat_num_array_obj = q_clear_counter_obj:get_field(Constants.FIELD_SAVE_CLEAR_NUM_PER_CATEGORY)
        if not cat_num_array_obj then error("'_ClearNumPerCategory' array field not found for writing.") end

        local target_category_param_object = nil
        for i = 0, cat_num_array_obj:get_size() - 1 do
            local temp_param_obj, _ = Utils.get_array_element_by_invoke(cat_num_array_obj, i)
            if temp_param_obj then
                local saved_fixed_id_in_array = temp_param_obj:get_field(Constants.FIELD_CATEGORY_FIXED_ID)
                if type(saved_fixed_id_in_array) == "number" and saved_fixed_id_in_array == tonumber(category_fixed_id_from_ui) then
                    target_category_param_object = temp_param_obj
                    break
                end
            end
        end

        if not target_category_param_object then
            error("Target category parameter object not found for FixedId: " .. category_fixed_id_from_ui)
        end

        local target_array_field_name = (weapon_group_str == "Main" and Constants.FIELD_CATEGORY_MAIN_WEAPON_USE_NUM) or
        Constants.FIELD_CATEGORY_SUB_WEAPON_USE_NUM
        local target_weapon_use_array_object = target_category_param_object:get_field(target_array_field_name)
        if not target_weapon_use_array_object then
            error("Target weapon use array '" .. target_array_field_name .. "' not found in category parameter object.")
        end

        if target_weapon_use_array_object:get_size() <= weapon_id then
            error("Weapon ID " ..
            weapon_id ..
            " is out of bounds for array '" ..
            target_array_field_name .. "' (size: " .. target_weapon_use_array_object:get_size() .. ").")
        end

        -- REFrameworkはプリミティブ型配列の要素への直接代入をサポート
        local assign_pcall_success, assign_pcall_error = pcall(function()
            target_weapon_use_array_object[weapon_id] = new_count
        end)
        if not assign_pcall_success then
            error("Failed to assign value to weapon use array: " .. tostring(assign_pcall_error))
        end
        write_success = true
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX ..
        "Write weapon use count for CatID " ..
        category_fixed_id_from_ui ..
        ", Group " .. weapon_group_str .. ", WpnID " .. weapon_id .. " failed (pcall error): " .. error_message)
        write_success = false
    elseif not write_success then
        log.error(LOG_PREFIX ..
        "Write weapon use count for CatID " ..
        category_fixed_id_from_ui ..
        ", Group " .. weapon_group_str .. ", WpnID " .. weapon_id .. " failed (internal logic): " .. error_message)
    else
        log.info(LOG_PREFIX ..
        "Successfully wrote weapon use count for CatID " ..
        category_fixed_id_from_ui ..
        ", Group " .. weapon_group_str .. ", WpnID " .. weapon_id .. " with value " .. new_count)
    end
    return write_success
end

--- 指定されたカテゴリの総クエストクリア回数 (Numフィールド) をセーブデータに書き込む
-- @param category_fixed_id_from_ui 対象カテゴリのFixedId
-- @param total_quest_count 新しい総クエストクリア回数
-- @return 書き込み成功時はtrue、失敗時はfalse
function M.write_category_total_quest_count_to_save(category_fixed_id_from_ui, total_quest_count)
    if category_fixed_id_from_ui == 0 then return true end -- 0はスキップ

    local write_success = false
    local error_message = "Unknown error during category total write."
    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data for writing totals.") end
        local h_prof = current_save_data:get_field(Constants.FIELD_SAVE_HUNTER_PROFILE)
        if not h_prof then error("HunterProfile nil for writing totals.") end
        local q_clear = h_prof:get_field(Constants.FIELD_SAVE_QUEST_CLEAR_COUNTER)
        if not q_clear then error("QuestClearCounter nil for writing totals.") end
        local cat_arr = q_clear:get_field(Constants.FIELD_SAVE_CLEAR_NUM_PER_CATEGORY)
        if not cat_arr then error("ClearNumPerCategory nil for writing totals.") end

        local target_category_param = nil
        for i = 0, cat_arr:get_size() - 1 do
            local temp_param, _ = Utils.get_array_element_by_invoke(cat_arr, i)
            if temp_param and temp_param:get_field(Constants.FIELD_CATEGORY_FIXED_ID) == tonumber(category_fixed_id_from_ui) then
                target_category_param = temp_param
                break
            end
        end

        if not target_category_param then error("Target category for total write not found: ID " ..
            category_fixed_id_from_ui) end

        local assign_ok, assign_err = pcall(function() target_category_param[Constants.FIELD_CATEGORY_TOTAL_NUM] =
            total_quest_count end)
        if not assign_ok then error("Failed to assign total count: " .. tostring(assign_err)) end
        write_success = true
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX ..
        "Write category total for ID " .. category_fixed_id_from_ui .. " failed (pcall): " .. error_message)
        write_success = false
    elseif not write_success then
        log.error(LOG_PREFIX ..
        "Write category total for ID " .. category_fixed_id_from_ui .. " failed (internal): " .. error_message)
    else
        log.info(LOG_PREFIX .. "Category total for ID " .. category_fixed_id_from_ui .. " written: " .. total_quest_count)
    end
    return write_success
end

--- 特定のクエストカテゴリの武器使用回数編集UIを描画する
-- @param category_definition_from_localized Localized.game_data.quest_categories 内のカテゴリ定義エントリ
function M.draw_weapon_use_table_for_category(category_definition_from_localized)
    local T = Localized.T -- 現在の言語テキストを取得
    local category_key_for_ui = category_definition_from_localized.key
    local ui_data_for_this_category = M.ui_state_weapon_use[category_key_for_ui]

    -- カテゴリごとのツリーノード
    local category_display_name = category_definition_from_localized.localized_name or
    (Localized.T.unknown_category_name_prefix .. category_key_for_ui)
    local tree_node_id = "##WeaponUseCategoryTreeNode_" .. category_key_for_ui
    if imgui.tree_node(category_display_name .. tree_node_id) then
        if not ui_data_for_this_category then
            imgui.text_colored(T.label_no_play_history_for_category or "No play history for this category.", 0xFFAAAAAA)
            imgui.tree_pop()
            return
        end

        -- 合計値表示と整合性チェック
        imgui.text(string.format("%s: %d", T.label_main_total or "Main Total", ui_data_for_this_category.TotalMain))
        imgui.same_line(nil, 20)
        imgui.text(string.format("%s: %d", T.label_sub_total or "Sub Total", ui_data_for_this_category.TotalSub))

        local totals_are_consistent
        local expected_relation_msg = ""
        if category_key_for_ui == "Assignments" then -- "Assignments" は任務クエストのキー
            totals_are_consistent = (ui_data_for_this_category.TotalMain == ui_data_for_this_category.TotalSub + Constants.ASSIGNMENTS_TOTAL_MAIN_OFFSET)
            expected_relation_msg = string.format("Main = Sub + %d", Constants.ASSIGNMENTS_TOTAL_MAIN_OFFSET)
        else
            totals_are_consistent = (ui_data_for_this_category.TotalMain == ui_data_for_this_category.TotalSub)
            expected_relation_msg = "Main = Sub"
        end
        if not totals_are_consistent then
            local warning_text = string.format(
            T.label_total_mismatch_warning or "<Warning> Totals mismatch! (Expected: %s)", expected_relation_msg)
            imgui.text_colored(warning_text, 0xFFFF0000) -- 赤色で警告
        end
        imgui.separator()

        -- 武器使用回数テーブル
        -- local child_window_id = "WeaponUseNumTableChild_" .. category_key_for_ui
        -- imgui.begin_child_window(child_window_id, { 450, 0 }, true, 0) -- 幅を調整
        local table_id_for_category = "WeaponUseTable_" .. category_key_for_ui
        local table_flags = imgui.TableFlags.BordersInnerV | imgui.TableFlags.RowBg
        if imgui.begin_table(table_id_for_category, 3, table_flags, { 650, 0 }) then
            imgui.table_setup_column(T.label_weapon_type_header or "Weapon Type", 0, 180.0)
            imgui.table_setup_column(T.label_main_weapon_header or "Main", 0, 100.0)
            imgui.table_setup_column(T.label_sub_weapon_header or "Sub", 0, 100.0)
            imgui.table_headers_row()

            for _, weapon_definition_entry in ipairs(Localized.game_data.weapon_types) do
                local weapon_id = weapon_definition_entry.id
                local weapon_display_name = weapon_definition_entry.localized_name or ("WpnID:" .. weapon_id)

                imgui.table_next_row()
                -- 武器種名
                imgui.table_next_column()
                imgui.text(weapon_display_name)

                -- メイン武器使用回数
                imgui.table_next_column()
                imgui.push_item_width(-1)     -- カラム幅に合わせる
                local main_drag_int_id = string.format("##WpnMainDrag_%s_%d", category_key_for_ui, weapon_id)
                local current_main_value = ui_data_for_this_category.Main[weapon_id] or Constants.DEFAULT_NUMBER
                local main_value_changed, new_main_value = imgui.drag_int(main_drag_int_id, current_main_value, 1, 0,
                    Constants.MAX_GENERIC_COUNT)
                if main_value_changed then
                    M.ui_state_weapon_use[category_key_for_ui].Main[weapon_id] = new_main_value
                    -- 合計値を再計算
                    local new_total_main = 0
                    for _, w_def_recalc in ipairs(Localized.game_data.weapon_types) do
                        new_total_main = new_total_main +
                        (M.ui_state_weapon_use[category_key_for_ui].Main[w_def_recalc.id] or 0)
                    end
                    M.ui_state_weapon_use[category_key_for_ui].TotalMain = new_total_main
                end
                imgui.pop_item_width()

                -- サブ武器使用回数
                imgui.table_next_column()
                imgui.push_item_width(-1)
                local sub_drag_int_id = string.format("##WpnSubDrag_%s_%d", category_key_for_ui, weapon_id)
                local current_sub_value = ui_data_for_this_category.Sub[weapon_id] or Constants.DEFAULT_NUMBER
                local sub_value_changed, new_sub_value = imgui.drag_int(sub_drag_int_id, current_sub_value, 1, 0,
                    Constants.MAX_GENERIC_COUNT)
                if sub_value_changed then
                    M.ui_state_weapon_use[category_key_for_ui].Sub[weapon_id] = new_sub_value
                    -- 合計値を再計算
                    local new_total_sub = 0
                    for _, w_def_recalc in ipairs(Localized.game_data.weapon_types) do
                        new_total_sub = new_total_sub +
                        (M.ui_state_weapon_use[category_key_for_ui].Sub[w_def_recalc.id] or 0)
                    end
                    M.ui_state_weapon_use[category_key_for_ui].TotalSub = new_total_sub
                end
                imgui.pop_item_width()
            end
            imgui.end_table()
        end
        -- imgui.end_child_window()
        imgui.tree_pop()
    end
end

return M
