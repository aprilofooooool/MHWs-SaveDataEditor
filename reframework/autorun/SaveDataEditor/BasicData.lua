-- SaveDataEditor/BasicData.lua
-- 基本情報 (ハンターランク、所持金など) の編集ロジックを担当するモジュール
local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local type = type
local string = string
local math = math -- 既に使用されているのでそのまま

-- 必須モジュールの読み込み
local Localized = require("SaveDataEditor/Localized")
local Constants = require("SaveDataEditor/Constants")
local Utils = require("SaveDataEditor/Utils")
local SaveDataAccess = require("SaveDataEditor/SaveDataAccess")

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_BASIC_DATA

-- UI表示用の基本情報データ一時保管テーブル
M.ui_state_basic_data = {
    HunterRankPoint = Constants.DEFAULT_NUMBER,
    Money = Constants.DEFAULT_NUMBER,
    GuildPoint = Constants.DEFAULT_NUMBER,
    LuckyTicket = Constants.DEFAULT_NUMBER,
    PlayTime = Constants.DEFAULT_NUMBER,
    CharName = Constants.DEFAULT_STRING,
    OtomoName = Constants.DEFAULT_STRING,
}

--- セーブデータから基本情報を読み込み、M.ui_state_basic_data に格納する
-- @return 読み込み成功時はtrue、失敗時はfalse
function M.load_basic_data_from_save()
    local load_success = false
    local error_message = "Unknown error during basic data load."

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object.") end

        local basic_data_object = current_save_data:get_field(Constants.FIELD_SAVE_BASIC_DATA)
        if not basic_data_object then error("'_BasicData' field not found in save data.") end

        -- Mandrake型フィールドの読み込み
        local hrp, _, hrp_err = Utils.get_decrypted_mandrake_field(basic_data_object, Constants.FIELD_BASIC_HUNTER_POINT)
        if hrp_err then error("Error reading HunterRankPoint: " .. hrp_err) end
        M.ui_state_basic_data.HunterRankPoint = hrp or Constants.DEFAULT_NUMBER

        local money, _, money_err = Utils.get_decrypted_mandrake_field(basic_data_object, Constants.FIELD_BASIC_MONEY)
        if money_err then error("Error reading Money: " .. money_err) end
        M.ui_state_basic_data.Money = money or Constants.DEFAULT_NUMBER

        local guild_points, _, gp_err = Utils.get_decrypted_mandrake_field(basic_data_object, Constants
        .FIELD_BASIC_POINT)
        if gp_err then error("Error reading GuildPoint: " .. gp_err) end
        M.ui_state_basic_data.GuildPoint = guild_points or Constants.DEFAULT_NUMBER

        local lucky_tickets, _, lt_err = Utils.get_decrypted_mandrake_field(basic_data_object,
            Constants.FIELD_BASIC_LUCKY_TICKET)
        if lt_err then error("Error reading LuckyTicket: " .. lt_err) end
        M.ui_state_basic_data.LuckyTicket = lucky_tickets or Constants.DEFAULT_NUMBER

        -- 通常フィールドの読み込み
        local play_time_value = current_save_data:get_field(Constants.FIELD_BASIC_PLAY_TIME)
        M.ui_state_basic_data.PlayTime = (type(play_time_value) == "number") and play_time_value or
        Constants.DEFAULT_NUMBER

        local char_name_value = basic_data_object:get_field(Constants.FIELD_BASIC_CHAR_NAME)
        M.ui_state_basic_data.CharName = (type(char_name_value) == "string") and char_name_value or
        Constants.DEFAULT_STRING

        local otomo_name_value = basic_data_object:get_field(Constants.FIELD_BASIC_OTOMO_NAME)
        M.ui_state_basic_data.OtomoName = (type(otomo_name_value) == "string") and otomo_name_value or
        Constants.DEFAULT_STRING

        load_success = true -- 全ての処理が成功した場合
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX .. "Load basic data failed (pcall error): " .. error_message)
        load_success = false
    elseif not load_success then -- pcallは成功したが、内部ロジックでload_successがtrueにならなかった場合
        log.error(LOG_PREFIX .. "Load basic data failed (internal logic): " .. error_message)
    else
        log.info(LOG_PREFIX .. "Basic data loaded successfully.")
    end
    return load_success
