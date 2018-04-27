/// Declares the Jaguar `Context` class
library jaguar.src.http.context;

import 'dart:async';

import 'dart:io';
import 'package:jaguar/jaguar.dart';
import 'package:logging/logging.dart';
import 'dart:convert' as conv;

import 'package:mime/mime.dart';
import 'package:http_server/http_server.dart';

typedef FutureOr<void> ExceptionHandler<ET>(
    Context ctx, ET exception, StackTrace trace);

/// Prototype of route handler that returns [Response]
typedef FutureOr<void> RouteFunc(Context ctx);

/// Function type for a route handler
typedef FutureOr<RespType> RouteHandler<RespType>(Context ctx);

/// Per-request context object
///
/// Contains:
/// 1. Request object
/// 2. Path parameters
/// 3. Query parameters
/// 4. Route inputs
/// 5. Route variables
/// 6. Interceptors
/// 7. Session object
class Context {
  /// Uri of the HTTP request
  Uri get uri => req.uri;

  /// Path of the HTTP request
  String get path => uri.path;

  /// Path segments of the HTTP request
  List<String> get pathSegments => uri.pathSegments;

  /// Method of the HTTP request
  String get method => req.method;

  /// [Request] object of the current HTTP request.
  ///
  /// Example:
  ///
  ///     final server = new Jaguar();
  ///     server.post('/api/book', (Context ctx) async {
  ///       // Decode request body as JSON Map
  ///       final List json = await ctx.req.bodyAsJsonList();
  ///       // ...
  ///     });
  ///     await server.serve();
  final Request req;

  /// Path parameters
  ///
  /// Example:
  ///
  ///     server.get('/api/quote/:index', (ctx) { // The magic!
  ///       final int index = ctx.pathParams.getInt('index', 1);  // The magic!
  ///       return quotes[index + 1];
  ///     });
  final PathParams pathParams = new PathParams();

  QueryParams _query;

  /// Returns query parameters of the request
  ///
  /// Lazily creates query parameters to enhance performance of route handling.
  ///
  /// Example:
  ///
  ///     server.get('/api/quote', (ctx) {
  ///       final int index = ctx.query.getInt('index', 1); // The magic!
  ///       return quotes[index + 1];
  ///     });
  QueryParams get query {
    if (_query != null) return _query;

    _query = new QueryParams(req.uri.queryParameters);
    return _query;
  }

  final SessionManager _sessionManager;

  Session _session;

  /// Does the session need update?
  bool get sessionNeedsUpdate => _session != null && _session.needsUpdate;

  /// Parsed session. Returns null, if the session is not parsed yet.
  Session get parsedSession => _session;

  /// The session for the given request.
  ///
  /// Example:
  ///
  ///     server.get('/api/set/:item', (ctx) async {
  ///       final Session session = await ctx.req.session;
  ///       session['item'] = ctx.pathParams.item;
  ///       // ...
  ///     });
  Future<Session> get session async {
    if (_session == null) {
      _session = await _sessionManager.parse(this);
    }
    return this._session;
  }

  final Logger log;

  final List<String> debugMsgs = <String>[];

  Context(this.req, this._sessionManager, this.log,
      {this.beforeGlobal, this.afterGlobal});

  final _variables = <Type, Map<String, dynamic>>{};

  /// Gets variable by type and id
  T getVariable<T>({String id}) {
    Map<String, dynamic> map = _variables[T];
    if (map != null) {
      if (id == null)
        return map.values.first;
      else {
        if (map.containsKey(id)) return map[id];
      }
    }

    if (id == null) {
      for (map in _variables.values) {
        for (dynamic v in map.values) {
          if (v is T) return v;
        }
      }
    } else {
      for (map in _variables.values) {
        if (map[id] is T) return map[id];
      }
    }

    return null;
  }

  /// Adds variable by type and id
  void addVariable<T>(T value, {String id}) {
    if (!_variables.containsKey(value.runtimeType)) {
      _variables[value.runtimeType] = {id: value};
    } else {
      _variables[value.runtimeType][id] = value;
    }
  }

  /// Private cache for request body
  List<int> _body;

  Future<List<int>> get body async => _body ??= await req.body;

  /// Returns the body of HTTP request
  Future<Stream<List<int>>> get bodyAsStream async {
    final List<int> bodyRaw = await body;
    return new Stream<List<int>>.fromIterable(<List<int>>[bodyRaw]);
  }

  /// Returns body as text
  ///
  /// Example:
  ///     final server = new Jaguar();
  ///     server.post('/api/book', (Context ctx) async {
  ///       // Decode request body as JSON Map
  ///       final String body = await ctx.req.bodyAsText();
  ///       // ...
  ///     });
  ///     await server.serve();
  Future<String> bodyAsText([conv.Encoding encoding = conv.utf8]) async {
    return encoding.decode(await body);
  }

