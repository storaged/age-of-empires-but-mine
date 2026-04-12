# Phase 1 Smoke Notes

Run project main scene in headless mode to exercise deterministic skeleton.

Expected behavior:
- command scheduled for tick `0` executes on first simulation step
- command scheduled for tick `2` does not execute on tick `1`
- authoritative state hash is recorded after each completed tick
