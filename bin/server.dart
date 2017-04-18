import 'dart:io';
import 'package:url_shortener/url_shortener.dart';

main() async {
  var app = await createServer();
  var server = await app.startServer(InternetAddress.ANY_IP_V4, 9090);
  print(
      'URL shortener listening at http://${server.address.address}:${server.port}');
}
