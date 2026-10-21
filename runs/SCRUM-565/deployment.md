# SCRUM-565 — The channel dropdown becomes messy and the "+ Tipe Salesman" button overlaps the channel dropdown on small resolution (deployment)
Card: [SCRUM-565: The channel dropdown become messy and add salesman button overlap channel dropdown on small resolution.](https://productclosio.atlassian.net/browse/SCRUM-565)

## For QA
**What it adds:** This fixes a layout bug in the incentive scheme config form. On small/mobile screen widths, the channel dropdown in the "1. Channel" block used to collapse to a tiny width (the options stacked one character per line, e.g. "C A T E R I N G" vertically) and the "+ Tipe Salesman" button overlapped the dropdown. After the fix, the Channel row lays out responsively: the dropdown keeps a usable width with its options on one line, and the "+ Tipe Salesman" button no longer overlaps it. On a normal desktop width the row still shows on a single line as before.

**Where to find it:** Manajemen Insentif › Tipe Insentif › open a schema › create or edit a configuration (ageing or slab) → the form's "1. Channel" block. To see the fix, make the browser window narrow (about phone width) or open the page on a mobile phone, then open the channel dropdown and look at the "+ Tipe Salesman" button.

**Already checked on dev (2026-10-21):** every acceptance criterion passed —
1. the channel dropdown stays usable (keeps a readable width) at a narrow width (~786px) and at phone width (~390px);
2. the "+ Tipe Salesman" button does not overlap the dropdown at the narrow width;
3. on a normal desktop width (~1280px) the Channel row stays on a single line.

## For the person deploying
**Order:** the web app only.
1. Closio web app (closio-web-v2): MR [!653](https://jcvs.japfacomfeed.co.id/closio/frontend-web/closio-web-v2/-/merge_requests/653)

### closio-web-v2
- **Database changes:** none
- **Default data:** none
- **New settings:** none
- **After deploying:** nothing — this is a display-only (CSS) change; no cache, config or data step is needed.

## Special instructions
none
