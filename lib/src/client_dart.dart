import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:eventsource/eventsource.dart';
import 'package:flutter_home_connect_sdk/flutter_home_connect_sdk.dart';
import 'package:flutter_home_connect_sdk/src/models/coffee_device.dart';
import 'package:flutter_home_connect_sdk/src/models/dishwasher_device.dart';
import 'package:flutter_home_connect_sdk/src/models/dryer_device.dart';
import 'package:flutter_home_connect_sdk/src/models/fridge_freezer_device.dart';
import 'package:flutter_home_connect_sdk/src/models/washer_device.dart';
import 'package:flutter_home_connect_sdk/src/utils/utils.dart';
import 'package:http/http.dart' as http;

import './utils/uri.dart';

class HomeConnectApi {
  late http.Client client;
  Uri baseUrl;
  String _accessToken = '';
  late final HomeDevice currentDevice;
  late StreamSubscription<Event> subscription;

  /// oauth client credentials
  HomeConnectClientCredentials credentials;
  HomeConnectAuth? authenticator;
  HomeConnectAuthStorage storage = MemoryHomeConnectAuthStorage();

  HomeConnectApi(this.baseUrl, {required this.credentials, HomeConnectAuthStorage? storage, this.authenticator}) {
    client = http.Client();

    // set default storage
    if (storage != null) {
      this.storage = storage;
    }
  }

  Future<void> authenticate() async {
    if (authenticator == null) {
      throw Exception('No authenticator provided');
    }
    final token = await authenticator!.authorize(baseUrl, credentials);
    storage.setCredentials(token);
  }

  Future<bool> shouldRefreshToken() async {
    final userCredentials = await storage.getCredentials();
    if (userCredentials == null || userCredentials.isAccessTokenExpired()) {
      return true;
    }
    return false;
  }

  Future<void> refreshToken() async {
    if (authenticator == null) {
      throw Exception('No authenticator provided');
    }
    final userCredentials = await storage.getCredentials();
    final tokens = await authenticator?.refresh(baseUrl, userCredentials!.refreshToken);
    if (tokens == null) {
      throw Exception('Failed to refresh token');
    }
    // set token in storage
    await storage.setCredentials(tokens);
  }

  Future<http.Response> put({required String resource, required String body}) async {
    HomeConnectAuthCredentials? userCredentials = await checkTokenIntegrity();
    _accessToken = userCredentials!.accessToken;
    final uri = baseUrl.join('/api/homeappliances/$resource');
    final response = await client.put(uri, headers: commonHeaders, body: body);
    return response;
  }

  Future<http.Response> get(String resource) async {
    HomeConnectAuthCredentials? userCredentials = await checkTokenIntegrity();
    _accessToken = userCredentials!.accessToken;
    final uri = baseUrl.join('/api/homeappliances/$resource');
    final response = await client.get(
      uri,
      headers: commonHeaders,
    );
    return response;
  }

  Map<String, String> get commonHeaders {
    final result = <String, String>{};
    result['Authorization'] = 'Bearer $_accessToken';
    result['Content-Type'] = 'application/vnd.bsh.sdk.v1+json';
    return result;
  }

