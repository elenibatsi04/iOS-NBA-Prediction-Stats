"""Export next-game projections for every active rotation player to JSON.

The iOS app reads this file (bundled + optionally refreshed from a URL), so the
heavy models stay in Python and the phone only renders results.

    python -m src.export                       # uses the full-data bundle if present
    python -m src.export --as-of 2026-11-21    # date of the games you care about
"""
from __future__ import annotations

import argparse
import json
from datetime import date, datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from .config import MODEL_DIR, QUANTILES, ROOT, TARGETS
from .data import load_logs
from .features import build_features

DEFAULT_OUT = ROOT / "ios" / "NBAStatPredictor" / "Resources" / "predictions.json"
RECENT_GAMES = 10
ACTIVE_WINDOW_DAYS = 21
ASSUMPTIONS = (
    "Opponent and venue for the next game are not known, so projections assume a "
    "league-average opponent and average the home and away scenarios. Rest days "
    "are measured from each player's last game to the as-of date."
)


def _pick_bundle(backend: str, bundle_path: Path | None) -> Path:
    if bundle_path:
        return bundle_path
    full = MODEL_DIR / backend / "quantile_bundle_full.joblib"
    return full if full.exists() else MODEL_DIR / backend / "quantile_bundle.joblib"


def _next_game_features(raw: pd.DataFrame, as_of: pd.Timestamp, active: pd.DataFrame):
    """Append one placeholder 'future' game per active player and reuse build_features,
    so the rolling windows include the player's most recent real game."""
    fut = pd.DataFrame({
        "SEASON_ID": active["SEASON_ID"].values,
        "PLAYER_ID": active["PLAYER_ID"].values,
        "PLAYER_NAME": active["PLAYER_NAME"].values,
        "TEAM_ABBREVIATION": active["TEAM_ABBREVIATION"].values,
        "GAME_ID": "FUTURE_" + active["PLAYER_ID"].astype(str).values,
        "GAME_DATE": as_of,
        "MATCHUP": active["TEAM_ABBREVIATION"].values + " vs. UNK",
    })
    feats = build_features(pd.concat([raw, fut], ignore_index=True))
    is_future = feats["GAME_ID"].str.startswith("FUTURE_")
    return feats[~is_future], feats[is_future].copy()


def build_payload(backend: str, bundle_path: Path | None, as_of: date | None) -> dict:
    path = _pick_bundle(backend, bundle_path)
    bundle = joblib.load(path)
    missing = [t for t in TARGETS if t not in bundle["models"]]
    if missing:
        raise SystemExit(
            f"{path.name} has no models for {missing}. Retrain: "
            f"python -m src.train --backend {backend} --full"
        )

    raw = load_logs()
    raw["GAME_DATE"] = pd.to_datetime(raw["GAME_DATE"])
    last_date = raw["GAME_DATE"].max()
    as_of_ts = max(pd.Timestamp(as_of or date.today()), last_date + pd.Timedelta(days=1))

    last_game = raw.sort_values("GAME_DATE").groupby("PLAYER_ID").tail(1)
    active = last_game[last_game["GAME_DATE"] >= last_date - pd.Timedelta(days=ACTIVE_WINDOW_DAYS)]

    real, fut = _next_game_features(raw, as_of_ts, active)

    # No opponent known: use the league-average of recent opponent baselines.
    opp_cols = [c for c in fut.columns if c.startswith("OPP_") and c.endswith("_ALLOWED_15")]
    recent_real = real[real["GAME_DATE"] >= last_date - pd.Timedelta(days=30)]
    for c in opp_cols:
        fut[c] = recent_real[c].mean()

    cols = bundle["feature_cols"]
    proj = {t: np.zeros((len(fut), len(QUANTILES))) for t in TARGETS}
    for is_home in (0, 1):
        X = fut[cols].copy()
        X["IS_HOME"] = is_home
        for t in TARGETS:
            q = np.column_stack([bundle["models"][t][qq].predict(X) for qq in QUANTILES])
            proj[t] += np.sort(q, axis=1) / 2  # sort fixes quantile crossing

    # Recent games (most recent first)
    ids = set(fut["PLAYER_ID"])
    recent = (
        raw[raw["PLAYER_ID"].isin(ids)]
        .sort_values("GAME_DATE")
        .groupby("PLAYER_ID")
        .tail(RECENT_GAMES)
        .sort_values("GAME_DATE", ascending=False)
    )
    opp = recent["MATCHUP"].str.extract(r"(?:vs\.|@)\s+([A-Z]{3})")[0]
    recent = recent.assign(_opp=opp, _home=recent["MATCHUP"].str.contains("vs."))
    recent_by_player = {pid: g for pid, g in recent.groupby("PLAYER_ID")}

    players = []
    for i, (_, row) in enumerate(fut.iterrows()):
        pid = int(row["PLAYER_ID"])
        projection = {
            t: {
                f"p{int(q * 100)}": round(float(max(proj[t][i, j], 0.0)), 2)
                for j, q in enumerate(QUANTILES)
            }
            for t in TARGETS
        }
        games = []
        for _, g in recent_by_player.get(pid, pd.DataFrame()).iterrows():
            stats = {t: float(g[t]) for t in TARGETS if pd.notna(g[t])}
            games.append({
                "date": g["GAME_DATE"].strftime("%Y-%m-%d"),
                "opp": g["_opp"],
                "home": bool(g["_home"]),
                "wl": g["WL"] if pd.notna(g["WL"]) else None,
                "min": round(float(g["MIN"]), 1) if pd.notna(g["MIN"]) else None,
                "stats": stats,
            })
        players.append({
            "id": pid,
            "name": row["PLAYER_NAME"],
            "team": row["TEAM_ABBREVIATION"],
            "projection": projection,
            "recent": games,
        })

    players.sort(key=lambda p: p["name"])
    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "as_of": as_of_ts.strftime("%Y-%m-%d"),
        "trained_through": bundle.get("trained_through"),
        "data_through": last_date.strftime("%Y-%m-%d"),
        "assumptions": ASSUMPTIONS,
        "stats": TARGETS,
        "players": players,
    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", choices=["sklearn", "lightgbm"], default="sklearn")
    ap.add_argument("--bundle", type=Path, default=None)
    ap.add_argument("--as-of", type=date.fromisoformat, default=None)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    payload = build_payload(args.backend, args.bundle, args.as_of)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, separators=(",", ":")))
    print(f"Wrote {len(payload['players'])} players to {args.out} "
          f"({args.out.stat().st_size / 1024:.0f} KB)")
