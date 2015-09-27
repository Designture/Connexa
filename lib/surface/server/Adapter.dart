part of connexa.surface.server;

/**
 * Memory adapter
 */
class Adapter extends Eventus {

  Namespace _namespace;
  Map<String, Map<String, bool>> _sids = new Map();
  Map<String, Map<String, bool>> _rooms = new Map();

  /**
   * Constructor.
   */
  Adapter(Namespace this._namespace);

  /**
   * Adds a socket to a room.
   *
   * @param {String} socket id
   * @param {String} room name
   * @param {Function} callback
   */
  void add(String id, String room, [Function fn = null]) {
    this._sids.putIfAbsent(id, () => new Map());
    this._sids[id][room] = true;
    this._rooms.putIfAbsent(room, () => new Map());
    this._rooms[room][id] = true;

    if (fn != null) {
      Timer.run(() => fn(null, null));
    }
  }

  /**
   * Removes a socket from a room.
   *
   * @param {String} socket id
   * @param {String} room name
   * @param {Function} callback
   */
  void del(String id, String room, [Function fn = null]) {
    this._sids.putIfAbsent(id, () => new Map());
    this._rooms.putIfAbsent(room, () => new Map());
    this._sids[id].remove(room);
    this._rooms[room].remove(id);

    if (this._rooms[room].isEmpty) {
      this._rooms.remove(room);
    }

    if (fn != null) {
      Timer.run(() => fn(null, null));
    }
  }

  /**
   * Removes a socket from all rooms it's joined.
   *
   * @param {String} socket id
   * @param {Function} callback
   */
  void delAll(String id, [Function fn = null]) {
    Map rooms = this._sids[id];
    if (rooms != null) {
      rooms.forEach((String room, _) {
        if (rooms.containsKey(room)) {
          this._rooms[room].remove(id);
        }

        if (this._rooms.containsKey(room) && this._rooms[room].isEmpty) {
          this._rooms.remove(room);
        }
      });
    }

    this._sids.remove(id);

    if (fn != null) {
      Timer.run(() => fn(null, null));
    }
  }

  /**
   * Broadcasts a packet.
   *
   * Options:
   *  - `flags` {Object} flags for this packet
   *  - `except` {Array} sids that should be excluded
   *  - `rooms` {Array} list of rooms to broadcast to
   */
  void broadcast(Packet packet, Map opts) {
    List<String> rooms = opts.containsKey('rooms') ? opts['rooms'] : [];
    List<String> except = opts.containsKey('except') ? opts['except'] : [];
    Map flags = opts.containsKey('flags') ? opts['flags'] : {};

    Map packetOpts = {
      'preEncoded': true,
      'volatile': flags['volatile'],
      'compress': flags['compress']
    };

    Map ids = {};
    Socket socket;

    packet.namespace = this._namespace._name;
    Parser.encode(packet, (String encoded) {
      if (this._rooms.isNotEmpty) {
        this._rooms.forEach((String roomN, Map room) {
          for (String id in room) {
            if (ids.containsKey(id) || except.contains(id)) {
              continue;
            }

            if (socket != null) {
              socket.packet(encoded, packetOpts);
              ids[id] = true;
            }
          }
        });
      } else {
        for (String id in this._sids) {
          if (this._sids.containsKey(id)) {
            if (except.contains(id)) {
              continue;
            }
            socket = this._namespace.connected[id];
            if (socket != null) {
              socket.packet(encoded, packetOpts);
            }
          }
        }
      }
    });
  }

  /**
   * Gets a list of clients by sid.
   *
   * @param {Array} explicit set of rooms to check.
   */
  void clients([List rooms = const [], Function fn]) {
    Map<String, bool> ids = {};
    List<String> sids = [];
    Socket socket;

    if (rooms.isNotEmpty) {
      this._rooms.forEach((String roomN, Map room) {
        if (room == null) {
          return;
        }

        for (String id in room) {
          if (ids.containsKey(id)) {
            continue;
          }
          socket = this._namespace.connected[id];
          if (socket != null) {
            sids.add(id);
            ids[id] = true;
          }
        }
      });
    } else {
      for (String id in this._sids) {
        socket = this._namespace.connected[id];
        if (socket != null) {
          sids.add(id);
        }
      }
    }

    if (fn != null) {
      Timer.run(() => fn(null, null, sids));
    }
  }

}