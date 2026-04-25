extends Node

const STRINGS: Dictionary = {
	"en": {
		"settings": "Settings",
		"music": "Music",
		"sfx": "SFX",
		"graphics": "Graphics",
		"language": "Language",
		"classic": "Classic",
		"modern": "Modern",
		"off": "Off",
		"on": "On",
		"graphics_old_label": "Classic",
		"close": "Close",
		"baby": "Baby",
		"intern": "Intern",
		"profi": "Profi",
		"master": "Master",
		"expert": "Expert",
		"torrero": "Torrero",
		"give_up": "Give Up",
		"start": "Start",
		"solve_anim": "Solve Anim",
	},
	"ru": {
		"settings": "Настройки",
		"music": "Музыка",
		"sfx": "Звуки",
		"graphics": "Графика",
		"language": "Язык",
		"classic": "Классика",
		"modern": "Модерн",
		"off": "Выкл",
		"on": "Вкл",
		"graphics_old_label": "Классика",
		"close": "Закрыть",
		"baby": "Новичок",
		"intern": "Стажёр",
		"profi": "Профи",
		"master": "Мастер",
		"expert": "Эксперт",
		"torrero": "ТОРеро",
		"give_up": "Сдаться",
		"start": "Старт",
		"solve_anim": "Анимация",
	},
}

func t(key: String) -> String:
	var lang: String = GlobalSettings.language
	var table: Dictionary = STRINGS.get(lang, STRINGS["en"])
	return table.get(key, key)
