import "dart:io";
import "dart:async";
import "package:url_shortener/template.dart";
import "package:vane/vane_server.dart";
import "package:mongo_dart/mongo_dart.dart";
import "package:uuid/uuid.dart";

final html = new ContentType("text", "html", charset: "utf-8");
final urlRegex = new RegExp("(https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})");
final indexT = new Template(new File("views/index.mustache"));
final createT = new Template(new File("views/create.mustache"));
final errorT = new Template(new File("views/error.mustache"));

DbCollection urls;

main() async {
  int port = 27017;
  String host = "localhost";
  String addr = "${host}:${port}";

  Db db = new Db("mongodb://${addr}/urlshortenerdb");
  await db.open();
  urls = db.collection("urls");
  serve();
  // db.close();
}

@Route("/")
index(HttpRequest request) async {
  request.response.headers.contentType = html;
  request.response.write(indexT.render({"title" : "Dart URL Shortener", "num" : await urls.count()}));
  request.response.close();
}

@Route("/create")
create(HttpRequest request) async {
  if (request.method != "POST") {
    request.response.close();
    return;
  }

  var url = new String.fromCharCodes((await request.toList())[0]);
  url = Uri.decodeComponent(url.substring(url.indexOf("=", 0) + 1));
  request.response.headers.contentType = html;

  if (url.startsWith("www."))
    url = "http://${url}";
  if (!urlRegex.hasMatch(url)) {
    request.response.write(errorT.render({"message" : "Invalid URL (Does your URL begin with 'http://' or 'www.'?)"}));
    request.response.close();
    return;
  }

  var id = _generateID(6);
  while (await mapById(id) != null)
    id = _generateID(6);
  urls.insert({"id" : id, "url" : url});

  request.response.write(createT.render({"location" : "${id}"}));
  request.response.close();
}

@Route("/{id}")
redirect(HttpRequest request, String id) async {
  if (id == "favicon.ico")
    return;
  var result = await mapById(id);
  if (result != null) {
    request.response.redirect(Uri.parse(result["url"]));
    request.response.close();
  }
}

Future<Map> mapById(String id) {
  return urls.findOne(where.eq("id", id));
}

String _generateID(int length) {
  return new Uuid().v1().substring(0, length);
}