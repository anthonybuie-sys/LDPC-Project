# Free/Open-Source Toolchain Inventory

All tools recorded here are free/open-source tooling. No Vivado, paid license,
or proprietary FPGA implementation flow was used for this validation pass.

## Repository

- Repository path: `C:\Users\18324\Verilog Project\LDPC Decoder`
- Phase-9 baseline after push: `ecb6c0a5983660dae9fc92d33039b3656727392d`

## Python

- Path: `C:\Users\18324\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
- Version: `Python 3.12.13`
- Use: numerical/test regression scripts.

## Icarus Verilog

- `iverilog` path: `C:\iverilog\bin\iverilog.exe`
- `vvp` path: `C:\iverilog\bin\vvp.exe`
- Version: `Icarus Verilog version 12.0 (devel) (s20150603-1539-g2693dd32b)`
- Runtime: `Icarus Verilog runtime version 12.0 (devel) (s20150603-1539-g2693dd32b)`
- Use: Phase 1 through Phase 9 SystemVerilog testbench regressions.

## OSS CAD Suite

- Installation source: official YosysHQ GitHub release metadata from `https://github.com/YosysHQ/oss-cad-suite-build/releases/latest`
- Release tag: `2026-08-30`
- Asset: `oss-cad-suite-windows-x64-20260830.tgz`
- Asset URL: `https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-08-30/oss-cad-suite-windows-x64-20260830.tgz`
- Archive path: `C:\Users\18324\.cache\oss-cad-suite-downloads\oss-cad-suite-windows-x64-20260830.tgz`
- Archive SHA-256: `ED8754A07C74F62B2496B49FAAE913DFDD1B66E7A3F701C4119D51F10B264A54`
- Installed path: `C:\Users\18324\.cache\oss-cad-suite-20260830`
- Suite version file: `20260830`

## Yosys

- Launch command:

```bat
call C:\Users\18324\.cache\oss-cad-suite-20260830\environment.bat && yosys -V
```

- Version: `Yosys 0.68+136 (git sha1 c30457480-dirty, Release, GNU /usr/bin/x86_64-w64-mingw32-g++ 15.2.1)`
- Use: generic synthesis/elaboration and `synth_xilinx -family xcup` technology mapping.

## Verilator

- Launch command:

```bat
call C:\Users\18324\.cache\oss-cad-suite-20260830\environment.bat && verilator_bin.exe --version
```

- Version: `Verilator 5.051 devel rev v5.050-294-gc81be029a (mod)`
- Use: static/elaboration/lint analysis.
