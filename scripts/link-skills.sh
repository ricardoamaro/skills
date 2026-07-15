#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it — or requests for
# modifications — will not be approved.
#
# Links all skills in the repository into the local skill directories used by
# each agent harness:
#   - ~/.claude/skills  — Claude Code (global, default)
#   - ~/.agents/skills  — Codex and other Agent Skills-compatible harnesses (global, default)
#   - ./.claude/skills  — project-local skills, when --local is passed
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.
#
# Usage:
#   link-skills.sh                 # link into the global ~/.claude/skills and ~/.agents/skills
#   link-skills.sh --local         # link into $PWD/.claude/skills (the project you're in)
#   link-skills.sh --local PATH    # link into PATH/.claude/skills (e.g. another project)
#   link-skills.sh --global        # explicitly request the default global behaviour
#   link-skills.sh --uninstall     # remove this repo's symlinks from the chosen destinations
#   link-skills.sh -h | --help     # show this usage

REPO="$(cd "$(dirname "$0")/.." && pwd)"

LOCAL=0
LOCAL_PATH=""
GLOBAL=1
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      LOCAL=1
      GLOBAL=0
      shift
      if [[ $# -gt 0 && "$1" != -* ]]; then
        LOCAL_PATH="$1"
        shift
      fi
      ;;
    --global)
      GLOBAL=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--local [PATH]] [--global] [-h|--help]"
      echo "  (no args)  link into ~/.claude/skills and ~/.agents/skills"
      echo "  --local     link into \$PWD/.claude/skills (project you're in)"
      echo "  --local PATH  link into PATH/.claude/skills"
      echo "  --global    explicitly use the default global destinations"
      echo "  --uninstall remove this repo's symlinks from the chosen destinations"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      echo "Usage: $(basename "$0") [--local [PATH]] [--global] [--uninstall] [-h|--help]" >&2
      exit 1
      ;;
  esac
done

DESTS=()
if [[ $GLOBAL -eq 1 ]]; then
  DESTS+=("$HOME/.claude/skills" "$HOME/.agents/skills")
fi
if [[ $LOCAL -eq 1 ]]; then
  if [[ -n "$LOCAL_PATH" ]]; then
    DESTS+=("$LOCAL_PATH/.claude/skills")
  else
    DESTS+=("$PWD/.claude/skills")
  fi
fi

if [[ $UNINSTALL -eq 1 ]]; then
  for DEST in "${DESTS[@]}"; do
    if [[ ! -d "$DEST" ]]; then
      echo "skip: $DEST does not exist"
      continue
    fi

    removed=0
    for link in "$DEST"/*; do
      [[ -L "$link" ]] || continue
      t="$(readlink -f "$link")"
      case "$t" in
        "$REPO"/*)
          rm -f "$link"
          echo "removed $(basename "$link") ($DEST)"
          removed=$((removed + 1))
          ;;
      esac
    done

    if [[ $removed -gt 0 && -z "$(ls -A "$DEST" 2>/dev/null)" ]]; then
      rmdir "$DEST" 2>/dev/null && echo "removed empty dir $DEST"
    fi
  done
  exit 0
fi

# Collect the repo's skills once, link into every destination.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -print0)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($DEST)"
  done
done
