library connexa.server;

import 'dart:io' hide Socket;
import 'package:logging/logging.dart';
import 'package:events/events.dart';
import 'package:route/server.dart';
import 'package:connexa/src/Parser.dart';
import 'package:connexa/src/Packet.dart';
import 'package:connexa/src/Socket.dart';
import 'package:uuid/uuid.dart';

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
  Map<String, Object> _settings = new Map();

  /**
   * Logger
   */
  Logger log = new Logger('connexa:server');

  /**
   * Map with all connected clients.
   */
  Map<String, Socket> clients = new Map();

  /**
   * Map with all clients's sockets.
   */
  Map<String, WebSocket> sockets = new Map();

  /**
   * Constructor.
   */
  Server(HttpServer server, Map options) {
    this._server = server;

    // setup the default settings
    _settings.addAll({
      'pingTimeout' : 60000,
      'pingInterval': 2500
    });

    // subscribe the default settings with the user options
    this._settings.addAll(options);

    // setup WebSocket
    Router router = new Router (server);

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
   * Accessor for ping timeout config
   */
  int get pingTimeout => _settings['pingTimeout'];

  /**
   * Accessor for ping interval config.
   */
  int get pingInterval => _settings['pingInterval'];

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
   * Generate a new socket id.
   */
  String _generateSocketId() {
    return (new Uuid()).v4();
  }

  /**
   * Process the packet.
   */
  void _processPacket(WebSocket socket, String encodedPacket) {
    // parse the packet
    Packet packet = Parser.decode(encodedPacket);

    // the packet contains an socket id?
    if (packet.containsKey('sid')) {
      // get the client id
      String clientId = packet['sid'];

      // the client with that id exists?
      if (!this.clients.containsKey(clientId)) {
        log.info('connect attempt for invalid id');
        socket.close();
      }
    } else {
      // create a new Socket class for the new client
      Socket client = new Socket(_generateSocketId(), this);

      // register the new client
      clients[client.id] = client;

      // save client socket instance
      this.sockets[client.id] = socket;

      // add the event to be executed on client close
      client.once('close', (_) {
        this.clients.remove(client.id);
      });

      // emit a new connection event
      this.emit('connection', client);
    }

    print("=>" + packet.type.toString() + " - " + packet.content.toString());
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


  /**
   * Send a packet to a client.
   */
  void sendToClient(String id, String encodedPacket) {
    // check if the client exists
    if (this.clients.containsKey(id)) {
      // send the packet
      this.sockets[id].add(encodedPacket);
    }
  }
}