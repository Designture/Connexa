library connexa.server;

import 'dart:io';
import 'package:logging/logging.dart';
import 'dart:async';
import 'package:connexa/src/Store.dart';
import 'package:connexa/src/stores/MemoryStore.dart';
import 'package:connexa/src/transports/WebSocket.dart';
import 'package:connexa/src/Transport.dart';

class Server {

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
  Server(this._server, this._settings) {
    // setup WebSocket
    this._setupWebSocket();
  }

  /**
   * Setup WebSocket
   */
  void _setupWebSocket() {
    StreamController sc = new StreamController();
    sc.stream.transform(new WebSocketTransformer()).listen((WebSocket ws) {
      ws.listen((message) {
        _processMessage(ws, message);
      });
    });
  }

  void _processMessage(WebSocket ws, String message) {

  }

  /**
   * Emit an event to all connected clients.
   */
  void emit(String event) {
    // iterate all users and send the message
    sockets.forEach((socket) {
      socket.emit(event);
    });
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

}