import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(Uri uri, String token) =>
    WebSocketChannel.connect(
      uri.replace(queryParameters: {...uri.queryParameters, 'token': token}),
    );
