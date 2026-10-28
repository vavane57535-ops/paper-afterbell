# Afterbell — Architecture & module contracts

Developer reference. User-facing documentation is `README.md` (French).

Afterbell is a local desktop application: a Python backend (FastAPI on
`127.0.0.1`) plus a static HTML/JS interface opened in a native window
(pywebview, optional) or the default browser. Everything runs on the user's
computer; nothing is sent anywhere except public market/news requests and the
user's own exchange API calls.

## Non-negotiable design principles

1. **Honesty over hype.** No module, label, or doc may promise or imply
   guaranteed profits. The UI shows measured probabilities with their
   uncertainty, always labelled "en simulation".
2. **No payment-card data, ever.** The app never asks for, accepts, stores or
   logs credit-card numbers. Money stays on the user's exchange account, funded
   through the exchange's own (PCI-DSS certified) deposit flow. The bot uses
   exchange API keys with *trading only* permission (withdrawals disabled).
   Any API payload containing a Luhn-valid 13–19 digit number is rejected
   (`afterbell.security.guards`).
3. **Sim / live parity.** The exact same `Brain` code (vectorised over N) runs
   in simulation (N = thousands of paths), training, paper and live trading
   (N = number of symbols). No separate "backtest strategy".
4. **No look-ahead.** At step `t` the brain only sees data up to bar `t`.
   Orders decided at `t` are filled with costs at bar `t` close + spread +
   impact + latency penalty; P&L accrues from `t` to `t+1`. Simulated news
   sentiment is *reactive* (driven by past/current returns and jumps), never
   predictive of future returns.
5. **Spot, long/flat, no leverage, no shorting.** Exposure is in `[0, 1]` of
   the sleeve.
6. **Risk limits are enforced outside the brain** (risk manager), identically
   in sim (vectorised `VectorRiskState`) and live (`RiskManager`).
7. **Live mode is locked** until the readiness gate passes on ≥ 10 000
   validation simulations, all stress scenarios, and a paper-trading period.
8. **Local-only server**: bind `127.0.0.1`, random 256-bit session token,
   Host/Origin checks (anti DNS-rebinding), strict CSP, no CORS, no external
   scripts in the UI.

## Package layout and ownership

```
afterbell/
  __init__.py          version (shared, do not edit)
  __main__.py          entry point (API agent)
  config.py            settings & limits (shared, do not edit)
  core/types.py        data contracts (shared, do not edit)
  core/indicators.py   vectorised indicator helpers (AI agent)
  sim/                 market simulation (SIM agent) + engine (ENGINE agent)
  ai/                  brain, features, experts, checkpoint (AI agent) + trainer (ENGINE agent)
  risk/                metrics, risk manager, readiness gate (RISK agent)
  market/              ccxt exchange client, scanner, datastore (MARKET agent)
  news/                RSS / fear & greed / sentiment (MARKET agent)
  execution/           brokers (EXEC agent)
  security/            vault, guards, audit log (SECURITY agent)
  engine/              paper/live trading runner (API agent)
  api/                 FastAPI server, job manager, routes (API agent)
  ui/static/           index.html, app.js, charts.js, style.css (UI agent)
tests/                 test_<module>.py per module
```

Coding conventions: Python ≥ 3.10, `from __future__ import annotations`,
type hints, dataclasses, numpy vectorisation, docstrings on public functions,
English identifiers/comments, **French** for any user-facing string (errors
returned to the UI, labels). Only dependencies listed in `pyproject.toml`
(numpy, fastapi, uvicorn, websockets, ccxt, cryptography, httpx, defusedxml);
pytest + pytest-asyncio for tests (`asyncio_mode = "auto"`). No scipy, no
pandas. Tests must not touch the network (mock httpx/ccxt).

---

## core/indicators.py (AI agent)

Pure numpy, vectorised over the leading axis; used by features and scanner.

```python
def ema_alpha(period: float) -> float                     # 2/(period+1)
def halflife_alpha(halflife: float) -> float              # 1 - 0.5**(1/halflife)
def ema(x: np.ndarray, period: float, axis: int = -1) -> np.ndarray   # full-series EMA
def rsi(close: np.ndarray, period: int = 14) -> np.ndarray            # Wilder, last axis
def rolling_max(x, window) / rolling_min(x, window) -> np.ndarray     # trailing, includes current
def realized_vol(log_returns, halflife) -> np.ndarray                 # EWMA std per bar
```

## ai/ (AI agent)

### ai/features.py

```python
class FeatureState:
    """Incremental, vectorised feature computation for N independent series."""
    def __init__(self, n: int, params: BrainParams)
    def update(self, price: np.ndarray, volume: np.ndarray, sentiment: np.ndarray | None) -> np.ndarray
        # price/volume/sentiment shape (N,). Returns features (N, F) float64 in FEATURE_NAMES
        # order, each clipped to [-5, 5], NaN-free. O(1) per step except the rolling
        # channel (ring buffer of channel_period).
    bars_seen: np.ndarray   # (N,) int
    last_return: np.ndarray # (N,) log return of the latest bar (0 on first bar)
    vol_fast: np.ndarray    # (N,) EWMA std of log returns per bar (fast halflife)
    vol_slow: np.ndarray    # (N,) idem slow halflife
    ema_fast, ema_slow: np.ndarray
    def state_dict(self) -> dict; def load_state_dict(self, d: dict) -> None
```
Feature definitions are listed next to `FEATURE_NAMES` in `core/types.py`.
Vol floor: never divide by less than `1e-4`. Sentiment `None` means 0.

