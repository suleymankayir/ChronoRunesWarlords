class_name CharacterData extends Resource

enum Element { FIRE, WATER, EARTH, LIGHT, DARK }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export_group("Kimlik")
@export var id: String = "hero_001" # Benzersiz kod (örn: hero_fire)
@export var name: String = "Karakter Adı"
@export var title: String = "Unvanı"
@export_multiline var description: String = "Kısa hikayesi..."

@export_group("Görseller")
@export var full_body_art: Texture2D # Büyük resmi buraya koyacağız
@export var element: Element = Element.FIRE
@export var rarity: Rarity = Rarity.COMMON

@export_group("Güç Değerleri")
@export var base_hp: int = 1000
@export var base_damage: int = 100
