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
import 'package:connexa/src/Transport.dart';

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
        print('(${rec.loggerName}) ${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    }

    // attache the HTTPServer to Connexa server manager
    this.attach(server);
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

  /**
   * Handle Http requests
   */
  void _handleRequest(HttpRequest req) {
    log.info('handling "${req.method}" http request "${req.uri}"');

    // TODO: put this validations in a separated method
    if (!this._hasSocket(req.uri.path)) {
      return this._giveNiceReply(req);
    } else if (!this._validaProtocol(req)) {
      return this._denialRequest(req);
    }

    // get query parameters
    Map query = req.uri.queryParameters;

    // check the request has already a socket Id
    if (query.containsKey('sid')) {
      log.info('setting new request for existing client');
      this.clients[query['sid']].transport.onRequest(req);
    } else {
      this.handshake(query['transport'], req);
    }
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
   * Handshakes a new client.
   */
  void handshake(String transportName, HttpRequest req) {
    // generate a new unique id for new client
    String id = this._generateSocketId();

    log.info('handshaking client "${id}"');

    // TODO: Search if we can do this in a dynamic way
    Transport transport;
    if (transportName == 'websocket') {
      transport = new WebSocketTransport(req);
    }

    // get query params
    Map query = req.uri.queryParameters;


    // client supports binary?
    transport.supportsBinary = !query.containsKey('b64');

    // create a new Socket instance
    Socket socket = new Socket(id, this, transport, req);

    // TODO: add support to cookies

    // set the request on transport
    transport.onRequest(req);

    // save client instance
    this.clients[id] = socket;

    // define action on socket close
    socket.on('close', (_) {
      this.clients.remove(id);
    });

    this.emit('connection', socket);
  }

  /**
   * Close all open clients.
   */
  Server close() {
    log.info('closing all open clients');
    this.clients.forEach((String k, Socket s) => s.close());
    return this;
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