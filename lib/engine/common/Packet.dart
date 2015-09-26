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
class Packet implements Map<String, Object> {

  /**
   * Packet contents
   */
  Map<String, Object> _content = new Map();

  /**
   * Package type
   */
  PacketTypes type;

  /**
   * Get packet content map.
   */
  Map get content => _content;

  Packet([PacketTypes this.type = null, Object content = const {}]) {
    if (content != null) {
      this.addAll(content);
    }
  }

  /**
   * Returns whether this map contains the given [value].
   */
  bool containsValue(Object value) {
    _content.containsValue(value);
  }

  /**
   * Returns whether this map contains the given [key].
   */
  bool containsKey(String key) {
    return _content.containsKey(key);
  }

  /**
   * Returns the value for the given [key] or null if [key] is not
   * in the map. Because null values are supported, one should either
   * use containsKey to distinguish between an absent key and a null
   * value, or use the [putIfAbsent] method.
   */
  Object operator [](String key) {
    return _content[key];
  }

  /**
   * Associates the [key] with the given [value].
   */
  void operator []=(String key, Object value) {
    _content[key] = value;
  }

  /**
   * If [key] is not associated to a value, calls [ifAbsent] and
   * updates the map by mapping [key] to the value returned by
   * [ifAbsent]. Returns the value in the map.
   */
  Object putIfAbsent(String key, Object ifAbsent()) {
    return _content.putIfAbsent(key, ifAbsent);
  }

  /**
   * Removes the association for the given [key]. Returns the value for
   * [key] in the map or null if [key] is not in the map. Note that values
   * can be null and a returned null value does not always imply that the
   * key is absent.
   */
  Object remove(String key) {
    _content.remove(key);
  }

  /**
   * Removes all pairs from the map.
   */
  void clear() {
    _content.clear();
  }

  /**
   * Applies [f] to each {key, value} pair of the map.
   */
  void forEach(void f(String key, Object value)) {
    _content.forEach(f);
  }

  /**
   * Returns a collection containing all the keys in the map.
   */
  List<String> get keys => _content.keys;

  /**
   * Returns a collection containing all the values in the map.
   */
  List<Object> get values => _content.values;

  /**
   * The number of {key, value} pairs in the map.
   */
  int get length => _content.length;

  /**
   * Returns true if there is no {key, value} pair in the map.
   */
  bool get isEmpty => _content.isEmpty;

  @override
  void addAll(Map<String, Object> other) {
    _content.addAll(other);
  }

  @override
  bool get isNotEmpty => _content.isNotEmpty;
}