  Future<List<HomeDevice>> getDevices() async {
    final response = await get('');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> devices = data['data']['homeappliances'];
      final result = <HomeDevice>[];
      for (final device in devices) {
        final deviceType = device['type'];
        switch (deviceType) {
          case 'Oven':
            DeviceInfo info = DeviceInfo.fromJson(device);
            result.add(DeviceOven.fromInfoPayload(this, info));

            break;
          case 'Dryer':
            DryerDevice mock = DryerDevice(
              this,
              DeviceInfo.fromJson(device),
              [],
              [],
              [],
            );
            result.add(mock);
            break;
          case 'Washer':
            WasherDevice mock = WasherDevice(
              this,
              DeviceInfo.fromJson(device),
              [],
              [],
              [],
            );
            result.add(mock);
            break;
          case 'Dishwasher':
            DishwasherDevice mock = DishwasherDevice(
              this,
              DeviceInfo.fromJson(device),
              [],
              [],
              [],
            );
            result.add(mock);
            break;
          case 'FridgeFreezer':
            FridgeFreezerDevice mock = FridgeFreezerDevice(
              this,
              DeviceInfo.fromJson(device),
              [],
              [],
              [],
            );
            result.add(mock);
            break;
          case 'CoffeeMaker':
            CoffeeDevice mock = CoffeeDevice(
              this,
              DeviceInfo.fromJson(device),
              [],
              [],
              [],
            );
            result.add(mock);
            break;
          default:
            throw Exception('Unknown device type: $deviceType');
        }
      }
      return result;
    } else {
      throw Exception('Error getting devices: ${response.body}');
    }
  }

  /// Returns the specific type of device with its programs and status.
  ///
  /// For convenience, the returned device is also stored in the currentDevice property.
  /// This method should be used after getDevices() to get the specific type of device.
  /// Internally it calls getPrograms() and getStatus().
  /// The returned device will be of the specific type. For example, if the device is an oven,
  /// the returned device will be of type DeviceOven.
  Future<HomeDevice> getDevice(HomeDevice device) async {
    final devicePrograms = await getPrograms(haId: device.info.haId);
    final statResponse = await getStatus(device.info.haId);
    final deviceType = device.info.type;
    switch (deviceType) {
      case DeviceType.oven:
        device.programs = devicePrograms;
        device.status = statResponse;
        currentDevice = device;
        return device;

      case DeviceType.dryer:
        // result.add(DeviceDryer.fromPayload(this, device, settings, status));
        break;
      case DeviceType.washer:
        // result.add(DeviceWasher.fromPayload(this, device, settings, status));
        break;
      case DeviceType.dishwasher:
        // result.add(DeviceDishwasher.fromPayload(this, device, settings, status));
        break;
      case DeviceType.fridgeFreezer:
        // result.add(DeviceFridgeFreezer.fromPayload(this, device, settings, status));
        break;
      case DeviceType.coffeeMaker:
        // result.add(DeviceCoffeeMaker.fromPayload(this, device, settings, status));
        break;
      default:
      // throw Exception('Unknown device type: $deviceType');
    }

    HomeDevice? h;
    return h!;
  }

  Future<void> putPowerState(String haId, String settingKey, Map<String, dynamic> payload) async {
    final path = "$haId/settings/$settingKey";
    final body = json.encode(payload);
    try {
      final response = await put(resource: path, body: body);
      if (response.statusCode != 204) {
        print("error: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<void> startProgram(
      {required String haid, required String programKey, required List<DeviceOptions> options}) async {
    final path = "$haid/programs/active";

    final body = json.encode({
      'data': {'key': programKey, 'options': options.map((e) => compact(e.toJson())).toList()}
    });

    final response = await put(resource: path, body: body);
    if (response.statusCode != 204) {
      throw Exception('Error starting program: ${response.body}');
    }
  }

  Future<void> stopProgram({required String haid}) async {
    final uri = baseUrl.join('/api/homeappliances/$haid/programs/active');
    final headers = commonHeaders;

    try {
      final response = await http.delete(uri, headers: headers);
      if (response.statusCode != 204) {}
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<void> startListening(String haid, Function callback) async {
    final uri = baseUrl.join("$haid/events");
    final headers = commonHeaders;

    EventSource eventSource = await EventSource.connect(
      uri.toString(),
      headers: headers,
    );

    subscription = eventSource.listen((Event event) {
      callback(event);
    });
  }

  Future<List<DeviceOptions>> getProgramOptions({required String haId, required String programKey}) async {
    String path = "$haId/programs/available/$programKey";
    var res = await get(path);
    var data = json.decode(res.body);
    // Each program contains a list of options so we need to loop through each
    // option and then we create a DeviceOption object from the payload
    List<DeviceOptions> options = (data['data']['options'] as List).map((e) => DeviceOptions.fromJson(e)).toList();
    return options;
  }

  Future<List<DeviceOptions>> getSelectedProgramOptions({String? haId}) async {
    String deviceHaId = haId ?? currentDevice.info.haId;
    String path = "$deviceHaId/programs/selected";
    var res = await get(path);
    var data = json.decode(res.body);
    // Each program contains a list of options so we need to loop through each
    // option and then we create a DeviceOption object from the payload
    List<DeviceOptions> options = (data['data']['options'] as List).map((e) => DeviceOptions.fromJson(e)).toList();
    return options;
  }

  /// Selects a program for the device.
  ///
  /// If no haId is provided, the haId is taken from the current device.
  /// Trhows an exception if the program could not be selected.
  Future<void> selectProgram({
    String? haid,
    required String programKey,
  }) async {
    String deviceHaId = haid ?? currentDevice.info.haId;
    final path = "$deviceHaId/programs/selected";
    final body = json.encode({
      'data': {
        'key': programKey,
      }
    });

    try {
      final response = await put(resource: path, body: body);
      if (response.statusCode == 204) {
        print("Program selected successfully: $programKey");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<List<DeviceStatus>> getStatus(String haId) {
    Map<String, dynamic> statResponse = {
      "data": {
        "status": [
          {"key": "BSH.Common.Status.RemoteControlActive", "value": 'true'},
          {"key": "BSH.Common.Status.RemoteControlStartAllowed", "value": 'true'},
          {"key": "BSH.Common.Status.OperationState", "value": "BSH.Common.EnumType.OperationState.Ready"},
          {"key": "BSH.Common.Status.DoorState", "value": "BSH.Common.EnumType.DoorState.Closed"},
          {"key": "Cooking.Oven.Status.CurrentCavityTemperature", "value": '20'}
        ]
      }
    };
    List<DeviceStatus> stList = (statResponse['data']['status'] as List).map((e) => DeviceStatus.fromJson(e)).toList();
    var response = Future.delayed(Duration(seconds: 1), () => stList);
    return response;
  }

  Future<List<DeviceProgram>> getPrograms({String? haId}) async {
    String deviceHaid = haId ?? currentDevice.info.haId;

    String path = "$deviceHaid/programs/available";
    final res = await get(path);
    final List<DeviceProgram> programs =
        (json.decode(res.body)['data']['programs'] as List).map((e) => DeviceProgram.fromJson(e)).toList();
    return programs;
  }

  Future<HomeConnectAuthCredentials> getAccessToken(String code) async {
    final response = await client.post(
      Uri.parse('https://simulator.home-connect.com/security/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': credentials.clientId,
        'client_secret': credentials.clientSecret ?? '',
        'redirect_uri': credentials.redirectUri,
        'grant_type': 'authorization_code',
        'code': code,
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return HomeConnectAuthCredentials(
        accessToken: jsonResponse['access_token'],
        refreshToken: jsonResponse['refresh_token'],
        expirationDate: DateTime.now().add(Duration(seconds: jsonResponse['expires_in'])),
      );
    } else {
      throw Exception('Failed to get access token');
    }
  }

  Future<HomeConnectAuthCredentials?> checkTokenIntegrity() async {
    if (await shouldRefreshToken()) {
      await refreshToken();
    }

    final userCredentials = await storage.getCredentials();
    return userCredentials;
  }
}
