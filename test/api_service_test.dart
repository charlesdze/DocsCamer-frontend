import 'package:flutter_test/flutter_test.dart';
import 'package:docscamer/config/api_config.dart';

void main() {
  group('ApiService Configuration Unit Tests', () {
    test('Verify ApiConfig URLs and format correctness', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
      expect(ApiConfig.baseUrl.startsWith('http'), isTrue);
    });
  });
}
