# NBA Player Stat Quantile Predictor

An end-to-end machine learning pipeline that forecasts NBA player **Points (`PTS`)**, **Rebounds (`REB`)**, **Assists (`AST`)**, **3-Pointers Made (`FG3M`)**, **Turnovers (`TOV`)**, **Steals (`STL`)**, and **Blocks (`BLK`)** with 80% prediction intervals (`0.1` to `0.9` quantiles) and an interactive Streamlit explorer and a native iOS app.

## Pipeline Architecture
1. **`src/data.py`** — Downloads and caches historical NBA regular-season player game logs (`2017-18` through `2026-27`).
2. **`src/features.py`** — Computes leak-free (`shift(1)`) rolling player averages (`3`, `10`, `25` games), per-minute efficiency rates, rest/back-to-back indicators, and opponent defensive baselines.
3. **`src/train.py`** — Trains quantile regression models (`HistGradientBoostingRegressor` or `LightGBM`) using strict temporal train/validation splits.
4. **`src/evaluate.py`** — Evaluates median MAE, pinball loss, and empirical 80% interval calibration.
5. **`src/export.py`** — Projects every active rotation player's next game and writes `predictions.json` for the iOS app.
6. **`app/streamlit_app.py`** — Interactive web UI to inspect player projections and recent game logs.

## Quickstart
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python -m src.data
python -m src.features
python -m src.train --backend sklearn --val-season 2025-26
python -m src.evaluate --backend sklearn
streamlit run app/streamlit_app.py
```

## iOS app
The model runs in Python; the app (SwiftUI, iOS 17+) renders the exported projections.

```bash
python -m src.train --backend sklearn --full   # train on all games for the app
python -m src.export                           # writes ios/NBAStatPredictor/Resources/predictions.json
cd ios && brew install xcodegen && xcodegen generate && open NBAStatPredictor.xcodeproj
```
No XcodeGen? Create a new iOS App in Xcode (SwiftUI, iOS 17), delete its generated Swift files, and drag in
the contents of `ios/NBAStatPredictor/` (check "Copy items if needed" and your app target).

To update projections without a new App Store build, host `predictions.json` anywhere with a public URL and paste it
into the app's Settings (gear icon). Re-run `python -m src.export` daily (after `python -m src.data`/`src.features`)
and upload the file.

Note: For daily updates add https://raw.githubusercontent.com/elenibatsi04/iOS-NBA-Prediction-Stats/main/ios/NBAStatPredictor/Resources/predictions.json to the settings
