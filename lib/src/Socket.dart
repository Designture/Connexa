library connexa.socket;

import 'package:connexa/src/Server.dart';
import 'package:logging/logging.dart';
import 'package:connexa/src/Parser.dart';
import 'package:events/events.dart';
import 'package:connexa/src/Packet.dart';

enum SocketStates {
  opening,
  open,
  upgrade,
  closed,
  closing
}

/**
 * Client class.
 *
 * @api private
 */
class Socket extends Events {

  String _id;
  Server _manager;
  WebSocket socket;
  SocketStates readyState = SocketStates.opening;
  Map<int, Function> _acks = new Map();

  Socket(String this._id, Server this._manager) {

  }

  get id => _id;

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
  _packet(Packet packet) {
    // export packetCreate event
    this.emit('packetCreate', packet);

    // encode the packet
    String encodedPacket = Parser.encode(packet);

    // send the packet
    this._manager.sendToClient(this._id, encodedPacket);
  }

  /**
   * Kicks client.
   */
  void disconnect() {
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
  send(PacketTypes type, Object data, [Function ack]) {
    // build the packet
    Packet packet = new Packet();

    // add the packet type
    packet.type = type;

    // add the packet data
    packet['data'] = data;

    // send it
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