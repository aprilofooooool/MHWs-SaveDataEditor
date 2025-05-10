local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local type = type
local string = string
local math = math

local Localized = require("SaveDataEditor/Localized")

local M = {}

local LOG_PREFIX = "[SaveDataEditor-BasicData] "

M.ui_state_basic_data = {
    HunterRankPoint = 0, Money = 0, GuildPoint = 0, LuckyTicket = 0,
}

local function decrypt_value(encrypted, multiplier)
    if multiplier == nil or multiplier == 0 then
        log.error(LOG_PREFIX .. "Decryption error: Multiplier is zero or nil.")
        return 0
    end
    return math.floor(encrypted / multiplier)
end

local function encrypt_value(value, multiplier)
    if multiplier == nil then
        log.error(LOG_PREFIX .. "Encryption error: Multiplier is nil.")
        return 0
    end
    return math.floor(value * multiplier)
end

local function get_decrypted_field_value(basic_data_obj, field_name)
    if not basic_data_obj then return nil, nil, "BasicData object is nil" end
    local mandrake_obj = basic_data_obj:get_field(field_name)
    if not mandrake_obj then return nil, nil, "Failed to get field: " .. field_name end
    local encrypted_val = mandrake_obj:get_field("v")
    local multiplier_val = mandrake_obj:get_field("m")
    if type(encrypted_val) ~= "number" or type(multiplier_val) ~= "number" then
        return nil, nil, field_name .. " 'v' or 'm' field is not a number"
    end
    local decrypted = decrypt_value(encrypted_val, multiplier_val)
    return decrypted, multiplier_val, nil
end

function M.load_basic_data_from_save()
    -- log.info(LOG_PREFIX .. "Loading basic data from save...") -- Release: Remove info log
    local success_flag = false
    local last_error = "Unknown load error"
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager") ; if not sdManager then error("SaveDataManager singleton not found") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData") ; if not getCurMeth then error("getCurrentUserSaveData method not found") end
        local get_s, res = pcall(getCurMeth.call, getCurMeth, sdManager) ; if not get_s or not res then error("Failed to call getCurrentUserSaveData") end
        local curSave; if type(res)=="userdata"then curSave=res elseif type(res)=="number"and res~=0 then curSave=sdk.to_managed_object(res)end; if not curSave then error("Failed to get managed save data object") end
        local basicDataObj = curSave:get_field("_BasicData"); if not basicDataObj then error("_BasicData field not found") end
        local hrp, _, hrp_err = get_decrypted_field_value(basicDataObj, "HunterPoint")
        local money, _, money_err = get_decrypted_field_value(basicDataObj, "Money")
        local point, _, point_err = get_decrypted_field_value(basicDataObj, "Point")
        local ticket, _, ticket_err = get_decrypted_field_value(basicDataObj, "LuckyTicket")
        if hrp_err then error(hrp_err) end; if money_err then error(money_err) end; if point_err then error(point_err) end; if ticket_err then error(ticket_err) end
        M.ui_state_basic_data.HunterRankPoint = hrp or 0; M.ui_state_basic_data.Money = money or 0; M.ui_state_basic_data.GuildPoint = point or 0; M.ui_state_basic_data.LuckyTicket = ticket or 0
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Load failed: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Load failed internally: " .. last_error) end
    return success_flag
end

