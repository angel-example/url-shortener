import 'dart:async';
import 'dart:io';
import 'package:angel_common/angel_common.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

final Validator CREATE_URL = new Validator({
  'url*': [isString, isNotEmpty, isurl]
});

Future<Angel> createServer() async {
  // Configuration
  var app = new Angel();
  await app.configure(loadConfigurationFile());
  await app.configure(mustache(new Directory('views')));

  // Services
  var db = new Db(app.mongo_db);
  await db.open();
  app.use('/api/urls', new MongoService(db.collection('urls')));

  // Plain routes
  var urlService = app.service('api/urls');

  app.get('/', (ResponseContext res) async {
    List urls = await urlService.index();
    await res
        .render('index', {'title': 'Dart URL Shortener', 'num': urls.length});
  });

  // Validation ;)
  var uuid = new Uuid();
  app.chain(validate(CREATE_URL)).post('/create',
      (RequestContext req, ResponseContext res) async {
    var result = await urlService
        .create({'url': req.body['url'], 'stub': uuid.v4().substring(0, 6)});
    await res.render('create', {'location': result['stub']});
  });

  // Check out this parameter injection, though!
  app.get('/:stub', (String stub, ResponseContext res) async {
    List<Map> urls = await urlService.index({
      'query': {'stub': stub}
    });

    if (urls.isEmpty)
      throw new AngelHttpException.notFound();
    else
      res.redirect(urls.first['url']);
  });

  // Handle errors
  var errors = new ErrorHandler(handlers: {
    400: (req, ResponseContext res) => res.render('error', {
          'message':
              'Invalid URL (Does your URL begin with \'http://\' or \'www.\'?)'
        }),
    404: (RequestContext req, ResponseContext res) =>
        res.render('error', {'message': 'No page exists at ${req.path}.'}),
    500: (req, ResponseContext res) =>
        res.render('error', {'message': 'Internal Server Error'})
  });

  app.after.addAll([errors.throwError(), errors.middleware()]);
  await app.configure(errors);

  // Static server (with Cache-Control, If-Not-Modified-Since, etc.), GZIP, etc.
  await app
      .configure(new CachingVirtualDirectory(source: new Directory('dist')));
  app.responseFinalizers.add(gzip());
  await app.configure(logRequests());

  return app;
}
