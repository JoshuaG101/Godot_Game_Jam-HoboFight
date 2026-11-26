class_name PRConfig
extends RefCounted
## Shared constants for PlatformRace. Runner and camera feel live as @export
## vars on their scripts; major powers are tuned in PRMajors.

# --- Teams --------------------------------------------------------------------
const TEAM_BLUE := 0
const TEAM_GOLD := 1
## Blue & Gold, like college colours. Light blue and gold also stay easy to tell
## apart for colour-blind players.
const TEAM_NAMES: Array[String] = ["Blue", "Gold"]
const TEAM_COLORS: Array[Color] = [Color("#46C2FF"), Color("#F5B940")]
## World position of each team's course. 200 apart so no camera sees the other one.
const COURSE_OFFSETS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(200, 0, 0)]

# --- Roles / seats ------------------------------------------------------------
const ROLE_RUNNER := 0
const ROLE_BUDDY := 1
const ROLE_NAMES: Array[String] = ["Runner", "Buddy"]
## Seat order: Blue Runner, Blue Buddy, Gold Runner, Gold Buddy.
const SLOT_COUNT := 4

# --- Buddy modes ----------------------------------------------------------------
## HELP works your own tower's machines; HINDER drops barrels and springs traps
## on the enemy tower. The Buddy picks whenever both are possible.
enum Mode { HELP, HINDER }
const HELP_COLOR := Color("#F2F5FF")
const HINDER_COLOR := Color("#FF3B55")
## Plain symbols that render in the slanted display font (emoji-style ones do not).
const MODE_ICONS: Array[String] = ["✚", "✕"]
const MODE_NAMES: Array[String] = ["HELP", "HINDER"]
## The kind of stage each section is, by checkpoint index (index 0 is unused).
## HELP stages have machines; HINDER stages are where the Buddy attacks by default.
const SECTION_STAGES: Array[int] = [Mode.HELP, Mode.HELP, Mode.HINDER, Mode.HELP, Mode.HINDER, Mode.HELP, Mode.HINDER]
const SECTION_COUNT := 6
const SECTION_NAMES: Array[String] = ["", "Lift", "Rampart Hops", "Rune Steps", "Chimney", "Drawbridges", "Final Climb"]

# --- Race flow (seconds) ------------------------------------------------------
const COUNTDOWN_TIME := 3.0
const VERSUS_TIME := 1.8
const TIME_LIMIT := 240.0
## Results ignore input for this long, so a late jump press doesn't rematch.
const RESULTS_INPUT_DELAY := 1.5

# --- Devices ------------------------------------------------------------------
const LIFT_SPEED := 3.5
const LIFT_END_DWELL := 0.35
const BOOST_LIFT_MULT := 1.5
const BRIDGE_SLIDE := 0.4
const BRIDGE_HOLD := 4.0
const BRIDGE_HOLD_BOOSTED := 6.0
const BRIDGE_COOLDOWN := 2.0
## The bridge blinks for this long before it retracts.
const BRIDGE_WARN := 1.0
const SWAP_COLORS: Array[Color] = [Color("#46C2FF"), Color("#F5B940")]
const SWAP_NAMES: Array[String] = ["blue", "gold"]
const SWAP_ICONS: Array[String] = ["◆", "●"]
## Debug: make every Lift move on its own.
const DEBUG_AUTO_LIFTS := false

# --- Hinder -------------------------------------------------------------------
const DROP_MARKER_SPEED := 9.0
## The drop marker stays within this distance of the course centre.
const DROP_MARKER_LIMIT := 6.5
const DROP_FALL_TIME := 0.8
const DROP_COOLDOWN := 3.0
const STUN_TIME := 1.0
const TRAP_WARNING := 0.8
const TRAP_COOLDOWN := 8.0
const CRUMBLE_FALL := 0.4
const CRUMBLE_RETURN := 3.0
const GUST_TIME := 1.5
const GUST_SPEED := 5.5
const SPIKES_OUT := 0.5
const SPIKES_KNOCK := Vector2(8.0, 3.0)

# --- Catch-up -----------------------------------------------------------------
## A team this many checkpoints behind gets HELP BOOST (faster machines and
## faster power recharge); the leader is on a SPREE.
const CATCHUP_GAP := 1
const BOOST_POWER_RECHARGE := 1.5

# --- Physics layers (bit values, set in code; project layer names untouched) ---
const LAYER_WORLD := 1 # layer 1
const LAYER_RUNNER := 2 # layer 2
const LAYER_DEVICES := 4 # layer 3
const LAYER_TRIGGERS := 8 # layer 4
const RUNNER_MASK := LAYER_WORLD | LAYER_DEVICES


static func team_color(team: int) -> Color:
	return TEAM_COLORS[clampi(team, 0, 1)]


static func team_name(team: int) -> String:
	return TEAM_NAMES[clampi(team, 0, 1)]


static func other_team(team: int) -> int:
	return 1 - team


## The stage kind (HELP or HINDER) of the section that starts at this checkpoint.
static func stage_for_checkpoint(index: int) -> Mode:
	return SECTION_STAGES[clampi(index, 0, SECTION_STAGES.size() - 1)] as Mode


static func mode_color(mode: int) -> Color:
	return HELP_COLOR if mode == Mode.HELP else HINDER_COLOR


static func mode_name(mode: int) -> String:
	return MODE_NAMES[mode]


static func mode_icon(mode: int) -> String:
	return MODE_ICONS[mode]
