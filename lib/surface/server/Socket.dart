part of connexa.surface.server;

/**
 * Flagss
 */
enum SocketFlags {
  josn,
  volatile,
  broadcast
}

class Socket extends Eventus {

  Namespace _namespace;
  Client _client;
  Server _server;
  String _id;
  bool _connected = true;
  bool _disconnected = false;

  Socket(Namespace this._namespace, Client this._client) {
    this._server = _namespace._server;
    this._id = _client.id;
  }

  /**
   * Emits to this client.
   */
  void emit(String event, [arg1, arg2, arg3]) {
    // TODO
  }

  /**
   * targets a room when broadcasting.
   */
  void to(String name) {
    // TODO
  }

  /**
   * Writes a packet.
   */
  void packet(Packet packet) {
    // TODO
  }

  /**
   * Joins a room.
   */
  void join(String room) {
    // TODO
  }

  /**
   * Leave a room.
   */
  void leave(String room) {
    // TODO
  }

  /**
   * Leave all rooms.
   */
  void leaveAll() {
    // TODO
  }

  /**
   * Called by `Namespace` upon succesful
   * middleware execution (ie: authorization).
   */
  void onConnect() {
    // TODO
  }

  /**
   * Called with each packet. Called by `Client.`
   */
  void onPacket(Packet packet) {
    // TODO
  }

  /**
   * Called upon event packet.
   */
  void onEvent(Packet packet) {
    // TODO
  }

  /**
   * Produces an ack callback to emit with an event.
   */
  void ack(String id) {
    // TODO
  }

  /**
   * Called upon ack packet.
   */
  void onAck(Packet packet) {
    // TODO
  }

  /**
   * Called upon client disconnect packet.
   */
  void onDisconnect() {
    // TODO
  }

  /**
   * Handles a client error.
   */
  void onError(String err) {
    // TODO
  }

  /**
   * Called upon closing. Called by `Client`.
   */
  void onClose(String reason) {
    // TODO
  }

  /**
   * Produces an `error` packet.
   */
  void error() {
    // TODO
  }

  /**
   * Disconnects this client.
   *
   * @param {Boolean} if `true`, closes the underlying connection
   */
  void disconnect(bool close) {
    // TODO
  }

}