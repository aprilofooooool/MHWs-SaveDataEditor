local sdk = sdk
local log = log
local imgui = imgui
local ipairs = ipairs
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
    for _, category_data in ipairs(Localized.quest_categories_data) do
        local category_key = category_data.key
        M.ui_state_weapon_use[category_key] = { Main = {}, Sub = {}, TotalMain = 0, TotalSub = 0 }
        for _, weapon_data in ipairs(Localized.weapon_types_data) do
            local weapon_id = weapon_data.id
            M.ui_state_weapon_use[category_key].Main[weapon_id] = 0; M.ui_state_weapon_use[category_key].Sub[weapon_id] = 0
        end
    end
    -- log.info(LOG_PREFIX .. "UI state initialized.") -- Release: Remove info log
end

M.setup_weapon_use_ui_state()

function M.get_array_element_by_invoke(array_obj, index)
    if not array_obj then return nil, "Target array object is nil" end; if type(array_obj) ~= "userdata" then return nil, "Target is not a userdata object" end
    local array_type_def = array_obj:get_type_definition(); if not array_type_def then return nil, "Failed to get type definition" end
    local get_method = array_type_def:get_method("Get")
    if not get_method then local sys_arr_type=sdk.find_type_definition("System.Array"); if sys_arr_type then get_method=sys_arr_type:get_method("Get") end; if not get_method then return nil,"'Get' method not found" end end
    local success, result = pcall(get_method.call, get_method, array_obj, index)
    if not success then return nil, "Call to 'Get' failed: " .. tostring(result) end
    if type(result)=="userdata" then return result,nil elseif type(result)=="number" and result~=0 then local o=sdk.to_managed_object(result);if o then return o,nil else return nil,"Addr conv failed" end elseif result==nil then return nil,"'Get' returned nil" else return nil,"'Get' returned unexpected type:"..type(result) end
end

function M.load_all_weapon_counts_from_save()
    -- log.info(LOG_PREFIX .. "Loading weapon use counts from save...") -- Release: Remove info log
    M.setup_weapon_use_ui_state()
    local success_flag = false; local last_error = "Unknown load error"
    local ok, err = pcall(function()
        local sdManager=sdk.get_managed_singleton("app.SaveDataManager");if not sdManager then error("SDM not found") end
        local getCurMeth=sdManager:get_type_definition():get_method("getCurrentUserSaveData");if not getCurMeth then error("Method not found") end
        local get_s,res=pcall(getCurMeth.call,getCurMeth,sdManager);if not get_s or not res then error("Call getCurSaveData failed") end
        local curSave;if type(res)=="userdata"then curSave=res elseif type(res)=="number"and res~=0 then curSave=sdk.to_managed_object(res)end;if not curSave then error("Save object conv failed") end
        local hProf=curSave:get_field("_HunterProfile");if not hProf then error("_HunterProfile not found") end
        local qClear=hProf:get_field("_QuestClearCounter");if not qClear then error("_QuestClearCounter not found") end
        local catArr=qClear:get_field("_ClearNumPerCategory");if not catArr then error("_ClearNumPerCategory not found") end
        for i, category_data in ipairs(Localized.quest_categories_data) do
            local ck=category_data.key; local di=category_data.data_index
            local catParam,err_c=M.get_array_element_by_invoke(catArr,di)
            if catParam then
                local mainArr=catParam:get_field("MainWeaponUseNum"); local subArr=catParam:get_field("SubWeaponUseNum")
                if mainArr and subArr then
                    local mt,st=0,0
                    for _,weapon in ipairs(Localized.weapon_types_data) do
                        local wid=weapon.id; local mc,sc=0,0
                        if mainArr:get_size()>wid then local el=mainArr:get_element(wid);if el then local v=el:get_field("m_value");if type(v)=="number" then mc=v end end end
                        if subArr:get_size()>wid then local el=subArr:get_element(wid);if el then local v=el:get_field("m_value");if type(v)=="number" then sc=v end end end
                        M.ui_state_weapon_use[ck].Main[wid]=mc; M.ui_state_weapon_use[ck].Sub[wid]=sc; mt=mt+mc; st=st+sc
                    end
                    M.ui_state_weapon_use[ck].TotalMain=mt; M.ui_state_weapon_use[ck].TotalSub=st
                -- else log.warn(LOG_PREFIX..string.format("[%s]Failed get Main/Sub arrays",ck)) -- Release: Remove warn log
                end
            -- else log.warn(LOG_PREFIX..string.format("[%s]Failed get CatParam idx%d:%s",ck,di,err_c)) -- Release: Remove warn log
            end
        end
        success_flag=true
    end)
    if not ok then log.error(LOG_PREFIX .. "Load failed pcall: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Load failed internal: " .. last_error) end
    -- else log.info(LOG_PREFIX .. "Finished loading weapon use counts.") -- Release: Remove info log
    return success_flag
end

