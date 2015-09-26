library connexa.client.transport;

import 'package:connexa/src/common/Packet.dart';
import 'package:connexa/src/common/Parser.dart';
import 'package:eventus/eventus.dart';
import 'package:connexa/src/common/TransportException.dart';

enum TransportStates {
  opening,
  open,
  closed
}

abstract class Transport extends Eventus {

  TransportStates _readyState = TransportStates.closed;
  String name = '';

  Map<String, Object> settings;
  bool writable = true;

  /**
   * A counter used to prevent collisions in the timestamps used
   * for cache busting.
   */
  int timestamps = 0;

  Transport(Map this.settings);

  /**
   * Emits an error
   */
  void onError(String msg, String desc) {
    TransportException err = new TransportException(msg, desc);
    this.emit('error', err);
  }

  /**
   * Opens the transport.
   */
  void open() {
    if (_readyState == TransportStates.closed) {
      _readyState = TransportStates.opening;
      this.doOpen();
    }
  }

  /**
   * Closes the transport.
   */
  void close() {
    if (_readyState == TransportStates.opening ||
        _readyState == TransportStates.open) {
      this.doClose();
      this.onClose();
    }
  }

  /**
   * Send multiple packets.
   */
  void send(List<Packet> packets) {
    if (_readyState == TransportStates.open) {
      this.write(packets);
    } else {
      throw new Exception('Transport not open');
    }
  }

  /**
   * Called upon open.
   */
  void onOpen() {
    this._readyState = TransportStates.open;
    this.writable = true;
    this.emit('open');
  }

  /**
   * Called with data
   */
  void onData(String data) {
    Packet packet = Parser.decode(data);
    this.onPacket(packet);
  }

  /**
   * Called with a decoded packet.
   */
  void onPacket(Packet packet) {
    this.emit('packet', packet);
  }

  /**
   * Called upon close.
   */
  void onClose() {
    this._readyState = TransportStates.closed;
    this.emit('close');
  }

  void doOpen();

  void write(List<Packet> packets);

  void doClose();

}