package service

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// lastFrameSuffix marks a video's FULL-RESOLUTION last-frame still
// ("u/x.mp4" → "u/x.mp4.last.jpg"). The 画图台 uses it as the 首帧 reference
// when continuing a video (首尾帧 models); the first-frame THUMBNAIL reuses
// thumbSuffix so list views load videos and images the same way.
const lastFrameSuffix = ".last.jpg"

// LastFrameKey returns the last-frame object key for a video key, and
// IsLastFrameKey reports whether name refers to such a derived object.
func LastFrameKey(rel string) string      { return rel + lastFrameSuffix }
func IsLastFrameKey(name string) bool     { return strings.HasSuffix(name, lastFrameSuffix) }
func LastFrameOrigKey(name string) string { return strings.TrimSuffix(name, lastFrameSuffix) }

// extractVideoFrames pulls two stills from an mp4 via ffmpeg: the FIRST frame
// downscaled for list thumbnails (≤thumbMaxDim) and the LAST frame at full
// resolution. Callers treat this as best-effort — any missing ffmpeg or decode
// failure just means the derived objects aren't stored.
func extractVideoFrames(ctx context.Context, video []byte) (thumb, last []byte, err error) {
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		return nil, nil, errors.New("ffmpeg not installed")
	}
	dir, err := os.MkdirTemp("", "vidframes-*")
	if err != nil {
		return nil, nil, err
	}
	defer os.RemoveAll(dir)
	in := filepath.Join(dir, "in.mp4")
	if err := os.WriteFile(in, video, 0o600); err != nil {
		return nil, nil, err
	}

	thumbPath := filepath.Join(dir, "thumb.jpg")
	if out, err := exec.CommandContext(ctx, ffmpeg, "-y", "-i", in,
		"-vf", fmt.Sprintf("scale='min(%d,iw)':-2", thumbMaxDim),
		"-frames:v", "1", "-q:v", "4", thumbPath).CombinedOutput(); err != nil {
		return nil, nil, fmt.Errorf("ffmpeg first frame: %v: %s", err, clipTail(out))
	}
	thumb, err = os.ReadFile(thumbPath)
	if err != nil {
		return nil, nil, err
	}

	// -sseof seeks from the end; a tiny negative offset lands on the final
	// frame(s). Some encodes have sparse keyframes near EOF, so fall back to a
	// wider window before giving up (thumb alone is still useful).
	lastPath := filepath.Join(dir, "last.jpg")
	for _, off := range []string{"-0.1", "-1"} {
		_ = exec.CommandContext(ctx, ffmpeg, "-y", "-sseof", off, "-i", in,
			"-frames:v", "1", "-q:v", "2", "-update", "1", lastPath).Run()
		if b, rerr := os.ReadFile(lastPath); rerr == nil && len(b) > 0 {
			last = b
			break
		}
	}
	return thumb, last, nil
}

func clipTail(b []byte) string {
	s := strings.TrimSpace(string(b))
	if len(s) > 300 {
		s = s[len(s)-300:]
	}
	return s
}