function M.write_weapon_use_count_to_save(category_data_index, weapon_group, weapon_id, new_count)
    local success_flag = false; local last_error = "Unknown write error"
    local ok, err = pcall(function()
        local sdManager=sdk.get_managed_singleton("app.SaveDataManager");if not sdManager then error("SDM not found") end
        local getCurMeth=sdManager:get_type_definition():get_method("getCurrentUserSaveData");if not getCurMeth then error("Method not found") end
        local get_s,res=pcall(getCurMeth.call,getCurMeth,sdManager);if not get_s or not res then error("Call getCurSaveData failed") end
        local curSave;if type(res)=="userdata"then curSave=res elseif type(res)=="number"and res~=0 then curSave=sdk.to_managed_object(res)end;if not curSave then error("Save object conv failed") end
        local hProf=curSave:get_field("_HunterProfile");if not hProf then error("_HunterProfile not found") end
        local qClear=hProf:get_field("_QuestClearCounter");if not qClear then error("_QuestClearCounter not found") end
        local catArr=qClear:get_field("_ClearNumPerCategory");if not catArr then error("_ClearNumPerCategory not found") end
        local catParam,err_c=M.get_array_element_by_invoke(catArr,category_data_index);if not catParam then error("CatParam get failed:"..tostring(err_c)) end
        local targetArrName=(weapon_group=="Main" and "MainWeaponUseNum")or"SubWeaponUseNum"
        local targetArrObj=catParam:get_field(targetArrName);if not targetArrObj then error("Array get failed:"..targetArrName) end
        if targetArrObj:get_size()<=weapon_id then error("WpnID out of bounds:"..weapon_id) end
        local assign_s,assign_e=pcall(function()targetArrObj[weapon_id]=new_count end);if not assign_s then error("Direct assign failed:"..tostring(assign_e)) end
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Write failed pcall: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Write failed internal: " .. last_error) end
    return success_flag
end

function M.write_category_total_to_num_field_in_save(category_data_index, total_count)
    local success_flag = false; local last_error = "Unknown write error"
    local ok, err = pcall(function()
        local sdManager=sdk.get_managed_singleton("app.SaveDataManager");if not sdManager then error("SDM not found") end
        local getCurMeth=sdManager:get_type_definition():get_method("getCurrentUserSaveData");if not getCurMeth then error("Method not found") end
        local get_s,res=pcall(getCurMeth.call,getCurMeth,sdManager);if not get_s or not res then error("Call getCurSaveData failed") end
        local curSave;if type(res)=="userdata"then curSave=res elseif type(res)=="number"and res~=0 then curSave=sdk.to_managed_object(res)end;if not curSave then error("Save object conv failed") end
        local hProf=curSave:get_field("_HunterProfile");if not hProf then error("_HunterProfile not found") end
        local qClear=hProf:get_field("_QuestClearCounter");if not qClear then error("_QuestClearCounter not found") end
        local catArr=qClear:get_field("_ClearNumPerCategory");if not catArr then error("_ClearNumPerCategory not found") end
        local catParam,err_c=M.get_array_element_by_invoke(catArr,category_data_index);if not catParam then error("CatParam get failed:"..tostring(err_c)) end
        local set_s,set_e=pcall(function()catParam.Num=total_count end);if not set_s then error("Direct assign 'Num' failed:"..tostring(set_e)) end
        success_flag = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Write Num failed pcall: " .. tostring(err)); last_error = tostring(err)
    elseif not success_flag then log.error(LOG_PREFIX .. "Write Num failed internal: " .. last_error) end
    return success_flag
end

function M.draw_weapon_use_drag_ints(category_key, weapon_group, category_data_index)
    local drag_int_width = 120.0
    for _, weapon_data in ipairs(Localized.weapon_types_data) do
        local wid=weapon_data.id; local drgid=string.format("##WpnUseDrag_%s_%s_%d",category_key,weapon_group,wid); local cur_v=M.ui_state_weapon_use[category_key][weapon_group][wid]or 0
        imgui.set_next_item_width(drag_int_width); local chg,new_v=imgui.drag_int((weapon_data.localized_name or "WpnNameErr")..drgid,cur_v,1.0,0,9999)
        if chg then M.ui_state_weapon_use[category_key][weapon_group][wid]=new_v; local tot=0;if weapon_group=="Main"then for _,w in ipairs(Localized.weapon_types_data)do tot=tot+(M.ui_state_weapon_use[category_key].Main[w.id]or 0)end;M.ui_state_weapon_use[category_key].TotalMain=tot elseif weapon_group=="Sub"then for _,w in ipairs(Localized.weapon_types_data)do tot=tot+(M.ui_state_weapon_use[category_key].Sub[w.id]or 0)end;M.ui_state_weapon_use[category_key].TotalSub=tot end end
    end
end

function M.draw_weapon_use_category_ui(category_data)
    local ck=category_data.key; local ui_d=M.ui_state_weapon_use[ck]; local T=Localized.T
    if imgui.tree_node((category_data.localized_name or "CatNameErr").."##WpnUseCat_"..ck) then
        imgui.text(string.format("%s: %d",T.main_total,ui_d.TotalMain)); imgui.text(string.format("%s: %d",T.sub_total,ui_d.TotalSub))
        local match=false; if ck=="Assignments"then match=(ui_d.TotalMain==ui_d.TotalSub+2) else match=(ui_d.TotalMain==ui_d.TotalSub) end; if not match then imgui.text_colored(T.total_mismatch_warning, 0xFFFF0000) end
        imgui.separator()
        if imgui.tree_node(T.main_weapon.."##WpnUseMain_"..ck) then M.draw_weapon_use_drag_ints(ck,"Main",category_data.data_index); imgui.tree_pop() end
        if imgui.tree_node(T.sub_weapon.."##WpnUseSub_"..ck) then M.draw_weapon_use_drag_ints(ck,"Sub",category_data.data_index); imgui.tree_pop() end
        imgui.tree_pop()
    end
end

return M