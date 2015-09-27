library connexa.example;

import 'package:connexa/server_engine.dart';

main() {
  ConnexaEngine.listen(port: 8080).then((ServerEngine server) {
    server.on('connection', (SocketEngine socket) {
      socket.on('message', (msg) {
        socket.send({'msg': msg['msg'] + '-S'});
      });

      socket.on('disconnect', (_) {
        server.emit('user disconnected');
      });
    });
  });
}
