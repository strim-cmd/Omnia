#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AI_DIR="$ROOT/.ai"

FAILURES=()
FAILED=0
PASSED=0

record_fail() {
  FAILURES+=("$1")
  FAILED=$((FAILED + 1))
}

category_result() {
  local label="$1"
  local start="$2"
  if [ "$FAILED" -eq "$start" ]; then
    echo "Category $label: PASS"
    PASSED=$((PASSED + 1))
  else
    echo "Category $label: FAIL"
  fi
}

echo "Engineering Platform Validation Suite (VAL-000)"
echo "Validating: $AI_DIR"
echo ""

cat_start=$FAILED
echo "== 1. Reference resolution =="

check_ref() {
  local file="$1"
  local ref="$2"
  local base="${ref%%#*}"
  base="${base%%\?*}"
  [ -z "$base" ] && return 0
  case "$base" in
    ../*|./*)
      local resolved
      resolved="$(cd "$(dirname "$file")" && realpath "$base" 2>/dev/null || true)"
      if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
        record_fail "$file: broken relative reference \`$ref\`"
      fi
      ;;
    *)
      local cand
      for cand in \
        "$AI_DIR/$base" \
        "$AI_DIR/prompts/$base" \
        "$AI_DIR/prompts/workflows/$base" \
        "$AI_DIR/prompts/tasks/$base" \
        "$AI_DIR/checklists/$base" \
        "$AI_DIR/standards/$base" \
        "$AI_DIR/specifications/$base" \
        "$AI_DIR/orchestrator/$base" \
        "$AI_DIR/context/$base" \
        "$AI_DIR/agents/$base" \
        "$AI_DIR/pipelines/$base" \
        "$AI_DIR/prompts/templates/$base" \
        "$ROOT/$base" \
        "$ROOT/Documentation/$base"
      do
        [ -e "$cand" ] && return 0
      done
      record_fail "$file: unresolved reference \`$ref\`"
      ;;
  esac
}

ref_count=0
while IFS= read -r -d '' file; do
  fm_block="$(awk 'BEGIN{c=0} /^---$/{c++; next} c==1{print} c>=2{exit}' "$file")"
  refs="$(
    {
      grep -oE '[`][^`]*\.md[`]' "$file" | tr -d '[`]'
      grep -oE '\[[^]]*\]\([^)]*\.md[^)]*\)' "$file" | sed -E 's/^\[[^]]*\]\(//; s/\)$//'
      grep -E '^  - .*\.md' <<< "$fm_block" | sed -E 's/^  - *//'
    } | sort -u
  )"
  [ -z "$refs" ] && continue
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    ref_count=$((ref_count + 1))
    check_ref "$file" "$ref"
  done <<< "$refs"
done < <(find "$AI_DIR" -name '*.md' -print0)
echo "checked $ref_count references"
category_result "1 (reference resolution)" "$cat_start"

cat_start=$FAILED
echo "== 2. Registry integrity =="
REGISTRY="$AI_DIR/orchestrator/REGISTRY.md"
reg_count=0
if [ -f "$REGISTRY" ]; then
  while IFS='|' read -r _ _ wf task pl cl _; do
    for field in "$wf" "$task" "$pl" "$cl"; do
      while IFS= read -r token; do
        [ -z "$token" ] && continue
        token="${token//\`/}"
        reg_count=$((reg_count + 1))
        case "$token" in
          workflows/*|tasks/*)
            [ -e "$AI_DIR/prompts/$token" ] || record_fail "REGISTRY: missing $token"
            ;;
          pipelines/*|checklists/*)
            [ -e "$AI_DIR/$token" ] || record_fail "REGISTRY: missing $token"
            ;;
          *.md)
            { [ -e "$AI_DIR/context/$token" ] || [ -e "$AI_DIR/$token" ]; } || record_fail "REGISTRY: missing $token"
            ;;
        esac
      done < <(grep -oE '[`][^`]+[`]' <<< "$field")
    done
  done < <(grep -E '^\| [`]' "$REGISTRY")
else
  record_fail "REGISTRY file missing: $REGISTRY"
fi
echo "checked $reg_count registry references"
category_result "2 (registry integrity)" "$cat_start"

cat_start=$FAILED
echo "== 3. Version and identifier consistency =="

formal_dups="$(grep -h '^document_id:' "$AI_DIR"/specifications/*.md "$AI_DIR"/orchestrator/*.md "$AI_DIR"/standards/*.md 2>/dev/null | sort | uniq -d)"
if [ -n "$formal_dups" ]; then
  record_fail "duplicate document_id in formal documents: $(echo "$formal_dups" | tr '\n' ' ')"
fi

fm_version="$(grep -m1 '^version:' "$AI_DIR/VERSION.md" 2>/dev/null | sed 's/^version:[[:space:]]*//')"
body_version="$(sed -n '/^## Version$/,/^## /p' "$AI_DIR/VERSION.md" 2>/dev/null | grep -v '^##' | grep -v '^$' | head -1 | tr -d '[:space:]')"
history_version="$(grep -m1 -E '^- [0-9]+\.[0-9]+\.[0-9]+' "$AI_DIR/VERSION.md" 2>/dev/null | sed -E 's/^- ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
if [ -n "$fm_version" ] && [ "$fm_version" != "$body_version" ]; then
  record_fail "VERSION.md mismatch: front matter $fm_version vs Version section $body_version"
