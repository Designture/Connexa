import 'package:logging/logging.dart';
import 'package:connexa/surface/common/Packet.dart';
import 'dart:convert';


class Parser {

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
      _encodeAsString(packet, callback);
    }
  }

  static void _encodeAsString(Packet packet, Function callback) {
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

    // call callback
    callback(encoded);
  }

  /**
   * Encode packet as 'buffer sequence' by removing blobs, and
   * deconstructing packet into object with placeholders and
   * a list of buffers.
   */
  static _encodeAsBinary(Packet packet, Function callback) {
    // TODO:
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

        packet.id += encoded[i];
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

}