import QtQuick
import QtTest
import "../../../services/desktop/identity/GreeterContract.js" as GreeterContract

TestCase {
    name: "GreeterContract"

    function test_valid_usernames() {
        compare(GreeterContract.username(" test-user "), "test-user");
        compare(GreeterContract.username("build-user_2"), "build-user_2");
        compare(GreeterContract.username("guest$"), "guest$");
    }

    function test_rejects_unsafe_usernames() {
        ["", "root/path", "two words", "../test-user", "test-user\n", "-bad",
         "a".repeat(33)].forEach(function(value) {
            var failed = false;
            try { GreeterContract.username(value); } catch (error) { failed = true; }
            verify(failed, "accepted invalid account: " + value);
        });
    }

    function test_uwsm_handoff_is_exact() {
        compare(GreeterContract.handoff(), [
            "/usr/bin/uwsm", "start", "-e", "-D", "Hyprland", "--", "workstation.desktop"
        ]);
    }

    function test_state_labels_are_actionable() {
        compare(GreeterContract.stateLabel("Authenticating"), "Authenticating…");
        compare(GreeterContract.stateLabel("unknown"), "Login service is unavailable.");
    }
}
