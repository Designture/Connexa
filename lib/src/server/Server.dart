library connexa.server;

import 'dart:io' hide Socket;
import 'package:logging/logging.dart';
import 'package:eventus/eventus.dart';
import 'package:connexa/src/server/Socket.dart';
import 'package:uuid/uuid.dart';
import 'package:connexa/src/server/Transport.dart';
import 'dart:convert';
import 'package:connexa/src/server/transports/WebSocket.dart';

/**
 * Protocol errors mappings.
 */
enum ProtocolErrors {
  unknown_transport,
  unknown_sid,
  bad_handshake_method,
  bad_request
}

Map<int, String> ProtocolErrorMessage = {
  0: 'Transport unknown',
  1: 'Session ID unknown',
  2: 'Bad handshake method',
  3: 'Bad request'
};

class Server extends Eventus {

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
  Map<Socket, WebSocket> sockets = new Map();

  /**
   * Map to store some runtime data.
   */
  Map<String, Object> _stores = {'paths': ['/connexa']};

  /**
   * Constructor.
   */
  Server(HttpServer server, Map options) {
    this._server = server;

    // setup the default settings
    _settings.addAll({
      'pingTimeout' : 60000,
      'pingInterval': 2500,
      'upgradeTimeout': 10000,
      'debug': false,
      'allowRequest': false
    });

    // subscribe the default settings with the user options
    this._settings.addAll(options);

    // is to enable debug?
    if (_settings['debug'] == true) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('(${rec.loggerName}) ${rec.level.name}: ${rec.time}: ${rec
            .message}');
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

  int get upgradeTimeout => _settings['upgradeTimeout'];

  /**
   * fixme: hard coded
   */
  List get transports => ['websocket'];

  /**
   * Attach a HTTPServer.
   */
  void attach(HttpServer server) {
    // TODO: remove all listeners

    // save the HttpServer instance
    this._server = server;

    // start to listen the HttpRequests
    server.listen(this._handleRequest, onError: this._onError);
  }

  /**
   * Handle a HttpServer error.
   */
  void _onError(dynamic data) {
    // TODO: handle the error
  }

  /**
   * Get query map from the HttpRequest.
   */
  Map _queryFromRequest(HttpRequest req) {
    return req.uri.queryParameters;
  }

  /**
   * Handle Http requests
   */
  void _handleRequest(HttpRequest req) {
    log.info('handling "${req.method}" http request "${req.uri}"');

    // get query parameters
    Map query = _queryFromRequest(req);

    // validate the request
    this._verify(req, false, (ProtocolErrors err, bool success) {
      if (!success) {
        return this._sendErrorMessage(req, err);
      }

      // check if the request has already a socket Id
      if (query.containsKey('sid')) {
        log.info('settings new request for existing client');
        this.clients[query['sid']].transport.onRequest(req);
      } else {
        this.handshake(query['transport'], req);
      }
    });
  }

  /**
   * Check if the requested path has a socket.
   */
  bool _hasSocket(String path) {
    List<String> paths = this._stores['paths'];
    return paths.indexOf(path) != -1;
  }

  /**
   * Sends an Connexa Error Message
   */
  void _sendErrorMessage(HttpRequest req, ProtocolErrors code) {
    Map headers = { 'Content-Type': 'application/json'};

    if (req.headers.value('origin') != null) {
      headers['Access-Control-Allow-Credentials'] = 'true';
      headers['Access-Control-Allow-Origin'] = req.headers.value('origin');
    } else {
      headers['Access-Control-Allow-Origin'] = '*';
    }

    req.response.statusCode = 400;
    headers.forEach((k, v) {
      req.response.headers.add(k, v);
    });
    req.response.write(JSON.encode({
      'code': code.index,
      'message': ProtocolErrorMessage[code.index]
    }));
    req.response.close();
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

  void _verify(HttpRequest req, bool upgrade, Function fn) {
    // get the query parameters
    Map query = req.uri.queryParameters;

    // transport check
    if (query['transport'] != 'websocket') {
      log.warning('unknown transport "${query['transport']}"');
      return fn(ProtocolErrors.unknown_transport, false);
    }

    // sid check
    if (query.containsKey('sid')) {
      var sid = query['sid'];

      if (!this.clients.containsKey(sid)) {
        return fn(ProtocolErrors.unknown_sid, false);
      } else if (!upgrade &&
          this.clients[sid].transport.name != query['transprot']) {
        log.info('bad request: unexpected transport without upgrade');
        return fn(ProtocolErrors.bad_request, false);
      }
    } else {
      // handshake is GET only
      if (req.method.toLowerCase() != 'get') {
        fn(ProtocolErrors.bad_handshake_method, false);
      }
      if (!this._settings['allowRequest']) {
        return fn(null, true);
      } else if (this._settings['allowRequest'] == Function) {
        Function func = this._settings['allowRequest'];
        func(req, fn);
      }
    }

    fn(null, true);
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

    Transport transport;
    if (transportName == 'websocket') {
      transport = new WebSocketTransport(req);
    } else {
      log.warning(
          'client is requesting a none supported transport "${transportName}"');
    }

    // only end the configuration when the transport are open
    transport.once('open', () {
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
      socket.on('close', () {
        this.clients.remove(id);
      });

      this.emit('connection', socket);
    });
  }

  /**
   * Close all open clients.
   */
  Server close() {
    log.info('closing all open clients');
    this.clients.forEach((String k, Socket s) => s.close());
    return this;
  }

  List upgrades(String name) {
    return [];
  }
}