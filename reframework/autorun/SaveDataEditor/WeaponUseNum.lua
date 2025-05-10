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

local Localized = require("SaveDataEditor/Localized")

local M = {}

local LOG_PREFIX = "[SaveDataEditor-WeaponUseNum] "

M.ui_state_weapon_use = {}

function M.setup_weapon_use_ui_state()
    M.ui_state_weapon_use = {}
end
M.setup_weapon_use_ui_state()

function M.get_array_element_by_invoke(array_obj, index)
    if not array_obj then return nil, "Arr obj nil" end
    if type(array_obj) ~= "userdata" then return nil, "Not userdata" end
    local array_type_def = array_obj:get_type_definition()
    if not array_type_def then return nil, "No type def" end
    local get_method = array_type_def:get_method("Get")
    if not get_method then
        local system_array_type = sdk.find_type_definition("System.Array")
        if system_array_type then
            get_method = system_array_type:get_method("Get")
        end
        if not get_method then return nil, "No Get method" end
    end
    local success, result = pcall(get_method.call, get_method, array_obj, index)
    if not success then return nil, "Call Get fail:" .. tostring(result) end
    if type(result) == "userdata" then return result, nil
    elseif type(result) == "number" and result ~= 0 then
        local obj = sdk.to_managed_object(result)
        if obj then return obj, nil else return nil, "Addr conv fail" end
    elseif result == nil then return nil, "Get returned nil (idx:" .. index .. ")"
    else return nil, "Get unexpected type:" .. type(result) end
end

function M.load_all_weapon_counts_from_save()
    M.setup_weapon_use_ui_state()
    local success_flag = false
    local last_error = "Unknown load error"
    local ok, err = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager")
        if not sdManager then error("SDM nil") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData")
        if not getCurMeth then error("gcm nil") end
        local gs, r = pcall(getCurMeth.call, getCurMeth, sdManager)
        if not gs or not r then error("gcm call fail:" .. tostring(r)) end
        if r == nil then error("getCurrentUserSaveData returned nil") end
        local curSave
        if type(r) == "userdata" then curSave = r
        elseif type(r) == "number" and r ~= 0 then
            local cv_ok, cv_obj = pcall(sdk.to_managed_object, sdk, r)
            if cv_ok and cv_obj then curSave = cv_obj else error("Save obj conv fail(to_man):" .. tostring(cv_obj)) end
        else error("Save obj conv fail(type/val):T=" .. type(r) .. ",V=" .. tostring(r)) end
        if not curSave then error("curSave nil") end

        local hProf = curSave:get_field("_HunterProfile")
        if not hProf then error("_HP nil") end
        local qClear = hProf:get_field("_QuestClearCounter")
        if not qClear then error("_QCC nil") end
        local catArr = qClear:get_field("_ClearNumPerCategory")
        if not catArr then error("_CNPC nil") end
        local cat_arr_size = catArr:get_size()

        for i = 0, cat_arr_size - 1 do
            local categoryClearNumParam, err_cat = M.get_array_element_by_invoke(catArr, i)
            if categoryClearNumParam then
                local saved_category_fixed_id = categoryClearNumParam:get_field("CategoryFixedId")
                if type(saved_category_fixed_id) == "number" and saved_category_fixed_id ~= 0 then
                    local target_category_key_from_def = nil
                    local localized_name_for_ui = "UnkCat(ID:" .. saved_category_fixed_id .. ")"

                    for _, defined_cat_data in ipairs(Localized.quest_categories_data) do
                        if defined_cat_data.category_fixed_id == saved_category_fixed_id then
                            target_category_key_from_def = defined_cat_data.key
                            localized_name_for_ui = defined_cat_data.localized_name
                            break
                        end
                    end

                    if target_category_key_from_def then
                        local mainArr = categoryClearNumParam:get_field("MainWeaponUseNum")
                        local subArr = categoryClearNumParam:get_field("SubWeaponUseNum")
                        if mainArr and subArr then
                            local mt, st = 0, 0
                            local main_counts = {}
                            local sub_counts = {}
                            for _, weapon in ipairs(Localized.weapon_types_data) do
                                local wid = weapon.id
                                local mc, sc = 0, 0
                                if mainArr:get_size() > wid then
                                    local el = mainArr:get_element(wid)
                                    if el then local v = el:get_field("m_value"); if type(v) == "number" then mc = v end end
                                end
                                if subArr:get_size() > wid then
                                    local el = subArr:get_element(wid)
                                    if el then local v = el:get_field("m_value"); if type(v) == "number" then sc = v end end
                                end
                                main_counts[wid] = mc
                                sub_counts[wid] = sc
                                mt = mt + mc
                                st = st + sc
                            end
                            M.ui_state_weapon_use[target_category_key_from_def] = {
                                Main = main_counts, Sub = sub_counts,
                                TotalMain = mt, TotalSub = st,
                                localized_name_to_display = localized_name_for_ui -- This is actually not used if draw_weapon_use_category_ui takes category_data_from_localized
                            }
                        end
                    end
                end
            end
        end
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Load fail pcall:" .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Load fail internal:" .. last_error) end
    return success_flag
