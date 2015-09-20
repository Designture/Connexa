library connexa.transport;

import 'dart:io';
import 'Parser.dart';
import 'package:eventus/eventus.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Packet.dart';

enum TransportStates {
  open,
  closed,
  closing
}

abstract class Transport extends Eventus {

  /**
   * Current transport state.
   */
  TransportStates _readyState = TransportStates.open;

  /**
   * Original HttpRequest.
   */
  HttpRequest _request = null;

  /**
   * Socket id.
   */
  String sid;

  /**
   * Logger
   */
  Logger _log = new Logger('connexa:transport');

  /**
   * Is writable?
   */
  bool writable = false;

  /**
   * Transport name
   */
  String name;

  bool handlesUpgrades = true;
  bool supportsFraming = true;
  bool supportsBinary = false;

  /**
   * Construct
   */
  Transport(HttpRequest request) {
    this._readyState = TransportStates.open;
  }

  TransportStates get readyState => _readyState;

  /**
   * Get for the logger.
   */
  Logger get log => _log;

  /**
   * Called with an incoming HTTP request.
   */
  void onRequest(HttpRequest request) {
    log.info('setting request');
    this._request = request;
  }

  /**
   * CLose the transport.
   */
  void close([Function fn]) {
    if (this._readyState == TransportStates.closed ||
        this._readyState == TransportStates.closing) {
      return;
    }

    this._readyState = TransportStates.closing;
    this.onClose(fn ?? () => null);
  }

  /**
   * Called with a transport error.
   *
   * @param {String} message error
   * @param {Object} error description
   */
  void onError(msg, desc) {
    // FIXME: (#issue 9) We need to implement our EventEmitter
    if (!this.events.get('error').isEmpty()) {
      Error err = new Error();
      err.msg = msg;
      err.type = 'TransportError';
      err.description = desc;
      this.emit('error', err);
    }
  }

  /**
   * Called with parsed out a packets from the data stream.
   */
  void onPacket(Packet packet) {
    this.emit('packet', packet);
  }

  /**
   * Called with the encoded packet data.
   */
  void onData(Object data) {
    this.onPacket(Parser.decode(data));
  }

  void onClose([Function fn]) {
    this._readyState = TransportStates.closed;
    this.emit('close');
  }

  /**
   * Send data to the client.
   */
  void send(dynamic packets);

}