#!/bin/bash
# Refresh data, (re)train weekly, export projections, and push predictions.json.
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate

python -m src.data
python -m src.features

BUNDLE=models/sklearn/quantile_bundle_full.joblib
if [ ! -f "$BUNDLE" ] || [ -n "$(find "$BUNDLE" -mtime +7)" ]; then
  python -m src.train --backend sklearn --full
fi

python -m src.export

/usr/bin/git add ios/NBAStatPredictor/Resources/predictions.json
/usr/bin/git commit -m "Update projections $(date +%F)" || echo "No changes to commit"
/usr/bin/git push
