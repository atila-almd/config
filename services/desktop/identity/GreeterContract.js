.pragma library

// The greeter admits only account identifiers that can be passed to greetd as
// one argv value. Authentication and account existence remain greetd/PAM's
// responsibility.
function username(value) {
    if (typeof value !== "string") throw new Error("Enter an account name.");
    if (/[\u0000\r\n\t]/.test(value)) throw new Error("Enter a valid account name.");
    var normalized = value.trim();
    if (!/^[A-Za-z_][A-Za-z0-9_-]{0,30}\$?$/.test(normalized))
        throw new Error("Enter a valid account name.");
    return normalized;
}

function handoff() {
    return ["/usr/bin/uwsm", "start", "-e", "-D", "Hyprland", "--", "workstation.desktop"];
}

function stateLabel(state) {
    var labels = {
        "ReadyToLaunch": "Ready to start Workstation",
        "Launching": "Starting Workstation…",
        "Inactive": "Login service is idle",
        "Launched": "Workstation is starting…",
        "Authenticating": "Authenticating…"
    };
    return labels[state] || "Login service is unavailable.";
}
