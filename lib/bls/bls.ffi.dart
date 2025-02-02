import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:agent_dart/bls/bls.base.dart';
import 'package:agent_dart/utils/extension.dart';
import 'package:ffi/ffi.dart';
import 'ffi/ffi.dart';

class FFIBls implements BaseBLS {
  @override
  bool blsInitSync() {
    Pointer<Utf8> result = rustBlsInit();
    final rt = (result.cast<Utf8>().toDartString() == "true");
    freeCString(result);
    return rt;
  }

  @override
  bool blsVerifySync(
    Uint8List pk,
    Uint8List sig,
    Uint8List msg,
  ) {
    Pointer<Utf8> result = rustBlsVerify(
        sig.toHex(include0x: false).toNativeUtf8(),
        msg.toHex(include0x: false).toNativeUtf8(),
        pk.toHex(include0x: false).toNativeUtf8());
    final ret = result.cast<Utf8>().toDartString() == "true";
    freeCString(result);
    return ret;
  }

  @override
  Future<bool> blsInit() async {
    // ignore: unnecessary_null_comparison
    if (dylib == null) throw "ERROR: The library is not initialized 🙁";
    final response = ReceivePort();
    await Isolate.spawn(
      _isolateBlsInit,
      response.sendPort,
      onExit: response.sendPort,
    );
    final sendPort = await response.first as SendPort;
    final receivePort = ReceivePort();
    sendPort.send([receivePort.sendPort]);

    try {
      final result = await receivePort.first as bool;
      response.close();
      return result;
    } catch (e) {
      throw "Cannot initialize BLS instance :$e";
    }
  }

  void _isolateBlsInit(SendPort initialReplyTo) {
    final port = ReceivePort();

    initialReplyTo.send(port.sendPort);

    port.listen((message) async {
      try {
        Pointer<Utf8> result = rustBlsInit();
        final send = message.last as SendPort;
        send.send(result.cast<Utf8>().toDartString() == "true");
        freeCString(result);
      } catch (e) {
        message.last.send(e);
      }
    });
  }

  @override
  Future<bool> blsVerify(
    Uint8List pk,
    Uint8List sig,
    Uint8List msg,
  ) async {
    // ignore: unnecessary_null_comparison
    if (dylib == null) throw "ERROR: The library is not initialized 🙁";
    // if (await blsInit() != true) {
    //   throw "ERROR: Cannot initialize BLS instance";
    // }
    final response = ReceivePort();
    await Isolate.spawn(
      _isolateBlsVerify,
      response.sendPort,
      onExit: response.sendPort,
    );
    final sendPort = await response.first as SendPort;
    final receivePort = ReceivePort();
    sendPort.send([
      sig.toHex(include0x: false),
      msg.toHex(include0x: false),
      pk.toHex(include0x: false),
      receivePort.sendPort
    ]);

    try {
      final result = await receivePort.first as bool;
      response.close();
      return result;
    } catch (e) {
      throw "Cannot verify bls_verify instance :$e";
    }
  }

  void _isolateBlsVerify(SendPort initialReplyTo) {
    final port = ReceivePort();

    initialReplyTo.send(port.sendPort);

    port.listen((message) async {
      try {
        final sig = message[0] as String;
        final msg = message[1] as String;
        final pk = message[2] as String;
        final send = message.last as SendPort;
        Pointer<Utf8> result = rustBlsVerify(
            sig.toNativeUtf8(), msg.toNativeUtf8(), pk.toNativeUtf8());
        send.send(result.cast<Utf8>().toDartString() == "true");
        freeCString(result);
      } catch (e) {
        message.last.send(e);
      }
    });
  }
}

BaseBLS createBLS() => FFIBls();

String throwReturn(String message) {
  if (message.startsWith("Error:")) {
    throw message;
  } else {
    return message;
  }
}
