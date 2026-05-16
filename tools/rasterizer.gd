class_name Rasterizer

const BYTES_PER_PIXEL := 4  # RGBA8

## Renders a DrawCommandImage into an ImageTexture using a PackedByteArray framebuffer.
## Currently returns a blank white texture; rasterization logic will be added later.
func render(image_data: DrawCommandImage) -> ImageTexture:
	var w := image_data.bounds.x
	var h := image_data.bounds.y
	if w <= 0 or h <= 0:
		return null

	var framebuffer := PackedByteArray()
	framebuffer.resize(w * h * BYTES_PER_PIXEL)
	framebuffer.fill(0xFF)  # blank white, fully opaque

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, framebuffer)
	return ImageTexture.create_from_image(img)
