library connexa.server;

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:connexa/src/Store.dart';
import 'package:connexa/src/stores/MemoryStore.dart';
import 'package:events/events.dart';
import 'package:route/server.dart';
import 'package:connexa/src/Parser.dart';
import 'package:connexa/src/Packet.dart';

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
   * Map with all connected clients.
   */
  Map<String, Socket> clients = new Map();

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
        _processPacket(ws, packet);
      });
    });
  }

  /**
   * Default message to show on a request.
   */
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

  /**
   * Process the packet.
   */
  void _processPacket(WebSocket ws, String encodedPacket) {
    // parse the packet
    Packet packet = Parser.decode(encodedPacket);

    print("=>" + packet.type.toString() + " - " + packet.content.toString());

    this.close();
  }

  /**
   * Close all open clients.
   */
  Server close() {
    log.info('closing all open clients');
    this.clients.forEach((String k, Socket s) => s.close());
    return this;
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