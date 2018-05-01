import 'package:flutter/material.dart';

String parseBinaryString(String binaryString) {
  RegExp byteRegex = new RegExp(r'.{1,8}');
  Iterable<Match> byteMatches = byteRegex.allMatches(binaryString);

  Iterable<int> charCodes = byteMatches.map((byteMatch) =>
      int.parse(byteMatch.group(0), radix: 2));
  String asciiMessage = new String.fromCharCodes(charCodes);

  return asciiMessage;
}

String xorMessages(String message1, String message2) {
  if (message1.length < message2.length) {
    message2 = message2.substring(0, message1.length);
  } else if (message2.length < message1.length) {
    message1 = message1.substring(0, message2.length);
  }

  List<int> xorValues = new List<int>();
  message1.codeUnits.asMap().forEach((int index, int character) {
    xorValues.add(character ^ message2.codeUnitAt(index));
  });

  return new String.fromCharCodes(xorValues);
}

void showSnackbar(String content, BuildContext context) {
  SnackBar snackBar = new SnackBar(
    content: new Text(content)
  );

  Scaffold.of(context).showSnackBar(snackBar);
}

void log(String logEntry) {
  print('[Info] $logEntry');
}

void logWarning(String logEntry) {
  print('[Warning] $logEntry');
}

void logError(String logEntry) {
  print('[Error] $logEntry');
}