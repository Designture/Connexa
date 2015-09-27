library connexa.client;

import 'dart:html';
import 'package:connexa/engine/common/Packet.dart';
import 'package:connexa/engine/common/Parser.dart';
import 'package:logging/logging.dart';
import 'package:connexa/engine/client/transport.dart';
import 'package:connexa/engine/client/transports/websocket_transport.dart';
import 'dart:async';
import 'package:eventus/eventus.dart';

enum SocketStates {
  opening,
  open,
  upgrade,
  closed,
  closing
}

class Engine extends Eventus {

  /**
   * WebSocket instance
   */
  WebSocket _socket;

  /**
   * Logger.
   */
  Logger _log = new Logger('connexa:connexa');

  /**
   * Map with the Socket settings.
   */
  Map<String, Object> _settings;

  /**
   * Transport instance.
   */
  Transport _transport;

  /**
   * Current state of the Socket connection.
   */
  SocketStates _readyState = SocketStates.closed;

  /**
   * List with the Packets to be sent.
   */
  List<Packet> _writeBuffer = new List();
  int _prevBufferLen = 0;

  Timer _pingIntervalTimer = null;
  Timer _pingTimeoutTimer = null;

  /**
   * Constructor
   */
  Engine(String uri, [Map options = const {}]) {
    // default options
    _settings = {
      'transports': ['websocket'],
      'query': {},
      'agent': false,
      'path': '/engine.io',
      'hostname': 'localhost',
      'debug': false
    };

    // merge the user options
    _settings.addAll(options);

    // enable debug?
    if (_settings['debug'] == true) {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('(${rec.loggerName}) ${rec.level.name}: ${rec.time}: ${rec
            .message}');
      });
    }

    // define some uri vars
    if (uri != null) {
      Uri uriP = Uri.parse(uri);
      _settings['host'] = uriP.host;
      _settings['secure'] = uriP.scheme == 'https' || uriP.scheme == 'wss';
      _settings['port'] = uriP.port;
      _settings['query'] = uriP.queryParameters;
    }

    this._open();
  }

  /**
   * Initializes transport to use and start probe.
   */
  void _open() {
    this._readyState = SocketStates.opening;

    Transport transport = this._createTransport('websocket');

    transport.open();
    this._setTransport(transport);
  }

  Transport _createTransport(String transportName) {
    _log.info('creating transport "${transportName}');

    // create settings clone
    Map transportSettings = new Map();
    transportSettings.addAll(this._settings);

    // create a query clone
    Map query = new Map();
    query.addAll(this._settings['query']);

    // append Connexa protocol identifier
    query['EIO'] = Parser.protocol;

    // transport name
    query['transport'] = transportName;

    // session id if we already have one
    if (this._settings['sid']) {
      query['sid'] = this._settings['sid'];
    }

    // replace query
    transportSettings['query'] = query;

    if (transportName == 'websocket') {
      return new WebSocketTransport(transportSettings);
    } else {
      throw new Exception('Invalid transport');
    }
  }

  /**
   * Sets the current transport. Disables the existing one (if any).
   */
  void _setTransport(Transport transport) {
    _log.info('setting transport "${transport.name}"');

    if (this._transport != null) {
      _log.info('clearing existing transport "${this._transport.name}"');
      // TODO: remove all listeners from the previously transport
    }

    // set up transport
    this._transport = transport;

    // set up transport listeners
    this._transport..on('drain', () {
      this._onDrain();
    })..on('packet', (Packet packet) {
      this._onPacket(packet);
    })..on('error', (e) {
      this._onError(e);
    })..on('close', () {
      this._onClose('transport close');
    });
  }

  /**
   * Called when connection is deemed open.
   */
  void _onOpen() {
    _log.info('socket open');
    this._readyState = SocketStates.open;
    this.emit('open');
    this._flush();
  }

  /**
   * Handles a packet.
   */
  void _onPacket(Packet packet) {
    if (this._readyState == SocketStates.opening ||
        this._readyState == SocketStates.open) {
      _log.info(
          'socket receive: type "${packet.type}", data "${packet.data}"');

      this.emit('packet', packet);

      // Socket is live - any packet counts
      this.emit('heartbeat');

      switch (packet.type) {
        case PacketTypes.open:
          this._onHandshake(packet.data);
          break;
        case PacketTypes.pong:
          this._setPing();
          this.emit('pong');
          break;
        case PacketTypes.message:
          this.emit('data', packet.data);
          this.emit('message', packet.data);
          break;
        default:
      }
    } else {
      _log.info('packet received with socket readyState "${this._readyState}"');
    }
  }

  /**
   * Called on `drain` event.
   */
  void _onDrain() {
    this._writeBuffer.removeRange(0, this._prevBufferLen);

    this._prevBufferLen = 0;

    if (this._writeBuffer.isEmpty) {
      this.emit('drain');
    } else {
      this._flush();
    }
  }

  /**
   * Called upon transport error.
   */
  void _onError(err) {
    _log.info('socket error ${err}');
    this.emit('error', err);
    this._onClose('transport error', err);
  }

  /**
   * Called upon transport close.
   */
  void _onClose(String reason, [String desc = '']) {
    if (this._readyState == SocketStates.opening ||
        this._readyState == SocketStates.open ||
        this._readyState == SocketStates.closing) {
      // clear timmers
      this._pingIntervalTimer?.cancel();
      this._pingTimeoutTimer?.cancel();

      // stop event from firing again for transport
      this._transport.removeAllListeners('close');

      // ensure transport won't stay open
      this._transport.close();

      // ignore further transport communication
      // TODO: remove all listeners from transport

      // set ready state
      this._readyState = SocketStates.closed;

      // clear session id
      this._settings['sid'] = null;

      // emit close event
      this.emit('close', reason, desc);

      // clean buffer after, so users can still
      // grab the buffer on 'close' event
      this._writeBuffer.clear();
      this._prevBufferLen = 0;
    }
  }

  /**
   * Flush write buffer.
   */
  void _flush() {
    if (this._readyState != SocketStates.closed &&
        this._transport.writable &&
        this._writeBuffer.isNotEmpty) {
      _log.info('flushing ${this._writeBuffer.length} packet in socket');
      this._transport.send(this._writeBuffer);
      // keep track of current length of writeBuffer,
      // we need to remove the sent elements from writeBuffer
      // on `drain` event
      this._prevBufferLen = this._writeBuffer.length;
      this.emit('flush');
    }
  }

  /**
   * Called upon handshake completion.
   */
  void _onHandshake(Map data) {
    this.emit('handshake', data);
    this._settings['id'] = data['sid'];
    this._transport.settings['query']['sid'] = data['sid'];
    this._settings['pingInterval'] = data['pingInterval'];
    this._settings['pingTimeout'] = data['pingTimeout'];
    this._onOpen();

    // In case open handler closes socket
    if (this._readyState == SocketStates.closed) {
      return;
    }

    this._setPing();

    // Prolong liveness of socket on heartbeat
    this.removeAllListeners('heartbeat');
    this.on('heartbeat', this._onHeartbeat);
  }

  /**
   * Pings server every `pingInterval` and expects response within
   * `pingTimeout` or closes connection.
   */
  void _setPing() {
    this._pingIntervalTimer =
    new Timer(new Duration(milliseconds: _settings['pingInterval']), () {
      _log.info(
          'writing ping packet - expecting pong within ${_settings['pingTimeout']}');
      this._ping();
      this._onHeartbeat(_settings['pingTimeout']);
    });
  }

  /**
   * Sends a ping packet.
   */
  void _ping() {
    this._sendPacket(PacketTypes.ping, null, null, () {
      this.emit('ping');
    });
  }

  /**
   * Resets ping timeout.
   */
  void _onHeartbeat([int timeout = null]) {
    // cancel timer
    _pingTimeoutTimer?.cancel();

    // get the next duration
    int duration = 0;
    if (timeout != null) {
      duration = timeout;
    } else {
      duration = _settings['pingInterval'] + _settings['pingTimeout'];
    }

    // create the next timer
    _pingTimeoutTimer = new Timer(new Duration(milliseconds: duration), () {
      if (_readyState == SocketStates.closed) {
        return;
      }

      this._onClose('ping timeout');
    });
  }

  /**
   * Sends a packet.
   */
  void _sendPacket(PacketTypes type, [Map data, Map options, Function fn]) {
    // check if the connection is open
    if (this._readyState == SocketStates.closing ||
        this._readyState == SocketStates.closed) {
      return;
    }

    // create a packet
    Packet packet = new Packet(type, data);
    this.emit('packetCreate', packet);
    this._writeBuffer.add(packet);
    if (fn != null) {
      this.once('flush', fn);
    }
    this._flush();
  }

  // ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- [PUBLIC METHODS]

  /**
   * Send a new message.
   */
  void send(Map<String, Object> data, [Map options = const {}]) {
    this._sendPacket(PacketTypes.message, data);
  }

  /**
   * Closes the connection.
   */
  void close() {
    if (this._readyState == SocketStates.opening ||
        this._readyState == SocketStates.open) {
      this._readyState = SocketStates.closing;

      this._onClose('forced close');
      _log.info('socket closing - telling transport to close');
      this._transport.close();
    }
  }

}