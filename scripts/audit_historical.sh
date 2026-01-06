#!/bin/bash
HOST="${1:-localhost:9090}"
WINDOW="${2:-30d}"
DATE=$(date +"%Y%m%d_%H%M%S")
OUT1="audit_top10_${WINDOW}_${DATE}.json"
OUT2="audit_top10_team_${WINDOW}_${DATE}.json"
Q1="topk(10,%20sum%20by%20(alertname)%20(count_over_time(ALERTS%7Balertstate%3D%22firing%22%7D[${WINDOW}])))"
Q2="topk(10,%20sum%20by%20(alertname,%20team)%20(count_over_time(ALERTS%7Balertstate%3D%22firing%22%7D[${WINDOW}])))"
curl -s "http://${HOST}/api/v1/query?query=${Q1}" > "$OUT1"
curl -s "http://${HOST}/api/v1/query?query=${Q2}" > "$OUT2"
if command -v jq >/dev/null 2>&1; then
  echo "Top 10 by alertname (${WINDOW}):"
  jq -r '.data.result[] | "\(.metric.alertname)\t\(.value[1])"' "$OUT1" | column -t
  echo ""
  echo "Top 10 by alertname,team (${WINDOW}):"
  jq -r '.data.result[] | "\(.metric.alertname)\t\(.metric.team)\t\(.value[1])"' "$OUT2" | column -t
fi
echo "Saved: $OUT1"
echo "Saved: $OUT2"
