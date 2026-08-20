"""Frozen production-v1 configuration and deterministic artifact helpers."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
from typing import Any

from config.architecture import ArchitectureConfig
from ldpc_sim.fixed_point import FixedPointFormat, beta_equivalent_float


def canonical_json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def sha256_json(data: Any) -> str:
    return hashlib.sha256(canonical_json(data).encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class ProductionV1Config:
    config_name: str = "5g_nr_qc_ldpc_production_v1"
    config_version: str = "category_a_closed"
    P: int = 384
    B: int = 2
    D_A: int = 3
    D_R: int = 3
    num_app_banks: int = 8
    forward_cache_depth: int = 8
    num_acc_contexts: int = 2
    syndrome_S: int = 8
    syndrome_Q: int = 8
    w_CH: int = 6
    w_APP: int = 8
    w_q: int = 8
    w_M: int = 6
    channel_gain: float = 1.32
    ch_to_app_shift: int = 1
    beta_int: int = 1
    saturation_rule: str = "asymmetric_twos_complement"
    reference_BG: int = 1
    reference_Z: int = 384
    reference_iLS: int = 1
    reference_active_layers: tuple[int, ...] = (0, 1, 2, 3)
    reference_layer_order: tuple[int, ...] = (1, 3, 2, 0)
    reference_decoder_cycles: int = 71
    reference_syndrome_tail: int = 1
    reference_effective_boundary: int = 72
    iteration_policy: str = "non_speculative"
    channel_gain_location: str = "upstream_demapper_rate_recovery"
    decoder_core_input: str = "already_quantized_signed_CH6"
    decoder_core_app_init: str = "sat8(CH6 << 1)"

    def architecture_config(self) -> ArchitectureConfig:
        return ArchitectureConfig(
            Z=self.reference_Z,
            P=self.P,
            B=self.B,
            D_A=self.D_A,
            D_R=self.D_R,
            num_app_banks=self.num_app_banks,
            forward_cache_depth=self.forward_cache_depth,
            num_acc_contexts=self.num_acc_contexts,
            enable_lookahead=True,
            enable_forwarding=True,
            enable_jit_forwarding=True,
            enable_reconstruction_reorder=True,
            enable_layer_reorder=False,
            bank_strategy="optimized",
            pairing_strategy="optimized",
            max_cycles=20000,
        )

    def fixed_point_format(self) -> FixedPointFormat:
        return FixedPointFormat(
            "F1_PRODUCTION_V1",
            self.w_CH,
            self.w_APP,
            self.w_q,
            self.w_M,
            channel_gain=self.channel_gain,
            beta_int=self.beta_int,
            ch_to_app_shift=self.ch_to_app_shift,
        )

    def identity_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["beta_equiv"] = beta_equivalent_float(self.fixed_point_format())
        return data

    @property
    def identity_hash(self) -> str:
        return sha256_json(self.identity_dict())


PRODUCTION_V1 = ProductionV1Config()


def validate_production_architecture_config(
    config: ArchitectureConfig,
    production: ProductionV1Config = PRODUCTION_V1,
) -> None:
    """Reject historical exploration defaults and non-production settings."""

    if config == ArchitectureConfig():
        raise ValueError(
            "Production tooling requires ProductionV1Config; historical "
            "ArchitectureConfig defaults are not production authority."
        )

    expected = {
        "Z": production.reference_Z,
        "P": production.P,
        "B": production.B,
        "D_A": production.D_A,
        "D_R": production.D_R,
        "num_app_banks": production.num_app_banks,
        "forward_cache_depth": production.forward_cache_depth,
        "num_acc_contexts": production.num_acc_contexts,
        "enable_lookahead": True,
        "enable_forwarding": True,
        "enable_jit_forwarding": True,
        "enable_reconstruction_reorder": True,
        "enable_layer_reorder": False,
        "bank_strategy": "optimized",
        "pairing_strategy": "optimized",
    }
    mismatches = [
        f"{name}: expected {value!r}, got {getattr(config, name)!r}"
        for name, value in expected.items()
        if getattr(config, name) != value
    ]
    if mismatches:
        raise ValueError(
            "ArchitectureConfig is not the frozen production-v1 configuration: "
            + "; ".join(mismatches)
        )


def production_architecture_config(
    production: ProductionV1Config = PRODUCTION_V1,
) -> ArchitectureConfig:
    config = production.architecture_config()
    validate_production_architecture_config(config, production)
    return config
