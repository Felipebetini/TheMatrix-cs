# @verify — Self-Verify Skill

Run the self-verify loop after a fix has been applied.

## Process
1. Read the FIXED_WHEN criterion from the brief
2. Run the tool or check that would confirm the criterion
3. Compare actual output to expected output
4. Return PASS or FAIL with evidence

## Output
```
## Verification

**FIXED_WHEN:** [criterion]
**Check run:** [what was run]
**Actual output:** [what was observed]
**Result:** PASS / FAIL

[If FAIL: what still needs to change]
```

## Doom loop limit
After 3 FAIL iterations, stop and trigger the Hardline. Do not loop indefinitely.
