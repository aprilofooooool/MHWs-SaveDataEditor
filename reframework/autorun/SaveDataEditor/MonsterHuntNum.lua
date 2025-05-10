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
local WeaponUseNum = require("SaveDataEditor/WeaponUseNum")

local M = {}

local LOG_PREFIX = "[SaveDataEditor-MonsterHuntNum] "

M.ui_state_monster_hunt = {}
M.display_order_monster_hunt = {}

function M.setup_monster_hunt_ui_state()
    M.ui_state_monster_hunt = {}
    M.display_order_monster_hunt = {}
end
M.setup_monster_hunt_ui_state()

function M.load_monster_hunt_counts_from_save()
    M.setup_monster_hunt_ui_state()
    local success_flag_local = false
    local last_error_local = "Unknown internal load error"
    local ok, err_or_result = pcall(function()
        local sdManager = sdk.get_managed_singleton("app.SaveDataManager"); if not sdManager then error("SDM nil") end
        local getCurMeth = sdManager:get_type_definition():get_method("getCurrentUserSaveData"); if not getCurMeth then error("gcm nil") end
        local gs, r = pcall(getCurMeth.call, getCurMeth, sdManager); if not gs or not r then error("gcm call fail:" .. tostring(r)) end
        if r == nil then error("gCurSaveData returned nil") end
        local curSave; if type(r) == "userdata" then curSave = r
        elseif type(r) == "number" and r ~= 0 then
            local cv_ok, cv_obj = pcall(sdk.to_managed_object, sdk, r)
            if cv_ok and cv_obj then curSave = cv_obj else error("Save obj conv fail(to_man):" .. tostring(cv_obj)) end
        else error("Save obj conv fail(type/val):T=" .. type(r) .. ",V=" .. tostring(r)) end
        if not curSave then error("curSave nil") end
        local enemyReport = curSave:get_field("_EnemyReport"); if not enemyReport then error("_EnemyReport nil") end
        local bossArray = enemyReport:get_field("_Boss"); if not bossArray then error("_Boss nil") end
        local bas = bossArray:get_size()

        for i = 0, bas - 1 do
            local beo, be = WeaponUseNum.get_array_element_by_invoke(bossArray, i)
            if beo then
                local fid = beo:get_field("FixedId")
                if type(fid) == "number" and fid ~= 0 then
                    local mn = nil; local nf = false; local monster_def = nil
                    for _, md in ipairs(Localized.monster_data_list) do
                        if md.FixedId == fid then
                            monster_def = md; mn = md.localized_name; nf = true; break
                        end
                    end
                    if nf and monster_def then
                        local snv = beo:get_field("SlayingNum"); local cnv = beo:get_field("CaptureNum")
                        local mix_s_v = beo:get_field("MixSize"); local max_s_v = beo:get_field("MaxSize")
                        local sn = (type(snv) == "number") and snv or 0; local cn = (type(cnv) == "number") and cnv or 0
                        local mix_s = (type(mix_s_v) == "number") and mix_s_v or 0; local max_s = (type(max_s_v) == "number") and max_s_v or 0
                        M.ui_state_monster_hunt[fid] = {
                            SlayingNum = sn, CaptureNum = cn, MixSize = mix_s, MaxSize = max_s,
                            localized_name = mn, original_array_index = i,
                            min_size_lower_bound = monster_def.min_size_lower_bound or 0,
                            max_size_upper_bound = monster_def.max_size_upper_bound or 9999
                        }
                        table.insert(M.display_order_monster_hunt, fid)
                    end
                end
            end
        end
        success_flag_local = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Load fail during pcall: " .. tostring(err_or_result)); success_flag_local = false
    elseif not success_flag_local then log.error(LOG_PREFIX .. "Load logically failed. Last known error: " .. last_error_local) end
    return success_flag_local
end

function M.write_monster_hunt_stat_to_save(fixed_id, stat_field_name, new_value)
    local success_flag_local = false
    local last_error_local = "Unknown write error"
    local hunt_data = M.ui_state_monster_hunt[fixed_id]
    if not hunt_data or hunt_data.original_array_index == nil then
        log.error(LOG_PREFIX .. "Write error: Invalid FixedId or missing index: " .. tostring(fixed_id))
        return false
    end
    local original_array_index = hunt_data.original_array_index
    local ok, err_or_result = pcall(function()
        local sdm=sdk.get_managed_singleton("app.SaveDataManager");if not sdm then error("SDM nil")end;local gcm=sdm:get_type_definition():get_method("getCurrentUserSaveData");if not gcm then error("gcm nil")end;local gs,r=pcall(gcm.call,gcm,sdm);if not gs or not r then error("gcm call fail")end;if r==nil then error("gCurSaveData nil")end;local cs;if type(r)=="userdata"then cs=r elseif type(r)=="number"and r~=0 then local cv_ok,cv_obj=pcall(sdk.to_managed_object,sdk,r);if cv_ok and cv_obj then cs=cv_obj else error("Save obj conv fail(to_man)")end else error("Save obj conv fail(type/val)")end;if not cs then error("curSave nil")end;local er=cs:get_field("_EnemyReport");if not er then error("_EnemyReport nil")end;local ba=er:get_field("_Boss");if not ba then error("_Boss nil")end
        if ba:get_size() <= original_array_index then error("Index out of bounds:" .. original_array_index) end
        local beo, be = WeaponUseNum.get_array_element_by_invoke(ba, original_array_index)
        if not beo then error("Boss entry get fail:" .. tostring(be)) end
        local assign_s, assign_e = pcall(function() beo[stat_field_name] = new_value end)
        if not assign_s then error("DirectAssign fail:" .. stat_field_name .. ":" .. tostring(assign_e)) end
        success_flag_local = true
    end)
    if not ok then log.error(LOG_PREFIX .. "Write failed during pcall: " .. tostring(err_or_result)); success_flag_local = false
    elseif not success_flag_local then log.error(LOG_PREFIX .. "Write logically failed. Last known error: " .. last_error_local) end
    return success_flag_local
end

function M.update_monster_names_localization()
    local current_lang = Localized.display_language
    for fixed_id, hunt_data_entry in pairs(M.ui_state_monster_hunt) do
        local monster_name_updated = "Unknown ID:" .. fixed_id
        local monster_definition_found = nil
        for _, m_data_def in ipairs(Localized.monster_data_list) do
            if m_data_def.FixedId == fixed_id then
                monster_definition_found = m_data_def
                monster_name_updated = m_data_def.localized_name or m_data_def.name_en or m_data_def.name_ja
                break
            end
        end
        M.ui_state_monster_hunt[fixed_id].localized_name = monster_name_updated
        if monster_definition_found then
            M.ui_state_monster_hunt[fixed_id].min_size_lower_bound = monster_definition_found.min_size_lower_bound or 0
            M.ui_state_monster_hunt[fixed_id].max_size_upper_bound = monster_definition_found.max_size_upper_bound or 9999
        end
    end
end

function M.draw_monster_hunt_table_ui()
    local T = Localized.T
    imgui.begin_child_window("MonsterHuntTableChild", {600, 0}, true, 0)
        local table_flags = imgui.TableFlags.Borders | imgui.TableFlags.RowBg | imgui.TableFlags.Resizable
        if imgui.begin_table("MonsterHuntTable", 5, table_flags) then
            imgui.table_setup_column(T.monster_name or "Name", 0, 200.0)
            imgui.table_setup_column(T.slaying_num or "Slaying", 0, 70.0)
            imgui.table_setup_column(T.capture_num or "Capture", 0, 70.0)
            imgui.table_setup_column(T.min_size or "Min Size", 0, 70.0)
            imgui.table_setup_column(T.max_size or "Max Size", 0, 70.0)
            imgui.table_headers_row()

            for _, fixed_id_key in ipairs(M.display_order_monster_hunt) do
                local hunt_data = M.ui_state_monster_hunt[fixed_id_key]
                if hunt_data then
                    imgui.table_next_row()
                    imgui.table_next_column(); imgui.text(hunt_data.localized_name or "N/A")

                    local disable_slay_capt = (hunt_data.SlayingNum == 0 and hunt_data.CaptureNum == 0)

                    imgui.table_next_column(); imgui.begin_disabled(disable_slay_capt)
                        imgui.push_item_width(-1); local dsid="##Slay"..fixed_id_key; local sc,ns=imgui.drag_int(dsid,hunt_data.SlayingNum,1,0,9999); if sc and not disable_slay_capt then M.ui_state_monster_hunt[fixed_id_key].SlayingNum=ns end; imgui.pop_item_width()
                    imgui.end_disabled()

                    imgui.table_next_column(); imgui.begin_disabled(disable_slay_capt)
                        imgui.push_item_width(-1); local dcid="##Capt"..fixed_id_key; local cc,nc=imgui.drag_int(dcid,hunt_data.CaptureNum,1,0,9999); if cc and not disable_slay_capt then M.ui_state_monster_hunt[fixed_id_key].CaptureNum=nc end; imgui.pop_item_width()
                    imgui.end_disabled()

                    imgui.table_next_column(); local dis_min=(hunt_data.MixSize==9999);imgui.begin_disabled(dis_min)
                        imgui.push_item_width(-1); local dminid="##MixS"..fixed_id_key;local min_ch,new_min=imgui.drag_int(dminid,hunt_data.MixSize,1,hunt_data.min_size_lower_bound,100); if min_ch and not dis_min then if new_min<hunt_data.min_size_lower_bound then M.ui_state_monster_hunt[fixed_id_key].MixSize=hunt_data.min_size_lower_bound elseif new_min>100 then M.ui_state_monster_hunt[fixed_id_key].MixSize=100 else M.ui_state_monster_hunt[fixed_id_key].MixSize=new_min end end; imgui.pop_item_width()
                    imgui.end_disabled()

                    imgui.table_next_column();local dis_max=(hunt_data.MaxSize==0);imgui.begin_disabled(dis_max)
                        imgui.push_item_width(-1);local dmaxid="##MaxS"..fixed_id_key;local max_ch,new_max=imgui.drag_int(dmaxid,hunt_data.MaxSize,1,100,hunt_data.max_size_upper_bound); if max_ch and not dis_max then if new_max<100 then M.ui_state_monster_hunt[fixed_id_key].MaxSize=100 elseif new_max>hunt_data.max_size_upper_bound then M.ui_state_monster_hunt[fixed_id_key].MaxSize=hunt_data.max_size_upper_bound else M.ui_state_monster_hunt[fixed_id_key].MaxSize=new_max end end; imgui.pop_item_width()
                    imgui.end_disabled()
                end
            end
            imgui.end_table()
        end
    imgui.end_child_window()
end

return M