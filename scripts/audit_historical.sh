#!/bin/bash
HOST="${1:-localhost:9090}"
WINDOW="${2:-30d}"
TARGET_DAYS="${3:-30}"
DATE=$(date +"%Y%m%d_%H%M%S")
OUT1="audit_top10_${WINDOW}_${DATE}.json"
OUT2="audit_top10_team_${WINDOW}_${DATE}.json"
CSV1="audit_top10_${WINDOW}_${DATE}.csv"
CSV2="audit_top10_team_${WINDOW}_${DATE}.csv"
Q1="topk(10,%20sum%20by%20(alertname)%20(count_over_time(ALERTS%7Balertstate%3D%22firing%22%7D[${WINDOW}])))"
Q2="topk(10,%20sum%20by%20(alertname,%20team)%20(count_over_time(ALERTS%7Balertstate%3D%22firing%22%7D[${WINDOW}])))"
curl -s "http://${HOST}/api/v1/query?query=${Q1}" > "$OUT1"
curl -s "http://${HOST}/api/v1/query?query=${Q2}" > "$OUT2"
if [[ "$WINDOW" == *h ]]; then
  WH=${WINDOW%h}
  HOURS=$WH
elif [[ "$WINDOW" == *d ]]; then
  WD=${WINDOW%d}
  HOURS=$((WD*24))
else
  HOURS=24
fi
FACTOR=$(awk "BEGIN {printf(\"%.6f\", ($TARGET_DAYS*24)/$HOURS)}")
if command -v jq >/dev/null 2>&1; then
  jq -r --argjson factor "$FACTOR" '
    ["alertname","count_window","monthly_estimate"],
    (.data.result[] | [ .metric.alertname, (.value[1] | tonumber), ((.value[1] | tonumber) * $factor) ])
    | @csv
  ' "$OUT1" > "$CSV1"
  jq -r --argjson factor "$FACTOR" '
    ["alertname","team","count_window","monthly_estimate"],
    (.data.result[] | [ .metric.alertname, .metric.team, (.value[1] | tonumber), ((.value[1] | tonumber) * $factor) ])
    | @csv
  ' "$OUT2" > "$CSV2"
  echo "Factor monthly_estimate: $FACTOR (TARGET_DAYS=${TARGET_DAYS}, WINDOW=${WINDOW}, HOURS=${HOURS})"
  echo "CSV: $CSV1"
  echo "CSV: $CSV2"
else
  echo "Install jq to produce CSV outputs."
fi
echo "Saved JSON: $OUT1"
echo "Saved JSON: $OUT2"
