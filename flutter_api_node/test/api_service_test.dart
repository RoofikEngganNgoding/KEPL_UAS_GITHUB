import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_node/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chatbot health follows exact backend readiness and process state',
    () async {
      var ready = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (ready) {
          request.response.statusCode = HttpStatus.ok;
          request.response.write(
            jsonEncode({
              'status': 'ready',
              'service': 'bank-sampah-chatbot',
              'model_loaded': true,
            }),
          );
        } else {
          // HTTP 200 dari service lain tidak boleh dianggap sebagai chatbot.
          request.response.statusCode = HttpStatus.ok;
          request.response.write(
            jsonEncode({'status': 'ok', 'service': 'not-the-chatbot'}),
          );
        }
        await request.response.close();
      });

      final service = ApiService(nlpBaseUrl: 'http://127.0.0.1:${server.port}');

      final wrongService = await service.checkChatbotHealth();
      expect(wrongService.online, isFalse);

      ready = true;
      final modelReady = await service.checkChatbotHealth();
      expect(modelReady.online, isTrue);

      await subscription.cancel();
      await server.close(force: true);
      final stopped = await service.checkChatbotHealth();
      expect(stopped.online, isFalse);
    },
  );
}
