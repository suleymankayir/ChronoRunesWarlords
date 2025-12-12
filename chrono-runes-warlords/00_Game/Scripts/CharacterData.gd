# SCRIPT 1: CharacterData.gd
class_name CharacterData extends Resource

# --- ENUMS ---
# --- ENUMS ---
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum SkillType { DIRECT_DAMAGE, HEAL, BUFF_ATTACK }

# --- EXPORT VARIABLES (STRICT TYPING) ---
@export_group("Identity")
@export var id: String = "hero_001"
@export var character_name: String = "Hero Name" # Requested field name
@export_multiline var description: String = "Hero Description..."

@export_group("Visuals")
@export var portrait: Texture2D # Requested field name
@export var rarity_color: Color = Color.WHITE

@export_group("Stats")
@export var element_text: String = "Fire"
@export var level: int = 1
@export var rarity: Rarity = Rarity.COMMON

@export_group("Skill Specs")
@export var skill_type: SkillType = SkillType.DIRECT_DAMAGE
@export var skill_power: int = 250
@export var skill_name: String = "Fireball"

# --- BACKWARD COMPATIBILITY ---
# (Added by Lead Developer to prevent breaking InventorySlot.gd and other systems)
# These properties map old variable names to the new ones.

var name: String:
	get: return character_name
	set(value): character_name = value

var full_body_art: Texture2D:
	get: return portrait
	set(value): portrait = value
