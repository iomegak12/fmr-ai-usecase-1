# Cross-platform Automation

Phase 0 reserves this directory. There are no executable scripts yet.

[Implementation plan Section 5.8](../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md#58-p7--makefile-and-scripts)
defines matching Bash (`.sh`) and PowerShell (`.ps1`) scripts for setup,
lint, format, test, coverage, backup, restore, clean and wait-for-ready.
Scripts must include usage guidance and fail fast on errors.

Root and per-project Makefiles will call these scripts in the automation phase.
Do not add dummy scripts or targets that report success without doing work.