fi
if [ -n "$fm_version" ] && [ "$fm_version" != "$history_version" ]; then
  record_fail "VERSION.md mismatch: front matter $fm_version vs latest history entry $history_version"
fi
echo "framework version: $fm_version"
category_result "3 (version and identifier consistency)" "$cat_start"

cat_start=$FAILED
echo "== 4. Document structure =="

while IFS= read -r -d '' f; do
  head_block="$(head -10 "$f")"
  has_title="$(grep -m1 '^title:' <<< "$head_block" || true)"
  has_version="$(grep -m1 '^version:' <<< "$head_block" || true)"
  has_status="$(grep -m1 '^status:' <<< "$head_block" || true)"
  if [ -z "$has_title" ] || [ -z "$has_version" ] || [ -z "$has_status" ]; then
    record_fail "$f: missing front matter title/version/status"
  fi
done < <(find "$AI_DIR/specifications" "$AI_DIR/orchestrator" "$AI_DIR/standards" -name '*.md' -print0 2>/dev/null)
echo "checked formal documents in specifications/, orchestrator/, standards/"
category_result "4 (document structure)" "$cat_start"

cat_start=$FAILED
echo "== 5. Absence of placeholders =="

EXEMPT=(
  "$AI_DIR/checklists/documentation-review.md"
  "$AI_DIR/checklists/platform-validation.md"
  "$AI_DIR/prompts/templates"
  "$AI_DIR/prompts/workflows/documentation.md"
  "$AI_DIR/prompts/workflows/platform-validation.md"
  "$AI_DIR/specifications/PLATFORM_VALIDATION_SPECIFICATION.md"
)

while IFS= read -r -d '' f; do
  skip=0
  for ex in "${EXEMPT[@]}"; do
    case "$f" in
      "$ex"*) skip=1 ;;
    esac
  done
  [ "$skip" = 1 ] && continue
  hits="$(grep -nE 'TODO|FIXME|TBD|lorem ipsum|XXX-XXX|PLACEHOLDER|document_id: [A-Z]+-XXX' "$f" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    record_fail "$f: $(echo "$hits" | tr '\n' ' ')"
  fi
done < <(find "$AI_DIR" -name '*.md' -print0)
echo "checked for unresolved template markers and placeholder text"
category_result "5 (absence of placeholders)" "$cat_start"

cat_start=$FAILED
echo "== 6. Style artifacts =="

while IFS= read -r -d '' f; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    lineno="${line%%:*}"
    content="${line#*:}"
    record_fail "$f:$lineno: prose double-hyphen: $content"
  done < <(sed 's/[`][^`]*[`]//g' "$f" | grep -nE -- '--[A-Za-z]' || true)
done < <(find "$AI_DIR" -name '*.md' -print0)
echo "checked for prose double-hyphen outside inline code and CLI flags"
category_result "6 (style artifacts)" "$cat_start"

cat_start=$FAILED
echo "== 7. Absence of contradictions =="

all_ids="$(grep -rh '^document_id:' "$AI_DIR" --include='*.md' 2>/dev/null | grep -v '^document_id: [A-Z]*-XXX' | sort)"
id_dups="$(uniq -d <<< "$all_ids")"
if [ -n "$id_dups" ]; then
  record_fail "duplicate document_id across .ai: $(echo "$id_dups" | tr '\n' ' ')"
fi

while IFS= read -r -d '' f; do
  base_name="$(basename "$f")"
  self_refs="$(grep -E '^  - .*\.md' "$f" | grep -F "$base_name" || true)"
  if [ -n "$self_refs" ]; then
    record_fail "$f: self-reference in related_documents: $(echo "$self_refs" | tr '\n' ' ')"
  fi
done < <(find "$AI_DIR" -name '*.md' -print0)
echo "checked document_id uniqueness and related_documents self-references"
category_result "7 (absence of contradictions)" "$cat_start"

echo ""
if [ "$FAILED" -gt 0 ]; then
  echo "Result: $FAILED failure(s)"
  printf '%s\n' "${FAILURES[@]}"
  exit 1
fi

echo "Result: all categories passed ($PASSED/7)."
echo "The Engineering Platform Validation Suite certifies platform integrity."
exit 0
