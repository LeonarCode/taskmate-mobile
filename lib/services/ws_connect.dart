// Opens the backend WebSocket. Native platforms send the token in the
// Authorization header (preferred by the backend, since query strings end up in
// access logs); browsers cannot set headers on a WebSocket, so web falls back
// to the `?token=` parameter the backend also accepts.
export 'ws_connect_stub.dart'
    if (dart.library.io) 'ws_connect_io.dart'
    if (dart.library.js_interop) 'ws_connect_web.dart';
