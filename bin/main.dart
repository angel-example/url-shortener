import "dart:io";
import "dart:async";
import "package:url_shortener/template.dart";
import "package:vane/vane_server.dart";
import "package:mongo_dart/mongo_dart.dart";
import "package:uuid/uuid.dart";

final html = new ContentType("text", "html", charset: "utf-8");
DbCollection urls;

main() async {
  int port = 27017;
  String host = "localhost";
  String addr = "${host}:${port}";

  Db db = new Db("mongodb://${addr}/urlshortenerdb");
  await db.open();
  urls = db.collection("urls");
  serve();
  // TODO await db.close();
}

@Route("/")
void index(HttpRequest request) {
  var index = new Template(new File("views/index.mustache"));
  request.response.headers.contentType = html;
  request.response.write(index.render({}));
  request.response.close();
}

@Route("/create")
create(HttpRequest request) async {
  var create = new Template(new File("views/create.mustache"));
  var url = request.uri.queryParameters["url"];
  // TODO have a regex checking if it's a valid URL
  if (!url.startsWith("http://"))
    url = "http://${url}/";
  if (url != null) {
    var id = _generateID(6);
    while (await mapById(id) != null)
      id = _generateID(6);
    urls.insert({"id" : id, "url" : url});

    request.response.headers.contentType = html;
    request.response.write(create.render({"location" : "${id}"}));
    request.response.close();
  }
}

@Route("/{id}")
redirect(HttpRequest request, String id) async {
  if (id == "favicon.ico")
    return;
  var result = await mapById(id);
  if (result != null)
    request.response.redirect(Uri.parse(result["url"]));
}

Future<Map> mapById(String id) {
  return urls.findOne(where.eq("id", id));
}

String _generateID(int length) {
  return new Uuid().v1().substring(0, length);
}