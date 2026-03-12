from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


@dataclass
class CleanupStats:
    deleted_files: int = 0
    deleted_bytes: int = 0
    scanned_files: int = 0
    log_rotated: bool = False
    log_lines_before: int = 0
    log_lines_after: int = 0

    def to_dict(self) -> dict:
        return asdict(self)


def _iter_files(directory: Path) -> list[Path]:
    if not directory.exists():
        return []
    return [path for path in directory.rglob("*") if path.is_file()]


def _remove_file(path: Path, stats: CleanupStats, dry_run: bool) -> None:
    size = 0
    try:
        size = path.stat().st_size
    except Exception:
        size = 0
    if not dry_run:
        try:
            path.unlink()
        except Exception:
            return
    stats.deleted_files += 1
    stats.deleted_bytes += size


def _prune_by_retention(directory: Path, *, keep_days: int, keep_recent: int, dry_run: bool, stats: CleanupStats) -> None:
    files = _iter_files(directory)
    stats.scanned_files += len(files)
    if not files:
        return

    files_sorted = sorted(files, key=lambda p: p.stat().st_mtime, reverse=True)
    protected = {p for p in files_sorted[: max(keep_recent, 0)]}
    cutoff = datetime.now(timezone.utc) - timedelta(days=max(keep_days, 0))

    for path in files_sorted:
        if path in protected:
            continue
        try:
            modified = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
        except Exception:
            modified = cutoff
        if modified < cutoff:
            _remove_file(path, stats, dry_run)


def _hard_prune_dir(directory: Path, *, dry_run: bool, stats: CleanupStats) -> None:
    files = _iter_files(directory)
    stats.scanned_files += len(files)
    for path in files:
        _remove_file(path, stats, dry_run)


def _rotate_actions_log(log_path: Path, *, max_lines: int, keep_lines: int, dry_run: bool, stats: CleanupStats) -> None:
    if not log_path.exists():
        return
    try:
        lines = log_path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return

    stats.log_lines_before = len(lines)
    if len(lines) <= max(max_lines, 0):
        stats.log_lines_after = len(lines)
        return

    kept = lines[-max(keep_lines, 0):]
    stats.log_rotated = True
    stats.log_lines_after = len(kept)
    if not dry_run:
        payload = "\n".join(kept)
        if payload:
            payload += "\n"
        log_path.write_text(payload, encoding="utf-8")


def cleanup_runtime_artifacts(
    config,
    *,
    dry_run: bool,
    hard: bool,
    include_sessions: bool,
    screenshots_keep_days: int,
    audio_keep_days: int,
    sessions_keep_days: int,
    keep_recent_per_bucket: int,
    actions_max_lines: int,
    actions_keep_lines: int,
) -> CleanupStats:
    stats = CleanupStats()

    if hard:
        _hard_prune_dir(config.screenshots_dir, dry_run=dry_run, stats=stats)
        _hard_prune_dir(config.audio_dir, dry_run=dry_run, stats=stats)
        if include_sessions:
            _hard_prune_dir(config.sessions_dir, dry_run=dry_run, stats=stats)
        _rotate_actions_log(
            config.actions_log_path,
            max_lines=0,
            keep_lines=0,
            dry_run=dry_run,
            stats=stats,
        )
        return stats

    _prune_by_retention(
        config.screenshots_dir,
        keep_days=screenshots_keep_days,
        keep_recent=keep_recent_per_bucket,
        dry_run=dry_run,
        stats=stats,
    )
    _prune_by_retention(
        config.audio_dir,
        keep_days=audio_keep_days,
        keep_recent=keep_recent_per_bucket,
        dry_run=dry_run,
        stats=stats,
    )
    if include_sessions:
        _prune_by_retention(
            config.sessions_dir,
            keep_days=sessions_keep_days,
            keep_recent=keep_recent_per_bucket,
            dry_run=dry_run,
            stats=stats,
        )
    _rotate_actions_log(
        config.actions_log_path,
        max_lines=actions_max_lines,
        keep_lines=actions_keep_lines,
        dry_run=dry_run,
        stats=stats,
    )
    return stats