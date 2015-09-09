library connexa;

import 'dart:io';
import 'package:connexa/src/Server.dart';

export 'src/Server.dart';

class Connexa {

  /**
   * Version.
   */
  static const String version = '0.0.1';

  /**
   * Attaches a IPv4 manager.
   *
   *
   * @param {HttpServer} a HTTP/S server
   * @param {int} port here the server will listen for requests
   * @param {Map} opts to be passed to Manager and/or http server
   * @api public
   */
  static listen([HttpServer server, int port = 8080, options = const {}]) {
    if (server == null) {
      HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port)
          .then((HttpServer newServer) {
        // save server instance
        server = newServer;

        // config default request handler
        server.listen(_listenHandler);
      });
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
  static listenV6([HttpServer server, int port = 8080, options = const {}]) {
    if (server == null) {
      HttpServer.bind(InternetAddress.ANY_IP_V6, port)
          .then((HttpServer newServer) {
        // save server instance
        server = newServer;

        // config default request handler
        server.listen(_listenHandler);
      });
    }

    // create a new Manager instance
    return new Server(server, options);
  }

  static _listenHandler(HttpRequest request) {
    // get response object
    HttpResponse response = request.response;

    // prepare response
    response.headers.add("Content-Type", "text/html; charset=UTF-8");
    response.write(
        "Welcome to Connexa supported by <a target=\"_blank\" href=\"https://designture.net\">Designture</a>!");

    // send response
    response.close();
  }

}
