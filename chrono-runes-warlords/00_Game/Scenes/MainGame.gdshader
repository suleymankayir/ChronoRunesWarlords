shader_type canvas_item;

// Hız ayarını buradan yapabilirsin (X ve Y yönü)
uniform vec2 speed = vec2(0.02, 0.01);

void fragment() {
	// UV: Resmin koordinatları.
	// TIME: Oyunun geçen süresi.
	// Resmin koordinatlarını zamana göre kaydırıyoruz.
	COLOR = texture(TEXTURE, UV + (TIME * speed));
}