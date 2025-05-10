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
    PlayTime = 0, CharName = "", OtomoName = "",
}

local function decrypt_value(encrypted, multiplier)
    if multiplier == nil or multiplier == 0 then
        log.error(LOG_PREFIX .. "Decryption error: Multiplier zero or nil.")
        return 0
    end
    return math.floor(encrypted / multiplier)
end

local function encrypt_value(value, multiplier)
    if multiplier == nil then
        log.error(LOG_PREFIX .. "Encryption error: Multiplier nil.")
        return 0
    end
    return math.floor(value * multiplier)
end

local function get_decrypted_field_value(basic_data_obj, field_name)
    if not basic_data_obj then return nil, nil, "BasicData obj nil" end
    local mandrake_obj = basic_data_obj:get_field(field_name)
    if not mandrake_obj then return nil, nil, "Field get fail:" .. field_name end
    local encrypted_val = mandrake_obj:get_field("v")
    local multiplier_val = mandrake_obj:get_field("m")
    if type(encrypted_val) ~= "number" or type(multiplier_val) ~= "number" then
        return nil, nil, field_name .. " v or m field is not number"
    end
    local decrypted = decrypt_value(encrypted_val, multiplier_val)
    return decrypted, multiplier_val, nil
end

function M.load_basic_data_from_save()
    local success_flag = false
    local last_error = "Unknown load error"
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager"); if not sdManager then error("SaveDataManager not found") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData"); if not getCurMeth then error("getCurrentUserSaveData method not found") end
        local get_s, res = pcall(getCurMeth.call, getCurMeth, sdManager); if not get_s or not res then error("Failed to call getCurrentUserSaveData or got nil result") end
        local curSave; if type(res) == "userdata" then curSave = res elseif type(res) == "number" and res ~= 0 then curSave = sdk.to_managed_object(res) end
        if not curSave then error("Failed to get managed object for current save data") end
        local basicDataObj = curSave:get_field("_BasicData"); if not basicDataObj then error("_BasicData field not found") end

        local hrp, _, hrp_err = get_decrypted_field_value(basicDataObj, "HunterPoint")
        local money, _, money_err = get_decrypted_field_value(basicDataObj, "Money")
        local point, _, point_err = get_decrypted_field_value(basicDataObj, "Point")
        local ticket, _, ticket_err = get_decrypted_field_value(basicDataObj, "LuckyTicket")

        if hrp_err then error(hrp_err) end; if money_err then error(money_err) end; if point_err then error(point_err) end; if ticket_err then error(ticket_err) end

        M.ui_state_basic_data.HunterRankPoint = hrp or 0
        M.ui_state_basic_data.Money = money or 0
        M.ui_state_basic_data.GuildPoint = point or 0
        M.ui_state_basic_data.LuckyTicket = ticket or 0

        local play_time_val = curSave:get_field("PlayTime")
        M.ui_state_basic_data.PlayTime = (type(play_time_val) == "number") and play_time_val or 0
        local char_name_val = basicDataObj:get_field("CharName")
        M.ui_state_basic_data.CharName = (type(char_name_val) == "string") and char_name_val or ""
        local otomo_name_val = basicDataObj:get_field("OtomoName")
        M.ui_state_basic_data.OtomoName = (type(otomo_name_val) == "string") and otomo_name_val or ""
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Load failed: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Load failed internally: " .. last_error) end
    return success_flag
end

