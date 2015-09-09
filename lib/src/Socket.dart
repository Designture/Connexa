library connexa.socket;

import 'dart:async';
import 'package:connexa/src/Server.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Parser.dart';
import 'package:events/events.dart';
import 'package:connexa/src/Packet.dart';

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
class Socket extends Events {

  String _id;
  Server _server;
  SocketStates _readyState = SocketStates.opening;

  Timer _checkIntervalTimer = null;
  Timer _pingTimeoutTimer = null;

  /**
   * Constructor
   */
  Socket(String this._id, Server this._server) {
    this.onOpen();
  }

  /**
   * Getter for the client id.
   */
  String get id => _id;

  void onOpen() {
    this._readyState = SocketStates.open;

    // send an 'open' packet
    // TODO: set transport id

    // TODO: add the available upgrades
    this.send(PacketTypes.open, {
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
      this.emit('packet', packet);

      // reset ping timeout on any packet, incoming data is a good sign of
      // other side's liveness
      this.setPingTimeout();

      switch (packet.type) {
        case PacketTypes.ping:
        // TODO: send pong packet
          this.emit('heartbeat', null);
          break;
        case PacketTypes.close:
        // TODO: close transport
          this.onClose('parse error');
          break;
        case PacketTypes.message:
          this.emit('data', packet['data']);
          this.emit('message', packet['data']);
          break;
        default:
        // Don't do nothing
      }
    }
  }

  /**
   * Called upon transport error.
   */
  void onError(err) {
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
      // TODO: close transport
      this.onClose('ping timeout');
    });
  }

  /**
   * Attaches handlers for the given transport.
   */
  void setTransport(var transport) {
    // TODO: set up the transport
    // this function will manage packet events (also message callbacks)
    this.setupSendCallback();
  }

  /**
   * Clears listeners ans timers associated with current transport.
   */
  void clearTransport() {
    // silence further transport errors and prevent uncaught exceptions
    // TODO: handle error events on transport

    // ensure transport won't stay open
    // TODO: close the transport

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
   * Accessor shortcut for the logger.
   */
  Logger get log => _server.log;

  /**
   * Transmits a packet.
   */
  _packet(Packet packet) {
    // export packetCreate event
    this.emit('packetCreate', packet);

    // encode the packet
    String encodedPacket = Parser.encode(packet);

    // send the packet
    this._server.sendToClient(this._id, encodedPacket);
  }

  /**
   * Send a message.
   */
  send(PacketTypes type, Object data, [Function ack]) {
    // build the packet
    Packet packet = new Packet();

    // add the packet type
    packet.type = type;

    // add the packet data
    packet['data'] = data;

    // send it
    _packet(packet);
  }
}