### ai/online_model.py

```python
class OnlineLogistic:
    """Vectorised online logistic regression (one weight vector per path), AdaGrad + L2."""
    def __init__(self, n: int, n_features: int, lr: float, l2: float,
                 init_coef: np.ndarray | None = None, init_bias: float = 0.0)
    coef: np.ndarray (N, F); bias: np.ndarray (N,)
    def predict(self, x: np.ndarray) -> np.ndarray          # (N,) p in (0,1)
    def update(self, x: np.ndarray, y: np.ndarray, mask: np.ndarray | None = None) -> None
        # mask (N,) bool: only update where True. Gradients clipped, coef clipped to [-10, 10].
    def state_dict / load_state_dict
```

### ai/experts.py

Each expert maps features/state to a proposed exposure in `[0, 1]` (N,):
`cash` (0), `hold` (1), `trend` (soft sigmoid of ema_spread), `mean_reversion`
(buy when rsi/bb_z oversold, only when vol_ratio is not elevated; flat when
overbought), `breakout` (1 above channel high, 0 below channel low, keep
previous otherwise), `ml` (`clip((p_up - 0.5) / 0.1, 0, 1)`). Order must match
`EXPERT_NAMES`.

```python
def expert_signals(features: np.ndarray, p_up: np.ndarray, prev_signals: np.ndarray | None) -> np.ndarray  # (N, K)
```

### ai/brain.py — the core "AI"

```python
class Brain:
    def __init__(self, n: int, params: BrainParams, weights: ModelWeights | None = None, learn: bool = True)
    def step(self, price: np.ndarray, volume: np.ndarray, sentiment: np.ndarray | None = None,
             current_exposure: np.ndarray | None = None) -> BrainOutput
    def export_weights(self) -> ModelWeights   # average over the N paths (transfer learning)
    def state_dict(self) -> dict; def load_state_dict(self, d: dict) -> None   # JSON-safe
```
`step` algorithm (all vectorised over N, bar `t` just closed):
1. `x_t = features.update(price, volume, sentiment)`; `r_t = features.last_return`.
2. **Learn** (if `learn` and t ≥ 1): label `y = r_t > label_threshold` for the
   previous features `x_{t-1}`; `model.update(x_{t-1}, y, mask=ready)`.
3. **Hedge update**: reward_k = `(s_k(t-1) * r_t - cost_estimate * |s_k(t-1) - s_k(t-2)|) / max(vol_fast, 1e-4)`;
   `logw = hedge_decay * logw + hedge_eta * reward`, clipped to `[-50, 50]`.
4. `p_up = model.predict(x_t)`; `s(t) = expert_signals(...)`; weights = softmax(logw);
   `raw = Σ_k w_k s_k`.
5. Risk overlay: crash protection if `vol_fast > crash_vol_mult * vol_slow` and
   `mom_fast < 0` → `raw *= crash_cut` (flag 2); sentiment risk-off if smoothed
   sentiment < `sentiment_riskoff` → `raw *= 0.5` (flag 4); vol targeting:
   `raw *= min(1, target_vol_bar / vol_fast)` with
   `target_vol_bar = target_vol_annual / sqrt(bars_per_year)` (flag 8 when
   binding); clip to `[0, max_exposure]`.
6. Warm-up: while `bars_seen < warmup_bars`, target = 0 and ready = False (flag 1).
7. Hysteresis: if `current_exposure` is given and `|raw - current| < min_trade_delta`,
   target = current (except forced moves to 0 from crash/risk-off which always pass).
`Brain` must handle N = 1 and N = 20 000; paths never interact (path i of an
N-path brain behaves exactly like a 1-path brain fed the same data). Speed
target: one step for N = 5 000 in < 2 ms on a laptop.

```python
def warmup_signals(series: list[CandleSeries], params: BrainParams, weights: ModelWeights | None,
                   sentiments: list[float] | None = None) -> tuple[Brain, BrainOutput]
    # Feed each series (aligned on the last bar; shorter series are left-padded by
    # repeating their first bar) through a Brain with N = len(series); return the
    # brain (ready to continue live) and its last output. Used by scanner & runner.
```

### ai/checkpoint.py

```python
def save_checkpoint(path: Path, params: BrainParams, weights: ModelWeights, extra: dict | None = None) -> None
    # JSON {"format": "afterbell-brain", "version": 1, "params", "weights", "extra"}; atomic write 0600
def load_checkpoint(path: Path) -> tuple[BrainParams, ModelWeights, dict]
    # raises FileNotFoundError / ValueError (corrupt or incompatible)
def default_model() -> tuple[BrainParams, ModelWeights]
```

