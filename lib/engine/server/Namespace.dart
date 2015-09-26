library connexa.namespace;

import 'package:connexa/engine/server/Server.dart';
import 'package:connexa/engine/server/Socket.dart';
import 'package:logging/logging.dart';
import 'package:connexa/engine/common/Packet.dart';
import 'package:connexa/engine/common/Parser.dart';
import 'package:eventus/eventus.dart';

class SocketNamespace extends Eventus {

  Server _server;
  String _name;
  Map<String, Socket> _sockets = new Map();
  Map<String, Object> _flags;
  Function _auth;

  SocketNamespace(this._server, [this._name = '']) {
    this.setFlags();
  }

  Logger get log => _server.log;

  Store get store => _server.store;

  SocketNamespace get json {
    _flags['json'] = true;
    return this;
  }

  SocketNamespace get volatile {
    _flags['volatile'] = true;
    return this;
  }

  set to(String room) {
    _flags['endpoint'] = '_name${room != null ? '/$room' : ''}';
  }

  /**
   * Adds a session if we should prevent replaying messages to (flag).
   */
  set except(String id) {
    _flags['exceptions'].addLast(id);
  }

  /**
   * Sets the default flags.
   */
  void setFlags() {
    _flags = {
      'endpoint': _name,
      'exceptions' : []
    };
  }

  set authorization(Function fn) => _auth = fn;

  /**
   * Send out a packet.
   */
  void _packet(Packet packet) {
    packet.endpoint = this._name;

    var volatile = this._flags.volatile;
    var exceptions = this._flags.exception;
    var packet = Parser.encode(packet);

    // send the packet
    this._server.onDispatch(
        _flags['endpoint'], packet, _flags['volatile'], exceptions);
    store.publish(
        'dispatch', this._flags.endpoint, packet, volatile, exceptions);

    // reset flags
    setFlags();
  }

  /**
   * Sends to everyone.
   */
  void send(Map data) =>
      this._packet({'type': _flags.json ? 'json' : 'message', 'data': data});

  /**
   * Emit to everyone.
   */
  emit(String name, [data]) {
    return this._packet({
      'type': 'event',
      'name': name,
      'args': data
    });
  }

  /**
   * Retrieves or creates a write-only socket for a client, unless specified.
   *
   * @param {Boolean} whether the socket will be readable when initialized
   */
  Socket socket(String sid, [bool readable = false]) {
    return this._sockets.putIfAbsent(sid, () {
      new Socket(_server, sid, this, readable);
    });
  }

  /**
   * Called when a socket disconnects entirely.
   */
  void _handleDisconnect(String sid, reason, bool raiseOnDisconnect) {
    if (_sockets.containsKey(sid) && _sockets[sid].readable) {
      if (raiseOnDisconnect) {
        _sockets[sid].onDisconnect(reason);
      }
      _sockets.remove(sid);
    }
  }

  void _authorize(data, callback(Function error, bool authorized, [data])) {
    if (_auth != null) {
      _auth(data, (err, authorized) {
        log.fine('client' + (authorized ? '' : 'un') + 'authorized for $name');
        callback(err, authorized);
      });
    } else {
      log.fine('client authorized for $_name');
      callback(null, true);
    }
  }

  /**
   * Handles a packet.
   */
  void handlePacket(String sessid, Packet packet) {
    Socket socket = this.socket(sessid);
    bool dataAck = packet.ack == 'data';

    var ack = () {
      log.fine('sending data ack packet');
      socket.packet({
        'type': 'ack',
        'args': args,
        'ackId': packet.id
      });
    };

    var error = (String err) {
      log.warning('handshake error $err for $_name');
      socket.packet({'type':'error', 'reason':err});
    };

    var connect = () {
      _server.onJoin(sessid, _name);
      store.publish('join', sessid, _name);

      // packet echo
      socket.packet({'type': 'connect'});

      emit('connection', socket);
    };

    switch (packet.type) {
      case 'connect':
        if (packet.endpoint == '') {
          connect();
        } else {
          Object handshakeData = _server.handshaken[sessid];

          _authorize(handshakeData, (Function err, bool authorized, [newData]) {
            if (err != null) {
              return error(err);
            }

            if (authorized) {
              Map data = new Map.from(newData);
              _server.onHandshake(sessid, data);
              connect();
            } else {
              error('unauthorized');
            }
          });
        }
        break;

      case 'ack':
        if (socket._acks.containsKey(packet.ackId)) {
          socket._acks[packet.ackId](socket, packet.args);
        } else {
          log.info('unknown ack packet');
        }
        break;

      case 'event':
        if (_server.get('blacklist').indexOf(packet.name)) {
          log.fine('ignoring backlisted event `${packet.name}`');
        } else {
          List params = packet.args;

          if (dataAck) {
            params.add(ack);
          }

          socket.emit(packet.name, params);
        }
        break;

      case 'disconnect':
        this._server.onLeave(sessid, _name);
        this.store.publish('leave', sessid, _name);

        socket.emit('disconnect', packet.reason ?? 'packet');
        break;

      case 'json':
      case 'message':
        List params = [packet.data];

        if (dataAck) {
          params.add(ack);
        }

        socket.emit('messae', params);
        break;
    }
  }

}