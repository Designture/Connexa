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
      'allowRequest': false,
      'allowUpgrades': false
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
    // remove all listeners
    this.clearListeners();

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
   * Verifies a request.
   */
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
      socket.on('close', ([String reason, String description]) {
        this.clients.remove(id);
      });

      this.emit('connection', socket);
    });
  }

  /**
   * Close all clients.
   */
  Server close() {
    log.info('closing all open clients');
    this.clients.forEach((String k, Socket s) => s.close());
    return this;
  }

  /**
   * Returns a list of available transports for upgrade given a certain transport.
   */
  List upgrades(String transport) {
    if (!this._settings['allowUpgrades']) {
      return [];
    }

    // todo: go to the requested transport class check `upgradesTo` field
    return [];
  }
}