# Test fixtures

Files the headless tests read (kits drawn in each app, frame strips, hostile
files). Never shipped: `.gdignore` keeps Godot from importing or exporting
this folder, and both export presets exclude `test_data/*` as well. CI checks
the player pack carries none of it (docs/custom-critters-build-plan.md, P23).
