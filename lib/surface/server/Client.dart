part of connexa.surface.server;

class Client {

  Server _server;
  SocketEngine _connection;
  String _id;
  HttpRequest _request;
  List<Socket> _sockets;
  Map<String, Socket> _namespaces;
  List<String> _connectBuffer = [];

  Logger log = new Logger('connexa:client');

  String get id => _id;

  Client(Server this._server, SocketEngine this._connection) {
    this._id = _connection.id;
    this._request = _connection.request;
    this._setup();
  }

  /**
   * Sets up event listeners.
   */
  void _setup() {
    // TODO: event decoded?
    this._connection.on('data', this.onData);
    this._connection.on('error', this.onError);
    this._connection.on('close', this.close);
  }

  /**
   * Connects a client to a namespace.
   */
  void connect(String name) {
    log.info('connection to namespace ${name}');

    if (this._server.namespaces.containsKey(name)) {
      this.packet(new Packet(PacketType.error, 'Invalid namespace', name));
    }

    Namespace nsp = this._server.of(name);
    if (name != '/' && !this._namespaces.containsKey('/')) {
      this._connectBuffer.add(name);
      return;
    }

    Socket socket = null;
    socket = nsp.add(this, () {
      this._sockets.add(socket);
      this._namespaces[nsp._name] = socket;

      if (nsp._name == '/' && this._connectBuffer.isNotEmpty) {
        this._connectBuffer.forEach(this.connect);
        this._connectBuffer = [];
      }
    });
  }

  /**
   * Disconnects from all namespaces and closes transport.
   */
  void disconnect() {
    Socket socket;

    // we don't use a for loop because the length of
    // `sockets` changes upon each iteration
    while (this._sockets.isNotEmpty) {
      socket = this._sockets.removeAt(0);
      socket.disconnect();
    }

    this.close();
  }

  /**
   * Removes a socket. Called by each `Socket`.
   */
  void remove(Socket socket) {
    if (this._sockets.contains(socket)) {
      this._sockets.remove(socket);
      this._namespaces.remove(socket._namespace._name);
    } else {
      log.info('ignoring remove for ${socket.id}');
    }
  }

  /**
   * Closes the underlying connection.
   */
  void close() {
    if (this._connection.readyState == SocketStates.open) {
      log.info('forcing transport close');
      this._connection.close();
      this.onClose('forced server close');
    }
  }

  /**
   * Writes a packet to the transport.
   */
  void packet(dynamic packet, [Map opts]) {
    opts = (opts != null) ? opts : {};

    // this writes to the actual connection
    void writeToEngine(List<String> encodedPackets) {
      if (opts['volatile'] == true && !this._connection.transport.writable) {
        return;
      }

      encodedPackets.forEach((String encoded) =>
          this._connection.send(encoded, {'compress': opts['compress']}));
    }

    if (this._connection.readyState == SocketStates.open) {
      log.info('writing packet ${packet}');

      if (opts.containsKey('preEncoded')) {
        // not broadcasting, need to encode
        Parser.encode(packet, (List<String> encodedPackets) {
          writeToEngine(encodedPackets);
        });
      } else {
        // a broadcast pre-encodes a packet
        writeToEngine(packet);
      }
    } else {
      log.info('ignoring packet write ${packet}');
    }
  }

  /**
   * Called with incoming transport data.
   */
  void onData(String data) {
    // TODO
  }

  /**
   * Called when parser fully decodes a packet.
   */
  void onDecoded(Packet packet) {
    if (packet.type == PacketType.connect) {
      this.connect(packet.namespace);
    } else {
      Socket socket = this._namespaces[packet.namespace];
      if (socket != null) {
        socket.onPacket(packet);
      } else {
        log.info('no socket for namespace ${packet.namespace}');
      }
    }
  }

  /**
   * Handles an error.
   */
  void onError(String err) {
    this._sockets.forEach((Socket socket) {
      socket.onError(err);
    });
    this.onClose('client error');
  }

  /**
   * Called upon transport close.
   *
   * @param {String} reason
   */
  void onClose([String reason = '']) {
    log.info('client close with reason ${reason}');

    // ignore a potential subsequent `close` event
    this.destroy();

    // `nsps` and `sockets` are cleaned up seamlessly
    Socket socket;
    while (this._sockets.isNotEmpty) {
      socket = this._sockets.removeAt(0);
      socket.onClose(reason);
    }
  }

  /**
   * Cleans up event listeners.
   */
  void destroy() {
    this._connection.removeListener('data', this.onData);
    this._connection.removeListener('error', this.onError);
    this._connection.removeListener('close', this.onClose);
    // TODO decoded
  }

}