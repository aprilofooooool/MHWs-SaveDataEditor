-- SaveDataEditor/Localized.lua
-- 多言語対応テキストと共有ゲームデータ定義を管理するモジュール
local sdk = sdk -- 状況に応じて必要であれば使用
local log = log
local ipairs = ipairs
local pcall = pcall
local table = table

local Constants = require("SaveDataEditor/Constants") -- ログプレフィックス用

local M = {}

local LOG_PREFIX = Constants.LOG_PREFIX_LOCALIZED

-- MODのデフォルト表示言語
M.display_language = 'en' -- 'en' or 'ja'

-- 対応言語リスト
M.available_languages = {
    { code = 'en', name = "English" },
    { code = 'ja', name = "Japanese" },
    -- 今後他の言語を追加する場合はここに追加
}

-- imgui.comboで使用するための言語名リスト
M.language_names_for_combo = {}
for _, lang_data_entry in ipairs(M.available_languages) do
    table.insert(M.language_names_for_combo, lang_data_entry.name)
end

-- ゲーム内データ定義 (FixedIDや内部IDはゲームバージョンに依存する可能性あり)
M.game_data = {
    weapon_types = {
        { id = 0, name_ja = "大剣", name_en = "Great Sword" }, { id = 1, name_ja = "片手剣", name_en = "Sword & Shield" },
        { id = 2, name_ja = "双剣", name_en = "Dual Blades" }, { id = 3, name_ja = "太刀", name_en = "Long Sword" },
        { id = 4, name_ja = "ハンマー", name_en = "Hammer" }, { id = 5, name_ja = "狩猟笛", name_en = "Hunting Horn" },
        { id = 6, name_ja = "ランス", name_en = "Lance" }, { id = 7, name_ja = "ガンランス", name_en = "Gunlance" },
        { id = 8, name_ja = "スラッシュアックス", name_en = "Switch Axe" }, { id = 9, name_ja = "チャージアックス", name_en = "Charge Blade" },
        { id = 10, name_ja = "操虫棍", name_en = "Insect Glaive" }, { id = 11, name_ja = "弓", name_en = "Bow" },
        { id = 12, name_ja = "ヘビィボウガン", name_en = "Heavy Bowgun" }, { id = 13, name_ja = "ライトボウガン", name_en = "Light Bowgun" },
    },
    quest_categories = {
        -- data_index: 元のセーブデータ内での順序インデックスの可能性 (現在は未使用)
        -- category_fixed_id: セーブデータ内でカテゴリを特定するためのID
        { key = "Assignments", name_ja = "任務クエスト", name_en = "Assignments", data_index = 0, category_fixed_id = -1081821056 },
        { key = "Optional", name_ja = "フリークエスト", name_en = "Optional Quests", data_index = 1, category_fixed_id = -1381773696 },
        { key = "FieldSurvey", name_ja = "現地調査クエスト", name_en = "FieldSurvey", data_index = 2, category_fixed_id = -1238133888 },
        { key = "Investigations", name_ja = "調査クエスト", name_en = "Investigations", data_index = 3, category_fixed_id = 590510720 },
        { key = "Event", name_ja = "イベントクエスト", name_en = "Event Quests", data_index = 4, category_fixed_id = 1025928384 },
        { key = "Arena", name_ja = "闘技大会クエスト", name_en = "Arena Quests", data_index = 5, category_fixed_id = 1738735616 },
        { key = "Challenge", name_ja = "チャレンジクエスト", name_en = "Challenge Quests", data_index = 6, category_fixed_id = 630192064 },
        { key = "TAFreeQuests", name_ja = "フリーチャレンジ", name_en = "TA Free Quests", data_index = 7, category_fixed_id = -2008503424 }
    },
    monster_list = { -- モンスターの全リスト (FixedId: -334290336 のような未定義IDはセーブデータには存在しうる)
        { FixedId = 26, name_en = "Rathian", name_ja = "リオレイア", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 402056736, name_en = "Yian Kut-Ku", name_ja = "イャンクック", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 1049705664, name_en = "Gypceros", name_ja = "ゲリョス", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -1440201088, name_en = "Congalala", name_ja = "ババコンガ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -1363370496, name_en = "Nerscylla", name_ja = "ネルスキュラ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 16, name_en = "Balahara", name_ja = "バーラハーラ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 33, name_en = "Chatacabra", name_ja = "チャタカブラ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -34937520, name_en = "Quematrice", name_ja = "ケマトリス", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -1528962176, name_en = "Lala Barina", name_ja = "ラバラ・バリナ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 567628288, name_en = "Rompopolo", name_ja = "ププロポル", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 222933952, name_en = "Hirabami", name_ja = "ヒラバミ", min_size_lower_bound = 90, max_size_upper_bound = 113 },
        { FixedId = 1965232896, name_en = "Rathalos", name_ja = "リオレウス", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 1411933184, name_en = "Guardian Rathalos", name_ja = "護竜リオレウス", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -535078400, name_en = "Gravios", name_ja = "グラビモス", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 2129596800, name_en = "Blangonga", name_ja = "ドドブランゴ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 32634, name_en = "Mizutsune", name_ja = "タマミツネ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 107194928, name_en = "Guardian Fulgur Anjanath", name_ja = "護竜アンジャナフ亜種", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 1663995904, name_en = "Guardian Ebony Odogaron", name_ja = "護竜オドガロン亜種", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 15, name_en = "Doshaguma", name_ja = "ドシャグマ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -1916429696, name_en = "Guardian Doshaguma", name_ja = "護竜ドシャグマ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 777460864, name_en = "Ajarakan", name_ja = "アジャラカン", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 1401863296, name_en = "Xu Wu", name_ja = "シーウー", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -758250816, name_en = "Gore Magala", name_ja = "ゴア・マガラ", min_size_lower_bound = 90, max_size_upper_bound = 117 },
        { FixedId = -1547364608, name_en = "Rey Dau", name_ja = "レ・ダウ", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = 1467998976, name_en = "Uth Duna", name_ja = "ウズ・トゥナ", min_size_lower_bound = 90, max_size_upper_bound = 113 },
        { FixedId = 1657778432, name_en = "Nu Udra", name_ja = "ヌ・エグドラ", min_size_lower_bound = 90, max_size_upper_bound = 113 },
        { FixedId = 1553456768, name_en = "Jin Dahaad", name_ja = "ジン・ダハド", min_size_lower_bound = 100, max_size_upper_bound = 100 },
        { FixedId = 746996864, name_en = "Arkveld", name_ja = "アルシュベルド", min_size_lower_bound = 90, max_size_upper_bound = 123 },
        { FixedId = -2003468672, name_en = "Zoh Shia", name_ja = "ゾ・シア", min_size_lower_bound = 100, max_size_upper_bound = 100 },
        { FixedId = -283654400, name_en = "Guardian Arkveld", name_ja = "護竜アルシュベルド", min_size_lower_bound = 100, max_size_upper_bound = 100 },
    },
    charm_list = {
        { type_num = 79, name_ja = "挑戦者の証【闢獣】", name_en = "Doshaguma: Mark of Contest" },
        { type_num = 80, name_ja = "勇者の証【闢獣】", name_en = "Doshaguma: Mark of Bravery" },
        { type_num = 81, name_ja = "覇者の証【闢獣】", name_en = "Doshaguma: Mark of Mastery" }
    }
}

-- UI等で使用する翻訳済みテキスト
M.localized_texts_table = {
    ja = {
        -- メインUI
        profile_editor = "SaveDataEditor",
        load_button = "データ読込",
        save_changes_button = "変更を保存",
        status_prefix = "状態: ",
        status_basic_ok = "基本:OK",
        status_basic_ng = "基本:NG",
        status_wpn_use_ok = "武器:OK",
        status_wpn_use_ng = "武器:NG",
        status_mon_hunt_ok = "狩猟:OK",
        status_mon_hunt_ng = "狩猟:NG",
        status_access_error = " - アクセスエラー!",
        msg_load_complete = "Load Complete!",
        msg_load_partial_fail = "Some data failed to load. Check log.",
        msg_load_all_fail = "Critical Error: Failed to access save data structure.",
        msg_save_please_load_first = "Please load data first.",
        msg_save_no_data_to_save = "No data loaded to save.",
        msg_save_complete = "Update Complete! Please save in-game and restart the game for changes to take effect.",
        msg_save_fail_prefix = "Save fail:",
        msg_save_fail_basic = "BasicInfo fail.",
        msg_save_fail_wpn_use = "WeaponUse fail.",
        msg_save_fail_mon_hunt = "MonsterHunt fail.",
        -- Basic Info
        section_title_basic_data = "基本情報",
        load_needed_for_basic = "基本情報を表示/編集するにはデータを読み込んでください。",
        label_hunter_rank_point = "ハンターランクポイント",
        label_money = "所持金",
        label_guild_point = "ギルドポイント",
        label_lucky_ticket = "激運チケット",
        label_play_time = "プレイ時間 (秒)",
        label_char_name = "プレイヤー名",
        label_otomo_name = "オトモ名",
        -- Weapon Use
        section_title_weapon_use = "武器使用回数",
        load_needed_for_weapon = "武器使用回数を表示/編集するにはデータを読み込んでください。",
        label_main_total = "メイン合計",
        label_sub_total = "サブ合計",
        label_total_mismatch_warning = "<警告>合計数が不一致です (%s)", -- %s は期待される関係性など
        label_main_weapon_header = "メイン武器",
        label_sub_weapon_header = "サブ武器",
        label_weapon_type_header = "武器種",
        label_no_play_history_for_category = "このカテゴリのプレイ履歴はありません。",
        -- Monster Hunt
        section_title_monster_hunt = "モンスター狩猟数",
        load_needed_for_monster = "モンスター狩猟数を表示/編集するにはデータを読み込んでください。",
        label_monster_name_header = "モンスター名",
        label_slaying_num_header = "討伐数",
        label_capture_num_header = "捕獲数",
        label_min_size_header = "最小サイズ",
        label_max_size_header = "最大サイズ",
        unknown_monster_name_prefix = "不明なID:",
        unknown_category_name_prefix = "不明カテゴリ(ID:",
        -- charm owned
        section_title_charm_editor = "チャームアンロック",
        charm_get_success_message = "チャーム「%s」を取得済みに設定しました。",
        charm_get_fail_message = "チャーム「%s」の取得設定に失敗しました。ログを確認してください。",
        charm_system_error_init = "Error: Charm system not initialized.",
        charm_system_error_prepare = "Error: Failed to prepare charm system.",
        label_set_all_non_dlc_charms_owned = "DLCを除く全てのチャームを所有済みにする", -- ★新規追加★
        no_charms_defined_message = "Localized.lua にチャームが定義されていません。", -- ★追加または既存のものを流用★
    },
    en = {
        -- Main UI
        profile_editor = "SaveDataEditor",
        load_button = "Load Data",
        save_changes_button = "Save Changes",
        status_prefix = "Status: ",
        status_basic_ok = "Basic:OK",
        status_basic_ng = "Basic:NG",
        status_wpn_use_ok = "WpnUse:OK",
        status_wpn_use_ng = "WpnUse:NG",
        status_mon_hunt_ok = "MonHunt:OK",
        status_mon_hunt_ng = "MonHunt:NG",
        status_access_error = " - ACCESS ERROR!",
        msg_load_complete = "Load Complete!",
        msg_load_partial_fail = "Some data failed to load. Check log.",
        msg_load_all_fail = "Critical Error: Failed to access save data structure.",
        msg_save_please_load_first = "Please load data first.",
        msg_save_no_data_to_save = "No data loaded to save.",
        msg_save_complete = "Update Complete! Please save in-game and restart the game for changes to take effect.",
        msg_save_fail_prefix = "Save fail:",
        msg_save_fail_basic = "BasicInfo fail.",
        msg_save_fail_wpn_use = "WeaponUse fail.",
        msg_save_fail_mon_hunt = "MonsterHunt fail.",
        -- Basic Info
        section_title_basic_data = "Basic Info",
        load_needed_for_basic = "Load data to display/edit Basic Info.",
        label_hunter_rank_point = "Hunter Rank Points",
        label_money = "Zenny",
        label_guild_point = "Guild Points",
        label_lucky_ticket = "Lucky Vouchers",
        label_play_time = "Play Time (seconds)",
        label_char_name = "Character Name",
        label_otomo_name = "Palico Name",
        -- Weapon Use
        section_title_weapon_use = "Weapon Use Count",
        load_needed_for_weapon = "Load data to display/edit Weapon Use Counts.",
        label_main_total = "Main Total",
        label_sub_total = "Sub Total",
        label_total_mismatch_warning = "<Warning> Totals do not match! (%s)",
        label_main_weapon_header = "Main Weapon",
        label_sub_weapon_header = "Sub Weapon",
        label_weapon_type_header = "Weapon Type",
        label_no_play_history_for_category = "No play history for this category.",
        -- Monster Hunt
        section_title_monster_hunt = "Monster Hunt Counts",
        load_needed_for_monster = "Load data to display/edit Monster Hunt Counts.",
        label_monster_name_header = "Monster Name",
        label_slaying_num_header = "Slaying",
        label_capture_num_header = "Capture",
        label_min_size_header = "Min Size",
        label_max_size_header = "Max Size",
        unknown_monster_name_prefix = "Unknown ID:",
        unknown_category_name_prefix = "Unk.Category(ID:",
        -- charm owned
        section_title_charm_editor = "Charm Unlock",
        charm_get_success_message = "Charm '%s' set to owned.",
        charm_get_fail_message = "Failed to set charm '%s' to owned. Check log.",
        charm_system_error_init = "Error: Charm system not initialized.",
        charm_system_error_prepare = "Error: Failed to prepare charm system.",
        label_set_all_non_dlc_charms_owned = "Set all non-DLC charms as owned", -- ★Newly Added★
        no_charms_defined_message = "No charms defined in Localized.lua.", -- ★Added or reused★
    }
}

-- 現在の言語に対応するテキストを格納するテーブル (M.T)
M.T = {} -- 初期化は M.initialize_localization で行う

--- 指定されたアイテムオブジェクトから、現在の言語に基づいた名前を取得するヘルパー関数
-- @param item 対象のアイテムオブジェクト (name_ja, name_en フィールドを持つことを期待)
-- @param language_code 現在の言語コード (例: "ja", "en")
-- @return ローカライズされた名前。見つからない場合は英語名、それもなければ固定の不明名
function M.get_localized_name_for_item(item, language_code)
    local name_key_for_lang = "name_" .. language_code
    return item[name_key_for_lang] or item.name_en or "UnknownName" -- フォールバック
end

--- ローカライゼーション情報を初期化・更新する関数
-- M.display_language の変更後に呼び出す必要がある
function M.initialize_localization()
    local current_lang_code = M.display_language
    -- M.T を現在の言語のテキストで更新 (フォールバックは英語)
    M.T = M.localized_texts_table[current_lang_code] or M.localized_texts_table['en']

    -- ゲームデータ内の各名称をローカライズ (localized_name フィールドを追加)
    if M.game_data and M.game_data.weapon_types then
        for _, weapon_data in ipairs(M.game_data.weapon_types) do
            weapon_data.localized_name = M.get_localized_name_for_item(weapon_data, current_lang_code)
        end
    end
    if M.game_data and M.game_data.quest_categories then
        for _, category_data in ipairs(M.game_data.quest_categories) do
            category_data.localized_name = M.get_localized_name_for_item(category_data, current_lang_code)
        end
    end
    if M.game_data and M.game_data.monster_list then
        for _, monster_entry in ipairs(M.game_data.monster_list) do
            monster_entry.localized_name = M.get_localized_name_for_item(monster_entry, current_lang_code)
        end
    end
    if M.game_data and M.game_data.charm_list then
        -- CharmEditor自体は個別の名前を使わなくなるが、他の場所で参照される可能性を考慮し、
        -- Localized.game_data.charm_list の localized_name 更新は残しておく。
        for _, charm_type in ipairs(M.game_data.charm_list) do
            charm_type.localized_name = M.get_localized_name_for_item(charm_type, current_lang_code)
        end
    end
    log.info(LOG_PREFIX .. "Localization initialized for language: " .. current_lang_code)
end
-- モジュールロード時に一度ローカライゼーションを初期化
M.initialize_localization()

return M