## sim/ (SIM agent)

### sim/calibration.py

```python
@dataclass
class RegimeSpec:
    name: str              # "haussier", "baissier", "range", "krach"
    drift_annual: float    # log-drift per year
    vol_mult: float        # multiplier on base volatility
    mean_duration_days: float

@dataclass
class MarketModelParams:
    timeframe: str = "1h"
    base_vol_annual: float = 0.55
    regimes: list[RegimeSpec]                 # default 4 regimes, see below
    transition: list[list[float]] | None      # per-bar matrix; None = derived from durations
    garch_alpha: float = 0.08
    garch_beta: float = 0.90
    t_df: float = 4.0                         # Student-t innovations, scaled to unit variance
    jump_intensity_annual: float = 6.0
    jump_mean: float = -0.02
    jump_std: float = 0.05
    volume_base: float = 1500.0               # base units per bar (BTC-like, 1h)
    volume_vol_beta: float = 0.6              # log-volume sensitivity to |r|/sigma
    initial_price: float = 60000.0
    sentiment_persistence: float = 0.97
    sentiment_return_beta: float = 0.08
    sentiment_noise: float = 0.03
    def to_dict / from_dict
    def per_bar_transition(self) -> np.ndarray  # (R, R) rows sum to 1

def default_params(asset: str = "BTC", timeframe: str = "1h") -> MarketModelParams
    # Stylised facts of BTC (2018–2025): annual vol ~55 %, hourly excess kurtosis > 5,
    # volatility clustering, negative-skew jumps. Long-run drift deliberately
    # conservative (≈ +10..+20 %/yr), NOT the historical bull-run average.
    # Defaults: haussier (+0.8/yr, 0.9x, 60 d), baissier (-0.7/yr, 1.15x, 40 d),
    # range (0, 0.7x, 35 d), krach (-8/yr, 2.6x, 2.5 d).
    # Transition from durations; leaving a regime goes to the others with sensible
    # probabilities (krach mostly from baissier/haussier, exits to baissier/range).
def randomize_params(base: MarketModelParams, rng: np.random.Generator, strength: float = 1.0) -> MarketModelParams
    # Domain randomisation for training: vol x U(0.7, 1.4), drifts shifted by
    # N(0, 0.3*strength), jump intensity x U(0.5, 2), t_df U(3, 6), garch persistence jitter.
def calibrate_from_returns(log_returns: np.ndarray, timeframe: str, initial_price: float | None = None) -> MarketModelParams
    # Variance targeting + grid-search Gaussian quasi-likelihood for (alpha, beta);
    # t_df from excess kurtosis (df = 4 + 6/kurt, clipped 2.5..30); jumps from |r| > 5 sigma.
def stylized_facts(log_returns: np.ndarray, timeframe: str) -> dict
    # annual_vol, excess_kurtosis, skew, acf_r_lag1, acf_abs_r (lags 1, 6, 24), annual_drift
```

### sim/generator.py

```python
class MarketGenerator:
    def __init__(self, params: MarketModelParams, seed: int | None = None)
    def generate(self, n_paths: int, n_steps: int) -> SimMarket
```
Regime-switching Markov chain × GARCH(1,1) with Student-t innovations ×
Poisson jumps × volume–volatility coupling × reactive sentiment. Loop over
time, vectorised over paths. Each regime's GARCH uses variance targeting at
`(base_vol_bar * vol_mult)^2`. Initial regime drawn from the stationary
distribution. `tradable` all True; `spread_mult` = 1 + 2·max(0, sigma/base − 1).
Return per bar clipped to `[-0.5, 0.5]` log. Must generate 10 000 × 720 in
< 2 s. `meta` holds the params dict and seed.

### sim/bootstrap.py

```python
def stationary_bootstrap(log_returns: np.ndarray, n_paths: int, n_steps: int,
                         mean_block: float = 72.0, seed: int | None = None,
                         volumes: np.ndarray | None = None, initial_price: float = 1.0,
                         timeframe: str = "1h", params: MarketModelParams | None = None) -> SimMarket
    # Politis–Romano stationary bootstrap of *real* historical returns (keeps
    # volatility clustering and fat tails). Volumes resampled with the same indices
    # (or generated). Sentiment generated reactively as in generator. regimes = -1.
```

### sim/stress.py

