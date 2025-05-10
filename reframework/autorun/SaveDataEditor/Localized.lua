local sdk = sdk
local log = log
local ipairs = ipairs
local pcall = pcall
local table = table

local M = {}

local LOG_PREFIX = "[SaveDataEditor-Localized] "

M.display_language = 'en'

M.available_languages = {
    { code = 'en', name = "English" },
    { code = 'ja', name = "Japanese" },
}
M.language_names_for_combo = {}
for _, lang_data in ipairs(M.available_languages) do
    table.insert(M.language_names_for_combo, lang_data.name)
end

M.weapon_types_data = {
    { id = 0, name_ja = "大剣", name_en = "Great Sword" }, { id = 1, name_ja = "片手剣", name_en = "Sword & Shield" },
    { id = 2, name_ja = "双剣", name_en = "Dual Blades" }, { id = 3, name_ja = "太刀", name_en = "Long Sword" },
    { id = 4, name_ja = "ハンマー", name_en = "Hammer" }, { id = 5, name_ja = "狩猟笛", name_en = "Hunting Horn" },
    { id = 6, name_ja = "ランス", name_en = "Lance" }, { id = 7, name_ja = "ガンランス", name_en = "Gunlance" },
    { id = 8, name_ja = "スラッシュアックス", name_en = "Switch Axe" }, { id = 9, name_ja = "チャージアックス", name_en = "Charge Blade" },
    { id = 10, name_ja = "操虫棍", name_en = "Insect Glaive" }, { id = 11, name_ja = "弓", name_en = "Bow" },
    { id = 12, name_ja = "ヘビィボウガン", name_en = "Heavy Bowgun" }, { id = 13, name_ja = "ライトボウガン", name_en = "Light Bowgun" },
}

M.quest_categories_data = {
    { key = "Assignments", name_ja = "任務クエスト", name_en = "Assignments", data_index = 0, category_fixed_id = -1081821056 },
    { key = "Optional", name_ja = "フリークエスト", name_en = "Optional Quests", data_index = 1, category_fixed_id = -1381773696 },
    { key = "FieldSurvey", name_ja = "現地調査クエスト", name_en = "FieldSurvey", data_index = 2, category_fixed_id = -1238133888 },
    { key = "Investigations", name_ja = "調査クエスト", name_en = "Investigations", data_index = 3, category_fixed_id = 590510720 },
    { key = "Event", name_ja = "イベントクエスト", name_en = "Event Quests", data_index = 4, category_fixed_id = 1025928384 },
    { key = "Arena", name_ja = "闘技大会クエスト", name_en = "Arena Quests", data_index = 5, category_fixed_id = 1738735616 },
    { key = "Challenge", name_ja = "チャレンジクエスト", name_en = "Challenge Quests", data_index = 6, category_fixed_id = 630192064 },
    { key = "TAFreeQuests", name_ja = "フリーチャレンジ", name_en = "TA Free Quests", data_index = 7, category_fixed_id = -2008503424 }
}

M.monster_data_list = {
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
}

M.localized_texts_table = {
    ja = {
        profile_editor="SaveDataEditor", weapon_use_count="武器使用回数", main_total="メイン合計", sub_total="サブ合計",
        total_mismatch_warning="<警告>合計数が不一致です", main_weapon="メイン武器", sub_weapon="サブ武器",
        save_changes="変更を保存", status_loaded="状態: 読込済", status_not_loaded="状態: 未読込", load_button="データ読込",
        load_needed_for_weapon="武器使用回数を表示/編集するにはデータを読み込んでください。",
        load_needed_for_monster="モンスター狩猟数を表示/編集するにはデータを読み込んでください。",
        load_needed_for_basic="基本情報を表示/編集するにはデータを読み込んでください。",
        load_needed_for_save="先にデータを読み込んでください。",
        monster_hunt_count="モンスター狩猟数", monster_name="名前", slaying_num="討伐数", capture_num="捕獲数",
        min_size="最小サイズ", max_size="最大サイズ",
        basic_data="基本情報", hunter_rank_point="ハンターランクポイント", money="所持金", guild_point="ギルドポイント", lucky_ticket="激運チケット",
        play_time="プレイ時間 (秒)", char_name="プレイヤー名", otomo_name="オトモ名",
        no_play_history_for_category = "プレイ履歴がありません",
    },
    en = {
        profile_editor="SaveDataEditor", weapon_use_count="Weapon Use Count", main_total="Main Total", sub_total="Sub Total",
        total_mismatch_warning="<Warning>Totals do not match!", main_weapon="Main Weapon", sub_weapon="Sub Weapon",
        save_changes="Save Changes", status_loaded="Status: Loaded", status_not_loaded="Status: Not Loaded", load_button="Load Data",
        load_needed_for_weapon="Load data to display/edit Weapon Use Counts.",
        load_needed_for_monster="Load data to display/edit Monster Hunt Counts.",
        load_needed_for_basic="Load data to display/edit Basic Info.",
        load_needed_for_save="Please load data first.",
        monster_hunt_count="Monster Hunt Counts", monster_name="Name", slaying_num="Slaying", capture_num="Capture",
        min_size="Min Size", max_size="Max Size",
        basic_data="Basic Info", hunter_rank_point="Hunter Rank Points", money="Zenny", guild_point="Guild Points", lucky_ticket="Lucky Voucher",
        play_time="Play Time (sec)", char_name="Character Name", otomo_name="Palico Name",
        no_play_history_for_category = "No play history for this category.",
    }
}

M.T = {}

function M.get_localized_name(item, lang)
    local name_key = "name_" .. lang
    return item[name_key] or item.name_en or "UnknownName"
end

function M.initialize_localization()
    local current_lang = M.display_language
    M.T = M.localized_texts_table[current_lang] or M.localized_texts_table['en']
    for i, data in ipairs(M.weapon_types_data) do data.localized_name = M.get_localized_name(data, current_lang) end
    for i, data in ipairs(M.quest_categories_data) do data.localized_name = M.get_localized_name(data, current_lang) end
    for i, data in ipairs(M.monster_data_list) do data.localized_name = M.get_localized_name(data, current_lang) end
end

M.initialize_localization()

return M