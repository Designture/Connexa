library connexa.transport;

import 'dart:io';
import 'Parser.dart';
import 'package:events/events.dart';

enum TransportStates {
  open,
  closed,
  closing
}

abstract class Transport extends Events {

  TransportStates state = TransportStates.open;
  HttpRequest request = null;

  /**
   * Construct
   */
  Transport(dynamic request) {
    this._state = TransportStates.open;
  }

  void onRequest(HttpRequest request) {
    this.request = request;
  }

  /**
   * CLose the transport.s
   */
  void close(Function fn) {
    if (this.state == TransportStates.closed ||
        this.state == TransportStates.closing) {
      return;
    }

    this.state = TransportStates.closing;
    this.doClose(fn ?? () => null);
  }

  /**
   * Called with a transport error.
   *
   * @param {String} message error
   * @param {Object} error description
   */
  void onError(msg, desc) {
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
  void onPacket(var packet) {
    this.emit('packet', packet);
  }

  /**
   * Called with the encoded packet data.
   */
  void onData(Object data) {
    this.onPacket(Parser.decode(data));
  }

  void onClose() {
    this.state = TransportStates.closed;
    this.emit('close');
  }

}