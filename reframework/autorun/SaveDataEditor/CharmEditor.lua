-- SaveDataEditor/CharmEditor.lua
-- チャームの所有フラグ編集機能を提供するモジュール
local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
local pcall = pcall
local string = string -- string.format などで使用する可能性があるため残す
local tostring = tostring
-- local pairs = pairs -- M.ui_state_charms が単一フラグになったため不要

local Localized = require("SaveDataEditor/Localized")
local Constants = require("SaveDataEditor/Constants")

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_CHARM_EDITOR

-- モジュールロード時の型定義事前チェック (情報として残す)
local initial_type_def_check_success, initial_type_def_or_error_msg = pcall(sdk.find_type_definition, sdk, Constants.CHARM_UTIL_TYPENAME)
if initial_type_def_check_success and initial_type_def_or_error_msg then
    log.info(LOG_PREFIX .. "Initial check at module load: Type definition for '" .. Constants.CHARM_UTIL_TYPENAME .. "' was found.")
else
    log.warn(LOG_PREFIX .. "Initial check at module load: Type definition for '" .. Constants.CHARM_UTIL_TYPENAME .. "' was NOT found. Error (if any): " .. tostring(initial_type_def_or_error_msg) .. ". This will be re-attempted when setting charms.")
end

-- 単一のチェックボックスの状態
M.ui_state_set_all_non_dlc_charms_owned = false

-- UI状態を初期化する関数
function M.initialize_ui_state()
    M.ui_state_set_all_non_dlc_charms_owned = false
    log.info(LOG_PREFIX .. "Charm UI state (single checkbox) initialized.")
end
M.initialize_ui_state() -- モジュールロード時に初期化

-- 内部関数: 単一のチャームを所有済みに設定する
local function set_single_charm_as_owned_internal(charm_type_number)
    log.info(LOG_PREFIX .. "Attempting to set charm type " .. charm_type_number .. " as owned.")

    local instance_created_success, instance_or_error = pcall(function()
        return sdk.create_instance(Constants.CHARM_UTIL_TYPENAME)
    end)
    
    if not instance_created_success or not instance_or_error then
        log.error(LOG_PREFIX .. "Failed to create instance of " .. Constants.CHARM_UTIL_TYPENAME .. ". Error/Result: " .. tostring(instance_or_error))
        return false
    end
    local charm_util_instance = instance_or_error
    log.info(LOG_PREFIX .. "'" .. Constants.CHARM_UTIL_TYPENAME .. "' instance successfully created.")
    
    local method_call_successful, method_call_error_details = pcall(function()
        charm_util_instance:call(Constants.CHARM_SET_IS_OWNED_METHOD_NAME, charm_type_number, true)
    end)

    if not method_call_successful then
        log.error(LOG_PREFIX .. "Failed to call method '" .. Constants.CHARM_SET_IS_OWNED_METHOD_NAME .. "' for charm type " .. charm_type_number .. ". Error details: " .. tostring(method_call_error_details))
        return false 
    else
        log.info(LOG_PREFIX .. "Method '" .. Constants.CHARM_SET_IS_OWNED_METHOD_NAME .. "' successfully called for charm type " .. charm_type_number .. ".")
        return true 
    end
end

-- チェックボックスの状態に基づいてチャームの所有フラグをゲームに書き込む
function M.apply_charm_ownership_settings()
    if not M.ui_state_set_all_non_dlc_charms_owned then
        log.info(LOG_PREFIX .. "Checkbox 'Set all non-DLC charms as owned' is not checked. No charm operations performed.")
        return true -- 何も処理しなかったが、処理自体はエラーではないのでtrue
    end

    log.info(LOG_PREFIX .. "Processing 'Save Changes' for charms: Attempting to set all non-DLC charms as owned.")
    
    if not Localized or not Localized.game_data or not Localized.game_data.charm_list then
        log.error(LOG_PREFIX .. "Cannot apply charm settings: Charm list not found in Localized.game_data.")
        return false -- これは処理の失敗
    end

    if #Localized.game_data.charm_list == 0 then
        log.warn(LOG_PREFIX .. "No charms defined in Localized.game_data.charm_list. Nothing to set as owned.")
        return true -- 定義がないので何もしないがエラーではない
    end

    local all_operations_successful = true
    local any_charms_processed = false

    for _, charm_data_entry in ipairs(Localized.game_data.charm_list) do
        any_charms_processed = true
        if not set_single_charm_as_owned_internal(charm_data_entry.type_num) then
            all_operations_successful = false
            -- 1つでも失敗したらループは継続するが、最終結果はfalseになる
        end
    end

    if not any_charms_processed then
        log.info(LOG_PREFIX .. "No charms were processed (e.g., empty charm_list).")
        -- このケースは上の #Localized.game_data.charm_list == 0 でカバーされるはずだが念のため
        return true 
    end

    if all_operations_successful then
        log.info(LOG_PREFIX .. "All defined non-DLC charms successfully processed to be set as owned.")
    else
        log.warn(LOG_PREFIX .. "Some non-DLC charms could not be set to owned. Check previous error logs.")
    end
    
    return all_operations_successful
end

-- チャーム編集用のUIを描画する
function M.draw_charm_editor_ui()
    local T = Localized.T -- UI内の固定テキスト用に T は残す

    if not Localized.game_data or not Localized.game_data.charm_list then
        imgui.text_colored(T.no_charms_defined_message or "No charms defined in Localized.lua (required for processing).", 0xFFAAAAAA)
        -- return -- リストがなくてもチェックボックス自体は表示して良いかもしれない
    end
    
    local checkbox_label = T.label_set_all_non_dlc_charms_owned or "Set all non-DLC charms as owned"
    local changed, new_value = imgui.checkbox(checkbox_label .. "##SetAllCharmsCheckbox", M.ui_state_set_all_non_dlc_charms_owned)
    if changed then
        M.ui_state_set_all_non_dlc_charms_owned = new_value
        log.info(LOG_PREFIX .. "Checkbox '" .. checkbox_label .. "' state changed to: " .. tostring(new_value))
    end
end

-- M.update_charm_names_localization() は個別のチャーム名を表示しなくなったため不要。
-- 呼び出し元 (SaveDataEditor.lua) からも削除する。

return M