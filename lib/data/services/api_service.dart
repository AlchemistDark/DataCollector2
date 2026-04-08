import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:data_collector2/domain/entities/app_constants.dart';

/// A dedicated service for handling API interactions with the neural network server.
class ApiService {
  final http.Client _client = http.Client();

  /// Sends the processed luminosity matrix to the server to get position prediction.
  /// 
  /// Returns a record with [sensor] (height) and [distance] values if successful,
  /// or null if the request fails or times out.
  Future<({double sensor, double distance})?> getPrediction({
    required List<List<double>> matrix,
    String contentType = 'application/json',
  }) async {
    try {
      final String payload = json.encode({"photo": matrix});
      
      final http.Response response = await _client.post(
        Uri.https(AppConstants.apiAuthority, AppConstants.predictPath),
        body: payload,
        headers: {"content-type": contentType},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('ApiService: Server returned error ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (data.containsKey("sensor") && data.containsKey("distance")) {
        return (
          sensor: (data["sensor"] as num).toDouble(),
          distance: (data["distance"] as num).toDouble(),
        );
      } else {
        debugPrint('ApiService: Invalid response format');
      }
    } on TimeoutException {
      debugPrint('ApiService: Request timed out');
    } on SocketException catch (e) {
      debugPrint('ApiService: Network connection error: $e');
    } catch (e) {
      debugPrint('ApiService: Unknown error in getPrediction: $e');
    }
    
    return null;
  }

  /// Closes the underlying HTTP client.
  void dispose() {
    _client.close();
  }
}
