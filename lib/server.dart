import 'dart:io';
import 'dart:async';
import 'util.dart';

class Server {
  String _host;
  int _port;
  Socket _socket;
  StreamSubscription _inputStream;

  Function _onData;
  Function _onError;

  String get host => _host;
  int get port => _port;

  Server(String host, int port) {
    this._host = host;
    this._port = port;
    this._onData = () {};
    this._onError = () {};
  }

  Future<void> connect() async {
    if (_socket?.remoteAddress != null) {
      log('Socket is already open.');
      return null;
    }

    try {
      _socket = await Socket.connect(_host, _port);
      log('Socket opened successfully.');
      _inputStream = _socket.listen((event) => _handleSocketData(event));

      _socket.done.then((_) {
        log('Socket has been closed.');
        _inputStream.cancel();
      }).catchError((error) {
        logError('An error has been occurred in the socket.');
        logError(error);
      });
    } catch(exception) {
      logError('Error while opening socket.');
      logError(exception.toString());

      throw(exception);
    }
  }

  void disconnect({Function callback}) {
    if (_socket == null) {
      log('Connection was not opened. Nothing to close.');
      return;
    }

    try {
      _sendString('DISCONNECT', onData: (response) async {
        if (response.contains('Goodbye')) {
          await _socket.close();
          if (callback != null) callback();
        }
      });
    } catch(exception) {
      logError('Error while closing socket.');
      logError(exception.toString());
      throw(exception);
    }
  }

  void register(String username, Function onFinish, {Function onError}) {
    try {
      _sendString('REGISTER $username', onData: (response) {
        if (!response.contains('Welcome ')) {
          logError(response);
          if (onError != null) onError(response);
          return;
        }

        log('Registered as "$username".');
        onFinish(response);
      }, onError: onError);
    } catch (exception) {
      logError("Couldn't register user.");
      throw(exception);
    }
  }

  // TODO: [4] Invite user for conversation and send message
  void getUsers(Function callback) {
    try {
      _sendString('WHO', onData: callback);
    } catch (exception) {
      throw(exception);
    }
  }

  void _handleSocketData(event) {
    String response = new String.fromCharCodes(event);
    
    if (response.contains('ERROR')) {
      RegExp errorRegex = new RegExp(r'ERROR\s*(.*)');
      Match errorMatch = errorRegex.firstMatch(response);
      logError(errorMatch.group(1));
      _onError(errorMatch.group(1));
    } else {
      log('Message received: $response');
      _onData(response);
    }
  }

  void _sendString(String data, {Function onData, Function onError}) {
    if (_socket == null) {
      logError('Socket is not open.');
      throw new StateError('Socket is not open.');
    }

    _onData = onData;
    _onError = onError;
    _socket.write(data);
  }
}