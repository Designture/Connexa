library connexa.socket;

import 'dart:async';
import 'package:connexa/src/Server.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Parser.dart';
import 'package:events/events.dart';
import 'package:connexa/src/Packet.dart';
import 'package:connexa/src/Transport.dart';
import 'dart:io';

enum SocketStates {
  opening,
  open,
  upgrade,
  closed,
  closing
}

/**
 * Class to be passed on the flush event.
 */
class FlushEvent {

  Socket socket;
  List<Packet> writeBuffer;

  FlushEvent(this.socket, this.writeBuffer);

}

/**
 * Client class.
 *
 * @api private
 */
class Socket extends Events {

  String _id;
  Server _server;
  SocketStates _readyState = SocketStates.opening;
  Transport transport;
  HttpRequest _req;

  List<Packet> _writeBuffer = new List();
  List<Function> _packetsFn = new List();
  List<Function> _sendCallbackFn = new List();

  Timer _checkIntervalTimer = null;
  Timer _pingTimeoutTimer = null;

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

    // TODO: add the available upgrades
    this.sendPacket(PacketTypes.open, {
      'sid': this._id,
      'pingInterval': this._server.pingInterval,
      'pingTimeout': this._server.pingTimeout
    });

    this.emit('open', null);
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
          this.emit('heartbeat', null);
          break;
        case PacketTypes.close:
          this.transport.close();
          this.onClose('parse error');
          break;
        case PacketTypes.message:
          this.emit('data', packet['data']);
          this.emit('message', packet['data']);
          break;
        default:
        // Don't do nothing
      }
    } else {
      log.info('packet received with closed socket');
    }
  }

  /**
   * Called upon transport error.
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
   */
  void setTransport(Transport transport) {
    this.transport = transport;
    this.transport.once('error', this.onError);
    this.transport.on('packet', this.onPacket);
    this.transport.on('drain', this.flush);
    this.transport.once('close', this.onClose);
    // this function will manage packet events (also message callbacks)
    //this._setupSendCallback();
  }

  /**
   * Upgrades socket to the given transport.
   */
  void maybeUpgrade(Transport) {
    // TODO
  }

  /**
   * Clears listeners ans timers associated with current transport.
   */
  void clearTransport() {
    // silence further transport errors and prevent uncaught exceptions
    this.transport.on('error', (_) {
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
  void onClose(String reason, [String description]) {
    if (this._readyState != SocketStates.closed) {
      this._pingTimeoutTimer?.cancel();
      this._checkIntervalTimer?.cancel();
      this._checkIntervalTimer = null;
      // TODO: stop upgrade timeout timer (but first we need to implement it)
      this.clearTransport();
      this._readyState = SocketStates.closed;
      this.emit('close', {
        'reason': reason,
        'description': description
      });
    }
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
      [Object data, Map options, Function callback]) {
    if (this._readyState != SocketStates.closing) {
      log.info('sending packet "${type} (${data})"');

      // build the packet
      Packet packet = new Packet();

      // add the packet type
      packet.type = type;

      // add the packet data
      packet['data'] = data;

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
  void flush([_]) {
    if (this._readyState != SocketStates.closed && this.transport.writable &&
        !this._writeBuffer.isEmpty) {
      log.info('flusing buffer to transport');
      this.emit('flush', this._writeBuffer);
      this._server.emit('flush', new FlushEvent(this, this._writeBuffer));
      List<Packet> wbuf = this._writeBuffer;
      this._writeBuffer.clear();
      // TODO: send callback
      this._packetsFn.clear();
      this.transport.send(wbuf);
      this.emit('drain');
      this._server.emit('drain', this);
    }
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