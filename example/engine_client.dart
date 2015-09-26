import 'package:connexa/client_engine.dart';
import 'dart:html';

main() {
  ButtonElement btn = querySelector("#btn");
  DivElement panel = querySelector("#panel");
  InputElement input = querySelector("#input");

  // Open a new Connexa connection
  Engine socket = new Engine('ws://127.0.0.1:8080/socket.io');

  socket.on('open', () {
    socket.on('message', (msg) {
      panel.appendHtml("<p>Server: ${msg}</p>");
    });

    // send a new message to the server when the user
    // click on the button
    btn.onClick.listen((_) {
      socket.send({'msg': input.value});
    });

    socket.on('close', () {
      panel.appendHtml("<p>Server is now closed!</p>");
    });
  });
}