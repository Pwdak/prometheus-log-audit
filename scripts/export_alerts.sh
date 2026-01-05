#!/bin/bash
DATE=$(date +"%Y%m%d")
OUTPUT_FILE="alert_analysis_$DATE.json"
echo "Exporting alert data to $OUTPUT_FILE..."

# Query Prometheus for firing alerts
# Note: jq is recommended for formatting but not required
curl -s "http://localhost:9090/api/v1/alerts" > "$OUTPUT_FILE"

echo "Done. Data saved to $OUTPUT_FILE"
