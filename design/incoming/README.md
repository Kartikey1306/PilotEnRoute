# Incoming designs

New designs for this app land here first, as they arrive: mockups, PNG or
Figma exports, screenshots, specs from the founder or a designer. Name them
`YYYY-MM-DD-<topic>.<ext>` (`2026-11-12-onboarding-v2.png`); link a design
tool's source file in a `.md` next to the export.

They are reviewed in the app's delivery order, the queue in agl-manifest's
`docs/DELIVERY_QUEUE.md` (its "Designs incoming" column counts the files here,
this README excluded):

1. Check it against `../../SPEC.md` and `../IMPROVEMENTS.md`.
2. Accepted: move it to `../screens/` (mockups) or `../flows/` (flows) and
   build it; the commit that moves it says so.
3. Not taken: delete it, with the reason in the commit message.

An empty folder means nothing is waiting. No secrets, customer data or
unlicensed assets here: this repository is the app's source.
