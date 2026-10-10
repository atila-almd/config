.pragma library

// Island's motion vocabulary. QML behaviors consume these values so the
// shell has one tuning surface instead of unrelated per-card timings.
var primary = {spring: 7, damping: 0.78, mass: 1, duration: 450};
var collapse = {duration: 320};
var attentionIn = {spring: 8, damping: 0.72, mass: 0.9, duration: 380};
var attentionOut = {duration: 280};
var hover = {spring: 10, damping: 0.72, mass: 0.75, duration: 150};
var press = {spring: 12, damping: 0.72, mass: 0.8, duration: 90};
var content = {duration: 200, stagger: 30};
var rollingDigits = {duration: 220, stagger: 20};
var layout = {duration: 400};
var theme = {duration: 600};
var hoverIntentDelay = 180;
var hoverGrace = 300;
var attentionHold = 2500;

function speedValue(speed) {
    var value = Number(speed);
    return isFinite(value) && value > 0 ? value : 1;
}

function duration(base, speed, reduceMotion) {
    return reduceMotion ? 150 : Math.max(1, Math.round(Number(base) * speedValue(speed)));
}

function scaled(base, speed) {
    return Math.max(1, Math.round(Number(base) * speedValue(speed)));
}

function spring(token, speed, reduceMotion) {
    return reduceMotion ? 1000 : Number(token.spring) / speedValue(speed);
}

function damping(token, reduceMotion) {
    return reduceMotion ? 1 : Number(token.damping);
}
