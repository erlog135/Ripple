var Clay = require('@rebble/clay');
var clayConfig = require('./config');
var clay = new Clay(clayConfig, null, { autoHandleEvents: false });

var type_sequence = 1;
var type_bg_color = 2;
var type_clip_mode = 3;

var ws = null;

// Maximum bytes to put in a single PDC_DATA AppMessage.
// AppMessage payload budget is ~100-108 bytes on most firmware versions;
// using 100 keeps us safely under the limit with key/header overhead.
var CHUNK_SIZE = 100;

// Send a Uint8Array as a PDC_SIZE announcement, then PDC_DATA chunks,
// then a PDC_DONE sentinel. Each step only fires after the previous ACK,
// following the advanced communication guide's success-callback chain.
function sendPdcBytes(bytes) {
    var totalSize = bytes.length;
    var offset = 0;

    function sendNextChunk() {
        if (offset >= totalSize) {
            // All chunks ACK'd — signal completion
            Pebble.sendAppMessage({ "PDC_DONE": 1 },
                function () { console.log("PDC transfer complete (" + totalSize + " bytes)"); },
                function (e) { console.log("PDC_DONE failed: " + JSON.stringify(e)); }
            );
            return;
        }

        var end = Math.min(offset + CHUNK_SIZE, totalSize);

        // PebbleKit JS requires a plain Array for byte-array values;
        // Uint8Array (and subarray views) are NOT accepted directly.
        var chunk = Array.prototype.slice.call(bytes, offset, end);

        Pebble.sendAppMessage({ "PDC_DATA": chunk },
            function () {
                // Advance offset only after the watch ACKs this chunk.
                offset = end;
                sendNextChunk();
            },
            function (e) {
                console.log("PDC_DATA chunk failed at offset " + offset +
                            ", retrying in 500ms: " + JSON.stringify(e));
                // Retry same chunk — offset has NOT been advanced.
                setTimeout(sendNextChunk, 500);
            }
        );
    }

    // Announce total size first so C can malloc exactly the right buffer,
    // then start sending chunks on success.
    Pebble.sendAppMessage({ "PDC_SIZE": totalSize },
        function () {
            console.log("PDC_SIZE sent (" + totalSize + " bytes), beginning transfer");
            sendNextChunk();
        },
        function (e) {
            console.log("PDC_SIZE failed, retrying in 500ms: " + JSON.stringify(e));
            setTimeout(function () {
                sendPdcBytes(bytes);
            }, 500);
        }
    );
}

function handleWebSocketMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) {
        console.log("WS: ignoring non-binary message");
        return;
    }

    var buf  = new Uint8Array(event.data);
    if (buf.length < 2) {
        console.log("WS: message too short, ignoring");
        return;
    }

    var msgType = buf[0];          // type byte
    var payload = buf.subarray(1); // everything after the type byte

    console.log("WS: type=" + msgType + " payload=" + payload.length + " bytes");

    if (msgType === type_sequence) {
        sendPdcBytes(payload);
    } else if (msgType === type_bg_color) {
        var color = payload[0];
        Pebble.sendAppMessage({ "BG_COLOR": color },
            function () { console.log("BG_COLOR sent: " + color); },
            function (e) { console.log("BG_COLOR failed: " + JSON.stringify(e)); }
        );
    } else if (msgType === type_clip_mode) {
        var mode = payload[0];
        Pebble.sendAppMessage({ "CLIP_MODE": mode },
            function () { console.log("CLIP_MODE sent: " + mode); },
            function (e) { console.log("CLIP_MODE failed: " + JSON.stringify(e)); }
        );
    } else {
        console.log("WS: unknown message type " + msgType + ", ignoring");
    }
}

function connectWebSocket(url) {
    if (ws) {
        ws.close();
    }
    if (!url) return;

    console.log("Connecting to WebSocket: " + url);
    ws = new WebSocket(url);
    ws.binaryType = "arraybuffer";

    ws.onopen = function () {
        console.log("WebSocket connected to " + url);
    };

    ws.onmessage = handleWebSocketMessage;

    ws.onerror = function (error) {
        console.log("WebSocket error: " + JSON.stringify(error));
    };

    ws.onclose = function () {
        console.log("WebSocket closed");
    };
}


Pebble.addEventListener('showConfiguration', function (e) {
    Pebble.openURL(clay.generateUrl());
});

Pebble.addEventListener('webviewclosed', function (e) {
    if (e && !e.response) {
        return;
    }

    // Get the keys and values from each config item
    var dict = clay.getSettings(e.response, false);

    if (dict && dict.URL) {
        var url = dict.URL;
        if (typeof url === 'object' && url.value) {
            url = url.value;
        }
        localStorage.setItem('ws_url', url);
        connectWebSocket(url);
    }
});

Pebble.addEventListener('ready', function (e) {
    var url = localStorage.getItem('ws_url');
    if (url) {
        connectWebSocket(url);
    }
});
