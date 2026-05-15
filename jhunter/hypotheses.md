## PairDistanceCalculator distance matrix can be eliminated for Q-hat
The `distances[][]` matrix is only consumed to build `V` (column sums) and `H` (row cumulative sums). Both could be computed directly from `|series[i] - series[j]|^power` without materializing the full n×n matrix, halving peak memory per calculator instance. Unclear if the JIT already optimizes the access pattern enough to make this negligible for window sizes ≤ 50.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-30
Last tested: 2026-04-30