```python
@dataclass
class StressScenario:
    key: str; label: str; description: str   # French label/description for the UI
STRESS_SCENARIOS: dict[str, StressScenario]
def apply_stress(market: SimMarket, key: str, seed: int | None = None) -> SimMarket
def stress_market(key: str, n_paths: int, n_steps: int, params: MarketModelParams | None = None, seed: int | None = None) -> SimMarket
```
Scenarios (inspired by real episodes; shock injected at a random bar in the
first 60 % of the horizon, sentiment shock at the *same* bar, never earlier):
`krach_covid_2020` (−50 % over ~36 h, partial rebound), `effondrement_luna_2022`
(−90 % over 4 days, no rebound — alt-coin collapse), `faillite_ftx_2022`
(−25 % over 5 days + 2× vol + 12 h outage), `flash_crash` (−30 % in 1 bar,
80 % recovered over 6 bars, spread ×10 for 3 bars), `marche_baissier_2022`
(persistent −80 %/yr drift whole horizon), `marche_haussier_2021` (+250 %/yr —
tests missing out, not losses), `range_volatil` (zero drift, 1.5× vol —
whipsaw), `panne_exchange` (24 h non-tradable during a −15 % move),
`crise_liquidite` (spread ×8, volume ÷ 5 for the whole horizon).

### sim/microstructure.py

```python
class CostModel:
    def __init__(self, costs: CostParams)
    def fill_price(self, mid: np.ndarray, side: np.ndarray, trade_value: np.ndarray,
                   bar_value: np.ndarray, sigma_bar: np.ndarray, spread_mult: np.ndarray | None = None) -> np.ndarray
        # side +1 buy / -1 sell / 0 none. adverse = half_spread*spread_mult*(1+sigma/0.006)
        #   + slippage_coef*sigma*sqrt(trade_value/max(bar_value,1)) + latency_coef*sigma
        # price = mid * (1 + side * adverse)
    def fee(self, trade_value: np.ndarray, maker: bool = False) -> np.ndarray
```

## sim/engine.py (ENGINE agent)

```python
def build_market(cfg: SimConfig, n_paths: int, seed: int, history_returns: np.ndarray | None = None,
                 params: MarketModelParams | None = None) -> SimMarket
def run_simulation(cfg: SimConfig, params: BrainParams, weights: ModelWeights | None = None,
                   history_returns: np.ndarray | None = None, market_params: MarketModelParams | None = None,
                   progress: Callable[[float, dict], None] | None = None,
                   cancel: threading.Event | None = None, learn: bool = True) -> SimResult
def simulate_batch(market: SimMarket, params: BrainParams, weights, cfg: SimConfig, learn: bool = True) -> dict
```
Per step `t = 0..T-1` (vectorised over paths): mark-to-market equity at
`P[:, t]` → `VectorRiskState.update` (halt/kill masks) → `Brain.step(P[:,t],
V[:,t], S[:,t], current_exposure)` → target capped by `risk.max_total_exposure`
and forced to 0 when halted/killed → trade at `CostModel.fill_price` if
`tradable[:, t]` and `|Δvalue| ≥ min_order_value` → fees → hold to `t+1`.
Buy & hold benchmark: buy at `P[:,0]` with taker fee + spread, hold. Process
batches of `batch_size`; `workers=0` → `ProcessPoolExecutor(max(1, cpu-1))` when
there are ≥ 2 batches (fallback to in-process on any pool error). Deterministic
for a given seed (batch `i` uses `seed + i`). Equity percentiles on ~200
subsampled points. Progress callback receives `(fraction, {"paths_done", "sims_per_second"})`.
`cancel` set → stop after the current batch and return partial results
(summary flagged `"partial": True`).

## ai/trainer.py (ENGINE agent)

```python
@dataclass
class TrainConfig:
    generations: int = 6; candidates: int = 6; paths_per_eval: int = 600
    n_days: float = 30.0; timeframe: str = "1h"; validation_paths: int = 10_000
    stress_paths: int = 500; seed: int = 7; initial_capital: float = 1000.0
    costs: CostParams; risk: RiskLimits; gate: GateCriteria
@dataclass
class TrainResult:
    params: BrainParams; weights: ModelWeights; learning_curve: list[dict]
    validation: SimResult; stress: dict[str, dict]   # key -> summary
    gate: GateReport; elapsed_s: float
    def to_dict(self) -> dict
def train(cfg: TrainConfig, base_params: BrainParams | None = None, base_weights: ModelWeights | None = None,
          history_returns: np.ndarray | None = None, progress=None, cancel=None) -> TrainResult
def robust_score(summary: dict, loss_threshold: float) -> float
```
Each generation: (a) *experience*: run the current best on fresh
domain-randomised markets (plus bootstrap of real history when given) with
learning on, average the learned coefficients / Hedge log-weights into the new
`ModelWeights`; (b) *evolution*: mutate the best params into `candidates`
variants (bounded, integer periods stay ints, `fast_ema < slow_ema`), evaluate
all on the same common-random-numbers markets, keep the best by
`robust_score = median_return - 2*cvar5_loss_excess - 3*max(0, prob_loss_gt - 0.05) - 0.5*kill_rate`
(computed from `summarize`); learning curve entry per generation:
`{generation, train_score, val_score, median_return, prob_profit, prob_loss_gt_threshold}` where
val_score uses a held-out seed. Finally: validation on `validation_paths`
fresh paths (different seed, `learn=True`), every stress scenario, and
`evaluate_gate(...)` with `paper=None`.

## risk/ (RISK agent)

### risk/metrics.py

