# Ideas / Backlog

Not scheduled for implementation — parking lot for future consideration.

## Presence / "who's using what" registry (2026-08-21)

Idea: a lightweight mechanism where every user's MCCPortForwarder instance connects to a shared
server and reports which hosts/ports/datacenters/instances it's currently forwarding. This would let
teammates see who else is already tunneled into a given service/DC before they duplicate work or
collide on shared resources.

Open questions to resolve before this becomes a real proposal:
- Where would the shared server live / who owns it (new service vs. piggyback on existing MCC infra)?
- Privacy: is "user X is connected to host Y" OK to broadcast to the whole team?
- Opt-in vs. always-on reporting.
- Conflict handling: what happens when two people target the same instance/port — just visibility, or active coordination?

Not to be implemented until explicitly prioritized.