end

--- M.ui_state_basic_data の内容をセーブデータに書き込む
-- @return 書き込み成功時はtrue、失敗時はfalse
function M.write_basic_data_to_save()
    local overall_write_success = false
    local error_message = "Unknown error during basic data write."

    local pcall_success, pcall_result = pcall(function()
        local current_save_data, err_msg_save = SaveDataAccess.get_current_save_data_object()
        if not current_save_data then error(err_msg_save or "Failed to get current save data object for writing.") end

        local basic_data_object = current_save_data:get_field(Constants.FIELD_SAVE_BASIC_DATA)
        if not basic_data_object then error("'_BasicData' field not found in save data for writing.") end

        -- Mandrake型フィールドの書き込み処理
        local mandrake_fields_to_process = {
            { ui_key = "HunterRankPoint", field_name = Constants.FIELD_BASIC_HUNTER_POINT },
            { ui_key = "Money",           field_name = Constants.FIELD_BASIC_MONEY },
            { ui_key = "GuildPoint",      field_name = Constants.FIELD_BASIC_POINT },
            { ui_key = "LuckyTicket",     field_name = Constants.FIELD_BASIC_LUCKY_TICKET },
        }

        for _, field_detail in ipairs(mandrake_fields_to_process) do
            local target_plain_value = M.ui_state_basic_data[field_detail.ui_key]

            -- Mandrakeオブジェクトをローカルコピーとして取得 (sdk.set_fieldが使えない対策)
            local mandrake_obj_local_copy = basic_data_object:get_field(field_detail.field_name)
            if not mandrake_obj_local_copy then error("Failed to get Mandrake object for field: " ..
                field_detail.field_name) end

            local current_multiplier = mandrake_obj_local_copy:get_field(Constants.FIELD_MANDRAKE_MULTIPLIER)
            if type(current_multiplier) ~= "number" then
                error("Invalid multiplier for field '" ..
                field_detail.field_name .. "': type is " .. type(current_multiplier))
            end

            local new_encrypted_value = Utils.encrypt_mandrake_value(target_plain_value, current_multiplier)

            -- ローカルコピーの 'v' フィールドを更新
            -- Mandrakeオブジェクト自体が :set_field を持つことを期待
            if not mandrake_obj_local_copy.set_field then error("Mandrake object for '" ..
                field_detail.field_name .. "' does not have a ':set_field' method.") end
            local set_v_success, set_v_err = pcall(mandrake_obj_local_copy.set_field, mandrake_obj_local_copy,
                Constants.FIELD_MANDRAKE_ENCRYPTED_VALUE, new_encrypted_value)
            if not set_v_success then error("Failed to set 'v' on local Mandrake copy for '" ..
                field_detail.field_name .. "': " .. tostring(set_v_err)) end

            -- 変更したローカルコピーを親オブジェクトにセットし直す
            -- 親オブジェクト (_BasicData) が :set_field を持つことを期待
            if not basic_data_object.set_field then error(
                "Parent object '_BasicData' does not have a ':set_field' method.") end
            local set_back_success, set_back_err = pcall(basic_data_object.set_field, basic_data_object,
                field_detail.field_name, mandrake_obj_local_copy)
            if not set_back_success then error("Failed to set back modified Mandrake object for '" ..
                field_detail.field_name .. "': " .. tostring(set_back_err)) end

            log.info(LOG_PREFIX .. "Successfully wrote Mandrake field: " .. field_detail.field_name)
        end

        -- 通常フィールドの書き込み
        local write_direct_field = function(parent_obj, field_name_const, ui_value, field_description)
            local success, err = pcall(function() parent_obj[field_name_const] = ui_value end)
            if not success then
                log.error(LOG_PREFIX .. "Write " .. field_description .. " failed: " .. tostring(err))
                overall_write_success = false -- 1つでも失敗したら全体をfalseに
            else
                log.info(LOG_PREFIX .. "Successfully wrote field: " .. field_description)
            end
        end

        -- まず全体をtrueに設定し、個々の失敗でfalseにする
        overall_write_success = true
        write_direct_field(current_save_data, Constants.FIELD_BASIC_PLAY_TIME, M.ui_state_basic_data.PlayTime, "PlayTime")
        write_direct_field(basic_data_object, Constants.FIELD_BASIC_CHAR_NAME, M.ui_state_basic_data.CharName,
            "Character Name")
        write_direct_field(basic_data_object, Constants.FIELD_BASIC_OTOMO_NAME, M.ui_state_basic_data.OtomoName,
            "Otomo Name")
    end)

    if not pcall_success then
        error_message = tostring(pcall_result)
        log.error(LOG_PREFIX .. "Write basic data failed (pcall error): " .. error_message)
        overall_write_success = false
    elseif not overall_write_success then -- pcallは成功したが、内部ロジックで失敗があった場合
        log.error(LOG_PREFIX .. "Write basic data partially failed (internal logic). Check previous logs.")
    else
        log.info(LOG_PREFIX .. "Basic data written successfully.")
    end
    return overall_write_success
