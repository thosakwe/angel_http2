import 'dart:async';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_http2/angel_http2.dart';
import 'http2_server.dart';

main() async {
  var ctx = new SecurityContext()
    ..useCertificateChain('keys/server.crt')
    ..usePrivateKey('keys/server.key');

  var app =
      new Angel.custom((address, port) => Http2Server.bind(address, port, ctx));
  var server = await app.startServer(InternetAddress.LOOPBACK_IP_V4, 3000);
  print(
      'HTTP/2 server listening at https://${server.address.address}:${server.port}');
}