```python
def equity_metrics(equity: np.ndarray, bars_per_year: float) -> dict[str, np.ndarray]
    # equity (N, T+1) → total_return, max_drawdown (positive), sharpe, sortino, volatility (annualised)
def max_drawdown(equity: np.ndarray) -> np.ndarray
def wilson_interval(successes: int, n: int, z: float = 1.96) -> tuple[float, float]
def summarize(final_returns, max_drawdowns, sharpe, bh_returns, killed, n_trades, fees,
              loss_threshold: float = 0.10, initial_capital: float = 1000.0) -> dict
    # JSON-safe floats: n, prob_profit (+ prob_profit_ci [lo, hi]), prob_beat_bh, mean_return,
    # median_return, p5, p25, p75, p95, worst, best, cvar5 (mean of worst 5 % returns),
    # prob_loss_gt_threshold (+ _ci), loss_threshold, prob_dd_gt_20, median_max_dd,
    # p95_max_dd, median_sharpe, kill_rate, avg_trades, avg_fees, bh_median_return,
    # bh_prob_profit, bh_p5
def histogram(values: np.ndarray, bins: int = 60, range_: tuple | None = None, other: np.ndarray | None = None) -> dict
    # {"edges": [...], "counts": [...], "bh_counts": [...]}
def percentile_bands(curves: np.ndarray, points: int = 200) -> dict[str, list[float]]  # p5..p95
```

### risk/manager.py

```python
class VectorRiskState:
    def __init__(self, n: int, limits: RiskLimits, initial_equity: float | np.ndarray, bars_per_day: float)
    def update(self, equity: np.ndarray, t: int) -> tuple[np.ndarray, np.ndarray]
        # returns (can_hold (N,) bool, killed (N,) bool). Daily loss vs equity at the start
        # of the current day → can_hold False until next day; drawdown vs high-water mark
        # ≥ max_drawdown → killed permanently.
    killed: np.ndarray; halted: np.ndarray; n_daily_halts: np.ndarray

@dataclass
class RiskDecision: allowed: bool; reason: str; amount: float   # possibly reduced amount
@dataclass
class RiskEvent: kind: str ("daily_halt"|"kill"|"rearm"|"stale_data"|"rate_limit"); message: str; ts: int

class RiskManager:
    """Live/paper risk control for one bot allocation. Thread-safe."""
    def __init__(self, limits: RiskLimits, capital: float, timeframe: str = "1h", now_ms: Callable[[], int] | None = None)
    def on_equity(self, equity: float, ts: int) -> list[RiskEvent]
    def check_order(self, req: OrderRequest, portfolio: PortfolioSnapshot, last_bar_ts: int | None,
                    quote_volume_24h: float | None, now_ts: int) -> RiskDecision
        # rejects when killed / halted (except sells that reduce exposure), stale data,
        # illiquid market, rate limit, order below min value; reduces amount to respect
        # max_position_fraction & max_total_exposure; never allows leverage or shorting
        # (sell > position).
    def kill(self, reason: str, ts: int) -> RiskEvent
    def rearm(self, ts: int) -> RiskEvent      # only clears the kill switch; resets HWM to current equity
    @property can_open_positions: bool; must_flatten: bool
    def status(self) -> dict
```

### risk/gate.py

```python
def evaluate_gate(validation_summary: dict | None, stress_summaries: dict[str, dict] | None,
                  paper_stats: dict | None, criteria: GateCriteria, now_ts: int = 0) -> GateReport
```
Sim checks (French labels): validation paths ≥ min, `prob_loss_gt_threshold`
≤ max (and its Wilson upper bound reported in `detail`), prob_profit ≥ min,
median_return ≥ min, kill_rate ≤ max, every stress scenario median loss ≤
`max_stress_loss`. Paper checks: days ≥ min, max drawdown ≤ max, trades ≥
min, no kill-switch events, paper return within the sim p5 band (detail).
`live_unlocked = sim_passed and paper_passed`. `note` explains in French that
passing the gate is not a guarantee.

## security/ (SECURITY agent)

### security/vault.py

```python
class VaultError(Exception); class InvalidPassword(VaultError); class VaultLocked(VaultError)
class Vault:
    def __init__(self, path: Path, idle_timeout_s: float = 900, kdf_n: int = 2**17)
    def exists(self) -> bool
    def create(self, password: str) -> None       # validate strength, refuse overwrite
    def unlock(self, password: str) -> None       # exponential back-off after failures
    def lock(self) -> None                         # wipe key & plaintext from memory (best effort)
    @property is_unlocked: bool                    # auto-locks after idle_timeout_s
    def set_secret(self, name: str, value: dict[str, str]) -> None
    def get_secret(self, name: str) -> dict[str, str] | None
    def delete_secret(self, name: str) -> None
    def list_secrets(self) -> list[dict]           # [{"name", "masked": {"api_key": "abcd…wxyz", ...}}]
    def change_password(self, old: str, new: str) -> None
```
Scrypt (n=2^17, r=8, p=1) → 32-byte key → AES-256-GCM, 12-byte random nonce
per write, header as AAD. File JSON `{format, version, kdf:{name,n,r,p,salt},
nonce, ciphertext}` (base64), atomic write, mode 0600. Secrets never logged,
never returned unmasked to the API. `set_secret` refuses values containing
card numbers.

