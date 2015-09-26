part of connexa.surface.server;

enum NamespaceEvents {
  connect,
  connection,
  newListener
}

/**
 * Flags
 */
enum NamespaceFlags {
  json,
  volatile
}

class Namespace extends Eventus {

  String _name;
  Server _server;
  List<Socket> sockets = [];
  int ids = 0;

  /**
   * Namespace constructor.
   */
  Namespace(Server this._server, String this._name) {}

  /**
   * Adds a new client.
   */
  void add(Client client) {
    // TODO
  }

  /**
   * Removes a client. called by each `Socket`.
   */
  void remove(Socket socket) {
    // TODO
  }

  /**
   * Emits to all clients.
   */
  void emit(String event, [arg1, arg2, arg3]) {
    // TODO
  }

  /**
   * Targets a room when emitting.
   */
  void to(String name) {
    // TODO
  }

}