end

--- 基本情報編集用のUIを描画する
-- @param is_data_loaded データが正常に読み込まれているかのフラグ
function M.draw_basic_data_ui(is_data_loaded)
    local T = Localized.T -- 現在の言語テキストを取得
    if not is_data_loaded then
        imgui.text_colored(T.load_needed_for_basic or "Load data to edit Basic Info.", 0xFFAAAAAA)
        return
    end

    -- UI要素の幅定義
    local drag_int_width = 150.0   -- 数値入力フィールドの幅
    local input_text_width = 150.0 -- テキスト入力フィールドの幅

    -- 各種基本情報の編集UI
    imgui.set_next_item_width(input_text_width)
    local name_changed, new_char_name = imgui.input_text(T.label_char_name or "Character Name",
        M.ui_state_basic_data.CharName)
    if name_changed then M.ui_state_basic_data.CharName = new_char_name end

    imgui.set_next_item_width(input_text_width)
    local otomo_name_changed, new_otomo_name = imgui.input_text(T.label_otomo_name or "Palico Name",
        M.ui_state_basic_data.OtomoName)
    if otomo_name_changed then M.ui_state_basic_data.OtomoName = new_otomo_name end

    imgui.set_next_item_width(drag_int_width)
    local play_time_changed, new_play_time = imgui.drag_int(T.label_play_time or "Play Time (s)",
        M.ui_state_basic_data.PlayTime, 3600, 0, 0xFFFFFFFF)                                                                                           -- 上限は符号なし32bit整数の最大値
    if play_time_changed then M.ui_state_basic_data.PlayTime = new_play_time end

    imgui.set_next_item_width(drag_int_width)
    local hrp_changed, new_hrp = imgui.drag_int(T.label_hunter_rank_point or "HR Points",
        M.ui_state_basic_data.HunterRankPoint, 100, 0, Constants.MAX_MONEY_POINTS)
    if hrp_changed then M.ui_state_basic_data.HunterRankPoint = new_hrp end

    imgui.set_next_item_width(drag_int_width)
    local money_changed, new_money = imgui.drag_int(T.label_money or "Zenny", M.ui_state_basic_data.Money, 1000, 0,
        Constants.MAX_MONEY_POINTS)
    if money_changed then M.ui_state_basic_data.Money = new_money end

    imgui.set_next_item_width(drag_int_width)
    local gp_changed, new_gp = imgui.drag_int(T.label_guild_point or "Guild Points", M.ui_state_basic_data.GuildPoint,
        100, 0, Constants.MAX_MONEY_POINTS)
    if gp_changed then M.ui_state_basic_data.GuildPoint = new_gp end

    imgui.set_next_item_width(drag_int_width)
    local ticket_changed, new_ticket_count = imgui.drag_int(T.label_lucky_ticket or "Lucky Vouchers",
        M.ui_state_basic_data.LuckyTicket, 1, 0, Constants.MAX_LUCKY_TICKETS)
    if ticket_changed then M.ui_state_basic_data.LuckyTicket = new_ticket_count end
end

return M
