part of connexa.surface.server;

class Client {

  Server _server;
  Socket _connection;

  String get id => null;

  Client(Server this._server, Socket this._connection) {

  }

  /**
   * Connects a client to a namespace.
   */
  void connect(String name) {
    // TODO
  }

  /**
   * Disconnects from all namespaces and closes transport.
   */
  void disconnect() {
    // TODO
  }

  /**
   * Removes a socket. Called by each `Socket`.
   */
  void remove(Socket socket) {
    // TODO
  }

  /**
   * Closes the underlying connection.
   */
  void close() {
    // TODO
  }

  /**
   * Writes a packet to the transport.
   */
  void packet(Packet packet) {
    // TODO
  }

  /**
   * Called with incoming transport data.
   */
  void onData(String data) {
    // TODO
  }

  /**
   * Called when parser fully decodes a packet.
   */
  void onDecoded() {
    // TODO
  }

  /**
   * Handles an error.
   */
  void onError() {
    // TODO
  }

  /**
   * Called upon transport close.
   */
  void onClose() {
    // TODO
  }

  /**
   * Cleans up event listeners.
   */
  void destroy() {
    // TODO
  }

}