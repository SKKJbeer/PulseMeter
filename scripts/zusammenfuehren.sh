#!/usr/bin/env bash
# Führt einen PR zusammen, sobald sein letzter Stand grün ist — ohne dass eine
# Sitzung wach sein muss. Aufgerufen von `.github/workflows/zusammenfuehren.yml`.
#
# **Warum es das gibt (0.180.1).** PR #33 war am 23. November um 23:53 Uhr grün
# und blieb trotzdem bis zum Morgen liegen: Zusammenführen und den Bau anstoßen
# konnte nur eine Sitzung, und die wird erst wach, wenn jemand schreibt oder
# eine Erinnerung fällig ist. Dazwischen kam main zweimal weiter, und jedes
# Abgleichen kostete einen neuen Mac-Lauf von über einer Stunde.
#
# Was es tut, und nur das:
#   · Nur PRs mit der Marke `zusammenfuehren`, nicht als Entwurf, gegen main,
#     aus diesem Repository. Die Marke setzt die Sitzung, wenn sie selbst
#     zusammenführen würde. Ohne Marke passiert nichts.
#   · Nur, wenn der CI-Lauf für **genau den letzten Commit** des PRs grün ist und
#     keine andere Prüfung an diesem Commit rot ist.
#   · Zusammenführen als Squash, mit `--match-head-commit`: Kam inzwischen ein
#     neuer Push, lehnt GitHub ab, statt den ungeprüften Stand zu nehmen.
#   · Danach die Abläufe auf main von Hand anstoßen, die ein Push sonst
#     auslöst. Ein Zusammenführen mit dem `GITHUB_TOKEN` löst nämlich selbst
#     keine Abläufe aus (Schutz von GitHub gegen Schleifen); `workflow_dispatch`
#     ist die Ausnahme, die erlaubt ist.
#   · Mit der Marke `testflight` zusätzlich den TestFlight-Bau (Regel 4).
#
# Geht etwas nicht (Konflikt mit main, Prüfung rot, noch nicht fertig), endet
# es mit einem Hinweis und **grün**. Rot hieße eine Fehler-Mail für etwas, das
# kein Fehler ist; der PR bleibt offen und zeigt selbst, woran es hängt.
#
# Aufruf: scripts/zusammenfuehren.sh <pr-nummer>
# Braucht GH_TOKEN und GITHUB_REPOSITORY. Mit `PROBE=1` prüft es alles, führt
# aber nicht zusammen (zum Ausprobieren von Hand, auch ohne Marke).
set -euo pipefail

PR="${1:?PR-Nummer fehlt}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY fehlt}"
MARKE="zusammenfuehren"

hinweis() { echo "::notice::PR #$PR: $*"; }

pr=$(gh api "repos/$REPO/pulls/$PR")
state=$(jq -r .state <<<"$pr")
draft=$(jq -r .draft <<<"$pr")
base=$(jq -r .base.ref <<<"$pr")
head_repo=$(jq -r .head.repo.full_name <<<"$pr")
sha=$(jq -r .head.sha <<<"$pr")
marken=$(jq -r '[.labels[].name] | join(" ")' <<<"$pr")

[ "$state" = "open" ]       || { hinweis "nicht offen ($state)."; exit 0; }
[ "$draft" = "false" ]      || { hinweis "Entwurf, wird nicht zusammengeführt."; exit 0; }
[ "$base" = "main" ]        || { hinweis "Ziel ist $base, nicht main."; exit 0; }
[ "$head_repo" = "$REPO" ]  || { hinweis "aus einem fremden Repository."; exit 0; }
case " $marken " in
  *" $MARKE "*) ;;
  *) [ -n "${PROBE:-}" ] && hinweis "ohne Marke, PROBE prüft trotzdem weiter." || {
     hinweis "ohne Marke „$MARKE“, nichts zu tun."; exit 0; } ;;
esac

# Der CI-Lauf für genau diesen Commit. `head_sha` filtert auf den Stand, nicht
# auf den Zweig: Ein grüner Lauf eines älteren Commits zählt nicht.
ci=$(gh api "repos/$REPO/actions/workflows/ci.yml/runs?head_sha=$sha&per_page=20" \
  --jq '[.workflow_runs[] | select(.event=="push" or .event=="workflow_dispatch")] | sort_by(.created_at) | last | (.status + " " + (.conclusion // "-"))')
if [ "$ci" != "completed success" ]; then
  hinweis "CI für ${sha:0:7} steht auf „${ci:-keiner}“, noch nicht grün."
  exit 0
fi

# Keine andere Prüfung an diesem Commit rot (z. B. CloudKit-Wache).
rot=$(gh api "repos/$REPO/commits/$sha/check-runs?per_page=100" \
  --jq '[.check_runs[] | select(.conclusion=="failure" or .conclusion=="timed_out" or .conclusion=="action_required") | .name] | join(", ")')
if [ -n "$rot" ]; then
  hinweis "an ${sha:0:7} sind Prüfungen rot: $rot."
  exit 0
fi

# GitHub rechnet die Zusammenführbarkeit im Hintergrund aus; `null` heißt
# „noch nicht fertig", nicht „nein".
for _ in 1 2 3 4 5 6; do
  mergeable=$(gh api "repos/$REPO/pulls/$PR" --jq '.mergeable')
  [ "$mergeable" != "null" ] && break
  sleep 5
done
if [ "$mergeable" != "true" ]; then
  hinweis "lässt sich nicht zusammenführen (Konflikt mit main?). Abgleichen, dann geht es von selbst weiter."
  exit 0
fi

if [ -n "${PROBE:-}" ]; then
  hinweis "PROBE: würde ${sha:0:7} jetzt zusammenführen."
  exit 0
fi

titel=$(jq -r .title <<<"$pr")
if ! gh pr merge "$PR" --repo "$REPO" --squash --match-head-commit "$sha" \
     --subject "$titel (#$PR)"; then
  hinweis "Zusammenführen abgelehnt (neuer Push dazwischen?)."
  exit 0
fi
echo "::notice::PR #$PR zusammengeführt (${sha:0:7})."

# Welche Dateien der PR berührt, entscheidet, welche Abläufe auf main laufen.
dateien=$(gh api "repos/$REPO/pulls/$PR/files?per_page=100" --paginate --jq '.[].filename')
beruehrt() { grep -qE "$1" <<<"$dateien"; }

anstossen() {
  echo "Stoße $1 auf main an."
  gh workflow run "$1" --repo "$REPO" --ref main "${@:2}" \
    || echo "::warning::$1 ließ sich nicht anstoßen."
}

anstossen ci.yml
# Dieselben Pfade wie in den `push`-Auslösern der Abläufe.
beruehrt '^(docs/website/|docs/website-server/|scripts/website-fertig\.sh|scripts/website-paket\.sh|\.github/workflows/website\.yml)' \
  && anstossen website.yml
beruehrt '^(Packages/KameraMessung/|Packages/PulseCore/Sources/PulseCore/Engine/MeterTextReader\.swift|docs/kamera/|\.github/workflows/kamera\.yml)' \
  && anstossen kamera.yml
beruehrt '^(cloudkit/|scripts/check-cloudkit-schema\.py|\.github/workflows/cloudkit-wache\.yml)' \
  && anstossen cloudkit-wache.yml
case " $marken " in
  *" testflight "*) anstossen testflight.yml ;;
esac
exit 0
