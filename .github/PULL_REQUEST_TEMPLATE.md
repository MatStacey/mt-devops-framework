## Summary

## Checklist

- [ ] `shellcheck` passes on any changed `.sh` files (see the exact suppressions/command in `CONTRIBUTING.md`)
- [ ] `shfmt -d -i 2 -ci -sr .` reports no diff
- [ ] Changed Python passes `ruff check .`
- [ ] `python3 -m pytest tests/python/` passes, if Python changed
- [ ] `bats tests/bash/` passes, if bash logic changed
- [ ] README.md / COMMANDS.md are up to date if this changes a user-facing command (automatic via `mtupd`/`mt-push-update`, but worth a glance)
