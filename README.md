# angel_http2
Experimental - Angel served via HTTP/2. We've got CORS, GZIP, and a static file running...

It turns out that Angel itself doesn't need to be modified to run on HTTP/2.
Instead, my approach was leveraging `package:mock_request` to manufacture
`HttpRequest` instances on incoming HTTP/2 connections.

AFAIK, this should work even if you write directly to `res.io`.

To run, do the following in your terminal:

```bash
dart bin/server.dart
```

Then, visit the following pages:
* https://127.0.0.1:9090
* https://127.0.0.1:9090/protocol

I've found this to work in both Chrome and Firefox. No Edge (Edge sucks).