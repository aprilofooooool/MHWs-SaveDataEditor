-- SaveDataEditor/SaveDataAccess.lua
-- セーブデータアクセス共通処理モジュール
local sdk = sdk
local log = log
local pcall = pcall
local type = type
local tostring = tostring

local Constants = require("SaveDataEditor/Constants")

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_SAVE_ACCESS

--- 現在のユーザーセーブデータオブジェクトを取得する
-- @return 成功時はカレントセーブデータのManagedObject、失敗時はnilとエラーメッセージ
function M.get_current_save_data_object()
    local save_data_manager = sdk.get_managed_singleton(Constants.SAVE_DATA_MANAGER_SINGLETON)
    if not save_data_manager then
        return nil, "SaveDataManager singleton not found."
    end

    local get_method = save_data_manager:get_type_definition():get_method(Constants
    .GET_CURRENT_USER_SAVE_DATA_METHOD_NAME)
    if not get_method then
        return nil, "'" .. Constants.GET_CURRENT_USER_SAVE_DATA_METHOD_NAME .. "' method not found in SaveDataManager."
    end

    local success, result = pcall(get_method.call, get_method, save_data_manager)
    if not success or result == nil then
        local err_msg = result or "Unknown error during call."
        return nil,
            "Failed to call '" ..
            Constants.GET_CURRENT_USER_SAVE_DATA_METHOD_NAME .. "' or got nil result: " .. tostring(err_msg)
    end

    if type(result) == "userdata" then
        return result, nil -- ManagedObjectが直接返された
    elseif type(result) == "number" and result ~= 0 then
        -- ポインタ(アドレス)が返された場合、ManagedObjectに変換
        local conv_success, obj = pcall(sdk.to_managed_object, sdk, result)
        if conv_success and obj then
            return obj, nil
        else
            local conv_err_msg = obj or "Unknown conversion error."
            log.error(LOG_PREFIX .. "Failed to convert save data address to managed object: " .. tostring(conv_err_msg))
            return nil, "Failed to convert save data address to managed object: " .. tostring(conv_err_msg)
        end
    else
        log.warn(LOG_PREFIX ..
        "Unexpected type or null value for save data from '" ..
        Constants.GET_CURRENT_USER_SAVE_DATA_METHOD_NAME .. "': Type=" .. type(result) .. ", Value=" .. tostring(result))
        return nil, "Unexpected type or null value for save data: Type=" .. type(result)
    end
end

return M
