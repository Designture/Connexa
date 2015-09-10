library connexa.example;

import 'package:connexa/connexa.dart';

main() {
  // create a new Connexa instance
  Connexa.listen(null, 8080, {'debug': true}).then((Server server) {
    server.on('connection', (Socket socket) {
      print("New client connected > " + socket.id);

      socket.on('close', (Socket socket) {
        print('Client socket closed > ' + socket.id);
      });
    });
  });
}
