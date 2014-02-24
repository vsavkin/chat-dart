library chat;

import 'dart:html';
import 'dart:convert';
import 'dart:async';
import 'package:angular/angular.dart';

main(){
  final module = new Module()
    ..type(ChatController)
    ..value(Socket, new Socket("ws://127.0.0.1:3001/ws"));

  ngBootstrap(module: module);
}

class Chat {
  List messages = [];

  void newUser(Map message) =>
  addMessage("${message["name"]} just joined the chat!");

  void newMessage(Map message) =>
  addMessage("${message["name"]}: ${message["text"]}");

  addMessage(message) =>
  messages.add({"timestamp": new DateTime.now(), "text": message});
}


@NgController(selector: '[chat-ctrl]', publishAs: 'ctrl')
class ChatController {
  @NgTwoWay("message") String message;

  Chat chat = new Chat();
  Socket socket;

  ChatController(this.socket){
    socket.onMessage.listen(handleMessage);
  }

  void handleMessage(Map message){
    final handlers = {"newUser": chat.newUser, "newMessage": chat.newMessage};
    handlers[message["type"]](message);
  }

  void sendMessage(){
    chat.newMessage({"name": "You", "text": message});
    socket.sendMessage({"type": "message", "text": message});
    message = "";
  }
}

/**
* A wrapper around WebSocket to provide a socketio like API.
*/
class Socket {
  WebSocket webSocket;

  Socket(String url){
    webSocket = new WebSocket(url);
  }

  Stream<Map> get onMessage =>
  webSocket.onMessage.
  map((_) => _.data).
  map(JSON.decode);

  void sendMessage(Map message) => webSocket.sendString(JSON.encode(message));
}
