part of connexa.surface.server;

enum NamespaceEvents {
  connect,
  connection,
  newListener
}

/**
 * Flags
 */
enum NamespaceFlags {
  json,
  volatile
}

class Namespace extends Eventus {

  /**
   * Blacklisted events.
   */
  static final List<String> _eventsBlackList = [
    'connect',
    'connection',
    'newListener'
  ];

  String _name;
  Server _server;
  List<Socket> sockets = new List();
  int ids = 0;
  List<Function> _fns = new List();
  List<String> _rooms = new List();
  Map<String, Socket> connected = new Map();
  Adapter _adapter = null;
  Map<String, Object> _flags;

  /**
   * Logger
   */
  Logger _log = new Logger('connexa:socket');

  /**
   * Namespace constructor.
   */
  Namespace(Server this._server, String this._name) {
    this.initAdapter();
  }

  Logger get log => _log;

  /**
   * Sets up namespace middleware.
   */
  void use(Function fn) {
    _fns.add(fn);
  }

  /**
   * Executes the middleware for an incoming client.
   *
   * @param {Socket} socket that will get added
   * @param {Function} last fn call in the middleware
   */
  void run(Socket socket, Function fn) {
    List fns = this._fns.toList();

    if (fns.isEmpty) {
      fn(null);
    }

    void runInner(i) {
      fns[i](socket, ([err = null]) {
        // upon error, short-circuit
        if (err != null) {
          return fn(err);
        }

        // if no middleware left, summon callback
        if (fns.length == (i + 1)) {
          return fn(null);
        }

        // go on the next
        runInner(i + 1);
      });
    }

    runInner(0);
  }

  /**
   * Adds a new client.
   *
   * @return {Socket}
   */
  Socket add(Client client, Function fn) {
    log.info('adding socket to namespace ${this._name}');
    Socket socket = new Socket(this, client);

    this.run(socket, (err) {
      Timer.run(() {
        if (client._connection.readyState == SocketStates.open) {
          if (err != null) {
            // TODO: pass the error message to the socket
            return socket.error();
          }

          // track socket
          this.sockets.add(socket);

          // it's paramount that the internal `onconnect` logic
          // fires before user-set events to prevent state order
          // violations (such as a disconnection before the connection
          // logic is complete)
          socket.onConnect();

          if (fn != null) {
            fn();
          }

          // fire user-set events
          this.emit('connect', socket);
          this.emit('connection', socket);
        } else {
          log.info('next called after client was closed - ignoring socket');
        }
      });
    });

    return socket;
  }

  /**
   * Removes a client. called by each `Socket`.
   */
  void remove(Socket socket) {
    if (this.sockets.contains(socket)) {
      this.sockets.remove(socket);
    } else {
      log.info('ignoring remove for ${socket.id}');
    }
  }

  Object _preparePacketData(arg1, arg2, arg3) {
    if (arg3 != null) {
      return [arg1, arg2, arg3];
    } else if (arg2 != null) {
      return [arg1, arg2];
    } else if (arg1 != null) {
      return arg1;
    }

    return null;
  }

  /**
   * Emits to all clients.
   */
  void emit(String event, [arg1, arg2, arg3]) {
    if (Namespace._eventsBlackList.contains(event)) {
      // TODO
      log.warning('TODO');
    } else {
      // set up a packet
      // TODO add binary support
      Packet packet = new Packet();
      packet.type = PacketType.event;
      packet.data = _preparePacketData(arg1, arg2, arg3);

      this._adapter.broadcast(packet, {
        'rooms': this._rooms,
        'flags': this._flags
      });

      this._rooms.clear();
      this._flags.clear();
    }
  }

  /**
   * Targets a room when emitting.
   *
   * @param {String} name
   */
  void to(String name) {
    if (!this._rooms.contains(name)) {
      this._rooms.add(name);
    }
  }

  /**
   * Sends a `message` event to all clients.
   */
  void send(Map data) => this.emit('message', data);

  /**
   *
   */
  void initAdapter() {
    this._adapter = new Adapter(this);
  }

  /**
   * Gets a list of clients.
   */
  void clients(Function fn) {
    this._adapter.clients(this._rooms, fn);
  }

  /**
   * Sets the compress flag.
   *
   * @param {Boolean} if `true`, compresses the sending data
   */
  void compress(bool compress) {
    this._flags = (this._flags != null) ? this._flags : new Map();
    this._flags['compress'] = compress;
  }

}