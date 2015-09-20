library connexa.example;

import 'package:connexa/server.dart';

main() {
  Connexa.listen(null, 8080, {'debug': true}).then((Server server) {
    server.on('connection', (Socket socket) {
      socket.on('chat message', (msg) {
        server.emit('chat message', msg);
      });

      socket.on('disconnect', (_) {
        server.emit('user disconnected');
      });
    });
  });
}
