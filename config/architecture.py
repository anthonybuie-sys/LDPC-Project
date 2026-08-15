"""Architecture configuration for DA-2B-OMS scheduling experiments."""

from __future__ import annotations

from dataclasses import dataclass, replace


@dataclass(frozen=True)
class ArchitectureConfig:
    Z: int = 384
    P: int = 384
    B: int = 2
    num_app_banks: int = 8
    forward_cache_depth: int = 4
    D_A: int = 4
    D_R: int = 4
    num_acc_contexts: int = 2
    enable_lookahead: bool = True
    enable_forwarding: bool = True
    enable_jit_forwarding: bool = True
    enable_reconstruction_reorder: bool = True
    enable_layer_reorder: bool = True
    max_iterations: int = 6
    input_overhead: int = 0
    output_overhead: int = 0
    termination_overhead: int = 0
    app_commit_delay: int = 1
    bank_strategy: str = "optimized"
    pairing_strategy: str = "optimized"
    deterministic_seed: int = 1
    max_cycles: int = 10000
    ipctek_fixed_overhead: int = 78
    ipctek_cycles_per_iteration: int = 133

    def __post_init__(self) -> None:
        if self.P != self.Z:
            raise ValueError("The first-pass simulator assumes P equals Z.")
        if self.B != 2:
            raise ValueError("The first-pass simulator currently models B = 2.")
        if self.num_app_banks <= 0:
            raise ValueError("num_app_banks must be positive.")
        if self.forward_cache_depth < 0:
            raise ValueError("forward_cache_depth cannot be negative.")
        if self.D_A < 1 or self.D_R < 1:
            raise ValueError("Pipeline depths must be positive.")
        if self.num_acc_contexts < 1:
            raise ValueError("At least one accumulation context is required.")
        if self.bank_strategy not in {"modulo", "optimized"}:
            raise ValueError("bank_strategy must be 'modulo' or 'optimized'.")
        if self.pairing_strategy not in {"sequential", "optimized"}:
            raise ValueError("pairing_strategy must be 'sequential' or 'optimized'.")

    def with_overrides(self, **kwargs: object) -> "ArchitectureConfig":
        return replace(self, **kwargs)

    @property
    def ipctek_total_cycles(self) -> int:
        return self.ipctek_fixed_overhead + (
            self.ipctek_cycles_per_iteration * self.max_iterations
        )
