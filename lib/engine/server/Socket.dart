library connexa.socket;

import 'dart:async';
import 'package:connexa/engine/server/Server.dart';
import 'package:logging/logging.dart';
import 'package:eventus/eventus.dart';
import 'package:connexa/engine/common/Packet.dart';
import 'package:connexa/engine/server/Transport.dart';
import 'dart:io';

enum SocketStates {
  opening,
  open,
  upgrade,
  closed,
  closing
}

/**
 * Client class.
 *
 * @api private
 */
class Socket extends Eventus {

  String _id;
  Server _server;
  SocketStates _readyState = SocketStates.opening;
  Transport transport;
  HttpRequest _req;

  List<Packet> _writeBuffer = new List();
  List<Function> _packetsFn = new List();
  List<Object> _sentCallbackFn = new List();

  Timer _checkIntervalTimer = null;
  Timer _pingTimeoutTimer = null;
  Timer _upgradeTimeoutTimer = null;

  bool upgrading = false;
  bool upgraded = false;

  /**
   * Logger
   */
  Logger _log = new Logger('connexa:socket');

  /**
   * Constructor
   */
  Socket(String this._id, Server this._server, Transport transport,
      HttpRequest this._req) {
    this.setTransport(transport);
    this.onOpen();
  }

  /**
   * Getter for the client id.
   */
  String get id => _id;

  /**
   * Getter fr the logger.
   */
  Logger get log => _log;

  /**
   * Called upon transport considered open.
   */
  void onOpen() {
    this._readyState = SocketStates.open;

    // send an 'open' packet
    this.transport.sid = this._id;
    this.sendPacket(PacketTypes.open, {
      'sid': this._id,
      'upgrades': this.getAvailableUpgrades(),
      'pingInterval': this._server.pingInterval,
      'pingTimeout': this._server.pingTimeout
    });

    this.emit('open');
    this.setPingTimeout();
  }

  /**
   * Called upon transport packet.
   *
   * @param {Object} packet
   */
  void onPacket(Packet packet) {
    if (this._readyState == SocketStates.open) {
      // export packet event
      log.info('packet');
      this.emit('packet', packet);

      // reset ping timeout on any packet, incoming data is a good sign of
      // other side's liveness
      this.setPingTimeout();

      switch (packet.type) {
        case PacketTypes.ping:
          this.sendPacket(PacketTypes.pong);
          this.emit('heartbeat');
          break;
        case PacketTypes.message:
          this.emit('data', packet.content);
          this.emit('message', packet.content);
          break;
        default:
          this.transport.close();
          this.onClose('parse error');
          break;
      }
    } else {
      log.info('packet received with closed socket');
    }
  }

  /**
   * Called upon transport error.
   *
   * @param Exception     Exception object
   */
  void onError(err) {
    log.info('transport error');
    this.onClose('transport error', err);
  }

  /**
   * Sets and resets ping timeout timer based on client pings.
   */
  void setPingTimeout() {
    // cancel the previous ping
    this._pingTimeoutTimer?.cancel();

    // create the duration object
    Duration duraction = new Duration(
        milliseconds: this._server.pingInterval + this._server.pingTimeout);

    this._pingTimeoutTimer =
    new Timer(duraction, () {
      this.transport.close();
      this.onClose('ping timeout');
    });
  }

  /**
   * Attaches handlers for the given transport.
   *
   * @param Transport     transport
   */
  void setTransport(Transport transport) {
    this.transport = transport;
    this.transport.once('error', this.onError);
    this.transport.on('packet', this.onPacket);
    this.transport.on('drain', this.flush);
    this.transport.once('close', this.onClose);
    // this function will manage packet events (also message callbacks)
    this._setupSendCallback();
  }

  /**
   * Upgrades socket to the given transport.
   *
   * @param Transport     transport
   */
  void maybeUpgrade(Transport transport) {
    log.info('might upgrade socket transport from "${this.transport
        .name}" to "${transport.name}"');

    this.upgrading = true;

    void cleanup() {
      this.upgrading = false;

      this._checkIntervalTimer?.cancel();
      this._checkIntervalTimer = null;

      this._upgradeTimeoutTimer?.cancel();
      this._upgradeTimeoutTimer = null;

      // TODO: remove listeners
    }

    // we force a polling cycle to ensure a fast upgrade
    void check() {
      if (this.transport.name == 'polling' && this.transport.writable) {
        log.info('writing a noop packet to polling for fast upgrade');
        this.transport.send(
            new Packet(PacketTypes.noop, {'options': {'compress': true}}));
      }
    }

    void onPacket(Packet packet) {
      if (packet.type == PacketTypes.ping && packet.containsKey('probe')) {
        Packet responseP = new Packet();
        responseP.type = PacketTypes.pong;
        responseP.addAll({'data': 'probe', 'options': {'compress': true}});
        transport.send(responseP);
        _checkIntervalTimer?.cancel();
        _checkIntervalTimer = new Timer(new Duration(milliseconds: 100), check);
      } else if (packet.type == PacketTypes.upgrade &&
          _readyState != SocketStates.closed) {
        log.info('got upgrade packet - upgrading');
        cleanup();
        this.upgraded = true;
        this.clearTransport();
        this.setTransport(transport);
        this.emit('upgrade', transport);
        this.setPingTimeout();
        this.flush();
        if (_readyState == SocketStates.closing) {
          transport.close(() {
            this.onClose('forced close');
          });
        }
      } else {
        cleanup();
        transport.close();
      }
    }

    void onError(err) {
      log.info('client did not complete upgrade - ${err}');
      cleanup();
      transport.close();
      transport = null;
    }

    void onTransportClose() {
      onError('trabsport closed');
    }

    void onClose(String reason, String description) {
      onError('socket closed');
    }

    transport.on('packet', onPacket);
    transport.once('close', onTransportClose);
    transport.once('error', onError);

    this.once('close', onClose);

    // set transport upgrade timer
    Duration duration = new Duration(milliseconds: this._server.upgradeTimeout);
    this._upgradeTimeoutTimer = new Timer(duration, () {
      log.info('client did not complete upgrade - closing transport');
      cleanup();
      if (transport.readyState == TransportStates.open) {
        transport.close();
      }
    });
  }

