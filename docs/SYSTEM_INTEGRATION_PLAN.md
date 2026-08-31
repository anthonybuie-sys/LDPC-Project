# System Integration Plan

This is a future-work plan for wrapping the finished decoder core in a usable
accelerator system. It does not claim that PCIe, DMA, rate matching, buffering,
or host software already exist.

## Current Boundary

Finished:

- Production decoder RTL core for BG1 Z=384 first-four-layer reference profile.
- APP load interface and core start/abort/status behavior.
- Full internal ACC/REC/storage/forwarding/syndrome/controller path.
- Functional verification through Phase 9.

Absent:

- PCIe endpoint.
- DMA engine.
- Host driver/API.
- Input/output buffering around multiple codeblocks.
- Rate matching and de-rate matching.
- Filler handling.
- CRC/segmentation/HARQ orchestration.
- Board-level clocks/resets/CDC.
- Target-device timing closure.

## Intended Accelerator Context

```text
Host
  |
PCIe
  |
DMA
  |
LLR/input buffering
  |
rate matching / filler handling
  |
decoder core
  |
decoded output buffering
  |
DMA
  |
Host
```

## Decoder-Core Interface Role

The current core accepts loaded APP/channel-derived vectors for active columns,
then starts a decode operation with `max_iterations`. It reports busy, done,
success, max-iteration, abort, error, completed iteration count, and syndrome
status. It also exposes debug signals used by regression scoreboards.

An accelerator wrapper must translate system-level buffers and codeblock
metadata into the core's frozen reference interface. It must not imply that the
core itself implements rate matching, transport, or complete receiver control.

## Input Path Future Work

LLR/input buffering must:

- Receive channel LLRs from host/DMA or upstream baseband logic.
- Apply any required rate recovery before core load.
- Handle filler/null positions according to 5G NR ownership decisions.
- Quantize or provide already-quantized CH6 values consistent with the frozen
  numerical profile.
- Load all active APP columns required by the production profile exactly once.
- Hold or stream data in the order required by the core load interface.

## Rate Matching And Filler Handling

Rate matching and filler handling are not implemented in the production core.
A future wrapper must define:

- who owns de-rate matching,
- how filler bits are represented,
- how inactive columns/layers are treated outside the frozen profile,
- how decoded bits are selected from final APP/hard decisions,
- and how invalid external profiles are rejected.

## Output Path Future Work

Decoded output buffering must:

- Capture final hard decisions or selected decoded bits.
- Preserve block status: success, max-iteration reached, abort, and errors.
- Attach iteration count and syndrome status if needed by host software.
- Package data for DMA back to the host.

The current core exposes syndrome rows and internal final-touch debug paths for
verification, but a product wrapper should define a stable output contract.

## Control And Status

A platform wrapper should define registers or descriptors for:

- start/abort,
- max iterations,
- profile ID,
- block length and rate-matching metadata,
- input/output buffer addresses,
- completion interrupt,
- error code,
- completed iterations,
- success/max-iteration status,
- and optional debug capture.

The wrapper must guard against starting a new block while the core is busy.

## Clocking And Reset

The core is treated as a synchronous RTL block. If the host, DMA, or board
fabric uses different clock domains, CDC belongs in the wrapper. Use explicit
asynchronous FIFOs, handshakes, or synchronizers and verify them separately.

Reset integration must preserve the core's IDLE-safe reset behavior and must
not rely on payload memory bulk clearing.

## Error Handling

Core fatal errors should be surfaced to host software. The wrapper must define
whether an error:

- interrupts the host,
- invalidates the current output buffer,
- requires a core reset,
- or is recoverable with a clear/reload sequence.

Do not hide core errors behind a generic timeout without preserving the actual
error code.

## Multi-Block And Throughput Scaling

The current release is a single-core, single-reference-profile decoder core.
Future system throughput may come from:

- batching host transfers,
- double-buffering input/output memory,
- multiple decoder cores,
- or overlapping host/DMA transfer with core execution.

Those are platform-level architecture choices. They do not change the frozen
71/72/73/74 internal cycle behavior unless a new architecture review is opened.

## Validation For System Integration

Future integration should add:

- host-side unit tests for descriptor programming,
- DMA loopback tests,
- end-to-end codeblock tests with known vectors,
- timeout/error injection tests,
- CDC checks,
- board reset/restart tests,
- and performance counters for transfer latency versus core latency.

## What Not To Claim Yet

Until implemented and verified, do not claim:

- PCIe bandwidth,
- DMA throughput,
- end-to-end receiver latency,
- complete 5G rate-matching support,
- board-level Fmax,
- or system power.
