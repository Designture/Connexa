part of connexa.surface.client;

class Socket extends Eventus {

  /**
   * Internal events (blacklist).
   * These events can't be emitted by the user.
   */
  static final _events = [
    'connect',
    'connect_error',
    'connect_timeout',
    'disconnect',
    'error',
    'reconnect',
    'reconnect_attempt',
    'reconnect_failed',
    'reconnect_error',
    'reconnecting',
    'ping',
    'pong'
  ];

  Manager _io;
  String _namespace;
  int _ids = 0;
  Map<int, Function> _acks = {};
  List<Packet> _receiveBuffer = [];
  List<Packet> _sendBuffer = [];
  bool _connected = false;
  bool disconnected = true;
  Map<String, bool> _flags = {};
  String id;
  bool subs = false;
  Logger log = new Logger('connexa:socket');

  /**
   * Constructor.
   */
  Socket(Manager this._io, String this._namespace) {
    if (this._io.autoConnect) {
      this.open();
    }
  }

  /**
   * Subscribe to open, close and packet events
   */
  void _subEvents() {
    if (subs) {
      return;
    }

    this._io.on('open', this.onOpen);
    this._io.on('packet', this.onPacket);
    this._io.on('close', this.onClose);

    subs = true;
  }

  /**
   * "Opens" the socket.
   */
  void open() {
    if (this._connected) {
      return;
    }

    this._subEvents();
    this._io.open(); // ensure open
    if (this._io.readyState == SocketStates.open) {
      this.onOpen();
    }
  }

  /**
   * Sends a `message` event.
   */
  void send(arg1, [arg2, arg3]) => this.emit('message', arg1, arg2, arg2);

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
   * Override `emit`.
   * If the event is in `events`, it's emitted normally.
   *
   * @param {String} event name
   */
  void emit(String event, [arg1, arg2, arg3]) {
    if (Socket._events.contains(event)) {
      super.emit(event, arg1, arg2, arg3);
      return;
    }

    // TODO: add binary support
    // TODO: add compress support

    Packet packet = new Packet(PacketType.event);
    packet.data = _preparePacketData(arg1, arg2, arg3);

    // event ack callback
    if (arg3 is Function) {
      log.info('emitting packet with ack id ${this._ids}');
      this._acks[this._ids] = arg3;
      packet.id = this._ids++;
    }

    if (this._connected) {
      this.packet(packet);
    } else {
      this._sendBuffer.add(packet);
    }

    this._flags.clear();
  }

  /**
   * Sends a packet.
   */
  void packet(Packet packet) {
    packet.namespace = this._namespace;
    this._io.packet(packet);
  }

  /**
   * Called upon engine `open`.
   */
  void onOpen() {
    log.info('transport is open - connecting');

    // write connect packet if necessary
    if (this._namespace != '/') {
      Packet packet = new Packet(PacketType.connect);
      packet.options = {'compress': true};
      this.packet(packet);
    }
  }

  /**
   * Called upon engine `close`.
   *
   * @param {String} reason
   */
  void onClose([String reason = '']) {
    log.info('close (${reason})');
    this._connected = false;
    this.disconnected = true;
    this.id = null;
    this.emit('disconnect', reason);
  }

  /**
   * Called with socket packet.
   *
   * @param {Object} packet
   */
  void onPacket(Packet packet) {
    if (packet.namespace != this._namespace) {
      return;
    }

    switch (packet.type) {
      case PacketType.connect:
        this.onConnect();
        break;

      case PacketType.event:
      case PacketType.binary_event:
        this.onEvent(packet);
        break;


      case PacketType.ack:
      case PacketType.binary_ack:
        this.onAck(packet);
        break;

      case PacketType.disconnect:
        this.onDisconnect();
        break;

      case PacketType.error:
        this.emit('error', packet.data);
        break;

      default:
    }
  }

  /**
   * Called upon a server event.
   *
   * @param {Object} packet
   */
  void onEvent(Packet packet) {
    log.info('emitting event ${packet.data}');

    List<Object> data = packet.data;

    var arg3 = null;

    if (packet.id != null) {
      log.info('attaching ack callback to event');
      arg3 = this.ack(packet.id);
    }

    if (this._connected) {
      this.emit(data[0], data[1], null, arg3);
    } else {
      this._receiveBuffer.addAll(data);
    }
  }

  /**
   * Produces an ack callback to emit with an event.
   */
  Function ack() {
    bool sent = false;

    return ([Map data]) {
      // prevent double callbacks
      if (sent) {
        return;
      }

      sent = true;
      // TODO: add support to binary
      log.info('sending ack ${data}');
      Packet packet = new Packet(PacketType.ack, data);
      packet.id = id;
      packet.options = {'compress': true};
      this.packet(packet);
    };
  }

  /**
   * Called upon a server acknowlegement.
   *
   * @param {Object} packet
   */
  void onAck(Packet packet) {
    Function ack = this._acks[packet.id];

    if (ack is Function) {
      log.info('calling ack ${packet.id} with ${packet.data}');
      ack(packet.data);
      this._acks.remove(packet.id);
    } else {
      log.info('bad ack ${packet.id}');
    }
  }

  /**
   * Emit buffered events (received and emitted).
   */
  void onConnect() {
    this._connected = true;
    this.disconnected = false;
    this.emit('connect');
    this._emitBuffered();
  }

  /**
   * Emit buffered events (received and emitted).
   */
  void _emitBuffered() {
    this._receiveBuffer.forEach((Packet packet) {
      this.emit(packet);
    });
    this._receiveBuffer.clear();

    this._sendBuffer.forEach((Packet packet) {
      this.packet(packet);
    });
    this._sendBuffer.clear();
  }

  /**
   * Called upon server disconnect.
   */
  void onDisconnect() {
    log.info('server disconnect (${this._namespace})');
    this._destroy();
    this.onClose('io server disconnect');
  }

  /**
   * Called upon forced client/server side disconnections,
   * this method ensures the manager stops tracking us and
   * that reconnections don't get triggered for this.
   */
  void _destroy() {
    // clean subscriptions to avoid reconnections
    this._io.clearListeners();

    this._io.destroy(this);
  }

  void disconnect() => close();

  /**
   * Disconnects the socket manually.
   */
  void close() {
    if (this._connected) {
      log.info('performin disconnect (${this._namespace})');
      Packet packet = new Packet(PacketType.disconnect);
      packet.options = {'compress': true};
      this.packet(packet);
    }

    // remove socket from poll
    this._destroy();

    if (this._connected) {
      // fire events
      this.onClose('io client disconnect');
    }
  }

  /**
   * Sets the compress flag.
   *
   * @param {Boolean} if `true`, compresses the sending data
   */
  void compress(bool compress) => this._flags['compress'] = compress;

}