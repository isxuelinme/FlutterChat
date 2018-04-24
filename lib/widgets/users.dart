import 'package:flutter/material.dart';
import 'dart:async';

import '../server.dart';
import '../user.dart';
import '../util.dart';
import '../conversation.dart';

import 'package:flutterchat/widgets/chat.dart';
import 'package:flutterchat/widgets/loading.dart';

class Users extends StatefulWidget {
  final User user;
  final Server server;

  Users({this.user, this.server});

  @override
  UsersState createState() => new UsersState();
}

class UsersState extends State<Users> {
  List<String> _onlineUsers;
  Map<String, Conversation> _conversations = new Map<String, Conversation>();

  final TextStyle _biggerFont = const TextStyle(fontSize: 18.0);

  Future<Null> _getUsers() async {
    Completer<Null> completer = new Completer<Null>();

    widget.server.getUsers((response) {
      RegExp listRegex = new RegExp(r"WHO\s*\[((?:'[^']*',?\s*)*)\]");
      Match listMatch = listRegex.firstMatch(response);

      if (listMatch == null) return;

      // TODO: Simpler quote removal
      List<String> matchList = listMatch[1].split(',');
      RegExp nameRegex = new RegExp(r"'(.*)'");
      Iterable<String> usernames = matchList.map((listElement) {
        Match nameMatch = nameRegex.firstMatch(listElement);
        return nameMatch[1];
      }).where((username) => username != widget.user.name);

      completer.complete();
      setState(() => _onlineUsers = usernames.toList());
      log('Online users: ${usernames.length > 0 ? usernames : '<none>'}');
    });

    return completer.future;
  }

  void _openChat(String username) {
    if (_conversations[username] == null) {
      _conversations[username] = new Conversation(username);
    }

    Navigator.of(context).push(
      new MaterialPageRoute(
        builder: (context) {
          return new Chat(
            user: widget.user,
            conversation: _conversations[username],
            sendMessage: _handleSendMessagePress,
          );
        }
      )
    );
  }

  void _sendMessage(String message, String username, int channelMode,
      MessageMode messageMode, Function callback) {
    switch (messageMode) {
      case MessageMode.binary:
        widget.server.sendMessageBitArray(message, username, channelMode, callback);
        break;
      case MessageMode.command:
        widget.server.sendMessage(message, username, callback, channelMode: channelMode);
        break;
      default:
        widget.server.sendMessage(message, username, callback);
    }
  }

  void _handleSendMessagePress(String message, String username) {
    Conversation currentConversation = _conversations[username];
    setState(() {
      currentConversation.messages.add(
        new Message(text: message, isFromUser: true)
      );
      currentChatState?.setState(() {});
    });

    int channelMode = currentConversation.channelMode;
    MessageMode messageMode = currentConversation.messageMode;
    if (!currentConversation.isActive) {
      widget.server.inviteUser(username,
          callback: (response) => _activateConversation(username));
    } else {
      _sendMessage(message, username, channelMode, messageMode,
          (response) => currentConversation.messages.last.changeToSent());
    }
  }

  void _activateConversation(username) {
    if (_conversations[username] == null) {
      _conversations[username] = new Conversation(username);
    }

    Conversation conversation = _conversations[username];
    conversation.isActive = true;

    int channelMode = conversation.channelMode;
    MessageMode messageMode = conversation.messageMode;
    conversation.messages.forEach((message) {
      _sendMessage(message.text, username, channelMode, messageMode,
          () => message.changeToSent());
    });
  }

  @override
  void initState() {
    super.initState();
    _getUsers();

    widget.server.onInvitation = (username) {
      widget.server.acceptInvitation(username);
      _activateConversation(username);
    };
    widget.server.onMessage = (message, username) {
      setState(() {
        _conversations[username].messages.add(
            new Message(text: message, isFromUser: false)
        );
      });
      currentChatState?.setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget usersWidget;

    if (_onlineUsers == null) {
      return new Loading(text: 'Looking for online users...');
    }

    if (_onlineUsers.length > 0) {
      List<Widget> userWidgets = _onlineUsers.map((username) {
        Conversation currentConversation = _conversations[username];

        String lastMessageString = '';
        if (currentConversation != null) {
          int messageCount = currentConversation.messages.length;
          if (messageCount > 0) {
            Message lastMessage = currentConversation.messages[messageCount - 1];
            lastMessageString = lastMessage.isFromUser ? 'You: ' : '';
            lastMessageString += lastMessage.text;
          }
        }

        return new ListTile(
          leading: new CircleAvatar(
              child: new Text(username[0].toUpperCase())
          ),
          title: new Text(username),
          subtitle: new Text(lastMessageString),
          onTap: () => _openChat(username),
        );
      }).toList();

      usersWidget = new RefreshIndicator(
        onRefresh: _getUsers,
        child: new ListView.builder(
          itemBuilder: (_, int index) => userWidgets[index],
          itemCount: userWidgets.length,
        )
      );
    } else {
      usersWidget = new Center(
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text('No online users.', style: _biggerFont),
            const SizedBox(height: 50.0),
            new RaisedButton(
              child: const Text('Refresh'),
              onPressed: _getUsers
            )
          ]
        )
      );
    }

    return usersWidget;
  }
}