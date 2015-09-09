library connexa.store;

import 'dart:async';

/**
 * Client interface
 */
abstract class Client {
  Store store;
  String id;

  Client(this.store, this.id);

  /**
   * Gets a key [key].
   */
  Future<Object> get(String key);

  /**
   * Sets a key [key] with value [value].
   */
  Future<bool> set(String key, Object value);

  /**
   * Deletes a key [key];
   */
  Future<int> del(String key);

  /**
   * Has a key [key]?
   */
  Future<bool> has(String key);

  /**
   * Destroys the client in [expiration] seconds.
   */
  void destroy([int expiration]);

}

/**
 * Store interface.
 */
abstract class Store {
  Map<String, Client> clients = new Map();

  Store([options = const {}]);

  /**
   * Initializes a client store with id [id].
   */
  Client client(String id) {
    if (!clients.containsKey(id)) {
      clients[id] = _createClient(this, id);
    }

    return clients[id];
  }

  Client _createClient(Store store, String id);

  /**
   * Destroys a client with id [id], client data will expire in [expiration]
   * seconds.
   */
  void destroyClient(String id, [int expiration]) {
    if (clients.containsKey(id)) {
      clients[id].destroy(expiration);
      clients.remove(id);
    }
  }

  /**
   * Destroys the store, client data will expire in [expiration] seconds.
   */
  void destroy([int expiration]) {
    clients.values.forEach((c) => destroyClient(c.id, expiration));
    clients.clear();
  }

  publish(String name, [data]);

  subscribe(String name, Function fn);

  unsubscribe(String name);
}