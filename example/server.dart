import 'package:connexa/server.dart';

main() {
  Server server = new Server(null, {'debug': true});

  server.on('connection', (Socket socket) {
    print('new user connected - ${socket.id}');

    socket.on('chat', (String msg) {
      server.emit('chat', 'Pre-' + msg);
    });
  });

  server.listen(8080);
}