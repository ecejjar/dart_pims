library dart_pims_server;

import 'dart:convert';
import 'dart:io';

import 'package:http_server/http_server.dart' as http_server;
import 'package:route/server.dart' show Router;
import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'package:sqljocky/sqljocky.dart' show ConnectionPool;
import 'package:dart_pims_server/pims_agent.dart' show PimsAgent;

part 'settings.dart';

final Logger log = new Logger('dart_pims');

PimsAgent agent = null;
ConnectionPool pool = null;

/**
 * Handle an established [WebSocket] connection.
 *
 * The WebSocket shall send commands as JSON-encoded messages,
 * which will be responded by one or more results and finally
 * a done message.
 */
void handleWebSocket ( WebSocket ws )
{
  log.info('New websocket connection');
  
  // Listen for incoming data; we expect the data to be a JSON-encoded String
  ws.map((string) => JSON.decode(string)).listen((json) {
    agent.handle(json)
      .map((json) => JSON.encode(json))
      .listen((string) => ws.add(string));
  }, onError: (error) {
    log.warning("Malformed JSON in request: $error");
  });
}

/**
 * Establishes a connection pool to the configured database engine.
 * If another pool is already established it is closed and a new one is opened.
 */
void connectDatabase ()
{
  if ( pool != null ) {
    pool.close();  
  }
  
  pool =
    new ConnectionPool(
      host: DATABASE['host'],
      port: DATABASE['port'],
      user: DATABASE['user'],
      password: DATABASE['password'],
      db: DATABASE['db'],
      max: DATABASE['poolsize']);  
}

void createAgent ()
{
  if ( pool != null ) {
    agent = new PimsAgent(pool);
  }
}

void main() {
  // Set up logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print("${rec.level.name}: ${rec.time}: ${rec.message}");
  });
  
  var buildPath = Platform.script.resolve('../build/web').toFilePath();
  if ( !new Directory(buildPath).existsSync() ) {
    log.severe("'build/' directory not found. Please run 'pub build'.");
    return;
  }
  
  // TODO: get result code or exception
  connectDatabase();
  
  try {
    createAgent();
    
    HttpServer.bind(HTTP_SERVER['host'], HTTP_SERVER['port']).then((HttpServer server) {
      log.info("PIMS server listening on http://${server.address.address}:${server.port}");
      var router = new Router(server);
  
      // The client will connect using a WebSocket. Upgrade requests to '/ws' and
      // forward them to 'handleWebSocket'.
      router.serve("/ws").transform(new WebSocketTransformer()).listen(handleWebSocket);
      
      // Set up default handler; this will serve files from our 'build' directory
      var virdir = new http_server.VirtualDirectory(buildPath);
      virdir
        ..jailRoot = false      // Disable jail root, as packages are local symlinks
        ..allowDirectoryListing = true
        ..directoryHandler = (Directory dir, HttpRequest request) {
          // Redirect directory requests to index.html files.
          var indexuri = new Uri.file(dir.path).resolve("index.html");
          virdir.serveFile(new File(indexuri.toFilePath()), request);
        };
  
      // Add an error page handler.
      virdir.errorPageHandler = (HttpRequest request) {
        log.warning("Resource not found: ${request.uri.path}");
        request.response.statusCode = HttpStatus.NOT_FOUND;
        request.response.close();
      };
      
      // Serve everything not routed elsewhere through the virtual directory.
      virdir.serve(router.defaultStream);
  
      // Special handling of client.dart. Running 'pub build' generates
      // JavaScript files but does not copy the Dart files, which are
      // needed for the Dartium browser.
      router.serve("/pims_client.dart").listen((HttpRequest request) {
        Uri clientscript = Platform.script.resolve("../web/pims_client.dart");
        virdir.serveFile(new File(clientscript.toFilePath()), request);
      });
    });
  } finally {  
    pool.close();
  }
}