function M.write_basic_data_to_save()
    local overall_success = true
    local last_error_internal = "Unknown write error"
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager"); if not sdManager then error("SDM get failed") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData"); if not getCurMeth then error("gcm get failed") end
        local get_s, res = pcall(getCurMeth.call, getCurMeth, sdManager); if not get_s or not res then error("gcm call failed") end
        local curSave; if type(res) == "userdata" then curSave = res elseif type(res) == "number" and res ~= 0 then curSave = sdk.to_managed_object(res) end
        if not curSave then error("Save obj conv failed") end
        local basicDataObj = curSave:get_field("_BasicData"); if not basicDataObj then error("_BasicData get failed") end

        local fields_to_process = {
            { ui_key = "HunterRankPoint", field_name = "HunterPoint" }, { ui_key = "Money", field_name = "Money" },
            { ui_key = "GuildPoint", field_name = "Point" }, { ui_key = "LuckyTicket", field_name = "LuckyTicket" },
        }
        for _, field_info in ipairs(fields_to_process) do
            local ui_key = field_info.ui_key; local field_name = field_info.field_name
            local target_value_lua_num = M.ui_state_basic_data[ui_key]
            local mandrake_obj = basicDataObj:get_field(field_name); if not mandrake_obj then error(field_name .. " field get failed") end
            local current_multiplier = mandrake_obj:get_field("m"); if type(current_multiplier) ~= "number" then error(field_name .. " multiplier invalid") end
            local new_encrypted_v_num = encrypt_value(target_value_lua_num, current_multiplier)
            local set_v_ok, set_v_err; if mandrake_obj.set_field then set_v_ok, set_v_err = pcall(mandrake_obj.set_field, mandrake_obj, "v", new_encrypted_v_num); if not set_v_ok then error("Set local 'v' failed for " .. field_name .. ": " .. tostring(set_v_err)) end else error(":set_field not found on Mandrake for " .. field_name) end
            local set_back_ok, set_back_err; if basicDataObj.set_field then set_back_ok, set_back_err = pcall(basicDataObj.set_field, basicDataObj, field_name, mandrake_obj); if not set_back_ok then error("Set back Mandrake failed for " .. field_name .. ": " .. tostring(set_back_err)) end else error("Parent :set_field not found.") end
        end

        local pt_val = M.ui_state_basic_data.PlayTime; local pt_ok, pt_err = pcall(function() curSave.PlayTime = pt_val end)
        if not pt_ok then log.error(LOG_PREFIX .. "Write PlayTime failed:" .. tostring(pt_err)); overall_success = false end
        local cn_val = M.ui_state_basic_data.CharName; local cn_ok, cn_err = pcall(function() basicDataObj.CharName = cn_val end)
        if not cn_ok then log.error(LOG_PREFIX .. "Write CharName failed:" .. tostring(cn_err)); overall_success = false end
        local on_val = M.ui_state_basic_data.OtomoName; local on_ok, on_err = pcall(function() basicDataObj.OtomoName = on_val end)
        if not on_ok then log.error(LOG_PREFIX .. "Write OtomoName failed:" .. tostring(on_err)); overall_success = false end
    end)
    if not ok then log.error(LOG_PREFIX .. "Write failed during pcall:" .. tostring(err)); overall_success = false; last_error_internal = tostring(err)
    elseif not overall_success then log.error(LOG_PREFIX .. "Write finished with internal errors. Last: " .. (last_error_internal or "N/A")) end
    return overall_success
end

function M.draw_basic_data_ui(is_loaded)
    local T = Localized.T
    if not is_loaded then imgui.text_colored(T.load_needed_for_basic or "Load data.", 0xFFAAAAAA); return end
    local dw = 120.0; local iw = 120.0

    imgui.set_next_item_width(iw); local ch_cn, n_cn = imgui.input_text(T.char_name or "Char Name", M.ui_state_basic_data.CharName); if ch_cn then M.ui_state_basic_data.CharName = n_cn end
    imgui.set_next_item_width(iw); local ch_on, n_on = imgui.input_text(T.otomo_name or "Palico Name", M.ui_state_basic_data.OtomoName); if ch_on then M.ui_state_basic_data.OtomoName = n_on end
    imgui.set_next_item_width(dw); local ch_pt, n_pt = imgui.drag_int(T.play_time or "PlayTime(s)", M.ui_state_basic_data.PlayTime, 3600, 0, 0xFFFFFFFF); if ch_pt then M.ui_state_basic_data.PlayTime = n_pt end
    imgui.set_next_item_width(dw); local ch_h, n_h = imgui.drag_int(T.hunter_rank_point or "HR Pts", M.ui_state_basic_data.HunterRankPoint, 100, 0, 99999999); if ch_h then M.ui_state_basic_data.HunterRankPoint = n_h end
    imgui.set_next_item_width(dw); local ch_m, n_m = imgui.drag_int(T.money or "Money", M.ui_state_basic_data.Money, 1000, 0, 99999999); if ch_m then M.ui_state_basic_data.Money = n_m end
    imgui.set_next_item_width(dw); local ch_g, n_g = imgui.drag_int(T.guild_point or "Guild Pts", M.ui_state_basic_data.GuildPoint, 100, 0, 99999999); if ch_g then M.ui_state_basic_data.GuildPoint = n_g end
    imgui.set_next_item_width(dw); local ch_t, n_t = imgui.drag_int(T.lucky_ticket or "Lucky Vouchers", M.ui_state_basic_data.LuckyTicket, 1, 0, 5); if ch_t then M.ui_state_basic_data.LuckyTicket = n_t end
end

return M