library connexa.parser;

import 'dart:convert';
import 'package:connexa/src/Packet.dart';

class Parser {

  /**
   * Current protocol version.
   */
  static final int protocol = 3;

  static String encode(Packet packet,
      [bool supportsBinary = false, bool utf8encode = false]) {
    String encoded = '';

    // add package type
    encoded += packet.type.index.toString();

    // encode packet content if exists (data fragment is optional)
    if (!packet.isEmpty) {
      encoded += JSON.encode(packet.content);
    }

    // returns the packet encoded
    return encoded;
  }

  static PacketTypes getPacketTypeFromChar(String c) {
    // convert char to int
    int type = int.parse(c);

    switch (type) {
      case 0:
        return PacketTypes.open;
      case 1:
        return PacketTypes.close;
      case 2:
        return PacketTypes.ping;
      case 3:
        return PacketTypes.pong;
      case 4:
        return PacketTypes.message;
      case 5:
        return PacketTypes.upgrade;
      case 6:
        return PacketTypes.noop;
    }
  }

  static Packet decode(String content) {
    Packet packet = new Packet();

    // look up packet type
    packet.type = getPacketTypeFromChar(content[0]);

    if (content.length > 1) {
      packet.addAll(JSON.decode(content.substring(1)));
    }

    return packet;
  }

}