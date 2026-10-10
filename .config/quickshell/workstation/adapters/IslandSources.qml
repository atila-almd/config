pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../adapters"

// One shared scheduler owns the small amount of polling that has no native
// event source. Media and PipeWire remain event-driven in their adapters.
Item {
    id: root
    property bool observing: true
    property var audioSnapshot: audio.snapshot
    property var mediaSnapshot: media.snapshot
    property alias audioBackend: audio
    property alias mediaBackend: media
    property var performance: ({status: "unavailable", cpu: null, load: null, memory: null, cpu_samples: [], memory_samples: []})
    property var battery: ({status: "unavailable", percent: null, state: null, energy: null, capacity: null, rate: null, rate_known: false})
    property var brightness: ({status: "unavailable", percent: null, value: null, maximum: null})
    property var systemInfo: ({distro: "blendOS", compositor: "Hyprland", hostname: Quickshell.env("HOSTNAME") || "workstation", uptime_seconds: 0})
    property real phase: 0
    property real previousCpuTotal: 0
    property real previousCpuIdle: 0
    property bool sampleQueued: false
    signal batteryAttention(string title, string detail)
    signal brightnessAttention(real percent)

    Audio {
        id: audio
        observing: root.observing
    }
    Media {
        id: media
        observing: root.observing
    }

    // The shell root calls tick() from its one shared scheduler. Keeping the
    // cadence here as a method means cards never create widget-owned timers.
    function tick() {
        if (!root.observing) return;
        root.phase += Math.PI / 8;
        root.mediaBackend.tickPosition();
        root.sample();
    }

    function sample() {
        if (sampler.running) {
            root.sampleQueued = true;
            return;
        }
        root.sampleQueued = false;
        sampler.running = true;
    }

    function parseSample(text) {
        var lines = String(text || "").split(/\r?\n/);
        lines.forEach(function(line) {
            var parts = line.split("|");
            if (parts[0] === "perf" && parts.length >= 7) {
                var total = Number(parts[1]);
                var idle = Number(parts[2]);
                var memoryTotal = Number(parts[3]) * 1024;
                var memoryAvailable = Number(parts[4]) * 1024;
                var uptime = Number(parts[5]);
                var load = Number(parts[6]);
                var cpu = null;
                if (isFinite(total) && isFinite(idle) && root.previousCpuTotal > 0 && total > root.previousCpuTotal) {
                    cpu = Math.max(0, Math.min(100, (1 - (idle - root.previousCpuIdle) / (total - root.previousCpuTotal)) * 100));
                }
                root.previousCpuTotal = total;
                root.previousCpuIdle = idle;
                var oldCpu = root.performance.cpu_samples || [];
                var oldMemory = root.performance.memory_samples || [];
                if (cpu !== null) oldCpu = oldCpu.concat([cpu]).slice(-48);
                var memory = memoryTotal > 0 ? Math.max(0, Math.min(100, (1 - memoryAvailable / memoryTotal) * 100)) : null;
                if (memory !== null) oldMemory = oldMemory.concat([memory]).slice(-48);
                root.performance = {status: "ready", cpu: cpu, load: isFinite(load) ? load : null,
                    memory: memory, memory_used: memoryTotal > 0 ? memoryTotal - memoryAvailable : null,
                    memory_total: memoryTotal > 0 ? memoryTotal : null, cpu_samples: oldCpu, memory_samples: oldMemory};
                root.systemInfo = {distro: "blendOS", compositor: "Hyprland",
                    hostname: root.systemInfo.hostname, uptime_seconds: isFinite(uptime) ? uptime : 0};
            } else if (parts[0] === "brightness" && parts.length >= 3) {
                var value = Number(parts[1]);
                var maximum = Number(parts[2]);
                var percent = maximum > 0 ? Math.max(0, Math.min(100, value / maximum * 100)) : null;
                var oldPercent = root.brightness.percent;
                root.brightness = {status: percent === null ? "unavailable" : "ready", percent: percent,
                    value: value, maximum: maximum};
                if (oldPercent !== null && percent !== null && Math.abs(oldPercent - percent) >= 0.5)
                    root.brightnessAttention(percent);
            } else if (parts[0] === "brightness" && parts[1] === "none") {
                root.brightness = {status: "unavailable", percent: null, value: null, maximum: null};
            } else if (parts[0] === "battery" && parts[1] === "none") {
                root.battery = {status: "unavailable", percent: null, state: null, energy: null,
                    capacity: null, rate: null, rate_known: false};
            } else if (parts[0] === "battery" && parts.length >= 9) {
                var batteryPercent = Number(parts[1]);
                var batteryState = parts[2] || "Unknown";
                var energyNow = Number(parts[3]);
                var energyFull = Number(parts[4]);
                var powerNow = Number(parts[5]);
                var chargeNow = Number(parts[6]);
                var chargeFull = Number(parts[7]);
                var currentNow = Number(parts[8]);
                var energy = isFinite(energyNow) && energyNow >= 0 ? energyNow / 1000000 :
                    (isFinite(chargeNow) && isFinite(currentNow) ? chargeNow / 1000000 * currentNow / 1000000 : null);
                var capacity = isFinite(energyFull) && energyFull > 0 ? energyFull / 1000000 :
                    (isFinite(chargeFull) && isFinite(currentNow) ? chargeFull / 1000000 * currentNow / 1000000 : null);
                var rate = isFinite(powerNow) && powerNow > 0 ? powerNow / 1000000 : null;
                root.battery = {status: "ready", percent: isFinite(batteryPercent) ? batteryPercent : null,
                    state: batteryState, energy: energy, capacity: capacity, rate: rate, rate_known: rate !== null};
            }
        });
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            "cpu_line=$(head -n 1 /proc/stat); set -- $cpu_line; user=$2; nice=$3; system=$4; idle=$5; iowait=$6; irq=$7; softirq=$8; steal=$9; total=$((user+nice+system+idle+iowait+irq+softirq+steal)); idle_all=$((idle+iowait)); mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo); mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo); uptime=$(cut -d. -f1 /proc/uptime); load=$(cut -d' ' -f1 /proc/loadavg); printf 'perf|%s|%s|%s|%s|%s|%s\\n' \"$total\" \"$idle_all\" \"$mem_total\" \"$mem_available\" \"$uptime\" \"$load\"; brightness_dir=''; for candidate in /sys/class/backlight/*; do if [ -r \"$candidate/brightness\" ] && [ -r \"$candidate/max_brightness\" ]; then brightness_dir=$candidate; break; fi; done; if [ -n \"$brightness_dir\" ]; then printf 'brightness|%s|%s\\n' \"$(cat \"$brightness_dir/brightness\")\" \"$(cat \"$brightness_dir/max_brightness\")\"; else printf 'brightness|none\\n'; fi; battery_dir=''; for candidate in /sys/class/power_supply/BAT*; do if [ -r \"$candidate/capacity\" ] && [ -r \"$candidate/status\" ]; then battery_dir=$candidate; break; fi; done; if [ -n \"$battery_dir\" ]; then energy_now=$(cat \"$battery_dir/energy_now\" 2>/dev/null || true); energy_full=$(cat \"$battery_dir/energy_full\" 2>/dev/null || true); power_now=$(cat \"$battery_dir/power_now\" 2>/dev/null || true); charge_now=$(cat \"$battery_dir/charge_now\" 2>/dev/null || true); charge_full=$(cat \"$battery_dir/charge_full\" 2>/dev/null || true); current_now=$(cat \"$battery_dir/voltage_now\" 2>/dev/null || true); printf 'battery|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$(cat \"$battery_dir/capacity\")\" \"$(tr -d '\\n' < \"$battery_dir/status\")\" \"\${energy_now:-}\" \"\${energy_full:-}\" \"\${power_now:-}\" \"\${charge_now:-}\" \"\${charge_full:-}\" \"\${current_now:-}\"; else printf 'battery|none\\n'; fi"]
        stdout: StdioCollector { id: sampleOutput }
        stderr: SplitParser { onRead: {} }
        onRunningChanged: if (!running && root.sampleQueued)
            Qt.callLater(function() { root.sample(); })
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) root.parseSample(sampleOutput.text);
        }
        // qmllint enable signal-handler-parameters
    }

    Component.onCompleted: root.sample()
}