function M.write_basic_data_to_save()
    -- log.info(LOG_PREFIX .. "Writing basic data to save...") -- Release: Remove info log
    local overall_success = true
    local last_error_internal = "Unknown write error"
    local ok, err = pcall(function()
        local sdManager=sdk.get_managed_singleton("app.SaveDataManager");if not sdManager then error("SDM get failed") end
        local getCurMeth=sdManager:get_type_definition():get_method("getCurrentUserSaveData");if not getCurMeth then error("Method get failed") end
        local get_s,res=pcall(getCurMeth.call,getCurMeth,sdManager);if not get_s or not res then error("SD get failed") end
        local curSave;if type(res)=="userdata"then curSave=res elseif type(res)=="number"and res~=0 then curSave=sdk.to_managed_object(res)end;if not curSave then error("SD Object conv failed") end
        local basicDataObj = curSave:get_field("_BasicData"); if not basicDataObj then error("_BasicData get failed") end
        local fields_to_process = { { ui_key = "HunterRankPoint", field_name = "HunterPoint" }, { ui_key = "Money", field_name = "Money" }, { ui_key = "GuildPoint", field_name = "Point" }, { ui_key = "LuckyTicket", field_name = "LuckyTicket" }, }
        for _, field_info in ipairs(fields_to_process) do
            local ui_key = field_info.ui_key; local field_name = field_info.field_name; local target_value_lua_num = M.ui_state_basic_data[ui_key]
            local mandrake_obj = basicDataObj:get_field(field_name); if not mandrake_obj then error(field_name .. " field get failed.") end
            local current_multiplier = mandrake_obj:get_field("m"); if type(current_multiplier) ~= "number" then error(field_name .. " multiplier invalid.") end
            local new_encrypted_v_num = encrypt_value(target_value_lua_num, current_multiplier)
            local set_v_ok, set_v_err; if mandrake_obj.set_field then set_v_ok, set_v_err = pcall(mandrake_obj.set_field, mandrake_obj, "v", new_encrypted_v_num); if not set_v_ok then error("Set local 'v' failed for " .. field_name .. ": " .. tostring(set_v_err)) end else error(":set_field not found on Mandrake for " .. field_name) end
            local set_back_ok, set_back_err; if basicDataObj.set_field then set_back_ok, set_back_err = pcall(basicDataObj.set_field, basicDataObj, field_name, mandrake_obj); if not set_back_ok then error("Set back Mandrake failed for " .. field_name .. ": " .. tostring(set_back_err)) end else error("Parent :set_field not found.") end
            -- log.info(LOG_PREFIX .. string.format("Value set attempt for [%s] finished (Target Value: %d).", field_name, target_value_lua_num)) -- Release: Remove info log
        end
    end)
    if not ok then log.error(LOG_PREFIX .. "Write failed during pcall: "..tostring(err)); overall_success=false; last_error_internal=tostring(err)
    elseif not overall_success then log.error(LOG_PREFIX .. "Write finished with internal errors. Last: " .. (last_error_internal or "N/A")) end
    return overall_success
end

function M.draw_basic_data_ui(is_loaded)
    local T = Localized.T
    if not is_loaded then imgui.text_colored(T.load_needed_for_basic or "Load data first.", 0xFFAAAAAA); return end
    local drag_int_width = 120.0
    imgui.set_next_item_width(drag_int_width); local ch_hrp, n_hrp = imgui.drag_int(T.hunter_rank_point or "HR Points", M.ui_state_basic_data.HunterRankPoint, 100, 0, 99999999); if ch_hrp then M.ui_state_basic_data.HunterRankPoint = n_hrp end
    imgui.set_next_item_width(drag_int_width); local ch_mon, n_mon = imgui.drag_int(T.money or "Money", M.ui_state_basic_data.Money, 1000, 0, 99999999); if ch_mon then M.ui_state_basic_data.Money = n_mon end
    imgui.set_next_item_width(drag_int_width); local ch_gp, n_gp = imgui.drag_int(T.guild_point or "Guild Points", M.ui_state_basic_data.GuildPoint, 100, 0, 99999999); if ch_gp then M.ui_state_basic_data.GuildPoint = n_gp end
    imgui.set_next_item_width(drag_int_width); local ch_tic, n_tic = imgui.drag_int(T.lucky_ticket or "Lucky Tickets", M.ui_state_basic_data.LuckyTicket, 1, 0, 5); if ch_tic then M.ui_state_basic_data.LuckyTicket = n_tic end
end

return M