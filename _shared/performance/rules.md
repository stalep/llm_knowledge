## Don't speculate on mechanisms without evidence
State the observation and its magnitude. If the cause is unknown, say "mechanism unknown."
Bad: "The context switch increase is caused by work-stealing contention in ForkJoinPool."
Good: "Context switches are 3x higher in FJ configs (1M vs 333K per 10s). Mechanism unknown."
Promoted from hypothesis: 2026-04-14
Confirmations: 3+

## When data doesn't support a conclusion, say so plainly
Don't hedge with "may", "suggests", "in certain scenarios" — either the data shows something or it doesn't.
Bad: "The results suggest that affinity may provide some benefit in certain scenarios."
Good: "Affinity has no measurable effect at 120K TPS. At max load, L2 misses drop 55%."
Promoted from hypothesis: 2026-04-14
Confirmations: 3+

## Don't explain things you don't know
"I don't know what this number means" is a valid and preferred answer over an invented explanation. perf stat "GHz" is cycles/task-clock, not CPU frequency. Gaps between reported and nominal frequency may have non-obvious causes (e.g., PMU counter multiplexing).
Bad: "The 2.1 GHz effective frequency indicates the CPU was throttled, possibly due to thermal limits."
Good: "perf stat reports 2.1 GHz (cycles/task-clock). Nominal is 2.3 GHz. The gap is unexplained."
Promoted from hypothesis: 2026-04-14
Confirmations: 3+

## Observations are not causal explanations
An observation (X exists) is not an explanation (Y causes X). Using "proves" shuts down investigation of alternative causes.
Bad: "The nvcswch imbalance proves that ForkJoinPool's work-stealing creates scheduling overhead."
Good: "nvcswch spread is 8.6x at max load, 1.04x at 120K. Load-dependent phenomenon. Cause not established."
Promoted from hypothesis: 2026-04-14
Confirmations: 3+

## Don't pad reports with filler
If data is trivially expected, fold it into a one-liner. Don't create full tables or sections for confirmatory results with no surprises.
Promoted from hypothesis: 2026-04-14
Confirmations: 3+

## Methodology reference docs
When doing Linux performance analysis (mpstat, perf stat, pidstat, wrk, JFR, flamegraphs), read the relevant methodology docs at `~/git/ClaudeFranzBFF/methodology/` before analyzing data:
- `linux-cpu-measurement.md` — what mpstat, perf stat, and JFR actually measure, when they agree/disagree, and known traps
- `benchmark-analysis-methodology.md` — extraction commands, derived per-request metrics, tool-specific pitfalls
- `three-agent-council.md` — three-agent council pattern for complex investigation decision points
Promoted from hypothesis: 2026-04-14
Confirmations: 3+
