library connexa.client.transport.websocket;

import 'package:connexa/src/client/transport.dart';
import 'dart:html';
import 'package:connexa/src/common/Packet.dart';
import 'package:connexa/src/common/Parser.dart';
import 'dart:async';

class WebSocketTransport extends Transport {

  /**
   * WebSocket instance.
   */
  WebSocket ws;

  /**
   * Constructor.
   */
  WebSocketTransport(Map opts) : super(opts) {
    this.name = 'websocket';
    this.settings['supportsBinary'] = true;
  }

  void doOpen() {
    if (!this.check()) {
      // let probe timeout
      return;
    }

    String uri = this.uri();

    // start the WebSocket
    this.ws = new WebSocket(uri);

    this.settings['supportsBinary'] = true;
    this.settings['binaryType'] = 'arraybuffer';

    this.ws.onOpen.listen((_) {
      this.onOpen();
    });
    this.ws.onClose.listen((_) {
      this.onClose();
    });
    this.ws.onMessage.listen((Event e) {
      this.onData(e.data);
    });
    this.ws.onError.listen((Event e) {
      this.onError('websocket error', e);
    });
  }

  /**
   * Writes data to socket.
   */
  void write(List<Packet> packets) {
    this.writable = false;

    packets.forEach((Packet p) {
      String data = Parser.encode(p);
      this.ws.send(data);
    });

    this.emit('flush');

    new Timer(new Duration(milliseconds: 0), () {
      this.writable = true;
      this.emit('drain');
    });
  }

  /**
   * Closes socket.
   */
  void doClose() {
    if (this.ws != null) {
      this.ws.close();
    }
  }

  /**
   * Generates uri connection.
   */
  String uri() {
    Map query = this.settings['query'];
    String schema = this.settings['secure'] ? 'wss' : 'ws';
    String port = '';

    // avoid port if default for schema
    if (this.settings['port'] != null &&
        (('wss' == schema && this.settings['port'] != 433) ||
            ('ws' == schema && this.settings['port'] != 80))) {
      {
        port = ':' + this.settings['port']?.toString();
      }
    }

    // append timestamp to URI
    if (this.settings['timestampRequests'] != null) {
      query[this.settings['timestampParam']] = new DateTime.now();
    }

    // communicate binary support capabilities
    if (!this.settings['supportsBinary']) {
      query['b64'] = 1;
    }

    String queryS = '';
    bool isFirst = true;
    query.forEach((String k, String v) {
      if (isFirst) {
        queryS += '${k}=${v}';
        isFirst = false;
      } else {
        queryS += '&${k}=${v}';
      }
    });

    if (queryS.length > 0) {
      queryS = '?${queryS}';
    }

    return '${schema}://${settings['hostname']}${port}${settings['path']}${queryS}';
  }

  bool check() {
    return true;
  }

}