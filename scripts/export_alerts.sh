#!/bin/bash
DATE=$(date +"%Y%m%d")
OUT_JSON="alert_analysis_$DATE.json"
OUT_CSV="alert_noise_top10_$DATE.csv"
echo "Exporting alert noise analysis to $OUT_JSON and $OUT_CSV..."

# Prometheus endpoint
PROM_URL=${PROM_URL:-http://localhost:9090}
WINDOW=${WINDOW:-6h}

# Top 10 alerts by notifications (Alertmanager metrics)
NOTIF_QUERY="topk(10, sum by(alertname)(increase(alertmanager_alerts_received_total[$WINDOW])))"
NOTIF_JSON=$(curl -s "$PROM_URL/api/v1/query" --data-urlencode "query=$NOTIF_QUERY")

# Top 10 alerts by firing duration (hours), assuming 15s scrape interval
DUR_QUERY="topk(10, (sum by(alertname)(sum_over_time(ALERTS{alertstate=\"firing\"}[$WINDOW])) * 15) / 3600)"
DUR_JSON=$(curl -s "$PROM_URL/api/v1/query" --data-urlencode "query=$DUR_QUERY")

# Merge JSON (simple concatenation)
echo "{\"notifications\":$NOTIF_JSON,\"duration_hours\":$DUR_JSON}" > "$OUT_JSON"

# Produce CSV: alertname,notifications,duration_hours
echo "alertname,notifications,duration_hours" > "$OUT_CSV"
python - <<'PY'
import json,sys
from collections import defaultdict
data = json.load(open(sys.argv[1]))
notif = {}
for r in data["notifications"]["data"].get("result", []):
    name = r["metric"].get("alertname","")
    val = float(r["value"][1])
    notif[name]=val
dur = {}
for r in data["duration_hours"]["data"].get("result", []):
    name = r["metric"].get("alertname","")
    val = float(r["value"][1])
    dur[name]=val
names = set(notif) | set(dur)
out = []
for n in names:
    out.append((n, notif.get(n,0.0), dur.get(n,0.0)))
out.sort(key=lambda x: (-x[1], -x[2]))
for row in out[:10]:
    print(f"{row[0]},{row[1]},{row[2]}")
PY
 "$OUT_JSON" >> "$OUT_CSV"

echo "Done. Files: $OUT_JSON and $OUT_CSV"
