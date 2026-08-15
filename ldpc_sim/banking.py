"""APP bank mapping strategies."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from itertools import combinations

from ldpc_sim.graph import LDPCGraph


@dataclass(frozen=True)
class BankMap:
    num_banks: int
    mapping: dict[int, int]
    strategy: str

    def bank(self, column: int) -> int:
        return self.mapping.get(column, column % self.num_banks)

    def banks(self, columns: list[int] | tuple[int, ...] | set[int]) -> tuple[int, ...]:
        return tuple(self.bank(column) for column in columns)

    def has_conflict(self, columns: list[int] | tuple[int, ...] | set[int]) -> bool:
        banks = self.banks(columns)
        return len(banks) != len(set(banks))


def modulo_bank_map(graph: LDPCGraph, num_banks: int) -> BankMap:
    return BankMap(
        num_banks=num_banks,
        mapping={column: column % num_banks for column in graph.columns},
        strategy="modulo",
    )


def weighted_conflict_graph(graph: LDPCGraph) -> dict[int, dict[int, int]]:
    weights: dict[int, dict[int, int]] = defaultdict(lambda: defaultdict(int))
    for layer in graph.layers:
        cols = sorted(layer.columns)
        for a, b in combinations(cols, 2):
            weights[a][b] += 1
            weights[b][a] += 1
        for start in range(0, len(layer.edges) - 1, 2):
            a = layer.edges[start].column
            b = layer.edges[start + 1].column
            weights[a][b] += 100
            weights[b][a] += 100
    for left, right in combinations(graph.layers, 2):
        shared = left.columns.intersection(right.columns)
        for column in shared:
            for neighbor in left.columns.union(right.columns):
                if neighbor == column:
                    continue
                weights[column][neighbor] += 1
                weights[neighbor][column] += 1
    return {col: dict(neighbors) for col, neighbors in weights.items()}


def optimized_bank_map(graph: LDPCGraph, num_banks: int) -> BankMap:
    weights = weighted_conflict_graph(graph)
    columns = sorted(
        graph.columns,
        key=lambda col: (-sum(weights.get(col, {}).values()), col),
    )
    mapping: dict[int, int] = {}
    bank_loads = [0 for _ in range(num_banks)]
    for column in columns:
        best_bank = min(
            range(num_banks),
            key=lambda bank: (
                sum(
                    weight
                    for neighbor, weight in weights.get(column, {}).items()
                    if mapping.get(neighbor) == bank
                ),
                bank_loads[bank],
                bank,
            ),
        )
        mapping[column] = best_bank
        bank_loads[best_bank] += 1
    return BankMap(num_banks=num_banks, mapping=mapping, strategy="optimized")


def build_bank_map(graph: LDPCGraph, num_banks: int, strategy: str) -> BankMap:
    if strategy == "modulo":
        return modulo_bank_map(graph, num_banks)
    if strategy == "optimized":
        return optimized_bank_map(graph, num_banks)
    raise ValueError(f"Unknown bank mapping strategy: {strategy}")
