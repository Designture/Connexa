library connexa.stores.memory;

import 'package:connexa/src/Store.dart';
import 'dart:async';

class _MemoryClient implements Client {

  MemoryStore store;
  String id;
  Map<String, Object> _data = new Map();

  _MemoryClient(this.store, this.id);

  /**
   * gets a key [key].
   */
  Future<Object> get(String key) => new Future.value(_data[key]);

  /**
   * Sets a [key] with [value].
   */
  Future<bool> set(String key, Object value) {
    _data[key] = value;
    return new Future.value(true);
  }

  /**
   * Delete a [key].
   */
  Future<int> del(String key) {
    _data.remove(key);
    return new Future.value(1);
  }

  /**
   * Has a [key]?
   */
  Future<bool> has(String key) => new Future.value(_data.containsKey(key));

  /**
   * Destroy client.
   */
  void destroy([int expiration]) {
    if (expiration != null) {
      Duration TIMEOUT = const Duration(seconds: expiration);
      new Timer(TIMEOUT, () => _data.clear());
    } else {
      _data.clear();
    }
  }
}

class MemoryStore extends Store {

  MemoryStore([Map options = const {}]) : super(options);

  Client createClient(Store store, String id) => new _MemoryClient(store, id);

  publish(String name, [data]) {}

  subscribe(String name, Function fn) {}

  unsubscribe(String name) {}

}