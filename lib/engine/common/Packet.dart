library connexa.packet;

/**
 * Packets types
 *
 * 0 - open   - nws
 * 1 - close  - nws
 * 2 - ping
 * 3 - pong
 * 4 - message
 * 5 - upgrade
 * 6 - noop
 */
enum PacketTypes {
  open,
  close,
  ping,
  pong,
  message,
  upgrade,
  noop
}

/**
 * Class how represents a Packet.
 */
class Packet {

  /**
   * Packet contents
   */
  Object data;

  /**
   * Package type
   */
  PacketTypes type;

  Packet([PacketTypes this.type = null, Object this.data]);
}