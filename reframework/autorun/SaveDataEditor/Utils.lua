-- SaveDataEditor/Utils.lua
-- 汎用ユーティリティ関数モジュール
local sdk = sdk
local log = log
local pcall = pcall
local type = type
local tostring = tostring
local math = math
local table = table

local Constants = require("SaveDataEditor/Constants")

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_UTILS

--- ManagedObjectの配列から指定インデックスの要素を安全に取得する
-- @param array_object ManagedObjectの配列インスタンス
-- @param index 取得したい要素の0ベースインデックス
-- @return 成功時は要素のManagedObject、失敗時はnilとエラーメッセージ
function M.get_array_element_by_invoke(array_object, index)
    if not array_object then return nil, "Array object is nil." end
    if type(array_object) ~= "userdata" then return nil, "Array object is not userdata." end

    local array_type_def = array_object:get_type_definition()
    if not array_type_def then return nil, "Failed to get type definition for array object." end

    local get_method = array_type_def:get_method(Constants.ARRAY_GET_METHOD_NAME)
    if not get_method then
        -- フォールバックとして System.Array の Get メソッドを試す
        local system_array_type = sdk.find_type_definition(Constants.SYSTEM_ARRAY_TYPENAME)
        if system_array_type then
            get_method = system_array_type:get_method(Constants.ARRAY_GET_METHOD_NAME)
        end
        if not get_method then return nil, "Failed to find 'Get' method on array object or System.Array." end
    end

    local success, result = pcall(get_method.call, get_method, array_object, index)
    if not success then
        return nil, "Call to 'Get' method failed: " .. tostring(result)
    end

    if result == nil then
        -- log.warn(LOG_PREFIX .. "'Get' method returned nil for index: " .. tostring(index)) -- 状況により警告
        return nil, "Get method returned nil for index: " .. tostring(index) -- 呼び出し側でnilを処理
    elseif type(result) == "userdata" then
        return result, nil                                                   -- ManagedObjectが直接返された
    elseif type(result) == "number" and result ~= 0 then
        -- ポインタ(アドレス)が返された場合、ManagedObjectに変換
        local success_conv, obj = pcall(sdk.to_managed_object, sdk, result)
        if success_conv and obj then
            return obj, nil
        else
            log.error(LOG_PREFIX .. "Failed to convert address to managed object: " .. tostring(obj))
            return nil, "Failed to convert address to managed object: " .. tostring(obj)
        end
    else
        -- 予期しない型 (0など)
        log.warn(LOG_PREFIX ..
        "Array 'Get' method returned unexpected type or value: " .. type(result) .. ", " .. tostring(result))
        return nil, "Array 'Get' method returned unexpected type: " .. type(result)
    end
end

--- Mandrake型で難読化された値を復号する
-- @param encrypted_value 難読化された値 (vフィールド)
-- @param multiplier 乗数 (mフィールド)
-- @return 復号された値、エラー時は0
function M.decrypt_mandrake_value(encrypted_value, multiplier)
    if type(encrypted_value) ~= "number" or type(multiplier) ~= "number" then
        log.error(LOG_PREFIX ..
        "Decryption error: Invalid input types. Encrypted: " ..
        type(encrypted_value) .. ", Multiplier: " .. type(multiplier))
        return Constants.DEFAULT_NUMBER
    end
    if multiplier == 0 then
        log.error(LOG_PREFIX .. "Decryption error: Multiplier is zero.")
        -- 0除算を避ける。状況に応じてエラーを投げるかデフォルト値を返す
        return Constants.DEFAULT_NUMBER
    end
    return math.floor(encrypted_value / multiplier)
end

--- 通常の値をMandrake型で用いるために暗号化(乗算)する
-- @param plain_value 通常の値
-- @param multiplier 乗数 (mフィールド)
-- @return 暗号化(乗算)された値、エラー時は0
function M.encrypt_mandrake_value(plain_value, multiplier)
    if type(plain_value) ~= "number" or type(multiplier) ~= "number" then
        log.error(LOG_PREFIX ..
        "Encryption error: Invalid input types. Plain: " .. type(plain_value) .. ", Multiplier: " .. type(multiplier))
        return Constants.DEFAULT_NUMBER
    end
    return math.floor(plain_value * multiplier)
end

--- ManagedObjectのMandrake型フィールドから値を復号して取得する
-- @param parent_object Mandrake型フィールドを持つ親オブジェクト
-- @param mandrake_field_name Mandrake型フィールドの名前
-- @return 復号された値、乗数、エラーメッセージ (成功時はエラーメッセージnil)
function M.get_decrypted_mandrake_field(parent_object, mandrake_field_name)
    if not parent_object then return nil, nil, "Parent object is nil for field: " .. mandrake_field_name end

    local mandrake_object = parent_object:get_field(mandrake_field_name)
    if not mandrake_object then
        return nil, nil, "Failed to get Mandrake field '" .. mandrake_field_name .. "' from parent object."
    end

    local encrypted_value = mandrake_object:get_field(Constants.FIELD_MANDRAKE_ENCRYPTED_VALUE)
    local multiplier_value = mandrake_object:get_field(Constants.FIELD_MANDRAKE_MULTIPLIER)

    if type(encrypted_value) ~= "number" then
        return nil, nil,
            "Encrypted value 'v' in '" .. mandrake_field_name .. "' is not a number: " .. type(encrypted_value)
    end
    if type(multiplier_value) ~= "number" then
        return nil, multiplier_value,
            "Multiplier 'm' in '" .. mandrake_field_name .. "' is not a number: " .. type(multiplier_value)
    end

    local decrypted_value = M.decrypt_mandrake_value(encrypted_value, multiplier_value)
    return decrypted_value, multiplier_value, nil
end

return M
