class_name PRMajors
extends RefCounted
## The six college majors. Every player picks one: a Runner gets that major's
## Runner power, a Buddy gets its Buddy power (an upgraded barrel). All tuning
## for the powers lives here.

enum Major { ART, ANTHROPOLOGY, MUSIC, HISTORY, RELIGION, COMPUTER_SCIENCE }

const COUNT := 6

## Display data. "card" is the name on the small grid card (pre-split so it
## never wraps mid-word), "runner"/"buddy" are the power names, and the *_text
## lines are the one-sentence descriptions shown on the major select screen.
const INFO: Array[Dictionary] = [
	{
		"name": "Art", "card": "ART", "short": "ART", "icon": "✎",
		"runner": "Paint Shield", "runner_text": "Paint a shield on your head. It blocks one barrel.",
		"buddy": "Paint Bomb", "buddy_text": "Barrel splashes paint: Runners in it are slow and jump low.",
	},
	{
		"name": "Anthropology", "card": "ANTHRO-\nPOLOGY", "short": "ANTH", "icon": "❂",
		"runner": "Read the Room", "runner_text": "The enemy Buddy's next barrel backfires and stuns them.",
		"buddy": "Culture Shock", "buddy_text": "A barrel hit flips the Runner's left and right.",
	},
	{
		"name": "Music", "card": "MUSIC", "short": "MUS", "icon": "♫",
		"runner": "Tempo", "runner_text": "Run faster for a few seconds.",
		"buddy": "Drop the Beat", "buddy_text": "A barrel hit stuns longer and makes the Runner dance.",
	},
	{
		"name": "History", "card": "HISTORY", "short": "HIST", "icon": "⧗",
		"runner": "Bookmark", "runner_text": "Leave a clone, press again to jump back to it.",
		"buddy": "Study the Past", "buddy_text": "The barrel tracks the Runner as it falls.",
	},
	{
		"name": "Religion", "card": "RELIGION", "short": "REL", "icon": "✧",
		"runner": "Leap of Faith", "runner_text": "Time it right and a barrel passes through you.",
		"buddy": "Blessing", "buddy_text": "The barrel stuns everything around where it breaks.",
	},
	{
		"name": "Computer Science", "card": "COMPUTER\nSCIENCE", "short": "CS", "icon": "</>",
		"runner": "Hack", "runner_text": "Freeze the barrels over your tower in time.",
		"buddy": "Glitch", "buddy_text": "The barrel glitches left and right as it falls.",
	},
]

# --- Runner powers ------------------------------------------------------------------
## Seconds before a Runner power can be used again (by major).
const RUNNER_COOLDOWNS: Array[float] = [12.0, 15.0, 12.0, 10.0, 6.0, 13.0]
const SHIELD_TIME := 5.0
## How long the enemy Buddy's next barrel stays cursed.
const HEX_TIME := 5.0
## How long a Buddy is stunned by their own cursed barrel.
const HEX_BUDDY_STUN := 3.0
const TEMPO_TIME := 4.0
const TEMPO_SPEED := 1.45
## How long the History clone waits for you to jump back.
const CLONE_TIME := 6.0
## The Religion window: a barrel touching you inside it passes straight through.
const FAITH_WINDOW := 0.45
## A perfectly timed Leap of Faith leaves only this much cooldown.
const FAITH_SUCCESS_COOLDOWN := 2.0
const FREEZE_TIME := 3.0
## With no barrel to freeze, the hack waits this long for the next one.
const HACK_ARM_TIME := 3.0

# --- Buddy powers (special barrels) ---------------------------------------------------
## Seconds after a special barrel drops before the next one can be armed.
const BUDDY_COOLDOWNS: Array[float] = [14.0, 14.0, 14.0, 16.0, 16.0, 12.0]
const PAINT_TIME := 5.0
const PAINT_WIDTH := 3.2
const PAINT_SPEED := 0.55
## Jump speed multiplier in paint (0.8 speed ≈ two thirds of the height).
const PAINT_JUMP := 0.8
const INVERT_TIME := 4.0
const DANCE_STUN := 2.2
const HOMING_SPEED := 7.0
const BLESS_RADIUS := 2.8
## The glitch barrel jumps sideways this often, by up to GLITCH_JUMP.
const GLITCH_STEP := 0.16
const GLITCH_JUMP := 1.6


static func info(major: int) -> Dictionary:
	return INFO[clampi(major, 0, COUNT - 1)]


static func major_name(major: int) -> String:
	return info(major)["name"]


static func short_name(major: int) -> String:
	return info(major)["short"]


static func icon(major: int) -> String:
	return info(major)["icon"]


static func runner_cooldown(major: int) -> float:
	return RUNNER_COOLDOWNS[clampi(major, 0, COUNT - 1)]


static func buddy_cooldown(major: int) -> float:
	return BUDDY_COOLDOWNS[clampi(major, 0, COUNT - 1)]
