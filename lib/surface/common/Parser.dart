library connexa.surface.parser;

import 'package:logging/logging.dart';
import 'package:connexa/surface/common/Packet.dart';
import 'dart:convert';
import 'package:eventus/eventus.dart';


class Parser extends Eventus {

  /**
   * Protocol version.
   *
   * Maintain Socket.IO compatibility.
   */
  static int protocol = 4;

  /**
   * Logger
   */
  static Logger _log = new Logger('connexa:parser');

  /**
   * Gte logger instance
   */
  static Logger get log => _log;

  /**
   * Encode a packet as a single string if non-binary, or as a
   * buffer sequence, depending on packet type.
   */
  static void encode(Packet packet, Function callback) {
    log.info('encoding packet ${packet}');

    if (packet.type == PacketType.binary_event ||
        packet.type == PacketType.binary_ack) {
      _encodeAsBinary(packet, callback);
    } else {
      String encoded = _encodeAsString(packet);
      callback([encoded]);
    }
  }

  static String _encodeAsString(Packet packet) {
    String encoded = '';
    bool nsp = false;

    // first is type
    encoded += packet.type.index.toString();

    // if we have a namespace other than '/'
    // we append it followed by a comma ','
    if (packet.namespace != '/') {
      nsp = true;
      encoded += packet.namespace;
    }

    // immediately followed by the id
    if (packet.id != null) {
      if (nsp) {
        encoded += ',';
        nsp = false;
      }
      encoded += packet.id;
    }

    // json data
    if (packet.data != null) {
      if (nsp) {
        encoded += ',';
      }
      encoded += JSON.encode(packet.data);
    }

    log.info('encoded ${packet} as ${encoded}');

    return encoded;
  }

  /**
   * Encode packet as 'buffer sequence' by removing blobs, and
   * deconstructing packet into object with placeholders and
   * a list of buffers.
   */
  static _encodeAsBinary(Packet packet, Function callback) {
    // TODO:
  }

}