import 'package:connexa/client.dart';

main() {
  Connexa socket = new Connexa('ws://127.0.0.1:8080/socket.io', {'debug': true});

  socket.on('new message', (msg) {
    print("=> ${msg}");
  });
}