### security/guards.py

```python
class CardDataRejected(ValueError)
def luhn_valid(digits: str) -> bool
def find_card_numbers(text: str) -> list[str]   # 13–19 digits, spaces/dashes allowed, Luhn-valid
def reject_card_data(payload: Any) -> None      # recursive over dict/list/str; raises CardDataRejected (French message)
def redact(text: str) -> str                    # masks card numbers and long API-key-like tokens
class RedactingFilter(logging.Filter)
def password_problems(password: str) -> list[str]   # French; min 12 chars, 3 classes, not common
def validate_symbol(symbol: str) -> str         # ^[A-Z0-9]{2,15}/[A-Z0-9]{2,10}$ else ValueError
def validate_exchange_id(exchange_id: str) -> str   # must be in SUPPORTED_EXCHANGES
SUPPORTED_EXCHANGES = ["binance", "kraken", "coinbase", "bybit", "okx", "kucoin", "bitget", "gate", "bitstamp", "bitfinex"]
```

### security/audit.py

```python
class AuditLog:
    """Append-only JSONL, each entry hash-chained (sha256 of previous entry) — tamper-evident."""
    def __init__(self, path: Path)
    def append(self, kind: str, data: dict) -> dict  # entry {seq, ts, kind, data, prev, hash}; data redacted
    def tail(self, n: int = 200) -> list[dict]
    def verify(self) -> tuple[bool, int | None]      # (ok, first bad seq)
```

## market/ & news/ (MARKET agent)

### market/exchange.py

```python
class ExchangeError(Exception)
class ExchangeClient:
    """Thin async wrapper over ccxt.async_support with retries, rate limiting and clean errors."""
    def __init__(self, exchange_id: str, credentials: dict | None = None, sandbox: bool = False, timeout_ms: int = 15000)
    async def load_markets(self) -> dict
    async def fetch_tickers(self, symbols: list[str] | None = None) -> dict[str, dict]
    async def fetch_ohlcv(self, symbol: str, timeframe: str = "1h", since: int | None = None, limit: int = 500) -> CandleSeries
    async def fetch_history(self, symbol: str, timeframe: str, days: float) -> CandleSeries   # paginated
    async def fetch_order_book(self, symbol: str, limit: int = 20) -> dict   # {"bids", "asks", "ts"}
    async def fetch_balance(self) -> dict[str, float]          # free balances
    async def create_limit_order(self, symbol, side: Side, amount, price, client_id: str, post_only: bool = False) -> Order
    async def cancel_order(self, order_id: str, symbol: str) -> None
    async def fetch_order(self, order_id: str, symbol: str) -> Order
    async def fetch_open_orders(self, symbol: str | None = None) -> list[Order]
    async def check_permissions(self) -> dict   # {"can_trade": bool|None, "can_withdraw": bool|None, "detail": str}
    def amount_to_precision(self, symbol, amount) -> float; def price_to_precision(self, symbol, price) -> float
    def min_amount(self, symbol) -> float; def min_cost(self, symbol) -> float
    async def close(self) -> None
```
`check_permissions` uses Binance `sapi_get_account_apirestrictions` when
available (`enableWithdrawals`), otherwise returns `None` with a French detail
asking the user to confirm withdrawals are disabled. Credentials are kept only
in the ccxt instance, never logged (`__repr__` masks them).

### market/scanner.py

```python
class MarketScanner:
    def __init__(self, client: ExchangeClient)
    async def scan(self, quote: str = "USDT", top_n: int = 50, min_quote_volume: float = 0.0) -> list[MarketRow]
async def fetch_global_overview(http: httpx.AsyncClient | None = None) -> dict
    # CoinGecko /api/v3/global + /coins/markets?vs_currency=usd&per_page=100:
    # {"total_market_cap_usd", "btc_dominance", "market_cap_change_24h_pct", "top": [{id, symbol, name, price, change_24h_pct, market_cap, volume_24h}]}
```

### market/datastore.py

```python
class DataStore:
    """SQLite cache of OHLCV candles (WAL mode, thread-safe)."""
    def __init__(self, path: Path)
    def save_candles(self, exchange: str, symbol: str, timeframe: str, series: CandleSeries) -> int
    def load_candles(self, exchange: str, symbol: str, timeframe: str, since: int | None = None, limit: int | None = None) -> CandleSeries
    def last_ts(self, exchange, symbol, timeframe) -> int | None
    def close(self) -> None
```

### news/sentiment.py

