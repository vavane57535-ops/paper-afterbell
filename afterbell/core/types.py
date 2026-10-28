"""Shared data contracts used across every Afterbell module.

Rules:
- Arrays are numpy; ``to_dict`` methods return JSON-safe Python types.
- Timestamps are integer milliseconds since the Unix epoch (UTC), like ccxt.
- Simulation arrays are shaped ``(n_paths, n_steps + 1)``: column 0 is the
  starting bar, column ``t`` is the bar that has just closed at step ``t``.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields
from enum import Enum
from typing import Any

import numpy as np

from afterbell.config import CostParams, RiskLimits

# --------------------------------------------------------------------------- #
# Time helpers
# --------------------------------------------------------------------------- #

TIMEFRAME_SECONDS: dict[str, int] = {
    "1m": 60,
    "5m": 300,
    "15m": 900,
    "30m": 1800,
    "1h": 3600,
    "4h": 14400,
    "1d": 86400,
}


def timeframe_seconds(timeframe: str) -> int:
    try:
        return TIMEFRAME_SECONDS[timeframe]
    except KeyError as exc:
        raise ValueError(f"Unité de temps inconnue : {timeframe!r}") from exc


def bars_per_day(timeframe: str) -> float:
    """Crypto markets trade 24/7."""
    return 86400.0 / timeframe_seconds(timeframe)


def bars_per_year(timeframe: str) -> float:
    return 365.0 * bars_per_day(timeframe)


def _jsonable(value: Any) -> Any:
    if isinstance(value, np.ndarray):
        return value.tolist()
    if isinstance(value, (np.floating,)):
        v = float(value)
        return v if np.isfinite(v) else None
    if isinstance(value, float):
        return value if np.isfinite(value) else None
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.bool_,)):
        return bool(value)
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, dict):
        return {str(k): _jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonable(v) for v in value]
    return value


def to_jsonable(value: Any) -> Any:
    """Public helper: convert numpy / enum / nested containers to JSON-safe values.

    Non-finite floats (nan, inf) become ``None``.
    """
    return _jsonable(value)


# --------------------------------------------------------------------------- #
# Enums
# --------------------------------------------------------------------------- #


class Mode(str, Enum):
    SIMULATION = "simulation"
    PAPER = "paper"
    LIVE = "live"


class Side(str, Enum):
    BUY = "buy"
    SELL = "sell"


class OrderType(str, Enum):
    LIMIT = "limit"
    MARKET = "market"


class OrderStatus(str, Enum):
    OPEN = "open"
    PARTIAL = "partial"
    FILLED = "filled"
    CANCELED = "canceled"
    REJECTED = "rejected"


# --------------------------------------------------------------------------- #
# Market data
# --------------------------------------------------------------------------- #


@dataclass
class CandleSeries:
    """OHLCV candles in ascending time order (``ts`` = candle open time, ms)."""

    ts: np.ndarray
    open: np.ndarray
    high: np.ndarray
    low: np.ndarray
    close: np.ndarray
    volume: np.ndarray  # base-asset units

    def __post_init__(self) -> None:
        self.ts = np.asarray(self.ts, dtype=np.int64)
        for name in ("open", "high", "low", "close", "volume"):
            setattr(self, name, np.asarray(getattr(self, name), dtype=np.float64))
        n = len(self.ts)
        for name in ("open", "high", "low", "close", "volume"):
            if len(getattr(self, name)) != n:
                raise ValueError("CandleSeries: toutes les colonnes doivent avoir la même longueur")

    def __len__(self) -> int:
        return int(len(self.ts))

    @classmethod
    def empty(cls) -> "CandleSeries":
        z = np.zeros(0)
        return cls(np.zeros(0, dtype=np.int64), z, z, z, z, z)

    @classmethod
    def from_ccxt(cls, rows: list[list[float]]) -> "CandleSeries":
        """Build from ccxt ``fetch_ohlcv`` rows ``[ts, o, h, l, c, v]``.

        Rows are sorted, de-duplicated on timestamp, and rows with missing or
        non-positive prices are dropped.
        """
        clean: dict[int, list[float]] = {}
        for r in rows or []:
            if r is None or len(r) < 6:
                continue
            ts, o, h, lo, c, v = r[:6]
            if None in (ts, o, h, lo, c):
                continue
            if min(o, h, lo, c) <= 0:
                continue
            clean[int(ts)] = [float(o), float(h), float(lo), float(c), float(v or 0.0)]
        if not clean:
            return cls.empty()
        keys = sorted(clean)
        arr = np.array([clean[k] for k in keys], dtype=np.float64)
        return cls(np.array(keys, dtype=np.int64), arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3], arr[:, 4])

    def tail(self, n: int) -> "CandleSeries":
        s = slice(max(0, len(self) - n), None)
        return CandleSeries(self.ts[s], self.open[s], self.high[s], self.low[s], self.close[s], self.volume[s])

    def concat(self, other: "CandleSeries") -> "CandleSeries":
        """Merge two series, newer values win on duplicate timestamps."""
        rows = [
            [int(t), o, h, lo, c, v]
            for t, o, h, lo, c, v in zip(self.ts, self.open, self.high, self.low, self.close, self.volume)
        ] + [
            [int(t), o, h, lo, c, v]
            for t, o, h, lo, c, v in zip(other.ts, other.open, other.high, other.low, other.close, other.volume)
        ]
        return CandleSeries.from_ccxt(rows)

    def log_returns(self) -> np.ndarray:
        if len(self) < 2:
            return np.zeros(0)
        return np.diff(np.log(self.close))

    def to_dict(self) -> dict[str, Any]:
        return {
            "ts": self.ts.tolist(),
            "open": self.open.tolist(),
            "high": self.high.tolist(),
            "low": self.low.tolist(),
            "close": self.close.tolist(),
            "volume": self.volume.tolist(),
        }


@dataclass
class MarketRow:
    """One line of the market scanner."""

    symbol: str
    exchange: str
    last: float
    change_24h_pct: float | None = None
    quote_volume_24h: float | None = None
    high_24h: float | None = None
    low_24h: float | None = None
    spread_pct: float | None = None
    volatility_24h: float | None = None  # (high-low)/last
    signal: float | None = None  # AI target exposure 0..1 when computed
    p_up: float | None = None  # AI probability of an up move when computed

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


@dataclass
class NewsItem:
    id: str
    title: str
    url: str
    source: str
    published_ts: int
    summary: str = ""
    sentiment: float = 0.0  # -1 (very negative) .. +1 (very positive)
    assets: list[str] = field(default_factory=list)  # e.g. ["BTC", "ETH"]
    tags: list[str] = field(default_factory=list)  # e.g. ["hack", "regulation"]

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


# --------------------------------------------------------------------------- #
# Orders & portfolio
# --------------------------------------------------------------------------- #


@dataclass
class OrderRequest:
    symbol: str
    side: Side
    amount: float  # base-asset units
    price: float | None = None  # limit price; None only for MARKET
    order_type: OrderType = OrderType.LIMIT
    client_id: str = ""
    reason: str = ""

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


@dataclass
class Order:
    id: str
    client_id: str
    symbol: str
    side: Side
    order_type: OrderType
    amount: float
    price: float | None
    filled: float = 0.0
    avg_price: float = 0.0
    status: OrderStatus = OrderStatus.OPEN
    fee: float = 0.0  # in quote currency
    ts: int = 0
    reason: str = ""

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


@dataclass
class Position:
    symbol: str
    amount: float = 0.0  # base-asset units (spot, never negative)
    avg_entry: float = 0.0

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


@dataclass
class PortfolioSnapshot:
    ts: int
    cash: float  # quote currency available to the bot (within its allocation)
    positions: dict[str, Position] = field(default_factory=dict)
    prices: dict[str, float] = field(default_factory=dict)
    quote: str = "USDT"

    @property
    def positions_value(self) -> float:
        return float(sum(p.amount * self.prices.get(s, p.avg_entry) for s, p in self.positions.items()))

    @property
    def equity(self) -> float:
        return float(self.cash + self.positions_value)

    def exposure(self, symbol: str) -> float:
        eq = self.equity
        if eq <= 0:
            return 0.0
        p = self.positions.get(symbol)
        if p is None:
            return 0.0
        return float(p.amount * self.prices.get(symbol, p.avg_entry) / eq)

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(
            {
                "ts": self.ts,
                "cash": self.cash,
                "quote": self.quote,
                "equity": self.equity,
                "positions_value": self.positions_value,
                "positions": {s: p.to_dict() for s, p in self.positions.items()},
                "prices": dict(self.prices),
            }
        )


# --------------------------------------------------------------------------- #
# AI brain contracts
# --------------------------------------------------------------------------- #

FEATURE_NAMES: list[str] = [
    "ret_1",  # last log return / EWMA vol
    "mom_fast",  # EMA of returns (fast) / vol
    "ema_spread",  # (ema_fast / ema_slow - 1) / vol
    "rsi",  # (RSI - 50) / 50
    "bb_z",  # (price - ema_mid) / EW std of price
    "vol_ratio",  # short vol / long vol - 1
    "volume_z",  # z-score of log volume
    "channel_pos",  # position in rolling high/low channel, -0.5..0.5
    "drawdown",  # price / rolling max - 1
    "sentiment",  # EMA of news sentiment, -1..1
    "sentiment_delta",  # change of sentiment EMA
]

EXPERT_NAMES: list[str] = ["cash", "hold", "trend", "mean_reversion", "breakout", "ml"]


@dataclass
class BrainParams:
    """Hyper-parameters of the trading brain (tuned by the trainer)."""

    fast_ema: int = 12
    slow_ema: int = 48
    rsi_period: int = 14
    bb_period: int = 20
    channel_period: int = 72
    vol_fast_halflife: float = 12.0
    vol_slow_halflife: float = 96.0
    target_vol_annual: float = 0.45  # volatility targeting of the sleeve
    max_exposure: float = 0.8  # cap of the brain output (also capped by RiskLimits)
    min_trade_delta: float = 0.10  # hysteresis: ignore smaller exposure changes
    learning_rate: float = 0.05  # AdaGrad base rate of the online logistic model
    l2: float = 1e-4
    label_threshold: float = 0.0015  # an "up" label needs a return above estimated costs
    hedge_eta: float = 0.3  # Hedge learning rate on vol-normalised rewards
    hedge_decay: float = 0.995  # forgetting factor so the ensemble adapts to regimes
    cost_estimate: float = 0.0015  # per unit of turnover, used in expert rewards
    crash_vol_mult: float = 2.5  # short/long vol ratio that triggers crash protection
    crash_cut: float = 0.25  # exposure multiplier while crash protection is on
    sentiment_riskoff: float = -0.6  # sentiment below this halves exposure
    warmup_bars: int = 96  # no trading before the features are warmed up
    bars_per_year: float = 8760.0  # set from the timeframe by callers

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "BrainParams":
        names = {f.name: f for f in fields(cls)}
        kwargs: dict[str, Any] = {}
        for k, v in (data or {}).items():
            if k in names and v is not None:
                kwargs[k] = int(v) if names[k].type in ("int", int) else float(v)
        return cls(**kwargs)


@dataclass
class ModelWeights:
    """Learned state transferable between simulation, paper and live trading."""

    feature_names: list[str]
    coef: np.ndarray  # (F,) logistic regression coefficients
    bias: float
    expert_names: list[str]
    expert_log_weights: np.ndarray  # (K,) Hedge prior (log-space)
    version: int = 1
    trained_at: int = 0  # ms
    meta: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self.coef = np.asarray(self.coef, dtype=np.float64)
        self.expert_log_weights = np.asarray(self.expert_log_weights, dtype=np.float64)

    @classmethod
    def untrained(cls) -> "ModelWeights":
        return cls(
            feature_names=list(FEATURE_NAMES),
            coef=np.zeros(len(FEATURE_NAMES)),
            bias=0.0,
            expert_names=list(EXPERT_NAMES),
            expert_log_weights=np.zeros(len(EXPERT_NAMES)),
        )

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(
            {
                "feature_names": self.feature_names,
                "coef": self.coef,
                "bias": self.bias,
                "expert_names": self.expert_names,
                "expert_log_weights": self.expert_log_weights,
                "version": self.version,
                "trained_at": self.trained_at,
                "meta": self.meta,
            }
        )

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ModelWeights":
        w = cls(
            feature_names=list(data["feature_names"]),
            coef=np.asarray(data["coef"], dtype=np.float64),
            bias=float(data.get("bias", 0.0)),
            expert_names=list(data["expert_names"]),
            expert_log_weights=np.asarray(data["expert_log_weights"], dtype=np.float64),
            version=int(data.get("version", 1)),
            trained_at=int(data.get("trained_at", 0)),
            meta=dict(data.get("meta", {})),
        )
        if w.feature_names != FEATURE_NAMES or w.expert_names != EXPERT_NAMES:
            raise ValueError("Modèle incompatible avec cette version d'Afterbell")
        return w


@dataclass
class BrainOutput:
    """Result of ``Brain.step`` for N parallel paths / symbols."""

    target: np.ndarray  # (N,) desired exposure, 0..max_exposure (spot, long/flat)
    p_up: np.ndarray  # (N,) ML probability that the next bar beats costs
    expert_weights: np.ndarray  # (N, K) normalised Hedge weights
    expert_signals: np.ndarray  # (N, K) each expert's proposed exposure
    risk_flags: np.ndarray  # (N,) bitmask: 1 warmup, 2 crash protection, 4 sentiment risk-off, 8 vol cap
    ready: np.ndarray  # (N,) bool, False while warming up


# --------------------------------------------------------------------------- #
# Simulation contracts
# --------------------------------------------------------------------------- #


@dataclass
class SimMarket:
    """A batch of simulated (or bootstrapped) markets."""

    prices: np.ndarray  # (N, T+1) float64 close prices, > 0
    volumes: np.ndarray  # (N, T+1) float64 base-asset volume per bar, >= 0
    sentiment: np.ndarray  # (N, T+1) float32 in [-1, 1], reactive (never predictive)
    regimes: np.ndarray  # (N, T+1) int8 regime index (-1 when unknown, e.g. bootstrap)
    tradable: np.ndarray  # (N, T+1) bool, False during simulated exchange outages
    timeframe: str = "1h"
    spread_mult: np.ndarray | None = None  # (N, T+1) float32 multiplier on half spread, None = 1
    meta: dict[str, Any] = field(default_factory=dict)

    @property
    def n_paths(self) -> int:
        return int(self.prices.shape[0])

    @property
    def n_steps(self) -> int:
        return int(self.prices.shape[1] - 1)


@dataclass
class SimConfig:
    n_paths: int = 2000
    n_days: float = 30.0
    timeframe: str = "1h"
    initial_capital: float = 1000.0
    model: str = "regime_garch"  # "regime_garch" | "bootstrap" | "stress"
    scenario: str | None = None  # stress scenario key when model == "stress"
    seed: int = 42
    batch_size: int = 2000
    workers: int = 0  # 0 = auto (processes), 1 = in-process
    costs: CostParams = field(default_factory=CostParams)
    risk: RiskLimits = field(default_factory=RiskLimits)
    market_overrides: dict[str, Any] = field(default_factory=dict)  # e.g. {"drift_annual_shift": -0.2}
    keep_samples: int = 8  # number of example paths kept for charts

    @property
    def n_steps(self) -> int:
        return max(1, int(round(self.n_days * bars_per_day(self.timeframe))))

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(
            {
                "n_paths": self.n_paths,
                "n_days": self.n_days,
                "timeframe": self.timeframe,
                "initial_capital": self.initial_capital,
                "model": self.model,
                "scenario": self.scenario,
                "seed": self.seed,
                "batch_size": self.batch_size,
                "workers": self.workers,
                "costs": self.costs.to_dict(),
                "risk": self.risk.to_dict(),
                "market_overrides": self.market_overrides,
                "keep_samples": self.keep_samples,
                "n_steps": self.n_steps,
            }
        )


@dataclass
class SimResult:
    config: SimConfig
    n_paths: int
    n_steps: int
    elapsed_s: float
    sims_per_second: float
    summary: dict[str, Any]  # output of afterbell.risk.metrics.summarize
    final_returns: np.ndarray  # (N,) strategy return over the horizon
    bh_returns: np.ndarray  # (N,) buy & hold return (after one entry fee)
    max_drawdowns: np.ndarray  # (N,) positive fractions
    sharpe: np.ndarray  # (N,) annualised
    n_trades: np.ndarray  # (N,)
    fees: np.ndarray  # (N,) quote currency
    killed: np.ndarray  # (N,) bool, kill switch triggered
    equity_percentiles: dict[str, list[float]] = field(default_factory=dict)  # p5,p25,p50,p75,p95 (~200 pts, relative to 1.0)
    bh_percentiles: dict[str, list[float]] = field(default_factory=dict)
    sample_equity: list[list[float]] = field(default_factory=list)  # relative to 1.0
    sample_prices: list[list[float]] = field(default_factory=list)  # relative to 1.0
    histogram: dict[str, list[float]] = field(default_factory=dict)  # edges, counts, bh_counts

    def to_dict(self, include_arrays: bool = False) -> dict[str, Any]:
        out: dict[str, Any] = {
            "config": self.config.to_dict(),
            "n_paths": self.n_paths,
            "n_steps": self.n_steps,
            "elapsed_s": self.elapsed_s,
            "sims_per_second": self.sims_per_second,
            "summary": self.summary,
            "equity_percentiles": self.equity_percentiles,
            "bh_percentiles": self.bh_percentiles,
            "sample_equity": self.sample_equity,
            "sample_prices": self.sample_prices,
            "histogram": self.histogram,
        }
        if include_arrays:
            out.update(
                {
                    "final_returns": self.final_returns,
                    "bh_returns": self.bh_returns,
                    "max_drawdowns": self.max_drawdowns,
                    "sharpe": self.sharpe,
                    "n_trades": self.n_trades,
                    "fees": self.fees,
                    "killed": self.killed,
                }
            )
        return to_jsonable(out)


# --------------------------------------------------------------------------- #
# Readiness gate
# --------------------------------------------------------------------------- #


@dataclass
class GateCheck:
    key: str
    label: str  # French, shown in the UI
    value: float | None
    threshold: float | None
    passed: bool
    stage: str = "sim"  # "sim" | "paper"
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(asdict(self))


@dataclass
class GateReport:
    sim_passed: bool
    paper_passed: bool
    live_unlocked: bool
    checks: list[GateCheck] = field(default_factory=list)
    evaluated_at: int = 0
    note: str = ""

    def to_dict(self) -> dict[str, Any]:
        return to_jsonable(
            {
                "sim_passed": self.sim_passed,
                "paper_passed": self.paper_passed,
                "live_unlocked": self.live_unlocked,
                "checks": [c.to_dict() for c in self.checks],
                "evaluated_at": self.evaluated_at,
                "note": self.note,
            }
        )

    @classmethod
    def locked(cls, note: str = "Aucune validation effectuée.") -> "GateReport":
        return cls(sim_passed=False, paper_passed=False, live_unlocked=False, note=note)
