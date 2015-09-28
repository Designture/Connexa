/**
 * Packet types.
 */
enum PacketType {
  connect,
  disconnect,
  event,
  binary_event,
  ack,
  binary_ack,
  error
}

/**
 * Class how represents a Packet
 */
class Packet {

  /**
   * Packet content.
   */
  Object data;

  /**
   * Packet type.
   */
  PacketType type;

  /**
   * Namespace.
   */
  String namespace = '/';

  /**
   * ID
   */
  Object id = '';

  /**
   * Packet options.
   */
  Map options = {};

  Packet(
      [PacketType this.type = null, Object this.data = null, String this.namespace = '/', String this.id]);

}