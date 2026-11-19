-- Generated from CHANGELOG.md; do not edit by hand.
local _, addon = ...

addon.ReleaseNotes = {
    version = "Unreleased",
    unreleased = true,
    notes = {
        { kind = "heading", text = "Added" },
        { kind = "bullet", text = "Added in-game update highlights and full release notes through Settings > Raid Group Manager, /rgm changelog, and the shared /changelog window; read status and automatic-notice preferences are shared across all characters" },
        { kind = "bullet", text = "Added middle-click automatic assistant choices to Guild rows, with the same crown indicators and live updates as the Roster tab" },
        { kind = "bullet", text = "Debug mode now reports each character's role and the numbered detection source, including spec changes resolved without inspection; unchanged decisions do not repeat on spec-change events or refreshes" },
        { kind = "heading", text = "Changed" },
        { kind = "bullet", text = "Reduced inspections by resolving certain roles directly from class and assigned role, with slow cached-spec refreshes after reloads and faster checks for new members, spec changes, or longer logouts" },
        { kind = "bullet", text = "Reduced repeated roster and role lookups when refreshing group slots and resolving layouts" },
        { kind = "bullet", text = "Apply advances on confirmed moves with at least 50 ms between requests, replacing the fixed delay after each roster update" },
        { kind = "bullet", text = "Apply debug output now reports each move once as Succeeded or Failed, with action details and failure reasons, instead of separate request and confirmation messages" },
        { kind = "heading", text = "Fixed" },
        { kind = "bullet", text = "Fixed group slots retaining placeholder colors when a joining member's name/class data arrives late or roster changes occur during Apply" },
        { kind = "bullet", text = "Fixed player role detection when WoW's deprecated API fallbacks are disabled" },
        { kind = "bullet", text = "Prevented role display and group splitting errors when character stats are restricted" },
        { kind = "bullet", text = "Improved role fallbacks to use imported roster information before assumptions, including role and class balancing before characters join your group" },
        { kind = "bullet", text = "Fixed Apply leaving generic role templates unfilled despite available players when the slots are unevenly distributed between two groups" },
        { kind = "bullet", text = "Apply now warns when player ordering must be skipped because no free group is available, instead of reporting that the layout already matches or was fully applied" },
        { kind = "bullet", text = "Fixed overlapping inspect requests and bypassed retry limits; offline and unavailable members no longer consume failed attempts, and Raid row icons update when inspected roles change" },
        { kind = "bullet", text = "Fixed group-slot errors for story-mode followers with no class information and prevented NPCs from entering the player spec inspection queue" },
        { kind = "bullet", text = "Fixed Apply advancing on unrelated roster updates or overlapping timers, continuing after unconfirmed moves, and reporting success without checking the final layout; impossible move plans are rejected before any group changes" },
    },
}
