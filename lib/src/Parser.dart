library connexa.parser;

import 'dart:convert';

/**
 * Message types enumeration.
 */
enum MsgTypes {
  connect,
  disconnect,
  event,
  ack,
  error
}

class Parser {

  static String encode(obj) {
    var content = '';
    var namespace = false;

    // fist if the type
    content += obj.type;

    // if we have a namespace other than '/'
    // we append it followed by a comma ','
    if (obj.nsp && '/' != obj.nsp) {
      namespace = true;
      content += obj.nsp;
    }

    // immediately followed by the id
    if (null != obj.id) {
      if (namespace) {
        content += ',';
        namespace = false;
      }

      content += obj.id;
    }

    // json data
    if (null != obj.data) {
      if (namespace) {
        content += ',';
        content += JSON.encode(obj.data);
      }
    }

    return content;
  }

  static Map decode(String content) {
    Map decoded = new Map();
    int i = 0;

    // look up type
    decoded.type = int.parse(content[0]);

    if (MsgTypes.values[decoded.type] == null) {
      return error();
    }

    if (content[i + 1] == '/') {
      decoded.namespace = '';
      while (++i) {
        var c = content[i];
        if (c == ',') {
          break;
        }
        decoded.namespace += c;
        if (content.length == i + 1) {
          break;
        }
      }
    } else {
      decoded.namespace = '/';
    }

    // look up id
    var next = content[i + 1];
    if (next != '' && int.parse(next) == next) {
      decoded.id = '';

      while (++i) {
        var c = content[i];

        if (c == null || int.parse(c) != c) {
          --i;
          break;
        }

        decoded.id = content[i];
        if (i + 1 == content.length) {
          break;
        }
        decoded.id = int.parse(decoded.id);
      }
    }

    // loop up json data
    if (content[++i]) {
      try {
        decoded.data = JSON.decode(content.substring(i));
      } on FormatException catch (e) {
        return error();
      }
    }


    return decoded;
  }

  static Map error() {
    return {
      'type': MsgTypes.error,
      'data': 'parser error'
    };
  }

}