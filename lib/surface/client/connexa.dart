import 'package:connexa/client.dart';

class Connexa {

  Map managers = {};

  static Socket listen([String uri, Map opts = const {}]) {
    // TODO: add a cache mechanism

    Manager io = new Manager(uri, opts);
    return io.socket('/');
  }

}