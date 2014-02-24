library dartchat;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mime_type/mime_type.dart';

final HOST = "127.0.0.1";
final PORT = 3001;

main() =>
  HttpServer.bind(HOST, PORT).then((server){
    final sockets = new WebSockets();
    final chatBackend = new ChatBackend(sockets);
    final serveStatic = new ServeStatic();

    server.listen((request) {
      if(request.uri.path == '/ws')
        sockets.handleRequest(request);
      else
        serveStatic.handleRequest(request);
    });
  });


class ServeStatic {
  void handleRequest(HttpRequest request){
    final path = request.uri.path;
    final file = getFile(path);

    file.exists().then((exists){
      if(exists){
        sendFile(request.response, file);
      } else {
        render404(request.response);
      }
    });
  }

  getFile(path){
    final filePath = path == "/" ? "./public/index.html" : "./public${path}";
    return new File(filePath);
  }

  sendFile(HttpResponse response, File file){
    response.headers.set('Content-Type', mime(file.path));
    file.openRead().pipe(response).catchError((_) => render404(response));
  }

  render404(HttpResponse response){
    response.statusCode = HttpStatus.NOT_FOUND;
    response.write("Error 404: resource not found.");
    response.close();
  }
}


class ChatBackend {
  WebSockets sockets;
  Map users = {};

  ChatBackend(this.sockets){
    sockets.onNewConnection.listen(onNewConnection);;
  }

  void onNewConnection(conn){
    registerGuest(conn);
    setUpListener(conn);
  }

  registerGuest(conn){
    var name = "Guest ${users.length + 1}";
    users[conn] = {"name": name};
    sockets.broadcast(conn, {"type" : "newUser", "name" : name});
  }

  setUpListener(conn){
    sockets.onMessage(conn).listen((m){
      if(m["type"] == "message"){
        sockets.broadcast(conn, {
            "type" : "newMessage",
            "name" : users[conn]["name"],
            "text" : m["text"]
        });
      }
    });
  }
}

/**
* A wrapper around WebSocket to provide a socketio like API.
*/
class WebSockets {
  List<WebSocket> sockets = [];
  StreamController controller;
  Stream<WebSocket> onNewConnection;

  WebSockets(){
    controller = new StreamController();
    onNewConnection = controller.stream.
    transform(new WebSocketTransformer()).
    map((conn){sockets.add(conn); return conn;});
  }

  Stream<Map> onMessage(WebSocket conn) => conn.map(JSON.decode);

  void broadcast(WebSocket conn, Map message){
    final m = JSON.encode(message);
    sockets.where((_) => _ != conn).forEach((_) => _.add(m));
  }

  void handleRequest(HttpRequest request) => controller.add(request);
}
