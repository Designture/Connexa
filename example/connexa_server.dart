library connexa.example;

import 'package:connexa/server_engine.dart';

main() {
  Connexa.listen(null, 8080).then((Server server) {
    server.on('connection', (Socket socket) {
      socket.on('message', (msg) {
        socket.send({'msg': msg['msg'] + '-S'});
      });

      socket.on('disconnect', (_) {
        server.emit('user disconnected');
      });
    });
  });
}
