local _, addon = ...
addon.LocaleRegister("enUS", {
    HELP = "Commands: /gp help, /gp version, /gp diag, /gp minimap",
    MINIMAP_TITLE = "GoldPilot",
    MINIMAP_LEFT = "Left-click: help / version",
    MINIMAP_RIGHT = "Right-click: run diagnostics",
    VERSION = "GoldPilot %s",
    DIAG_SUMMARY = "Diagnostic: %d capabilities present, %d absent.",
    DIAG_MISSING = "Missing: ",
    DIAG_AUCTION = "Diagnostic: auction house opened.",
    DIAG_MAIL = "Diagnostic: mailbox opened.",
    DIAG_LOOT = "Diagnostic: loot observed.",
    DIAG_PROFS = "Diagnostic: profession window opened.",
    DIAG_AUCTION_EVENT = "Diagnostic auction event: ",
})
