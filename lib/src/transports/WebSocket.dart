library connexa.transports.websocket;

import 'dart:io';
import 'package:connexa/src/Transport.dart';
import 'package:connexa/src/Server.dart';
import 'package:connexa/src/Parser.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Packet.dart';

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
  Logger _log = new Logger('connexa:ws');

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

      this._socket.handleError(() {
        this.onClose();
      });

      // start listen the socket;
      socket.listen((packet) {
        this.onData(packet);
      });
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
   */
  void send(dynamic packet) {
    if (packet is List) {
      packet.forEach((Packet p) {
        // encode packet
        String encodedPacket = Parser.encode(p);

        // send the encoded packet
        log.info('writing "${encodedPacket}"');
        this._socket.add(encodedPacket);
      });
    } else if (packet is Packet) {

    } else {
      throw new Exception('Invalid method call!');
    }
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