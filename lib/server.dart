library connexa;

import 'dart:io';
import 'dart:async';
import 'package:connexa/src/server/Server.dart';

export 'src/server/Server.dart';
export 'src/server/Socket.dart';

class Connexa {

  /**
   * Version.
   */
  static const String version = '0.1.0';

  /**
   * Attaches a IPv4 manager.
   *
   *
   * @param {HttpServer} a HTTP/S server
   * @param {int} port here the server will listen for requests
   * @param {Map} opts to be passed to Manager and/or http server
   * @api public
   */
  static Future<Server> listen(
      [HttpServer server, int port = 8080, options = const {}]) async {
    if (server == null) {
      server = await HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port);
    }

    // create a new Manager instance
    return new Server(server, options);
  }

  /**
   * Attaches a IPv6 manager.
   *
   * @param {HttpServer} a HTTP/S server
   * @param {int} port here the server will listen for requests
   * @param {Map} opts to be passed to Manager and/or http server
   * @api public
   */
  static Future<Server> listenV6(
      [HttpServer server, int port = 8080, options = const {}]) async {
    if (server == null) {
      server = await HttpServer.bind(InternetAddress.ANY_IP_V6, port);
    }

    // create a new Manager instance
    return new Server(server, options);
  }

}