  /// Decodes JSON body of the request
  ///
  /// Example:
  ///     final server = new Jaguar();
  ///     server.post('/api/book', (Context ctx) async {
  ///       // Decode request body as JSON Map
  ///       final json = await ctx.req.bodyAsJson();
  ///       // ...
  ///     });
  ///     await server.serve();
  Future<T> bodyAsJson<T, F>(
      {conv.Encoding encoding: conv.utf8, T convert(F d)}) async {
    final String text = await bodyAsText(encoding);
    if (convert == null) return conv.json.decode(text);
    return convert(conv.json.decode(text));
  }

  /// Decodes JSON body of the request as [Map]
  ///
  /// Example:
  ///     final server = new Jaguar();
  ///     server.post('/api/book', (Context ctx) async {
  ///       // Decode request body as JSON Map
  ///       final Map<String, dynamic> json = await ctx.req.bodyAsJsonMap();
  ///       // ...
  ///     });
  ///     await server.serve();
  Future<Map> bodyAsJsonMap({conv.Encoding encoding: conv.utf8}) async {
    final String text = await bodyAsText(encoding);
    final ret = conv.json.decode(text);
    return ret;
  }

  /// Decodes JSON body of the request as [List]
  ///
  /// Example:
  ///     final server = new Jaguar();
  ///     server.post('/api/book', (Context ctx) async {
  ///       // Decode request body as JSON Map
  ///       final List json = await ctx.req.bodyAsJsonList();
  ///       // ...
  ///     });
  ///     await server.serve();
  Future<List<T>> bodyAsJsonList<T, F>(
      {conv.Encoding encoding: conv.utf8, T convert(F d)}) async {
    final String text = await bodyAsText(encoding);
    final ret = conv.json.decode(text);
    if (convert != null) return (ret as List).cast<F>().map(convert).toList();
    return ret;
  }

  /// Decodes url-encoded form from the body and returns the form as
  /// Map<String, String>.
  ///
  /// Example:
  ///     final server = new Jaguar();
  ///     server.post('/add', (ctx) async {
  ///       final Map<String, String> map = await ctx.req.bodyAsUrlEncodedForm();
  ///       // ...
  ///     });
  ///     await server.serve();
  Future<Map<String, String>> bodyAsUrlEncodedForm(
      {conv.Encoding encoding: conv.utf8}) async {
    final String text = await bodyAsText(encoding);
    return text
        .split("&")
        .map((String part) => part.split("="))
        .map((List<String> part) => <String, String>{part.first: part.last})
        .reduce((Map<String, String> value, Map<String, String> element) =>
            value..putIfAbsent(element.keys.first, () => element.values.first));
  }

  /// Decodes `multipart/form-data` body
  ///
  /// Example:
  ///     server.post('/upload', (ctx) async {
  ///       final Map<String, FormField> formData = await ctx.req.bodyAsFormData();
  ///       BinaryFileFormField pic = formData['pic'];
  ///       File file = new File('bin/data/' + pic.filename);
  ///       IOSink sink = file.openWrite();
  ///       await sink.addStream(pic.value);
  ///       await sink.close();
  ///       return Response.redirect(Uri.parse("/"));
  ///     });
  Future<Map<String, FormField>> bodyAsFormData(
      {conv.Encoding encoding: conv.utf8}) async {
    if (!req.headers.contentType.parameters.containsKey('boundary')) {
      return null;
    }

    final String boundary = req.headers.contentType.parameters['boundary'];

    final Map<String, FormField> ret = {};

    final Stream<List<int>> bodyStream = await bodyAsStream;

    // Transform body to [MimeMultipart]
    final transformer = new MimeMultipartTransformer(boundary);
    final Stream<MimeMultipart> stream = bodyStream.transform(transformer);

    await for (MimeMultipart part in stream) {
      HttpMultipartFormData multipart = HttpMultipartFormData.parse(part);

      // Parse field content type
      final ContentType contentType = multipart.contentType;

      final String name = multipart.contentDisposition.parameters['name'];

      final String fn = multipart.contentDisposition.parameters['filename'];

      // Create field
      if (fn is! String && multipart.isText) {
        final String data = await multipart.join();
        final field = new StringFormField(name, data, contentType: contentType);
        ret[field.name] = field;
      } else if (multipart.isText) {
        final field = new TextFileFormField(name, multipart as Stream<String>,
            contentType: contentType, filename: fn);
        ret[field.name] = field;
      } else {
        final field = new BinaryFileFormField(
            name, multipart as Stream<List<int>>,
            contentType: contentType, filename: fn);
        ret[field.name] = field;
      }
    }

    return ret;
  }

  Response response;

  final List<ExceptionHandler> onException = <ExceptionHandler>[];

  final List<RouteFunc> beforeGlobal;

  final List<RouteFunc> afterGlobal;

  final before = <RouteFunc>[];

  final after = <RouteFunc>[];
}