from PIL import Image, ImageChops, ImageFilter, ImageSequence


def pixelate_gif(input_path, output_path, pixel_width=64, num_colors=32, alpha_threshold=128,
                 outline_color=(255, 182, 193), outline_width=1, edge_gap=2):
    img = Image.open(input_path)
    w, h = img.size
    pixel_height = max(1, round(pixel_width * h / w))

    pad = outline_width + edge_gap
    padded_w, padded_h = pixel_width + 2 * pad, pixel_height + 2 * pad
    out_w, out_h = round(padded_w * w / pixel_width), round(padded_h * h / pixel_height)

    frames = []
    durations = []

    for frame in ImageSequence.Iterator(img):
        rgba = frame.convert("RGBA")

        small = rgba.resize((pixel_width, pixel_height), Image.BILINEAR)
        canvas = Image.new("RGBA", (padded_w, padded_h), (0, 0, 0, 0))
        canvas.paste(small, (pad, pad))

        alpha = canvas.getchannel("A")
        mask = alpha.point(lambda a: 255 if a >= alpha_threshold else 0)

        rgb = canvas.convert("RGB").quantize(colors=num_colors).convert("RGB")

        dilated = mask.filter(ImageFilter.MaxFilter(2 * outline_width + 1))
        outline_ring = ImageChops.subtract(dilated, mask)

        rgb.paste(Image.new("RGB", (padded_w, padded_h), outline_color), (0, 0), outline_ring)
        combined_alpha = ImageChops.lighter(mask, outline_ring)

        rgba_small = rgb.convert("RGBA")
        rgba_small.putalpha(combined_alpha)

        pixelated = rgba_small.resize((out_w, out_h), Image.NEAREST)

        frames.append(pixelated)
        durations.append(frame.info.get("duration", 100))

    out = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    for src, dst in zip(frames, out):
        alpha = src.getchannel("A")
        transparent_mask = alpha.point(lambda a: 255 if a < alpha_threshold else 0)
        dst.paste(255, (0, 0), transparent_mask)

    out[0].save(
        output_path,
        save_all=True,
        append_images=out[1:],
        duration=durations,
        loop=0,
        transparency=255,
        disposal=2,
        optimize=False,
    )
    print(f"saved {output_path} ({len(out)} frames, {pixel_width}x{pixel_height} blocks)")


if __name__ == "__main__":
    src = "Sources/maxwell-popup/Resources/Maxwell.gif"
    pixelate_gif(src, "Sources/maxwell-popup/Resources/Maxwell_pixel.gif", num_colors=32)
