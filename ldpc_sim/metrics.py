"""Simulation metrics and formatting."""

from __future__ import annotations

from dataclasses import dataclass, field

STALL_CATEGORIES = (
    "STALL_RAW",
    "STALL_APP_BANK",
    "STALL_Q_BUFFER",
    "STALL_FORWARD_CAPACITY",
    "STALL_CONTEXT",
    "STALL_REC_NOT_CLOSED",
    "STALL_PIPE_RESOURCE",
    "STALL_PAIRING",
    "STALL_OTHER",
)


@dataclass
class SimulationMetrics:
    cycles_per_iteration: int
    service_lower_bound: int
    layer_order: tuple[int, ...]
    ACC_issue_cycles: int
    REC_issue_cycles: int
    active_edges: int
    B: int
    lower_bound_reference: int = 50
    lookahead_cycles_hidden: int = 0
    forwarded_APP_reads: int = 0
    normal_APP_reads: int = 0
    max_live_forward_vectors: int = 0
    max_forward_lifetime: int = 0
    min_forward_lifetime: int = 0
    avg_forward_lifetime: float = 0.0
    forward_overflow_events: int = 0
    dual_issue_cycles: int = 0
    overlap_window_cycles: int = 0
    stall_counts: dict[str, int] = field(default_factory=dict)
    input_overhead: int = 0
    output_overhead: int = 0
    termination_overhead: int = 0
    max_iterations: int = 6
    ipctek_cycles_per_iteration: int = 133
    ipctek_fixed_overhead: int = 78

    def __post_init__(self) -> None:
        for category in STALL_CATEGORIES:
            self.stall_counts.setdefault(category, 0)

    @property
    def overhead_above_lower_bound(self) -> int:
        return self.cycles_per_iteration - self.service_lower_bound

    @property
    def delta_T(self) -> int:
        return self.cycles_per_iteration - self.lower_bound_reference

    @property
    def ACC_utilization(self) -> float:
        return self.ACC_issue_cycles / self.cycles_per_iteration

    @property
    def REC_utilization(self) -> float:
        return self.REC_issue_cycles / self.cycles_per_iteration

    @property
    def B_lane_utilization(self) -> float:
        issued_slots = self.ACC_issue_cycles + self.REC_issue_cycles
        if issued_slots == 0:
            return 0.0
        used_lanes = self.active_edges * 2
        return used_lanes / (self.B * issued_slots)

    @property
    def full_iteration_overlap_utilization(self) -> float:
        return self.dual_issue_cycles / self.cycles_per_iteration

    @property
    def steady_state_overlap_utilization(self) -> float:
        if self.overlap_window_cycles == 0:
            return 0.0
        return self.dual_issue_cycles / self.overlap_window_cycles

    @property
    def bank_conflict_cycles(self) -> int:
        return self.stall_counts["STALL_APP_BANK"]

    @property
    def RAW_stall_cycles(self) -> int:
        return self.stall_counts["STALL_RAW"]

    @property
    def closure_stall_cycles(self) -> int:
        return self.stall_counts["STALL_REC_NOT_CLOSED"]

    @property
    def structural_stall_cycles(self) -> int:
        return sum(
            self.stall_counts[key]
            for key in (
                "STALL_APP_BANK",
                "STALL_Q_BUFFER",
                "STALL_FORWARD_CAPACITY",
                "STALL_CONTEXT",
                "STALL_PIPE_RESOURCE",
                "STALL_PAIRING",
            )
        )

    @property
    def total_stalls(self) -> int:
        return sum(self.stall_counts.values())

    @property
    def candidate_iteration_dependent_cycles(self) -> int:
        return self.cycles_per_iteration * self.max_iterations

    @property
    def candidate_total_cycles(self) -> int:
        return (
            self.input_overhead
            + self.candidate_iteration_dependent_cycles
            + self.termination_overhead
            + self.output_overhead
        )

    @property
    def ipctek_iteration_dependent_cycles(self) -> int:
        return self.ipctek_cycles_per_iteration * self.max_iterations

    @property
    def ipctek_total_cycles(self) -> int:
        return self.ipctek_fixed_overhead + self.ipctek_iteration_dependent_cycles

    @property
    def cycles_reduction_vs_ipctek_iter(self) -> int:
        return self.ipctek_cycles_per_iteration - self.cycles_per_iteration

    @property
    def percent_reduction_vs_ipctek_iter(self) -> float:
        return self.cycles_reduction_vs_ipctek_iter / self.ipctek_cycles_per_iteration * 100.0

    def as_dict(self) -> dict[str, object]:
        return {
            "cycles_per_iteration": self.cycles_per_iteration,
            "service_lower_bound": self.service_lower_bound,
            "overhead_above_lower_bound": self.overhead_above_lower_bound,
            "delta_T_vs_50": self.delta_T,
            "layer_order": self.layer_order,
            "ACC_issue_cycles": self.ACC_issue_cycles,
            "REC_issue_cycles": self.REC_issue_cycles,
            "ACC_utilization": self.ACC_utilization,
            "REC_utilization": self.REC_utilization,
            "B_lane_utilization": self.B_lane_utilization,
            "lookahead_cycles_hidden": self.lookahead_cycles_hidden,
            "forwarded_APP_reads": self.forwarded_APP_reads,
            "normal_APP_reads": self.normal_APP_reads,
            "max_live_forward_vectors": self.max_live_forward_vectors,
            "max_forward_lifetime": self.max_forward_lifetime,
            "min_forward_lifetime": self.min_forward_lifetime,
            "avg_forward_lifetime": self.avg_forward_lifetime,
            "forward_overflow_events": self.forward_overflow_events,
            "dual_issue_cycles": self.dual_issue_cycles,
            "overlap_window_cycles": self.overlap_window_cycles,
            "full_iteration_overlap_utilization": self.full_iteration_overlap_utilization,
            "steady_state_overlap_utilization": self.steady_state_overlap_utilization,
            "bank_conflict_cycles": self.bank_conflict_cycles,
            "RAW_stall_cycles": self.RAW_stall_cycles,
            "closure_stall_cycles": self.closure_stall_cycles,
            "structural_stall_cycles": self.structural_stall_cycles,
            "total_stalls": self.total_stalls,
            "stall_counts": dict(self.stall_counts),
            "candidate_iteration_dependent_cycles": self.candidate_iteration_dependent_cycles,
            "ipctek_iteration_dependent_cycles": self.ipctek_iteration_dependent_cycles,
            "candidate_total_cycles": self.candidate_total_cycles,
            "ipctek_total_cycles": self.ipctek_total_cycles,
            "ipctek_cycles_per_iteration": self.ipctek_cycles_per_iteration,
            "cycles_reduction_vs_ipctek_iter": self.cycles_reduction_vs_ipctek_iter,
            "percent_reduction_vs_ipctek_iter": self.percent_reduction_vs_ipctek_iter,
        }
