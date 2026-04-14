## Horreum's linear pipeline makes adding new extraction types costly
Adding a new extraction method (like h5m's jq/JSONata support) would require changes across Transformer, Dataset, Label, and potentially Variable layers. h5m's polymorphic node approach requires only one new NodeEntity subclass. This was a key motivation for the rewrite but hasn't been tested with a concrete new-type addition in Horreum.
Status: unconfirmed
Confirmations: 1 (architectural analysis)
First observed: 2026-04-13
Last tested: 2026-04-13

## Change detection algorithms could be extracted into a shared library
FixedThreshold and RelativeDifference implementations are algorithmically identical between Horreum and h5m, differing only in config format and input types. A shared library parameterized on input type could eliminate divergence risk. Neither project has attempted this yet.
Status: unconfirmed
Confirmations: 1 (code comparison)
First observed: 2026-04-13
Last tested: 2026-04-13
