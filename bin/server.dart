import 'dart:convert';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_http2/angel_http2.dart';
import 'package:http2/transport.dart';
import 'package:http2/multiprotocol_server.dart';
import 'package:mock_request/mock_request.dart';

main() async {
  var ctx = new SecurityContext()
    ..useCertificateChain('keys/server.crt')
    ..usePrivateKey('keys/server.key');

  var app = new Angel();
  await app.configure(configureServer);
  var server = await MultiProtocolHttpServer.bind(
      InternetAddress.LOOPBACK_IP_V4, 9090, ctx);
  server.startServing(app.handleRequest, hackHttp2(app));
  print(
      'HTTP/2 server listening at https://${server.address.address}:${server.port}');
}

hackHttp2(Angel app) {
  return (ServerTransportStream stream) {
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
            var uriString = '$scheme://$authority$path';
            var uri = Uri.parse(
                uriString); //new Uri(scheme: scheme, path: path, host: authority);
            rq = new MockHttpRequest(method, uri);
            rq.protocolVersion = '2.0';
            /*rq.connectionInfo = new MockHttpConnectionInfo(
                remoteAddress: client.address,
                remotePort: client.port,
                localPort: socket.port);*/

            // Add queued headers, etc.
            headerQueue.forEach((list) => rq.headers.add(list[0], list[1]));
          }
        }
      } else if (msg is DataStreamMessage) {
        if (rq != null) {
          rq.add(msg.bytes);
        } else
          buf.addAll(msg.bytes);
      }
    }, onDone: () async {
      if (rq != null) {
        // Let's push the HTTP/2 request along...
        rq.add(buf);
        rq.close();
        await app.handleRequest(rq);

        rq.response.done.then((_) {
          // Send headers
          var headers = [
            new Header.ascii(':status', rq.response.statusCode.toString())
          ];
          rq.response.headers.forEach((k, v) {
            headers.add(new Header.ascii(k, v.join(',')));
          });
          stream.sendHeaders(headers);

          rq.response.listen((buf) {
            stream.sendData(buf);
          }, onDone: () {
            return stream.outgoingMessages.close();
          });
        });
      }
    });
  };
}
