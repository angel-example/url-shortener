import "dart:io";
import "dart:async";
import "package:uuid/uuid.dart";
import "package:url_shortener/template.dart";
import "package:mongo_dart/mongo_dart.dart";
import 'package:shelf_static/shelf_static.dart';
import "package:redstone/redstone.dart";

// TODO use redstone's facilities for mongodb and templating

final urlRegex = new RegExp("(https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})");
final indexT = new Template(new File("views/index.mustache"));
final createT = new Template(new File("views/create.mustache"));
final errorT = new Template(new File("views/error.mustache"));

DbCollection urls;

Future<dynamic> main() async {
  int port = 27017;
  String host = "localhost";
  String addr = "${host}:${port}";

  Db db = new Db("mongodb://${addr}/urlshortenerdb");
  await db.open();
  urls = db.collection("urls");

  setShelfHandler(createStaticHandler("dist", serveFilesOutsidePath: true));
  setupConsoleLog();
  start(port: 9090);
}

@Route("/", responseType: "text/html")
Future<dynamic> index() async {
  return indexT.render({"title" : "Dart URL Shortener", "num" : await urls.count()});
}

@Route("/create", methods: const [POST], responseType: "text/html")
Future<dynamic> create() async {
  var url = request.body["url"];
  url = Uri.decodeComponent(url.substring(url.indexOf("=", 0) + 1));

  if (url.startsWith("www."))
    url = "http://${url}";
  if (!urlRegex.hasMatch(url))
    return errorT.render({"message" : "Invalid URL (Does your URL begin with 'http://' or 'www.'?)"});

  var id = _generateID(6);
  while (await mapById(id) != null)
    id = _generateID(6);
  urls.insert({"id" : id, "url" : url});

  return createT.render({"location" : "${id}"});
}

@Route("/:id")
Future<dynamic> redir(String id) async {
  var result = await mapById(id);
  if (result != null)
    return redirect(Uri.parse(result["url"]).toString());
}

Future<Map> mapById(String id) {
  return urls.findOne(where.eq("id", id));
}

String _generateID(int length) {
  return new Uuid().v1().substring(0, length);
}