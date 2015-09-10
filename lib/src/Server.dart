library connexa.server;

import 'dart:io' hide Socket;
import 'package:logging/logging.dart';
import 'package:events/events.dart';
import 'package:route/server.dart';
import 'package:connexa/src/Parser.dart';
import 'package:connexa/src/Packet.dart';
import 'package:connexa/src/Socket.dart';
import 'package:uuid/uuid.dart';
import 'package:connexa/src/transports/WebSocket.dart';

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
   * Map to store some runtime data.
   */
  Map<String, Object> _stores = {'paths': ['/socket.io']};

  /**
   * Constructor.
   */
  Server(HttpServer server, Map options) {
    this._server = server;

    // setup the default settings
    _settings.addAll({
      'pingTimeout' : 60000,
      'pingInterval': 2500,
      'debug': false,
      'transports': ['websocket']
    });

    // subscribe the default settings with the user options
    this._settings.addAll(options);

    // is to enable debug?
    if (_settings['debug'] == true) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    }

    // attache the HTTPServer to Connexa server manager
    this.attach(server);

    /*
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
    });*/
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
   * Attach a HTTPServer.
   */
  void attach(HttpServer server) {
    this._server = server;
    server.listen(this._handleRequest, onError: this._onError);
  }

  /**
   * Handle a HttpServer error.
   */
  void _onError(dynamic data) {
    // TODO: handle the error
  }

  void _handleRequest(HttpRequest req) {
    log.info('handling "${req.method}" http request "${req.uri}"');


    if (!this._hasSocket(req.uri.path)) {
      return this._giveNiceReply(req);
    } else if (!this._validaProtocol(req)) {
      return this._denialRequest(req);
    }

    // TODO: handshake
  }

  /**
   * Check if the requested path has a socket.
   */
  bool _hasSocket(String path) {
    List<String> paths = this._stores['paths'];
    return paths.indexOf(path) != -1;
  }

  /**
   * Give a nice default message to the user.
   */
  void _giveNiceReply(HttpRequest req) {
    req.response.statusCode = 200;
    req.response.headers.add('Content-Type', 'text/html; charset=UTF-8');
    req.response.write(
        'Welcome to Connexa supported by <a target="_blank" href="https://designture.net">Designture</a>!');
    req.response.close();
  }

  /**
   * Error response for an invalid request.
   */
  void _denialRequest(HttpRequest req) {
    req.response.statusCode = 500;
    req.response.headers.add('Content-Type', 'text/html; charset=UTF-8');
    req.response.write('Bad Request: Not a websocket Request!');
    req.response.close();
  }

  /**
   * Check if a alid protocol.
   */
  bool _validaProtocol(HttpRequest req) {
    // get necessary data from the request
    Uri uri = req.uri;
    HttpHeaders headers = req.headers;
    String method = req.method.toLowerCase();

    // we only allow get method
    if (method != 'get') {
      return false;
    }

    // get connection values from the header
    List coon = headers[HttpHeaders.CONNECTION];
    if (coon.isEmpty) {
      return false;
    }

    // Upgrade?
    bool isUpgrade = false;
    coon.forEach((f) {
      if (f.toLowerCase() == 'upgrade') {
        isUpgrade = true;
      }
    });

    if (!isUpgrade) {
      return false;
    }

    String upgrade = headers.value(HttpHeaders.UPGRADE);
    if (upgrade.isEmpty) {
      return false;
    }
    upgrade = upgrade.toLowerCase();
    if (upgrade != 'websocket') {
      return false;
    }

    return true;
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
      this.clients[client.id] = client;

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