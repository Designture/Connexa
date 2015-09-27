part of connexa.surface.server;

/**
 * Flags
 */
enum SocketFlags {
  json,
  volatile,
  broadcast
}

class Socket extends Eventus {

  static final List<String> eventsBlackList = [
    'error',
    'connect',
    'disconnect',
    'newListener',
    'removeListener'
  ];

  Namespace _namespace;
  Client _client;
  Server _server;
  String _id;
  bool _connected = true;
  bool _disconnected = false;
  Map<String, Object> _flags = {};
  List<String> _rooms = [];
  List<Function> _acks = [];
  Adapter _adapter;

  /**
   * logger
   */
  Logger log = new Logger('connexa.socket');

  Socket(Namespace this._namespace, Client this._client) {
    this._server = _namespace._server;
    this._id = _client.id;
    this._adapter = _namespace._adapter;
  }

  String get id => _id;

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
   * Emits to this client.
   */
  void emit(String event, [arg1, arg2, arg3]) {
    if (Socket.eventsBlackList.contains(event)) {
      // TODO:
      log.warning('TODO');
    } else {
      Packet packet = new Packet();
      // TODO: add binary support
      packet.type = PacketType.event;
      packet.data = _preparePacketData(arg1, arg2, arg3);

      Map<String, Object> flags = (this._flags != null) ? this._flags : {};

      if (arg3 is Function) {
        if (this._rooms != null || _flags.containsKey('broadcast')) {
          throw new Exception('Callbacks are not supported  when broadcasting');
        }

        log.info('emitting packet with ack id ${this._namespace.ids}');
        this._acks[this._namespace.ids] = arg3;
        packet.id = this._namespace.ids++;
      }

      if (this._rooms != null || this._flags.containsKey('broadcast')) {
        this._adapter.broadcast(packet, {
          'except': [this.id],
          'rooms': this._rooms,
          'flags': flags
        });
      } else {
        // dispatch packet
        this.packet(packet, {
          'volatile': flags['volatile'],
          'compress': flags['compress']
        });
      }

      // reset flags
      this._rooms.clear();
      this._flags.clear();
    }
  }

  /**
   * Targets a room when broadcasting.
   *
   * @param {String} name
   */
  void to(String name) {
    this._rooms = (this._rooms != null) ? this._rooms : [];
    if (!this._rooms.contains(name)) {
      this._rooms.add(name);
    }
  }

  /**
   * Sends a `message` event.
   */
  void send(Map data) => this.emit('message', data);

  /**
   * Writes a packet.
   *
   * @param {Object} packet object
   * @param {Object} options
   */
  void packet(Packet packet, [Map opts]) {
    packet.namespace = this._namespace._name;
    opts = (opts == null) ? {} : opts;
    opts.putIfAbsent('compress', () => false);
    this._client.packet(packet, opts);
  }

  /**
   * Joins a room.
   *
   * @param {String} room
   * @param {Function} optional, callback
   */
  void join(String room, [Function fn = null]) {
    log.info('joining room ${room}');
    if (this._rooms.contains(room)) {
      return;
    }

    this._adapter.add(this.id, room, (err) {
      if (err != null) {
        if (fn != null) {
          fn(err);
        }
      }
      log.info('joined room ${room}');
      this._rooms.add(room);
      if (fn != null) {
        fn(null);
      }
    });
  }

  /**
   * Leave a room.
   *
   * @param {String} room
   * @param {Function} optional, callback
   */
  void leave(String room, [Function fn = null]) {
    log.info('leave room ${room}');
    this._adapter.del(this.id, room, (err) {
      if (err != null) {
        if (fn != null) {
          fn(err);
        }
      }

      log.info('left room ${room}');
      if (this._rooms.contains(room)) {
        this._rooms.remove(room);
      }

      if (fn != null) {
        fn(null);
      }
    });
  }

  /**
   * Leave all rooms.
   */
  void leaveAll() {
    this._adapter.delAll(this.id);
    this._rooms.clear();
  }

  /**
   * Called by `Namespace` upon succesful
   * middleware execution (ie: authorization).
   */
  void onConnect() {
    log.info('socket connected - writting packet');
    this._namespace.connected[this.id] = this;
    this.join(this.id);
    this.packet(new Packet(PacketType.connect));
  }

  /**
   * Called with each packet. Called by `Client.`
   */
  void onPacket(Packet packet) {
    log.info('got packet ${packet}');

    switch (packet.type) {
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
   * Called upon event packet.
   *
   * @param {Object} packet object
   */
  void onEvent(Packet packet) {
    log.info('emitting event ${packet.data}');

    if (packet.id != null) {
      log.info('attaching ack callback to event');
      this.emit(packet.data['event'], packet.data, this.ack(packet.id));
    }

    this.emit(packet.data['event'], packet.data);
  }

  /**
   * Produces an ack callback to emit with an event.
   *
   * @param {Number} packet id
   */
  Function ack(String id) {
    bool sent = false;
    return ([Map data]) {
      // prevent double callbacks
      if (sent) {
        return;
      }
      // TODO: add support to binary
      log.info('sending ack ${data}');
      Packet packet = new Packet(PacketType.ack, data);
      packet.id = id;
      this.packet(packet);
    };
  }

  /**
   * Called upon ack packet.
   */
  void onAck(Packet packet) {
    Function ack = this._acks[packet.id];

    if (ack != null) {
      log.info('calling ack ${packet.id} with ${packet.data}');
      ack(packet.data);
      this._acks.remove(packet.id);
    }
  }

  /**
   * Called upon client disconnect packet.
   */
  void onDisconnect() {
    log.info('got disconnected packet');
    this.onClose('client namespace disconnect');
  }

  /**
   * Handles a client error.
   */
  void onError(String err) {
    if (this
        .listeners('error')
        .isNotEmpty) {
      this.emit('error', err);
    } else {
      throw new StateError('Missing error handler on `socket`');
    }
  }

  /**
   * Called upon closing. Called by `Client`.
   *
   * @param {String} reason
   * @param {Error} optional error object
   */
  void onClose([String reason = '']) {
    if (!this._connected) {
      return;
    }

    log.info('closing socket - reson ${reason}');
    this.leaveAll();
    this._namespace.remove(this);
    this._client.remove(this);
    this._connected = false;
    this.disconnect = true;
    this._namespace.connected.remove(this.id);
    this.emit('disconnect', reason);
  }

  /**
   * Produces an `error` packet.
   *
   * @param {Object} error object
   */
  void error([String err = '']) {
    this.packet(new Packet(PacketType.error, err));
  }

  /**
   * Disconnects this client.
   *
   * @param {Boolean} if `true`, closes the underlying connection
   */
  void disconnect(bool close) {
    if (!this._connected) {
      return;
    }

    if (close) {
      this._client.disconnect();
    } else {
      this.packet(new Packet(PacketType.disconnect));
      this.onClose('server namespace disconnect');
    }
  }

  /**
   * Sets the compress flag.
   *
   * @param {Boolean} if `true`, compresses the sending data
   */
  void compress(bool compress) {
    this._flags = (this._flags != null) ? this._flags : {};
    this._flags['compress'] = compress;
  }
}