end

function M.write_weapon_use_count_to_save(category_fixed_id_from_ui, weapon_group, weapon_id, new_count)
    if category_fixed_id_from_ui == 0 then return true end
    local success_flag = false
    local last_error = "Unknown write error"
    local ok, err = pcall(function()
        local sdm=sdk.get_managed_singleton("app.SaveDataManager");if not sdm then error("SDM nil")end;local gcm=sdm:get_type_definition():get_method("getCurrentUserSaveData");if not gcm then error("gcm nil")end;local gs,r=pcall(gcm.call,gcm,sdm);if not gs or not r then error("gcm call fail:"..tostring(r))end;if r==nil then error("gCurSaveData nil")end;local cs;if type(r)=="userdata"then cs=r elseif type(r)=="number"and r~=0 then local cv_ok,cv_obj=pcall(sdk.to_managed_object,sdk,r);if cv_ok and cv_obj then cs=cv_obj else error("Save obj conv fail(to_man):"..tostring(cv_obj))end else error("Save obj conv fail(type/val):T="..type(r)..",V="..tostring(r))end;if not cs then error("curSave nil")end
        local hProf=cs:get_field("_HunterProfile");if not hProf then error("_HP nil")end;local qClear=hProf:get_field("_QuestClearCounter");if not qClear then error("_QCC nil")end;local catArr=qClear:get_field("_ClearNumPerCategory");if not catArr then error("_CNPC nil")end
        local targetCategoryParam=nil
        for i=0,catArr:get_size()-1 do
            local tempParam,_ = M.get_array_element_by_invoke(catArr,i)
            if tempParam then
                local saved_fixed_id = tempParam:get_field("CategoryFixedId")
                if type(saved_fixed_id) == "number" and saved_fixed_id == tonumber(category_fixed_id_from_ui) then
                    targetCategoryParam = tempParam
                    break
                end
            end
        end
        if not targetCategoryParam then error("Write:TargetCatParam not found:" .. category_fixed_id_from_ui) end
        local targetArrName = (weapon_group=="Main" and "MainWeaponUseNum") or "SubWeaponUseNum"
        local targetArrObj = targetCategoryParam:get_field(targetArrName)
        if not targetArrObj then error("ArrayGetFail:" .. targetArrName) end
        if targetArrObj:get_size() <= weapon_id then error("WpnID OOB:" .. weapon_id) end
        local assign_s, assign_e = pcall(function() targetArrObj[weapon_id] = new_count end)
        if not assign_s then error("DirectAssignFail:" .. tostring(assign_e)) end
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Write fail pcall:" .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Write fail internal:" .. last_error) end
    return success_flag
end

