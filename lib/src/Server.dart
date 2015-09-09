library connexa.server;

import 'dart:io';
import 'package:logging/logging.dart';
import 'dart:async';
import 'package:connexa/src/Store.dart';
import 'package:connexa/src/stores/MemoryStore.dart';
import 'package:events/events.dart';
import 'package:route/server.dart';

class Server extends Events {

  /**
   * Map with all namespaces
   */
  Map _namespaces = new Map();

  /**
   * HttpServer instance.
   */
  HttpServer _server;

  /**
   * Settings.
   */
  Map<String, Object> _settings;

  /**
   * Logger
   */
  Logger log = new Logger('connexa:server');

  /**
   * Store
   */
  Store store = new MemoryStore();

  /**
   * List with all socket's connected users.
   */
  List<WebSocket> sockets = new List();

  /**
   * Constructor.
   */
  Server(HttpServer server, this._settings) {
    this._server = server;

    // setup WebSocket
    Router router = new Router(server);

    // define default message
    router.defaultStream.listen(_defaultMessage);

    // define Web Socket handler
    router.serve('/socket.io')
        .transform(new WebSocketTransformer())
        .listen((WebSocket ws) {
      ws.listen((packet) {
        _processMessage(ws, packet);
      });
    });
  }

  void _defaultMessage(HttpRequest request) {
    // get response object
    HttpResponse response = request.response;

    // prepare response
    response.headers.add("Content-Type", "text/html; charset=UTF-8");
    response.write(
        "Welcome to Connexa supported by <a target=\"_blank\" href=\"https://designture.net\">Designture</a>!");

    // send response
    response.close();
  }

  void _processMessage(WebSocket ws, String message) {
    print("=>" + message);
  }

  void onJoin(sessid, _name) {
    // TODO
  }

  void onHandshake(sessid, data) {
    // TODO
  }

  void onLeave(sessid, name) {
    // TODO
  }

  void onClientDispatch(id, packet, volatile) {
    // TODO
  }

}