```python
def score_text(text: str) -> tuple[float, list[str]]   # (sentiment in [-1, 1], tags)
def extract_assets(text: str) -> list[str]             # tickers & names → ["BTC", "ETH", ...]
def aggregate(items: list[NewsItem], now_ts: int, halflife_hours: float = 12.0) -> dict  # {"global": float, "by_asset": {...}, "count": int}
```
Crypto-specific weighted lexicon (EN + FR): strong negative (hack, exploit,
drained, bankruptcy, insolvency, lawsuit, SEC sues, ban, delisting, rug pull,
liquidations, crash, plunge, outage…), positive (ETF approval, adoption,
partnership, upgrade, record high, inflows, rally, surge…), negation handling
("not", "no", "pas"), intensifiers, title weighted 2× vs summary. Tags:
hack, regulation, etf, macro, adoption, exchange, stablecoin, liquidation.

### news/feeds.py

```python
class NewsAggregator:
    def __init__(self, feeds: list[tuple[str, str]], http: httpx.AsyncClient | None = None, max_items: int = 300)
    async def refresh(self) -> list[NewsItem]        # concurrent fetch; one feed failing never breaks others
    def items(self, asset: str | None = None, limit: int = 100) -> list[NewsItem]
    def sentiment(self, now_ts: int | None = None) -> dict  # aggregate(...)
    async def fear_greed(self) -> dict | None        # alternative.me /fng/?limit=30 → {"value", "classification", "history": [...]}
    last_refresh_ts: int; errors: dict[str, str]
def parse_feed(xml_bytes: bytes, source: str) -> list[NewsItem]   # RSS 2.0 and Atom, via defusedxml; strips HTML
```
Responses capped at 5 MB, timeout 10 s, item ids = sha1(url or title).

## execution/ (EXEC agent)

```python
class Broker(ABC):
    mode: Mode
    async def portfolio(self, prices: dict[str, float]) -> PortfolioSnapshot
    async def place_order(self, req: OrderRequest) -> Order
    async def cancel_all(self) -> None
    async def sync(self) -> None               # refresh open orders / fills
    def trades(self) -> list[Order]

class PaperBroker(Broker):
    def __init__(self, capital: float, costs: CostParams, quote: str = "USDT", state_path: Path | None = None)
    # fills limit orders immediately if marketable vs the provided/known price, else fills
    # when a later price crosses; applies CostModel-like spread + fees; persists state.
    def update_prices(self, prices: dict[str, float], ts: int) -> None

class LiveBroker(Broker):
    def __init__(self, client: ExchangeClient, capital: float, quote: str, risk: RiskManager, audit: AuditLog,
                 state_path: Path | None = None, dry_run: bool = False)
    # Sleeve accounting: the bot only uses `capital` (never the whole balance) and only
    # sells what it bought. Limit orders priced at best ask/bid ± max_slippage (price
    # protection), rounded with exchange precision, unique client ids
    # ("afb-<uuid12>"), refused below exchange minimums. Every order goes through
    # risk.check_order first and is written to the audit log. Never market orders.
    # Never withdraw (no such method exists anywhere in the codebase).

def plan_rebalance(targets: dict[str, float], portfolio: PortfolioSnapshot, prices: dict[str, float],
                   limits: RiskLimits, n_symbols: int) -> list[OrderRequest]
    # target exposure per symbol is relative to its sleeve (capital / n_symbols);
    # sells first, then buys; skips deltas below min_order_value.
```

## engine/ & api/ (API agent)

### engine/runner.py

```python
class TradingRunner:
    def __init__(self, mode: Mode, broker: Broker, client: ExchangeClient, symbols: list[str], timeframe: str,
                 params: BrainParams, weights: ModelWeights, risk: RiskManager, audit: AuditLog,
                 news: NewsAggregator | None = None, on_event: Callable[[dict], None] | None = None,
                 state_path: Path | None = None)
    async def start(self) -> None    # warm-up with ~500 candles per symbol (warmup_signals), then loop
    async def stop(self) -> None
    async def kill(self, reason: str) -> None   # cancel all orders, flatten (limit orders), halt
    def status(self) -> dict          # mode, running, symbols, last_bar_ts, equity, equity_curve (last 500),
                                      # positions, last_output per symbol, risk status, started_at, trades
```
Loop: sleep until the next bar close + 5 s; fetch latest closed candles; skip
duplicate bars; `brain.step` (N = symbols) with news sentiment per asset;
`risk.on_equity`; `plan_rebalance`; orders through broker; emit events;
persist brain state; any exception → logged, audit, backoff, never crashes the
app; stale data → no new orders.

### api/server.py & jobs.py

```python
def create_app(settings: AppSettings, token: str) -> FastAPI
class JobManager:   # background threads for CPU-bound sims/training
    def submit(self, kind: str, fn: Callable[[Callable[[float, dict], None], threading.Event], Any]) -> str
    def get(self, job_id: str) -> dict | None   # {id, kind, status, progress, message, info, result, error, created_at, finished_at}
    def cancel(self, job_id: str) -> bool
```
Security middleware: every `/api/*` request needs header
`X-Afterbell-Token: <token>` (constant-time compare) — WebSocket uses
`?token=`; `Host` must be `127.0.0.1:<port>` or `localhost:<port>`; if
`Origin` present it must match; responses carry CSP `default-src 'self';
img-src 'self' data:; connect-src 'self' ws://127.0.0.1:* ws://localhost:*;
frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy: no-referrer`, `Cache-Control: no-store` on API. JSON bodies
≤ 64 KB, all bodies passed through `reject_card_data`. Errors returned as
`{"error": "<French message>"}` with proper status codes.

