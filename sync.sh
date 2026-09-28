#!/usr/bin/env bash
# Mirror every repo listed in repos.txt into /<repo name>, one commit per upstream change.
# repos.txt line: <url> <branch> [module1,module2,...]; the third field keeps only those modules.
# A repo is skipped when its branch head and module list match the last sync (.sync.lock).
set -euo pipefail
cd "$(dirname "$0")"
lock=.sync.lock
touch "$lock"
changed=0
listed=()

while read -r url branch mods _; do
  [[ -z "${url:-}" || "$url" == \#* ]] && continue
  name=$(basename "$url" .git)
  listed+=("$name")
  mods=${mods:-}
  head=$(git ls-remote "$url" "refs/heads/$branch" | cut -f1)
  [[ -n "$head" ]] || { echo "branch $branch missing on $url" >&2; exit 1; }
  wanted="$head ${mods:-*}"
  [[ "$(awk -v n="$name" '$1==n{print $2" "$3}' "$lock")" == "$wanted" ]] && { echo "skip $name"; continue; }
  old=$(awk -v n="$name" '$1==n{print $2}' "$lock")
  web=${url%.git}
  if [[ -z "$old" ]]; then
    link="Tree: $web/tree/$head"
  elif [[ "$old" == "$head" ]]; then
    link="Upstream unchanged, module list changed: $web/tree/$head"
  else
    link="Diff: $web/compare/$old...$head"
  fi

  git fetch -q --depth 1 "$url" "refs/heads/$branch"
  if [[ -n "$mods" ]]; then
    IFS=, read -ra list <<< "$mods"
    entries=$(git ls-tree FETCH_HEAD -- "${list[@]}")
    for m in "${list[@]}"; do
      grep -q $'\t'"$m"'$' <<< "$entries" || { echo "module $m not found in $url@$branch" >&2; exit 1; }
    done
    tree=$(git mktree <<< "$entries")
  else
    tree=$(git rev-parse 'FETCH_HEAD^{tree}')
  fi

  git rm -rq --ignore-unmatch -- "$name"
  git read-tree --prefix="$name/" -u "$tree"
  { grep -v "^$name " "$lock" || true; echo "$name $wanted"; } > "$lock.tmp"
  mv "$lock.tmp" "$lock"
  git add "$lock"
  git commit -q -m "sync: $name $branch ${head:0:12}" -m "Upstream: $url@$head" -m "$link" -m "Modules: ${mods:-all}"
  echo "sync $name ${head:0:12}"
  changed=1
done < repos.txt

for d in */; do
  d=${d%/}
  [[ "$d" == .github ]] && continue
  printf '%s\n' "${listed[@]}" | grep -qx -- "$d" && continue
  git rm -rq -- "$d"
  { grep -v "^$d " "$lock" || true; } > "$lock.tmp"
  mv "$lock.tmp" "$lock"
  git add "$lock"
  git commit -q -m "remove: $d"
  echo "remove $d"
  changed=1
done

echo "changed=$changed" >> "${GITHUB_OUTPUT:-/dev/null}"
