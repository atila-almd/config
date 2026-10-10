import QtQuick
import QtTest
import WorkstationShared 1.0

Item {
    width: 720
    height: 520

    TestCase {
        id: test
        name: "NotificationsHistory"
        when: windowShown
        visible: true
        property var theme: ({
            accent: "#89b4fa", selection: "#45475a", muted: "#6c7086",
            background: "#1e1e2e", background_alt: "#181825",
            surface: "#313244", surface_alt: "#45475a",
            foreground: "#cdd6f4", foreground_muted: "#a6adc8",
            red: "#f38ba8", orange: "#fab387", yellow: "#f9e2af",
            green: "#a6e3a1", cyan: "#94e2d5", blue: "#89b4fa",
            magenta: "#cba6f7"
        })
        property var notificationSnapshot: ({
            schema_version: 1,
            type: "snapshot",
            topic: "notifications",
            revision: "fixture",
            observed_at: "2026-09-13T00:00:00Z",
            status: "ready",
            error: null,
            data: {
                dnd: false,
                unread_count: 1,
                items: [
                    {id: "41", app_label: "Fixture app", summary: "Build finished",
                        body: "<b>Plain text</b>", urgency: "normal",
                        timestamp: "2026-09-13T00:00:00Z", actions: [], state: "history"},
                    {id: "42", app_label: "Fixture app", summary: "Attention",
                        body: "Needs review", urgency: "critical",
                        timestamp: "2026-09-13T00:01:00Z", actions: [], state: "history"}
                ]
            }
        })
        function test_contract_and_plain_text_history() {
            var parsed = Contract.snapshot(JSON.stringify(test.notificationSnapshot));
            compare(parsed.topic, "notifications");
            compare(parsed.data.items.length, 2);
            compare(parsed.data.items[0].body, "<b>Plain text</b>");
            Contract.controlIntent("notifications.dismiss", {id: "41"}, {
                notifications: parsed
            });
            Contract.controlIntent("notifications.clear", {}, {
                notifications: parsed
            });
            Contract.controlIntent("notifications.set_dnd", {paused: true}, {
                notifications: parsed
            });
        }

        function test_contract_rejects_unbounded_or_duplicate_history() {
            var invalid = JSON.parse(JSON.stringify(test.notificationSnapshot));
            invalid.data.items[1].id = invalid.data.items[0].id;
            var failed = false;
            try { Contract.snapshot(JSON.stringify(invalid)); } catch (error) { failed = true; }
            verify(failed);
            invalid = JSON.parse(JSON.stringify(test.notificationSnapshot));
            invalid.data.items[0].actions = [{id: "x", label: "A"}];
            Contract.snapshot(JSON.stringify(invalid));
        }
    }
}
