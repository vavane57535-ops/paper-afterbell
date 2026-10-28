"""Application settings, risk limits, gate criteria and cost assumptions.

This module has no dependency on the rest of the package so every other module
can import it. All dataclasses round-trip through ``to_dict`` / ``from_dict``
for JSON persistence and for the HTTP API.
"""

from __future__ import annotations

import json
import os
import tempfile
from dataclasses import asdict, dataclass, field, fields
from pathlib import Path
from typing import Any

APP_NAME = "Afterbell"


def default_data_dir() -> Path:
    """Directory holding the vault, audit log, model checkpoint and caches."""
    env = os.environ.get("AFTERBELL_DATA_DIR")
    if env:
        return Path(env).expanduser()
    return Path.home() / ".afterbell"


def _filter_kwargs(cls: type, data: dict[str, Any]) -> dict[str, Any]:
    names = {f.name for f in fields(cls)}
    return {k: v for k, v in data.items() if k in names}


@dataclass
class RiskLimits:
    """Hard limits enforced by the risk manager in simulation, paper and live modes.

    Fractions are relative to the capital allocated to the bot (never the whole
    exchange balance).
    """

    max_total_exposure: float = 0.8  # max fraction of capital invested at once
    max_position_fraction: float = 0.5  # max fraction of capital in one symbol
    max_daily_loss: float = 0.03  # loss vs start of UTC day -> flatten + pause until next day
    max_drawdown: float = 0.10  # loss vs equity high-water mark -> kill switch (manual re-arm)
    max_orders_per_hour: int = 30
    min_order_value: float = 10.0  # quote currency; smaller rebalances are skipped
    max_slippage: float = 0.003  # limit-order price protection vs best bid/ask
    min_quote_volume_24h: float = 20_000_000.0  # only trade liquid markets
    stale_data_bars: float = 2.5  # data older than this many bars -> no new orders

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "RiskLimits":
        return cls(**_filter_kwargs(cls, data or {}))

    def validate(self) -> list[str]:
        """Return human-readable (French) problems; empty list means valid."""
        problems: list[str] = []
        for name in ("max_total_exposure", "max_position_fraction"):
            v = getattr(self, name)
            if not 0.0 < v <= 1.0:
                problems.append(f"{name} doit être entre 0 et 1 (pas de levier).")
        if not 0.0 < self.max_daily_loss <= 0.2:
            problems.append("max_daily_loss doit être entre 0 et 20 %.")
        if not 0.0 < self.max_drawdown <= 0.5:
            problems.append("max_drawdown doit être entre 0 et 50 %.")
        if self.max_daily_loss > self.max_drawdown:
            problems.append("max_daily_loss ne peut pas dépasser max_drawdown.")
        if self.max_orders_per_hour < 1 or self.max_orders_per_hour > 600:
            problems.append("max_orders_per_hour doit être entre 1 et 600.")
        if self.min_order_value < 0:
            problems.append("min_order_value doit être positif.")
        if not 0.0 < self.max_slippage <= 0.05:
            problems.append("max_slippage doit être entre 0 et 5 %.")
        if self.stale_data_bars < 1:
            problems.append("stale_data_bars doit être >= 1.")
        return problems


@dataclass
class GateCriteria:
    """Conditions the model must meet before live trading can be unlocked.

    "In at least 95 % of validation scenarios the loss stays below
    ``loss_threshold``" is the honest version of "95 % safe": it is a measured,
    simulated statistic, never a guarantee about the real future.
    """

    min_validation_paths: int = 10_000
    loss_threshold: float = 0.10
    max_prob_loss_beyond: float = 0.05  # P(return < -loss_threshold) must be <= this
    min_prob_profit: float = 0.50
    min_median_return: float = 0.0
    max_stress_loss: float = 0.20  # worst median loss tolerated in any stress scenario
    max_kill_rate: float = 0.15  # share of validation paths hitting the kill switch
    min_paper_days: float = 14.0
    max_paper_drawdown: float = 0.08
    min_paper_trades: int = 5

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "GateCriteria":
        return cls(**_filter_kwargs(cls, data or {}))


@dataclass
class CostParams:
    """Trading cost assumptions (defaults close to Binance spot, regular tier)."""

    taker_fee: float = 0.001
    maker_fee: float = 0.001
    half_spread: float = 0.0002  # fraction of mid price, scaled up with volatility
    slippage_coef: float = 0.1  # impact = coef * sigma_bar * sqrt(trade_value / bar_value)
    latency_coef: float = 0.05  # adverse move = coef * sigma_bar (signal-to-fill delay)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "CostParams":
        return cls(**_filter_kwargs(cls, data or {}))