function M.write_category_total_to_num_field_in_save(category_fixed_id_from_ui, total_count)
    if category_fixed_id_from_ui == 0 then return true end
    local success_flag = false
    local last_error = "Unknown write error"
    local ok, err = pcall(function()
        local sdm=sdk.get_managed_singleton("app.SaveDataManager");if not sdm then error("SDM nil")end;local gcm=sdm:get_type_definition():get_method("getCurrentUserSaveData");if not gcm then error("gcm nil")end;local gs,r=pcall(gcm.call,gcm,sdm);if not gs or not r then error("gcm call fail:"..tostring(r))end;if r==nil then error("gCurSaveData nil")end;local cs;if type(r)=="userdata"then cs=r elseif type(r)=="number"and r~=0 then local cv_ok,cv_obj=pcall(sdk.to_managed_object,sdk,r);if cv_ok and cv_obj then cs=cv_obj else error("Save obj conv fail(to_man):"..tostring(cv_obj))end else error("Save obj conv fail(type/val):T="..type(r)..",V="..tostring(r))end;if not cs then error("curSave nil")end
        local hProf=cs:get_field("_HunterProfile");if not hProf then error("_HP nil")end;local qClear=hProf:get_field("_QuestClearCounter");if not qClear then error("_QCC nil")end;local catArr=qClear:get_field("_ClearNumPerCategory");if not catArr then error("_CNPC nil")end
        local targetCategoryParam = nil
        for i = 0, catArr:get_size() - 1 do
            local tempParam, _ = M.get_array_element_by_invoke(catArr, i)
            if tempParam then
                local saved_fixed_id = tempParam:get_field("CategoryFixedId")
                if type(saved_fixed_id) == "number" and saved_fixed_id == tonumber(category_fixed_id_from_ui) then
                    targetCategoryParam = tempParam
                    break
                end
            end
        end
        if not targetCategoryParam then error("WriteNum:TargetCatParam not found:" .. category_fixed_id_from_ui) end
        local ss, se = pcall(function() targetCategoryParam.Num = total_count end)
        if not ss then error("DirectAssign Num fail:" .. tostring(se)) end
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Write Num fail pcall:" .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Write Num fail internal:" .. last_error) end
    return success_flag
end

function M.draw_weapon_use_drag_ints(category_key_for_ui_state, weapon_group, category_fixed_id_for_write)
    local drag_int_width = 120.0
    for _, weapon_data in ipairs(Localized.weapon_types_data) do
        local wid = weapon_data.id
        local drgid = string.format("##WpnUseDrag_%s_%s_%d", category_key_for_ui_state, weapon_group, wid)
        local cur_v = M.ui_state_weapon_use[category_key_for_ui_state][weapon_group][wid] or 0
        imgui.set_next_item_width(drag_int_width)
        local chg, new_v = imgui.drag_int((weapon_data.localized_name or "WpnNameErr") .. drgid, cur_v, 1.0, 0, 9999)
        if chg then
            M.ui_state_weapon_use[category_key_for_ui_state][weapon_group][wid] = new_v
            local tot = 0
            if weapon_group == "Main" then
                for _, w in ipairs(Localized.weapon_types_data) do tot = tot + (M.ui_state_weapon_use[category_key_for_ui_state].Main[w.id] or 0) end
                M.ui_state_weapon_use[category_key_for_ui_state].TotalMain = tot
            elseif weapon_group == "Sub" then
                for _, w in ipairs(Localized.weapon_types_data) do tot = tot + (M.ui_state_weapon_use[category_key_for_ui_state].Sub[w.id] or 0) end
                M.ui_state_weapon_use[category_key_for_ui_state].TotalSub = tot
            end
        end
    end
end

function M.draw_weapon_use_category_ui(category_data_from_localized)
    local T = Localized.T
    local category_key = category_data_from_localized.key
    local ui_data_for_this_category = M.ui_state_weapon_use[category_key]

    if imgui.tree_node((category_data_from_localized.localized_name or "CatNameErr") .. "##WpnUseCat_" .. category_key) then
        if not ui_data_for_this_category then
            imgui.text_colored(T.no_play_history_for_category or "No play history.", 0xFFAAAAAA)
            imgui.tree_pop()
            return
        end

        imgui.text(string.format("%s: %d", T.main_total, ui_data_for_this_category.TotalMain))
        imgui.text(string.format("%s: %d", T.sub_total, ui_data_for_this_category.TotalSub))
        local totals_match = false
        if category_key == "Assignments" then
            totals_match = (ui_data_for_this_category.TotalMain == ui_data_for_this_category.TotalSub + 2)
        else
            totals_match = (ui_data_for_this_category.TotalMain == ui_data_for_this_category.TotalSub)
        end
        if not totals_match then
            imgui.text_colored(T.total_mismatch_warning, 0xFFFF0000)
        end
        imgui.separator()

        if imgui.tree_node(T.main_weapon .. "##WpnUseMain_" .. category_key) then
            M.draw_weapon_use_drag_ints(category_key, "Main", category_data_from_localized.category_fixed_id)
            imgui.tree_pop()
        end
        if imgui.tree_node(T.sub_weapon .. "##WpnUseSub_" .. category_key) then
            M.draw_weapon_use_drag_ints(category_key, "Sub", category_data_from_localized.category_fixed_id)
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
end

return M