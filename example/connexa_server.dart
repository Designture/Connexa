library connexa.example;

import 'package:connexa/server.dart';

main() {
  Connexa.listen(null, 8080, {'debug': true}).then((Server server) {
    server.on('connection', (Socket socket) {
      socket.on('message', (msg) {
        socket.send({'msg': msg['msg']});
      });

      socket.on('disconnect', (_) {
        server.emit('user disconnected');
      });
    });
  });
}
