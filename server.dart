library dartchat;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mime_type/mime_type.dart';
import 'package:http_server/http_server.dart' show VirtualDirectory;

final HOST = "127.0.0.1";
final PORT = 3001;

main() {
  HttpServer.bind(HOST, PORT).then((server){
    final sockets = new WebSockets();
    final chatBackend = new ChatBackend(sockets);
    var root = Platform.script.resolve('./public').toFilePath();
    final vDir = new VirtualDirectory(root)
        ..followLinks = true
        ..allowDirectoryListing = true
        ..jailRoot = false;

    server.listen((request) {
      if(request.uri.path == '/ws') {
        sockets.handleRequest(request);
      } else {
        vDir.serveRequest(request);
      }

    });
  });
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
