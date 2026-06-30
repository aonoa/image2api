package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"

	"backend/internal/model"
	"backend/internal/repo"
)

// AnnouncementService serves the site-wide 公告 (markdown). It tracks, per user,
// the version they last dismissed so an updated announcement re-pops for everyone
// who hasn't seen the new text. The "version" is a hash of the content, so saving
// identical text doesn't re-notify; any edit does.
type AnnouncementService struct {
	settings *repo.SiteSettingRepository
	users    *repo.UserRepository
}

func NewAnnouncementService(settings *repo.SiteSettingRepository, users *repo.UserRepository) *AnnouncementService {
	return &AnnouncementService{settings: settings, users: users}
}

func announcementVersion(content string) string {
	if strings.TrimSpace(content) == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(strings.TrimSpace(content)))
	return hex.EncodeToString(sum[:8]) // 16 hex chars — plenty to detect a change
}

// Content returns the raw markdown (admin editor).
func (s *AnnouncementService) Content(ctx context.Context) string {
	v, _ := s.settings.GetValue(ctx, "announcement.content")
	return v
}

// ForUser returns {content, version, seen} for the logged-in user.
func (s *AnnouncementService) ForUser(ctx context.Context, user *model.User) map[string]any {
	content := s.Content(ctx)
	version := announcementVersion(content)
	// Admins never get the popup — they author/preview it in 系统设置 instead.
	seen := version == "" || (user != nil && (user.Role == "admin" || user.AnnouncementSeen == version))
	return map[string]any{
		"content": content,
		"version": version,
		"seen":    seen,
	}
}

// MarkSeen records that the user has dismissed the given version.
func (s *AnnouncementService) MarkSeen(ctx context.Context, userID, version string) error {
	_, err := s.users.Update(ctx, userID, map[string]any{"announcement_seen": version})
	return err
}

// Save persists new announcement markdown (admin). An empty string clears it.
func (s *AnnouncementService) Save(ctx context.Context, content string) error {
	return s.settings.UpsertValue(ctx, "announcement.content", content)
}