DEFAULT_FEEDS: list[tuple[str, str]] = [
    ("CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/"),
    ("Cointelegraph", "https://cointelegraph.com/rss"),
    ("Decrypt", "https://decrypt.co/feed"),
    ("Bitcoin Magazine", "https://bitcoinmagazine.com/.rss/full/"),
    ("CryptoSlate", "https://cryptoslate.com/feed/"),
    ("The Block", "https://www.theblock.co/rss.xml"),
]


@dataclass
class AppSettings:
    data_dir: Path = field(default_factory=default_data_dir)
    exchange: str = "binance"
    quote: str = "USDT"
    timeframe: str = "1h"
    symbols: list[str] = field(default_factory=lambda: ["BTC/USDT", "ETH/USDT"])
    risk: RiskLimits = field(default_factory=RiskLimits)
    gate: GateCriteria = field(default_factory=GateCriteria)
    costs: CostParams = field(default_factory=CostParams)
    news_feeds: list[tuple[str, str]] = field(default_factory=lambda: list(DEFAULT_FEEDS))
    idle_lock_minutes: int = 15
    sandbox: bool = False  # use the exchange testnet when the exchange offers one

    # ----- paths -------------------------------------------------------------
    @property
    def vault_path(self) -> Path:
        return self.data_dir / "vault.json"

    @property
    def audit_path(self) -> Path:
        return self.data_dir / "audit.jsonl"

    @property
    def model_path(self) -> Path:
        return self.data_dir / "model" / "brain.json"

    @property
    def db_path(self) -> Path:
        return self.data_dir / "market.db"

    @property
    def state_dir(self) -> Path:
        return self.data_dir / "state"

    @property
    def settings_path(self) -> Path:
        return self.data_dir / "settings.json"

    def ensure_dirs(self) -> None:
        for d in (self.data_dir, self.model_path.parent, self.state_dir):
            d.mkdir(parents=True, exist_ok=True)
            try:
                os.chmod(d, 0o700)
            except OSError:
                pass

    # ----- persistence -------------------------------------------------------
    def to_dict(self) -> dict[str, Any]:
        return {
            "exchange": self.exchange,
            "quote": self.quote,
            "timeframe": self.timeframe,
            "symbols": list(self.symbols),
            "risk": self.risk.to_dict(),
            "gate": self.gate.to_dict(),
            "costs": self.costs.to_dict(),
            "news_feeds": [list(f) for f in self.news_feeds],
            "idle_lock_minutes": self.idle_lock_minutes,
            "sandbox": self.sandbox,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any], data_dir: Path | None = None) -> "AppSettings":
        s = cls(data_dir=data_dir or default_data_dir())
        s.exchange = str(data.get("exchange", s.exchange))
        s.quote = str(data.get("quote", s.quote))
        s.timeframe = str(data.get("timeframe", s.timeframe))
        s.symbols = [str(x) for x in data.get("symbols", s.symbols)]
        s.risk = RiskLimits.from_dict(data.get("risk"))
        s.gate = GateCriteria.from_dict(data.get("gate"))
        s.costs = CostParams.from_dict(data.get("costs"))
        feeds = data.get("news_feeds")
        if feeds:
            s.news_feeds = [(str(n), str(u)) for n, u in feeds]
        s.idle_lock_minutes = int(data.get("idle_lock_minutes", s.idle_lock_minutes))
        s.sandbox = bool(data.get("sandbox", s.sandbox))
        return s

    @classmethod
    def load(cls, data_dir: Path | None = None) -> "AppSettings":
        data_dir = data_dir or default_data_dir()
        path = data_dir / "settings.json"
        if path.exists():
            with open(path, encoding="utf-8") as fh:
                return cls.from_dict(json.load(fh), data_dir=data_dir)
        return cls(data_dir=data_dir)

    def save(self) -> None:
        self.ensure_dirs()
        atomic_write_text(self.settings_path, json.dumps(self.to_dict(), indent=2, ensure_ascii=False))


def atomic_write_text(path: Path, text: str, mode: int = 0o600) -> None:
    """Write ``text`` to ``path`` atomically with restrictive permissions."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp-", suffix=path.suffix)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        try:
            os.chmod(tmp, mode)
        except OSError:
            pass
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
