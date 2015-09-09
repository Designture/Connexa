library connexa.socket;

import 'package:connexa/src/EventEmiter.dart';
import 'dart:async';
import 'package:connexa/src/Server.dart';
import 'package:connexa/src/Namespace.dart';
import 'package:connexa/src/Store.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Parser.dart';

/**
 * Client class.
 *
 * @api private
 */
class Socket extends EventEmitter {

  String _id;
  SocketNamespace _namespace;
  Client _store;
  Server _manager;
  bool _readable = false;
  bool _disconnected = false;
  int _ackPackets = 0;
  Map<int, Function> _acks = new Map();
  Map<String, Object> _flags;

  Socket(String this._id, Server this._manager, this._namespace,
      this._readable) {
    _manager.store.client(_id);
    this.on('error', defaultError);
  }

  /**
   * Accessor shortcut for the handshake data.
   */
  get handshake => _manager.handshaken[_id];

  /**
   * Accessor shortcut for the transport type.
   */
  get transport => _manager.transports[_id].name;

  /**
   * Accessor shortcut for the logger.
   */
  Logger get log => _manager.log;

  /**
   * JSON message flag.
   */
  get json => _flags.json = true;

  /**
   * Volatile message flag.
   */
  get volatile => _flags.volatile = true;

  /**
   * Broadcast message flag.
   */
  get broadcast => _flags.broadcast = true;

  /**
   * Overrides the room to broadcast messages to (flag)
   */
  set to(String room) => _flags.room = room;

  /**
   * Resets flags.
   */
  _setFlags() {
    _flags = {
      'endpoint': _namespace.name,
      'room': ''
    };
  }

  /**
   * Triggered on disconnect.
   */
  _onDisconnect(reason) {
    if (!_disconnected) {
      super.emit('disconnected', reason);
      _disconnected = true;
    }
  }

  /**
   * Joins user to a room.
   */
  join(String name) {
    name = '${_namespace.name}/${name}';
    _manager.onJoin(_id, name);
    _manager.store.publish('join', _id, name);
    return this;
  }

  /**
   * Un-joins a user from a room.
   */
  leave(String name) {
    name = '${_namespace.name}/${name}';
    _manager.onLeave(_id, name);
    _manager.store.publish('join', _id, name);
    return this;
  }

  /**
   * Transmits a packet.
   */
  _packet(Map packet) {
    if (_flags['broadcast']) {
      log.fine('broadcasting packet');
      _namespace.to(_flags['room']).except(_id).packet(packet);
    } else {
      packet.endpoint = _flags['endpoint'];
      packet = Parser.encodePacket(packet);

      _dispatch(packet, _flags['volatile']);
    }
    _setFlags();
  }

  /**
   * Dispatches a packet.
   */
  _dispatch(Object packet, bool volatile) {
    if (_manager.transports[_id] && _manager.transports[_id].open) {
      _manager.transports[_id].onDispatch(packet, volatile);
    } else {
      if (!volatile) {
        _manager.onClientDispatch(_id, packet, volatile);
      }
      _manager.store.publish('dispatch:$_id', packet, volatile);
    }
  }

  /**
   * Stores data for the client.
   */
  Future<bool> set(key, value, fn) => _store.set(key, value);

  /**
   * Retrieves data for the client
   */
  Future<Object> get(key) => _store.get(key);

  /**
   * Checks data for the client
   */
  Future<bool> has(key) => _store.has(key);

  /**
   * Deletes data for the client
   */
  Future<int> del(key) => _store.del(key);

  /**
   * Kicks client.
   */
  disconnect() {
    if (!_disconnected) {
      log.info('booting client');
      if (_namespace.name.isEmpty()) {
        if (_manager.transports.containsKey(_id) &&
            _manager.transports[_id].open) {
          _manager.transports[_id].onForcedDisconnect();
        } else {
          _manager.onClientDisconnect(_id);
          _manager.store.publish('disconnect:$_id');
        }
      } else {
        _packet({ 'type': 'disconnect'});
        _manager.onLeave(_id, _namespace.name);
        super.emit('disconnect', 'booted');
      }
    }
  }

  /**
   * Send a message.
   */
  send(Object data, [Function ack]) {
    Map packet = {
      'type': _flags['json'] ? 'json' : 'message',
      'data': data
    };

    if (ack != null) {
      packet.id = ++_ackPackets;
      packet.ack = true;
      _acks[packet.id] = ack;
    }

    _packet(packet);
  }

  emit(String event, [data]) {
    if (event == 'newListener') {
      super.emit(event, data);
    }

    var lastArg = data[data.length - 1];
    var packet = {
      'type': 'event',
      'name': event
    };

    if (lastArg is Function) {
      packet.id = ++this.ackPackets;
      packet.ack = lastArg.length ? 'data' : true;
      this.acks[packet.id] = lastArg;
      data = data.slice(0, args.length - 1);
    }

    packet.args = data;
    _packet(packet);
  }
}