part of connexa.surface.client;

class Manager extends Eventus {

  Map<String, Socket> _namespaces = {};
  ClientEngine _engine;
  String _uri;
  Logger log = new Logger('connexa:manager');
  SocketStates _readyState = SocketStates.closed;
  Map _opts = {};
  DateTime _lastPing;
  bool _skipReconnect;
  List<Socket> _connected = [];
  bool _encoding = false;
  List<Packet> _packetBuffer = [];
  bool _reconnection = false;
  Decoder _decoder = new Decoder();

  /**
   * Manager` constructor.
   *
   * @param {String} engine instance or engine uri/opts
   * @param {Object} options
   */
  Manager(String this._uri, [Map opts = const {}]) {
    // set default options
    this._opts.addAll({
      'path': '/socket.io',
      'autoConnect': true
    });

    // merge the new options
    this._opts.addAll(opts);

    if (this._opts['autoConnect']) {
      this.open();
    }
  }

  bool get autoConnect => _opts['autoConnect'];

  SocketStates get readyState => this._readyState;

  /**
   * Propagate given event to sockets and emit on `this`
   */
  void emitAll(String event, [arg1, arg2, arg3]) {
    this.emit(event, arg1, arg2, arg3);
    this._namespaces.forEach((_, Socket namespace) {
      namespace.emit(event, arg1, arg2, arg3);
    });
  }

  /**
   * Update `socket.id` of all sockets
   */
  void updateSocketIds() {
    this._namespaces.forEach((_, Socket namespace) {
      namespace.id = this._engine.id;
    });
  }

  /**
   * Sets the current transport `socket`.
   *
   * @param {Function} optional, callback
   */
  void open([Function fn]) {
    log.info('readyState ${this._readyState}');
    if (this._readyState == SocketStates.open) {
      return;
    }

    log.info('opening ${this._uri}');
    this._engine = new ClientEngine(this._uri, this._opts = {});
    this._readyState = SocketStates.opening;
    this._skipReconnect = false;

    // emit `open`
    this._engine.on('open', () {
      this.onOpen();
      if (fn != null) {
        fn();
      }
    });

    // TODO: emit `connection_error`

    // TODO: emit `connect_timeout`
  }

  void onOpen() {
    log.info('open');

    // clear old subs
    this.cleanup();

    // mark as open
    this._readyState = SocketStates.open;
    this.emit('open');

    // add new subs
    this._engine.on('data', this.onData);
    this._engine.on('ping', this.onPing);
    this._engine.on('pong', this.onPong);
    this._engine.on('error', this.onError);
    this._engine.on('close', this.onClose);
    this._decoder.on('decoded', this.onDecoded);
  }

  /**
   * Called upon a ping.
   */
  void onPing() {
    this._lastPing = new DateTime.now();
    this.emitAll('ping');
  }

  /**
   * Called upon a packet.
   */
  void onPong() {
    this.emitAll('pong', new DateTime.now()
        .difference(this._lastPing)
        .inMilliseconds);
  }

  /**
   * Called with data.
   */
  void onData(String data) {
    this._decoder.add(data);
  }

  /**
   * Called when parser fully decodes a packet.
   */
  void onDecoded(Packet packet) {
    this.emit('packet', packet);
  }

  /**
   * Called upon socket error.
   */
  void onError(String err) {
    log.warning(err);
    this.emitAll('error', err);
  }

  /**
   * Creates a new socket for the given `nsp`.
   */
  Socket socket(String namespace) {
    Socket socket = this._namespaces[namespace];

    if (socket == null) {
      socket = new Socket(this, namespace);
      this._namespaces[namespace] = socket;
      socket.on('connect', () {
        socket.id = this._engine.id;
        if (!this._connected.contains(socket)) {
          this._connected.add(socket);
        }
      });
    }

    return socket;
  }

  /**
   * Called upon a socket close.
   */
  void destroy(Socket socket) {
    if (!this._connected.contains(socket)) {
      this._connected.remove(socket);
    }

    if (this._connected.isNotEmpty) {
      return;
    }

    this.close();
  }

  /**
   * Writes a packet.
   */
  void packet(Packet packet) {
    log.info('writing packet ${packet}');

    if (!this._encoding) {
      // encode, then write to engine with result
      this._encoding = true;
      Parser.encode(packet, (List<String> encodedPackets) {
        encodedPackets.forEach((String encoded) =>
            this._engine.send(encoded, packet.options));
        this._encoding = false;
        this.processPacketQueue();
      });
    } else {
      // add packet to the queue
      this._packetBuffer.add(packet);
    }
  }

  /**
   * If packet buffer is non-empty, begins encoding the
   * next packet in line.
   */
  void processPacketQueue() {
    if (this._packetBuffer.isNotEmpty && !this._encoding) {
      Packet packet = this._packetBuffer.removeAt(0);
      this.packet(packet);
    }
  }

  /**
   * Clean up transport subscriptions and packet buffer.
   */
  void cleanup() {
    log.info('cleanup');

    this._engine.removeListener('data', this.onData);
    this._engine.removeListener('ping', this.onPing);
    this._engine.removeListener('pong', this.onPong);
    this._engine.removeListener('error', this.onError);
    this._engine.removeListener('close', this.onClose);

    this._packetBuffer.clear();
    this._encoding = false;
    this._lastPing = null;

    this._decoder.destroy();
  }

  /**
   * Close the current socket.
   */
  void disconnect() => this.close();

  /**
   * Close the current socket.
   */
  void close() {
    log.info('disconnect');
    this._skipReconnect = true;
    this._reconnection = false;

    if (this._readyState == SocketStates.opening) {
      // `onclose` will not fire because
      // an open event never happened
      this.cleanup();
    }

    // TODO: backoff.reset()?
    this._readyState = SocketStates.closed;
    if (this._engine != null) {
      this._engine.close();
    }
  }

  /**
   * Called upon engine close.
   */
  void onClose(String reason) {
    log.info('onClose');

    this.cleanup();
    // TODO: backoff.reset()?
    this._readyState = SocketStates.closed;
    this.emitAll('close', reason);

    if (this._reconnection && !this._skipReconnect) {
      this._reconnect();
    }
  }

  /**
   * Attempt a reconnection.
   */
  void _reconnect() {
    // TODO
  }

  /**
   * Called upon successful reconnect.
   */
  void onReconnect() {
    // TODO
  }
}