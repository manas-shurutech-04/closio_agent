# SCRUM-565 — The channel dropdown become messy and add salesman button overlap channel dropdown on small resolution.

_Bug · To Do · Read on 2026-10-21_

This issue occurs when open the web page on mobile phone

![](blob:https://media.staging.atl-paas.net/?type=file&localId=3a53c3f339a8&id=b973ffa1-4d8d-41e1-a991-7e34ee702d35&&collection=&height=740&occurrenceKey=null&width=1227&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)

## Explained at pick-up

- Screenshot-only Bug card (no Context/ACs/QA); proceeding and keeping the gaps (decision 1).
- Screenshot shows, on small/mobile resolution, in the incentive scheme form "1. Channel" block: the channel dropdown collapses to a tiny width (options render one character per line, e.g. C A T E R I N G stacked) and the "+ Tipe Salesman" button overlaps the dropdown.
- Expected behavior: on small/mobile widths the dropdown keeps a usable width (options on one line) and the + Tipe Salesman button does not overlap the dropdown; the Channel row lays out responsively (decision 2).

## Decided before planning

- Fix in the shared ChannelBox.vue `<style scoped>`; covers AgeingConfigForm and SlabConfigForm (decision 5).
- `@media (max-width: 768px)` stacks `.channel-header` vertically (title, full-width dropdown, full-width + Tipe Salesman button; trash icon kept accessible); CSS only, no template/logic change (decision 6).