### HTTP API contract (UI ↔ backend)

All responses JSON. `T` = header `X-Afterbell-Token`.

| Method & path | Body / query | Response |
|---|---|---|
| GET `/api/status` | – | `{version, mode, vault:{exists, unlocked}, model:{trained, trained_at, params}, gate: GateReport, runner: status\|null, settings:{exchange, quote, timeframe, symbols}, disclaimer}` |
| GET `/api/market/scan` | `exchange, quote, top` | `{rows: MarketRow[], ts, exchange, error?}` |
| GET `/api/market/ohlcv` | `exchange, symbol, timeframe, limit` | `CandleSeries.to_dict() + {symbol}` |
| GET `/api/market/global` | – | `fetch_global_overview()` or `{error}` |
| POST `/api/market/signals` | `{exchange, symbols[], timeframe}` | `{signals: [{symbol, target, p_up, experts:{name: weight}, flags}]}` |
| GET `/api/news` | `asset?` | `{items: NewsItem[], sentiment:{global, by_asset, count}, fear_greed, last_refresh_ts, errors}` |
| POST `/api/news/refresh` | – | same as GET |
| GET `/api/sim/scenarios` | – | `{models: [...], scenarios: [{key, label, description}]}` |
| POST `/api/sim/run` | `{n_paths, n_days, timeframe, model, scenario?, initial_capital, seed?, use_trained_model}` | `{job_id}` |
| GET `/api/jobs/{id}` | – | job dict; `result` = `SimResult.to_dict()` or `TrainResult.to_dict()` |
| POST `/api/jobs/{id}/cancel` | – | `{ok}` |
| POST `/api/train/start` | `{generations, candidates, paths_per_eval, validation_paths, n_days, use_history}` | `{job_id}` |
| GET `/api/model` | – | `{trained, params, weights, learning_curve, validation, stress, gate, trained_at}` |
| POST `/api/model/reset` | – | `{ok}` |
| GET `/api/gate` | – | `GateReport` |
| POST `/api/paper/start` | `{exchange, symbols[], timeframe, capital}` | runner status |
| POST `/api/paper/stop` | – | `{ok}` |
| POST `/api/live/start` | `{exchange, symbols[], timeframe, capital, confirmation: "JE COMPRENDS LES RISQUES", acknowledgements: [ack keys]}` | runner status or 403 `{error, gate}` |
| POST `/api/live/stop` | – | `{ok}` |
| POST `/api/kill` | `{reason}` | `{ok}` — stops everything, cancels orders, flattens |
| POST `/api/risk/rearm` | – | `{ok}` |
| GET `/api/portfolio` | – | `{snapshot, equity_curve: [[ts, equity]], trades: Order[]}` |
| GET `/api/vault` | – | `{exists, unlocked, secrets: [{name, masked}]}` |
| POST `/api/vault/create` | `{password}` | `{ok}` |
| POST `/api/vault/unlock` | `{password}` | `{ok}` |
| POST `/api/vault/lock` | – | `{ok}` |
| POST `/api/vault/exchange-keys` | `{exchange, api_key, secret, password?}` | `{ok, permissions}` |
| DELETE `/api/vault/exchange-keys/{exchange}` | – | `{ok}` |
| GET `/api/settings` | – | `AppSettings.to_dict()` |
| PUT `/api/settings` | partial settings (`risk`, `symbols`, `exchange`, `quote`, `timeframe`) | settings or 400 `{error, problems}` |
| GET `/api/audit` | `limit` | `{entries, verified, bad_seq}` |
| WS `/api/ws?token=` | – | server push `{type: "job"\|"runner"\|"alert"\|"news", data}` |

Acknowledgement keys for live start: `risk_of_loss`, `no_guarantee`,
`withdrawals_disabled`, `only_what_i_can_lose`.

## ui/static (UI agent)

Single-page app, French, dark theme, desktop-first (≥ 1280 px, usable at
1024 px). No external resources (CSP `'self'`): system fonts, inline SVG
icons, own canvas charts (`charts.js`: line, multi-line with bands (fan chart),
histogram (two series), candlestick, gauge, sparkline; HiDPI aware, resize
aware, tooltips). Token read from `location.hash` (`#token=...`), kept in
`sessionStorage`, hash removed from the URL. Pages (sidebar navigation):
Tableau de bord, Marché, Actualités, Simulation, Entraînement, Paper trading,
Lancement réel, Sécurité, Journal. A persistent honest disclaimer and a
mode badge (SIMULATION / PAPER / RÉEL) plus a red kill-switch button always
visible in the header. All dynamic text inserted with `textContent` (no
`innerHTML` with server data — XSS safe).
