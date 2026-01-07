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
if command -v python >/dev/null 2>&1; then
  python - "$OUT_JSON" <<'PY' > "$OUT_CSV"
import json,sys
data = json.load(open(sys.argv[1]))
notif = {}
for r in data["notifications"]["data"].get("result", []):
    name = r.get("metric", {}).get("alertname","")
    val = float(r.get("value",[0,"0"])[1])
    if name: notif[name]=val
dur = {}
for r in data["duration_hours"]["data"].get("result", []):
    name = r.get("metric", {}).get("alertname","")
    val = float(r.get("value",[0,"0"])[1])
    if name: dur[name]=val
names = sorted(set(list(notif.keys()) + list(dur.keys())))
rows = []
for n in names:
    rows.append((n, notif.get(n,0.0), dur.get(n,0.0)))
rows.sort(key=lambda x: (-x[1], -x[2]))
print("alertname,notifications,duration_hours")
for row in rows[:10]:
    print(f"{row[0]},{row[1]},{row[2]}")
PY
elif command -v docker >/dev/null 2>&1; then
  cat "$OUT_JSON" | docker run --rm -i node:18-alpine node -e '
    const chunks=[]; process.stdin.on("data",c=>chunks.push(c));
    process.stdin.on("end",()=>{
      const data=JSON.parse(Buffer.concat(chunks).toString());
      const notif={}, dur={};
      (data.notifications.data.result||[]).forEach(r=>{
        const name=(r.metric||{}).alertname||""; const val=parseFloat(r.value[1]); if(name) notif[name]=val;
      });
      (data.duration_hours.data.result||[]).forEach(r=>{
        const name=(r.metric||{}).alertname||""; const val=parseFloat(r.value[1]); if(name) dur[name]=val;
      });
      const names=new Set([...Object.keys(notif), ...Object.keys(dur)]);
      const rows=[...names].map(n=>({n, notifications:notif[n]||0, duration:dur[n]||0}))
        .sort((a,b)=> b.notifications - a.notifications || b.duration - a.duration)
        .slice(0,10);
      console.log("alertname,notifications,duration_hours");
      rows.forEach(r=>console.log(`${r.n},${r.notifications},${r.duration}`));
    });
  ' > "$OUT_CSV"
else
  echo "CSV non généré: ni Python ni Docker disponibles. Voir $OUT_JSON" >&2
fi

echo "Done. Files: $OUT_JSON and $OUT_CSV"
