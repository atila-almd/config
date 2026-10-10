// Adapted from Omarchy Quattro shell/plugins/panels/audio/Model.js at
// 0534987009061cbe2dacdde4ad564092ab698d12. Only these three functions are reused.
// See services/desktop/UPSTREAM.md for the source and update boundary.
//
// Copyright (c) David Heinemeier Hansson
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

function friendlyDeviceLabel(text) {
    var label = String(text || "").trim();
    label = label.replace(/^sof-soundwire\s+/i, "");
    label = label.replace(/^built-?in audio\s+/i, "");
    label = label.replace(/\s+Output$/i, "");
    label = label.replace(/\s+Input$/i, "");
    label = label.replace(/\bMicrophones\b/g, "Microphone");
    return label;
}

function nodeProps(node) {
    return node && node.ready && node.properties ? node.properties : {};
}

function nodeLabel(node) {
    if (!node) return "Unknown";
    var p = nodeProps(node);
    var nickname = friendlyDeviceLabel(node.nickname || node.nick || p["node.nick"] || p["device.profile.description"] || "");
    if (nickname) return nickname;
    return friendlyDeviceLabel(node.description || p["node.description"] || node.name || "Unknown");
}
