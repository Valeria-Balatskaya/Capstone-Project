import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChirpStackService {
  Future<Map<String, dynamic>> testConnection({
    required String serverUrl,
    required String apiToken,
  }) async {
    try {
      final authHeaders = [
        {
          'Accept': 'application/json',
          'Grpc-Metadata-Authorization': 'Bearer $apiToken',
        },
        {'Accept': 'application/json', 'Authorization': 'Bearer $apiToken'},
      ];

      http.Response? successResponse;
      Map<String, String>? workingHeaders;

      for (var headers in authHeaders) {
        try {
          final response = await http
              .get(
                Uri.parse('$serverUrl/api/tenants?limit=1'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            successResponse = response;
            workingHeaders = headers;
            break;
          } else if (response.statusCode == 401) {
            continue;
          }
        } catch (e) {
          continue;
        }
      }

      if (successResponse == null) {
        for (var headers in authHeaders) {
          try {
            final response = await http
                .get(
                  Uri.parse('$serverUrl/api/applications?limit=1'),
                  headers: headers,
                )
                .timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              successResponse = response;
              workingHeaders = headers;
              break;
            }
          } catch (e) {
            continue;
          }
        }
      }

      if (successResponse != null && successResponse.statusCode == 200) {
        final authType =
            workingHeaders!.containsKey('Grpc-Metadata-Authorization')
            ? 'gRPC metadata'
            : 'Standard Bearer';
        return {
          'success': true,
          'message':
              '✓ Successfully connected to ChirpStack!\n\nAuth type: $authType',
        };
      } else {
        return {
          'success': false,
          'message':
              '✗ Authentication failed.\n\n'
              'Please check:\n'
              '1. API token is correct\n'
              '2. Token has admin privileges\n'
              '3. Token is not expired',
        };
      }
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'message': '✗ Connection timeout. Check server URL and network.',
      };
    } on SocketException catch (_) {
      return {
        'success': false,
        'message': '✗ Cannot reach server. Check URL and network connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '✗ Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getApplications({
    required String serverUrl,
    required String apiToken,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/api/applications?limit=100'),
            headers: {
              'Accept': 'application/json',
              'Grpc-Metadata-Authorization': 'Bearer $apiToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch applications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching applications: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getDevices({
    required String serverUrl,
    required String apiToken,
    required String applicationId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$serverUrl/api/applications/$applicationId/devices?limit=100',
            ),
            headers: {
              'Accept': 'application/json',
              'Grpc-Metadata-Authorization': 'Bearer $apiToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch devices: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching devices: ${e.toString()}',
      };
    }
  }
}
