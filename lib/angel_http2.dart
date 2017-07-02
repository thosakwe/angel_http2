import 'dart:async';
import 'package:angel_framework/angel_framework.dart';

Future configureServer(Angel app) async {
  app.get('/', (RequestContext req) => req.io.protocolVersion);
}
