import 'dart:io' hide Socket;
import 'package:connexa/server.dart';
import 'package:connexa/server_engine.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class Server {

  HttpServer _server;
  Map<String, Object> _settings = new Map();
  Map<String, Namespace> namespaces = new Map();
  Namespace _sockets;
  ServerEngine engine;
  HttpServer httpServer = null;

  /**
   * Logger
   */
  Logger log = new Logger('connexa:server');

  Server([this._server, Map options = const {}]) {
    _settings.addAll({
      'path': '/socket.io',
      'origins': '*:*',
      'debug': false
    });

    _settings.addAll(options);
    this._sockets = this.of('/');

    // is to enable debug?
    if (_settings['debug'] == true) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('(${rec.loggerName}) ${rec.level.name}: ${rec.time}: ${rec
            .message}');
      });
    }

    if (this._server != null) {
      this.attach(this._server, this._settings);
    }
  }

  Adapter get adapter => _adapter;

  Namespace get sockets => _sockets;

  /**
   * Looks up a namespace.
   */
  Namespace of(String name) {
    if (name[0] != '/') {
      name = '/' + name;
    }

    if (!this.namespaces.containsKey(name)) {
      log.info('initializing namespace ${name}');
      this.namespaces[name] = new Namespace(this, name);
    }

    return this.namespaces[name];
  }

  /**
   * Closes server connection
   */
  void close() {
    this.namespaces['/'].sockets.forEach((Socket socket) {
      socket.onClose();
    });

    this.engine.close();

    if (this.httpServer != null) {
      this.httpServer.close();
    }
  }

  /**
   * Attaches Connexa to a server or port.
   */
  Future<Null> listen(Object server, [Map opts]) =>
      attach(server, opts);

  /**
   * Attaches Connexa to a server or port.
   */
  Future<Null> attach(Object server, [Map opts]) async {
    if (opts == null) {
      opts = new Map();
    }

    int port = null;
    if (server is int) {
      log.info('creating http server and binding to ${server}');
      port = server;
      server = null;
    }

    // set engine path to '/socket.io'
    opts['path'] = this._settings['path'];

    // TODO: set origins verification

    // initialize engine
    log.info('creating engine instance with opts ${opts}');
    this.engine =
    await ConnexaEngine.listen(server: server, port: port, options: opts);

    // export http server
    this.httpServer = server;

    // bind to engine events
    this.bind(this.engine);
  }

  /**
   * Binds socket.io to an engine.io instance.
   *
   * @param {engine.Server} engine.io (or compatible) server
   * @return {Server} self
   */
  void bind(ServerEngine engine) {
    this.engine = engine;
    this.engine.on('connection', this.onConnection);
  }

  /**
   * Called with each incoming transport connection.
   *
   * @param {engine.Socket} socket
   */
  void onConnection(SocketEngine conn) {
    log.info('incoming connection with id ${conn.id}');
    Client client = new Client(this, conn);
    client.connect('/');
  }

  void on(String event, Function handler) => this.sockets.on(event, handler);

  void to(String name) => this.sockets.to(name);

  void emit(String name, [arg1, arg2, arg3]) =>
      this.sockets.emit(name, arg1, arg2, arg3);

  void send(Map data) => this.sockets.send(data);

  List<Client> get clients => this.sockets.clients;
}