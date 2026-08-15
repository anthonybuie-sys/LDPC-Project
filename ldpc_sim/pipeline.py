"""Generic token pipeline reservations."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class PipelineToken:
    pipeline: str
    layer_id: int
    pair_id: int
    issue_cycle: int
    depth: int
    metadata: dict[str, object] = field(default_factory=dict)

    @property
    def done_cycle(self) -> int:
        return self.issue_cycle + self.depth


class TokenPipeline:
    def __init__(self, name: str, depth: int) -> None:
        self.name = name
        self.depth = depth
        self._stage_reservations: set[tuple[int, int]] = set()
        self.tokens: list[PipelineToken] = []

    def can_issue(self, cycle: int) -> bool:
        return all((cycle + stage, stage) not in self._stage_reservations for stage in range(self.depth))

    def issue(self, cycle: int, layer_id: int, pair_id: int, **metadata: object) -> PipelineToken:
        if not self.can_issue(cycle):
            raise RuntimeError(f"{self.name} pipeline stage collision at cycle {cycle}.")
        token = PipelineToken(
            pipeline=self.name,
            layer_id=layer_id,
            pair_id=pair_id,
            issue_cycle=cycle,
            depth=self.depth,
            metadata=metadata,
        )
        for stage in range(self.depth):
            self._stage_reservations.add((cycle + stage, stage))
        self.tokens.append(token)
        return token