  /**
   * Clears listeners ans timers associated with current transport.
   */
  void clearTransport() {
    // silence further transport errors and prevent uncaught exceptions
    this.transport.on('error', () {
      log.info('error triggered by discarted transport');
    });

    // ensure transport won't stay open
    this.transport.close();

    // cancel ping timeout
    this._pingTimeoutTimer?.cancel();
  }

  /**
   * Called upon transport considered closed.
   * Possible reasons: `ping timeout`, `client error`, `parse error`,
   * `transport error`, `server close`, `transport close`
   */
  void onClose([String reason = 'forced close', String description]) {
    if (this._readyState != SocketStates.closed) {
      this._pingTimeoutTimer?.cancel();
      this._checkIntervalTimer?.cancel();
      this._checkIntervalTimer = null;
      this._upgradeTimeoutTimer?.cancel();
      this._packetsFn.clear();
      this._sentCallbackFn.clear();
      this.clearTransport();
      this._readyState = SocketStates.closed;
      this.emit('close', reason, description);
    }
  }

  /**
   * Setup and manage send callback
   */
  void _setupSendCallback() {
    // the message was sent successfully, execute the callback
    this.transport.on('drain', () {
      if (this._sentCallbackFn.isNotEmpty) {
        Object seqFn = this._sentCallbackFn.removeAt(0);
        if (seqFn is Function) {
          log.info('executing send callback');
          seqFn(this.transport);
        } else if (seqFn is List) {
          log.info('executing batch send callback');

          seqFn.forEach((Object obj) {
            if (obj is Function) {
              obj(this.transport);
            }
          });
        }
      }
    });
  }

  /**
   * Sends a message packet.
   */
  void send(dynamic data, [Map options, Function callback]) {
    this.sendPacket(PacketTypes.message, data, options, callback);
  }

  /**
   * Send a message.
   */
  void sendPacket(PacketTypes type,
      [Object data, Map options = const {}, Function callback]) {
    if (this._readyState != SocketStates.closing) {
      log.info('sending packet "${type} (${data})"');

      // build the packet
      Packet packet = new Packet(type);

      // add the packet data
      if (data != null) {
        packet.content.addAll(data);
      }

      // export packetCreate event
      this.emit('packetCreate', packet);

      // add to the list of packet to be sent
      this._writeBuffer.add(packet);

      // add send callback to object
      this._packetsFn.add(callback);

      this.flush();
    }
  }

  /**
   * Attempts to flush the packets buffer.
   */
  void flush() {
    if (this._readyState != SocketStates.closed && this.transport.writable &&
        !this._writeBuffer.isEmpty) {
      log.info('flusing buffer to transport');
      this.emit('flush', this._writeBuffer);
      this._server.emit('flush', this, this._writeBuffer);
      List<Packet> wbuf = this._writeBuffer;
      this._writeBuffer = new List();
      if (!this.transport.supportsFraming) {
        this._sentCallbackFn.add(this._packetsFn);
      }
      this._packetsFn = new List();
      this.transport.send(wbuf);
      this.emit('drain');
      this._server.emit('drain', this);
    }
  }

  /**
   * Get available upgrades for this socket.
   */
  List getAvailableUpgrades() {
    List availableUpgrades = new List();
    List allUpgrades = this._server.upgrades(this.transport.name);
    allUpgrades.forEach((String upg) {
      if (this._server.transports.contains(upg)) {
        availableUpgrades.add(upg);
      }
    });

    return availableUpgrades;
  }

  /**
   * Closes the socket and underlying transport.
   */
  void close() {
    if (this._readyState != SocketStates.open) {
      return;
    }

    this._readyState = SocketStates.closing;

    if (!this._writeBuffer.isEmpty) {
      this.once('drain', this.closeTransport);
      return;
    }

    this.closeTransport();
  }

  /**
   * Closes the underlying transport.
   */
  void closeTransport() {
    this.transport.close(this.onClose);
  }
}