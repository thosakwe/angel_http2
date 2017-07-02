import 'dart:async';
import 'dart:io';
import 'package:angel_common/angel_common.dart';

Future configureServer(Angel app) async {
  app.before.add(cors());

  app.get(
      '/protocol',
      (RequestContext req) =>
          'You\'re running HTTP/${ req.io.protocolVersion}.');

  app.after.add((res) => res.sendFile(new File('web/index.html')));
  app.responseFinalizers.add(gzip());
}
