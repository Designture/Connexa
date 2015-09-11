library connexa.example;

import 'package:connexa/server.dart';

main() {
  // create a new Connexa instance
  Connexa.listen(null, 8080, {'debug': true, 'pingTimeout': 3000})
      .then((Server server) {
    server.on('connection', (Socket socket) {
      print("New client connected > " + socket.id);

      socket.emit('new message', 'something');

      socket.on('close', (_) {
        print('Client socket closed');
      });
    });
  });
}
