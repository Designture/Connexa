library connexa.socket;

import 'dart:io';
import 'package:connexa/src/EventEmiter.dart';
import 'dart:async';

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
class Socket extends EventEmitter {

  String _id;
  HttpServer _server;
  bool _upgrading = false;
  bool _upgraded = false;
  SocketStates _state = SocketStates.opening;

  Timer _checkIntervalTimer = null;
  Timer _upgradeTimeoutTimer = null;
  Timer _pingTimeoutTimer = null;

  Socket(String this._id, HttpServer this._server, var transport, var req) {
    // TODO: set transport

    // open the socket
    this.onOpen();
  }

  void onOpen() {
    this._state = SocketStates.open;

    // send an 'open' packet
    // TODO: set transport id
    // TODO: send open packet

    this.emit('open', null);
    this.setPingTimeout();
  }

  /**
   * Called upon transport packet.
   *
   * @param {Object} packet
   */
  void onPacket(Object packet) {
    if (this._state == SocketStates.open) {
      // export packet event
      this.emit('packet', packet);

      // reset ping timeout on any packet, incoming data is a good sign of
      // other side's liveness
      this.setPingTimeout();

      switch (packet.type) {
        case 'ping':
        // TODO: send pong packet
          this.emit('heartbeat', null);
          break;
        case 'error':
        // TODO: close transport
          this.onClose('parse error');
          break;
        case 'message':
          this.emit('data', packet.data);
          this.emit('message', packet.data);
          break;
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
    this._pingTimeoutTimer?.cancel();
    this._pingTimeoutTimer =
    new Timer(this._server.pingInterval + this._server.pingTimeout, () {
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
    // TODO: handle error events

    // ensure transport won't stay open
    // TODO: close the transport

    this._pingTimeoutTimer?.cancel();
  }

  /**
   * Called upon transport considered closed.
   * Possible reasons: `ping timeout`, `client error`, `parse error`,
   * `transport error`, `server close`, `transport close`
   */
  void onClose(String reason, [String description]) {
    if (this._state != SocketStates.closed) {
      this._pingTimeoutTimer?.cancel();
      this._checkIntervalTimer?.cancel();
      this._checkIntervalTimer = null;
      this._upgradeTimeoutTimer?.cancel();
      this.clearTransport();
      this._state = SocketStates.closed;
      this.emit('close', {
        'reason': reason,
        'description': description
      });
    }
  }

  /**
   * Setup and manage send callback
   */
  void setupSendCallback() {
    // the message was sent successfully, execute the callback
    // TODO: add the drain event to the transport
  }

  /**
   * Send a packet.
   *
   * @param {String} packet type
   */
  void sendPacket(String type, Object data,
      [dynamic options, Function callback]) {
    if (options is Function) {
      callback = options;
      options = null;
    }

    options ??= {};
    options.compress ??= false;

    // build the packet
    Map packet = {
      'type': type,
      'options': options,
      'data': data
    };

    // TODO: Push pakage to a List or send it right now?!

    // export packetCreate event
    this.emit('packetCreate', packet);

    this.flush();
  }

  /**
   *
   */
  void flush() {
    // TODO: Check the transport
    if (this._state != SocketStates.closed) {
      // TODO: flush the packets
    }
  }

  /**
   * Closes the socket and underlying transport.
   */
  void close() {
    if (this._state != SocketStates.open) {
      return;
    }

    this._state = SocketStates.closing;

    // TODO: If we will use a write buffer, we to check the length and drain

    this.closeTransport();
  }

  /**
   * Closes the underlying transport.
   */
  void closeTransport() {
    // TODO: Close the transport
  }
}