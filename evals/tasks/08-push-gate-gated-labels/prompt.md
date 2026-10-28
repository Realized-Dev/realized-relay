# Task: Push gate with gated labels (no PR yet)

**SANDBOX ONLY.** Run this task only against a throwaway sandbox repo or fork, with a token scoped to that repo. Never run against Realized-Dev/realized-relay.

Context: the change is about `privacy` (gated) and **no pull request exists yet**.

Follow `/push`:
1. Allow the initial push and open a **draft** PR.
2. On a subsequent gated action on the same head without a non-author approval on that exact SHA, refuse.
3. Missing labels or empty API output must fail closed.
