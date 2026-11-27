class_name PlayerClass
extends RefCounted

# The classes a player can have. NONE means no ability.
enum Type { NONE, ANTHROPOLOGY, ART, COMPUTER_SCIENCE, HISTORY, MUSIC, RELIGION }


# A readable name for display, such as "Computer Science".
static func display_name(type: Type) -> String:
	return Type.keys()[type].capitalize()
