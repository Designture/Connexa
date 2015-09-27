library connexa.transports.websocket;

import 'dart:io';
import 'package:connexa/engine/server/Transport.dart';
import 'package:connexa/engine/common/Parser.dart';
import 'package:logging/logging.dart';
import 'package:connexa/engine/common/Packet.dart';

/**
 * WebSocket transport
 */
class WebSocketTransport extends Transport {

  /**
   * Socket.
   */
  WebSocket _socket;

  /**
   *
   */
  Logger _log = new Logger('engine:ws');

  /**
   * Advertise upgrade support.
   */
  final bool handlesUpgrades = true;

  /**
   * Advertise framing support.
   */
  final bool supportsFraming = true;

  /**
   * Constructor.
   *
   * @param WebSocket
   */
  WebSocketTransport(HttpRequest req) : super(req) {
    // set transformer name
    this.name = 'websocket';

    // save socket instance
    WebSocketTransformer.upgrade(req).then((socket) {
      this._socket = socket;
      this.writable = true;

      // handle the socket errors
      this._socket.handleError(() {
        this.onClose();
      });

      // start listen the web socket
      socket.listen((packet) {
        this.onData(packet);
      });

      // informs those who are listening that the transport is now open
      this.emit('open');
    }).catchError((Exception e) {
      this.onError('Can\'t conenct with the socket.', e.toString());
    });
  }

  /**
   * Get logger
   */
  Logger get log => _log;

  /**
   * Processes the incoming data.
   */
  void onData(Object data) {
    log.info('received "${data}"');
    super.onData(data);
  }

  /**
   * Writes a packet payload.
   *
   * @param List    packets
   */
  void send(List<Packet> packets) {
    packets.forEach((Packet p) {
      // encode packet
      String encodedPacket = Parser.encode(p);

      // send the encoded packet
      log.info('writing "${encodedPacket}"');
      this.writable = false;
      this._socket.add(encodedPacket);
      this.writable = true;
      this.emit('drain');
    });
  }

  /**
   * Closes the transport.
   */
  void doClose([Function callback]) {
    log.info('closing');
    this._socket.close();
    if (callback != null) {
      callback();
    }
  }

}