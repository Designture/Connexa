import 'package:connexa/client.dart';
import 'dart:html';

main() {
  ButtonElement btn = querySelector("#btn");
  DivElement panel = querySelector("#panel");
  InputElement input = querySelector("#input");

  // Open a new Connexa connection
  Connexa socket = new Connexa('ws://127.0.0.1:8080/socket.io');

  // listen server messages
  socket.on('chat message', (msg) {
    panel.appendHtml("<p>Server: ${msg}</p>");
  });

  // send a new message to the server when the user
  // click on the button
  btn.onClick.listen((_) {
    socket.emit('chat message', input.value);
  });
}