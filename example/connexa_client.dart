import 'package:connexa/client.dart';
import 'dart:html';

main() {
  ButtonElement btn = querySelector("#btn");
  DivElement panel = querySelector("#panel");
  InputElement input = querySelector("#input");

  // Open a new Connexa connection
  Socket socket = Connexa.listen('ws://127.0.0.1:8080/socket.io', {'debug': true});

  socket.on('connect', () {
    // send a new message to the server when the user
    // click on the button
    btn.onClick.listen((_) {
      socket.emit('chat', input.value);
    });
  });

  socket.on('chat', (msg) {
    panel.appendHtml("<p>Server: ${msg}</p>");
  });

  socket.on('disconnect', () {
    panel.appendHtml("<p>Server is now closed!</p>");
  });
}