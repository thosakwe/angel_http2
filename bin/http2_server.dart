import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http2/transport.dart';
import 'package:mock_request/mock_request.dart';

class Http2Server extends Stream<HttpRequest> implements HttpServer {
  final StreamController<HttpRequest> _stream =
      new StreamController<HttpRequest>();

  @override
  String serverHeader = null;

  final SecureServerSocket socket;

  Http2Server._(this.socket);

  static Future<Http2Server> bind(
      InternetAddress address, int port, SecurityContext context) {
    return SecureServerSocket
        .bind(address, port, context)
        .then(Http2Server.fromSocket);
  }

  static Future<Http2Server> fromSocket(SecureServerSocket socket) async {
    var server = new Http2Server._(socket);

    socket.listen((client) {
      var connection = new ServerTransportConnection.viaSocket(client);
      connection.incomingStreams.listen((stream) {
        MockHttpRequest rq;
        String method, path, scheme, authority;
        List<List<String>> headerQueue = [];
        List<int> buf = [];

        stream.incomingMessages.listen((msg) {
          if (msg is HeadersStreamMessage) {
            for (var header in msg.headers) {
              var name = UTF8.decode(header.name),
                  value = UTF8.decode(header.value);

              if (name == ':method') {
                method = value;
              } else if (name == ':path') {
                path = value;
              } else if (name == ':scheme') {
                scheme = value;
              } else if (name == ':authority') {
                authority = value;
              } else if (rq == null) {
                headerQueue.add([name, value]);
              } else {
                rq.headers.add(name, value);
              }

              // Maybe initialize request
              if (method != null &&
                  path != null &&
                  scheme != null &&
                  authority != null) {
                var uri = new Uri(scheme: scheme, path: path, host: authority);
                rq = new MockHttpRequest(method, uri);
                rq.protocolVersion = '2.0';
                rq.connectionInfo = new MockHttpConnectionInfo(
                    remoteAddress: client.address,
                    remotePort: client.port,
                    localPort: socket.port);

                // Add queued headers, etc.
                headerQueue.forEach((list) => rq.headers.add(list[0], list[1]));
                rq.add(buf);
              }
            }
          } else if (msg is DataStreamMessage) {
            if (rq != null) {
              rq.add(msg.bytes);
            } else
              buf.addAll(msg.bytes);
          }
        }, onDone: () {
          if (rq != null) {
            // Let's push the HTTP/2 request along...
            server._stream.add(rq..close());
          }
        });
      });
    });

    return server;
  }

  @override
  InternetAddress get address => socket.address;

  @override
  HttpConnectionsInfo connectionsInfo() {
    // TODO: Connections info
    return new HttpConnectionsInfo();
  }

  @override
  HttpHeaders get defaultResponseHeaders => new MockHttpHeaders();

  @override
  int get port => socket.port;

  @override
  StreamSubscription<HttpRequest> listen(void onData(HttpRequest event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return _stream.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future close({bool force: false}) {
    _stream.close();
    return socket.close();
  }

  @override
  bool autoCompress = true;

  // TODO: Idle timeout
  @override
  Duration idleTimeout = null;

  @override
  set sessionTimeout(int timeout) {
    // TODO: Session timeout
  }
}
