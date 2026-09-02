# Mobile Game — Player Retention & Early Engagement Analysis

Identifying early return behaviour associated with Day-7 retention.

---

**Dataset:** Gamelytics: Mobile Analytics Challenge ([Kaggle](https://www.kaggle.com/datasets/debs2x/gamelytics-mobile-analytics-challenge)) — 1,000,000 registration records and 9,601,013 authentication records (`uid` + Unix timestamps only).

**Scope:** registration cohorts from 2020-01-01 to 2020-09-16 — **344,108 players**.

**Stack:** BigQuery (SQL) → Python / Pandas → Power BI → GitHub

![Power BI Dashboard](dashboard/dashboard.png)


---

## Data model

```
reg_data                      auth_data
├── uid                       ├── uid
└── reg_ts (Unix)             └── auth_ts (Unix)
     │                             ▲
     └──────── uid ────────────────┘

Grain — reg_data: one row per player registration (1,000,000 rows, 1,000,000 unique uid)
        auth_data: one row per authentication event (9,601,013 rows, 1,000,000 unique uid)
```

## Metric definitions

```
| Metric | Definition |
|---|---|
| D1 / D3 / D7 retention | % of the registration cohort with authentication activity **exactly** on day 1 / 3 / 7 after registration |
| Return days (D1–D6) | Number of distinct days with authentication activity between D1 and D6 |
| No-return rate (D1–D6) | % of players with zero authentication activity between D1 and D6 |
| Avg active days (D0–D6) | Mean number of distinct active days during the first week, registration day included |
```
---

## Method

- **Right-censoring control** — cohorts registering within 7 days of the dataset's end are excluded (10,855 players), since they never had a full observation window.
- **Shared cohort** — numerator and denominator both join against the same filtered cohort table, preventing a mismatch.
- **Leakage-free feature** — return days count D1–D6 only, excluding D7 (the label) and D0 (where nearly everyone is active).

Python and SQL implementations were cross-validated and produce identical results.

---

## Key findings

| D1 | D3 | D7 | Avg active days (D0–D6) | No-return rate (D1–D6) |
|---|---|---|---|---|
| 2.02% | 4.63% | 5.80% | 1.29 | **77.99%** |

**1 — Most players show no activity after registration day.** 268,385 of 344,108 players (78.0%) have no authentication record between D1 and D6. This dominates every other retention effect in the dataset.

**2 — A first return is the strongest early signal associated with D7 retention.**

| Return days (D1–D6) | Players | D7 retention |
|---|---|---|
| 0 | 268,385 | 2.53% |
| 1 | 54,222 | **19.02%** |
| 2 | 19,120 | 13.73% |
| 3 | 2,293 | 10.16% |

Returning at least once is associated with ~7.5× higher D7 retention. Retention then *declines* from one return day onward — this non-monotonic shape is treated as the same dataset artifact described below, not as evidence that lower engagement improves retention.

**3 — Retention held flat as acquisition grew.** Monthly registrations rose 41.9% (33,733 → 47,882) while D7 retention stayed within 5.58%–5.99% across all nine cohorts.

**Data quality note.** The curve rises from D1 (2.02%) to D6 (6.92%) before dipping at D7, rather than decaying monotonically. This is not a calculation error: Pandas and SQL implementations match, restricting to 2020 doesn't change it, registration volume is evenly distributed with no anomalous clusters, and weekly cohorts show the same pattern (1.2pp range across 38 weeks). The synthetic timestamps appear not to model organic churn, so this shape is treated as a structural property of the dataset — no product interpretation is drawn from it.

---

## Recommendations

1. **Prioritise the first return visit.** The strongest discontinuity is between zero and one return day, targeting the largest addressable segment — the 78% who never come back.
2. **Adopt "no-return rate" as a headline KPI** alongside D1/D7. It communicates early-lifecycle health more directly than the curve, given how concentrated the loss is.
3. **Instrument gameplay telemetry.** This data shows *that* and *when* players leave, not *why*. Tutorial completion, session duration, and level progression would be needed for causal diagnosis.
4. **Monitor retention as a guardrail** if acquisition spend increases further.
5. **Validate against production data before acting.** The analytical framework transfers; the specific magnitudes should not be treated as benchmarks.

---

## Next steps

- Re-run the pipeline on production data to establish whether the patterns hold outside a synthetic dataset.
- Extend the feature set with session duration and level progression once event telemetry is available, moving from association toward causal diagnosis.
- Automate the cohort tables and surface "no-return rate" as a monitored metric rather than a one-off report.

---

## Limitations

- Authentication records are a **proxy for activity** — a login is not necessarily a gameplay session.
- No session duration, gameplay events, level progression, or purchase data. Findings are **associations, not causes**.
- Registration timestamps span 1998–2020, with ~5.8% predating 2016 — implausible for a mobile game. Analysis is restricted to 2020 cohorts.
- Cohorts without a full 7-day observation window are excluded.
- The retention curve does not decay monotonically, indicating **synthetic data that does not model organic churn**. Results demonstrate analytical method rather than real player behaviour.
- The 2020-09 cohort covers only 1–16 September; its retention rates are valid, but its registration volume is not comparable to full months.

---

## Repository structure

```
gamelytics-player-retention-analysis/
├── README.md
├── sql/
│   ├── 1_data_quality.sql              
│   ├── 2_registration_activity.sql     
│   ├── 3_retention.sql
│   ├── 4_engagement.sql
│   └── 5_cohort.sql
├── notebooks/
│   └── retention.py
├── screenshots/                      
│   ├── timestamp_distribution.png
│   ├── retention_curve.png
│   ├── new_players_vs_d7.png
│   ├── engagement.png
│   └── cohort_heatmap.png
└── dashboard/
    ├── retention.pbix
    └── dashboard.png
```
