-- SaveDataEditor/Constants.lua
-- MOD全体で使用する定数を定義するモジュール
local M = {}

-- ログプレフィックス
M.LOG_PREFIX_MAIN = "[SaveDataEditor-Main] "
M.LOG_PREFIX_LOCALIZED = "[SaveDataEditor-Localized] "
M.LOG_PREFIX_BASIC_DATA = "[SaveDataEditor-BasicData] "
M.LOG_PREFIX_MONSTER_HUNT = "[SaveDataEditor-MonsterHuntNum] "
M.LOG_PREFIX_WEAPON_USE = "[SaveDataEditor-WeaponUseNum] "
M.LOG_PREFIX_UTILS = "[SaveDataEditor-Utils] "
M.LOG_PREFIX_SAVE_ACCESS = "[SaveDataEditor-SaveDataAccess] "

-- REFramework シングルトン / メソッド名
M.SAVE_DATA_MANAGER_SINGLETON = "app.SaveDataManager"
M.GET_CURRENT_USER_SAVE_DATA_METHOD_NAME = "getCurrentUserSaveData"
M.SYSTEM_ARRAY_TYPENAME = "System.Array"
M.ARRAY_GET_METHOD_NAME = "Get"

-- セーブデータ フィールド名
M.FIELD_SAVE_BASIC_DATA = "_BasicData"
M.FIELD_SAVE_HUNTER_PROFILE = "_HunterProfile"
M.FIELD_SAVE_QUEST_CLEAR_COUNTER = "_QuestClearCounter"
M.FIELD_SAVE_CLEAR_NUM_PER_CATEGORY = "_ClearNumPerCategory"
M.FIELD_SAVE_ENEMY_REPORT = "_EnemyReport"
M.FIELD_SAVE_BOSS_ARRAY = "_Boss"

-- BasicData フィールド名
M.FIELD_BASIC_HUNTER_POINT = "HunterPoint"
M.FIELD_BASIC_MONEY = "Money"
M.FIELD_BASIC_POINT = "Point"        -- Guild Points
M.FIELD_BASIC_LUCKY_TICKET = "LuckyTicket"
M.FIELD_BASIC_PLAY_TIME = "PlayTime" -- curSave直下
M.FIELD_BASIC_CHAR_NAME = "CharName"
M.FIELD_BASIC_OTOMO_NAME = "OtomoName"
M.FIELD_MANDRAKE_ENCRYPTED_VALUE = "v"
M.FIELD_MANDRAKE_MULTIPLIER = "m"

-- MonsterHuntNum フィールド名
M.FIELD_MONSTER_FIXED_ID = "FixedId"
M.FIELD_MONSTER_SLAYING_NUM = "SlayingNum"
M.FIELD_MONSTER_CAPTURE_NUM = "CaptureNum"
M.FIELD_MONSTER_MIN_SIZE = "MixSize" -- 注: MixSizeは最小サイズを指す
M.FIELD_MONSTER_MAX_SIZE = "MaxSize"

-- WeaponUseNum フィールド名
M.FIELD_CATEGORY_FIXED_ID = "CategoryFixedId"
M.FIELD_CATEGORY_MAIN_WEAPON_USE_NUM = "MainWeaponUseNum"
M.FIELD_CATEGORY_SUB_WEAPON_USE_NUM = "SubWeaponUseNum"
M.FIELD_CATEGORY_TOTAL_NUM = "Num"      -- クエストクリア総数
M.FIELD_ARRAY_ELEMENT_VALUE = "m_value" -- System.Int32[]などの要素の値フィールド

-- CharmEditor 関連
M.LOG_PREFIX_CHARM_EDITOR = "[SaveDataEditor-CharmEditor] "
M.CHARM_UTIL_TYPENAME = "app.CharmUtil"
M.CHARM_SET_IS_OWNED_METHOD_NAME = "setIsOwnedCharm"

-- UI関連 定数
M.MAX_LUCKY_TICKETS = 5
M.MAX_GENERIC_COUNT = 9999    -- 汎用的なカウント上限 (武器使用回数、狩猟数など)
M.MAX_MONEY_POINTS = 99999999 -- 所持金やギルドポイントの上限
M.MIN_SIZE_LOWER_BOUND_DEFAULT = 0
M.MAX_SIZE_UPPER_BOUND_DEFAULT = 9999
M.MONSTER_SIZE_CROWN_MIN_THRESHOLD = 100   -- サイズ編集時の仮の閾値 (実際の金冠とは異なる)
M.MONSTER_SIZE_CROWN_MAX_THRESHOLD = 123   -- サイズ編集時の仮の閾値
M.MONSTER_MIN_SIZE_UNRECORDED_VALUE = 9999 -- 最小サイズ未記録時のゲーム内値
M.MONSTER_MAX_SIZE_UNRECORDED_VALUE = 0    -- 最大サイズ未記録時のゲーム内値
M.ASSIGNMENTS_TOTAL_MAIN_OFFSET = 2        -- 任務クエストのメイン武器合計のオフセット値

-- デフォルト値
M.DEFAULT_STRING = ""
M.DEFAULT_NUMBER = 0

return M
