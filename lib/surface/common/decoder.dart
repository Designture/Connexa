library connexa.surface.common.decoder;

import 'dart:convert';
import 'package:eventus/eventus.dart';
import 'package:connexa/surface/common/Packet.dart';
import 'package:logging/logging.dart';

class Decoder extends Eventus {

  /**
   * Logger
   */
  static Logger log = new Logger('connexa:decoder');

  int _reconstructor = null;

  /**
   * Decodes an encoded packet string into packet JSON.
   *
   * TODO: add support to binary
   *
   * @param {String} obj - encoded packet
   */
  void add(dynamic encoded) {
    Packet packet;

    if (encoded is String) {
      // decode the string into a Packet
      packet = decodeString(encoded);

      if (packet.type == PacketType.binary_ack ||
          packet.type == PacketType.binary_event) {
        // binary packet's json
        // TODO
      } else {
        // non-binary full packet
        this.emit('decoded', packet);
      }
    } else {
      throw new StateError('Unknown type ${encoded}');
    }
  }

  /**
   * Decode a packet String to Packet type
   */
  static Packet decodeString(String encoded) {
    Packet packet = new Packet();
    int i = 0;

    // look up type
    packet.type = PacketType.values.elementAt(int.parse(encoded[0]));

    // look up attachments if type binary
    if (packet.type == PacketType.binary_ack ||
        packet.type == PacketType.binary_event) {
      // TODO
    }

    // look up namespace (if any)
    if (encoded[i + 1] == '/') {
      packet.namespace = '';
      while (++i) {
        String c = encoded[i];
        if (c == ',') {
          break;
        }
        packet.namespace += c;
        if (i == encoded.length) {
          break;
        }
      }
    } else {
      packet.namespace = '/';
    }

    // look up id
    String next = encoded[i + 1];
    if (next != '') {
      packet.id = '';
      while (++i) {
        String c = encoded[i];
        if (null == c) {
          --i;
          break;
        }

        packet.id = encoded[i];
        if (i == encoded.length) {
          break;
        }
      }
      packet.id = int.parse(packet.id);
    }

    // look up json data
    if (encoded[++i] != null) {
      try {
        packet.data = JSON.decode(encoded.substring(i));
      } on Exception catch (e) {
        return new Packet(PacketType.error, 'parser error');
      }
    }

    log.info('decoded ${encoded} as ${packet}');
    return packet;
  }

  /**
   * Deallocates a parser's resources
   */
  void destroy() {
    if (this._reconstructor != null) {
      // TODO
    }
  }

}