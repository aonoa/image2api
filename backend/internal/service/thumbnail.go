package service

import (
	"bytes"
	"image"
	"image/jpeg"
	"strings"

	"golang.org/x/image/draw"

	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"

	_ "golang.org/x/image/webp"
)

// thumbSuffix is appended to an image's object key to form its thumbnail key
// ("u/x.png" → "u/x.png.thumb.jpg"). List views load the thumbnail; preview and
// download always use the original.
const thumbSuffix = ".thumb.jpg"

// thumbMaxDim bounds the thumbnail's longest side. 512px is crisp for grid
// cards / table rows while staying ~20-50 KB as JPEG.
const thumbMaxDim = 512

// ThumbKey returns the thumbnail object key for an image key.
func ThumbKey(rel string) string { return rel + thumbSuffix }

// IsThumbKey reports whether name refers to a thumbnail object, and OrigKey
// maps a thumbnail key back to its original image key.
func IsThumbKey(name string) bool { return strings.HasSuffix(name, thumbSuffix) }
func OrigKey(name string) string  { return strings.TrimSuffix(name, thumbSuffix) }

// makeThumbnail downscales an image to thumbMaxDim (longest side) and encodes
// it as JPEG. Images already small enough are re-encoded as-is (so the thumb
// object always exists once generated). Returns an error for undecodable input
// (e.g. video bytes) — callers treat thumbnailing as best-effort.
func makeThumbnail(b []byte) ([]byte, error) {
	src, _, err := image.Decode(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	bounds := src.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	tw, th := w, h
	if w > thumbMaxDim || h > thumbMaxDim {
		if w >= h {
			tw = thumbMaxDim
			th = h * thumbMaxDim / w
		} else {
			th = thumbMaxDim
			tw = w * thumbMaxDim / h
		}
		if tw < 1 {
			tw = 1
		}
		if th < 1 {
			th = 1
		}
	}
	// JPEG has no alpha — composite onto white so transparent PNGs don't go black.
	dst := image.NewRGBA(image.Rect(0, 0, tw, th))
	draw.Draw(dst, dst.Bounds(), image.White, image.Point{}, draw.Src)
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, bounds, draw.Over, nil)
	var out bytes.Buffer
	if err := jpeg.Encode(&out, dst, &jpeg.Options{Quality: 78}); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}
