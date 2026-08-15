"""Initial BG1 Z=384 four-layer scheduling fixture."""

from __future__ import annotations

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import (
    load_bg1_z384_four_layer_actual,
    load_bg1_z384_four_layer_fixture,
)


DEFAULT_CONFIG = ArchitectureConfig()
DEFAULT_GRAPH = load_bg1_z384_four_layer_actual()
SYNTHETIC_GRAPH = load_bg1_z384_four_layer_fixture()
