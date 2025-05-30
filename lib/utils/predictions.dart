import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_places_flutter/DioErrorHandler.dart';
import 'package:google_places_flutter/model/place_details.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:google_places_flutter/model/prediction.dart';

class PlacesUtils {
  PlacesUtils._();

  static final predictions = <Prediction>[];
  static final _dio = Dio();
  static String? _apiKey;

  static void initialize(String apiKey) {
    _apiKey = apiKey;
  }

  static String _getApiKey() {
    if (_apiKey == null) {
      throw Exception("API key is not initialized!");
    }
    return _apiKey!;
  }

  static Future<List<Prediction>> getPredictions(
    String text, {
    List<String>? countries,
    String language = 'en',
    PlaceType? placeType,
  }) async {
    final apiKey = _getApiKey();
    var apiURL =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=$apiKey&language=$language";

    if (countries != null) {
      for (int i = 0; i < countries.length; i++) {
        String country = countries[i];
        if (i == 0) {
          apiURL += "&components=country:$country";
        } else {
          apiURL += "|country:" + country;
        }
      }
    }
    if (placeType != null) {
      apiURL += "&types=${placeType.apiString}";
    }

    CancelToken? _cancelToken = CancelToken();

    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
      _cancelToken = CancelToken();
    }

    try {
      String proxyURL = "https://cors-anywhere.herokuapp.com/";
      String url = (kIsWeb ? proxyURL : '') + apiURL;

      /// Add the custom header to the options
      // final options = kIsWeb
      //     ? Options(headers: {"x-requested-with": "XMLHttpRequest"})
      //     : null;

      final response = await _dio.get(url);
      final data = response.data;
      if (data.containsKey("error_message")) {
        throw response.data;
      }

      final subscriptionResponse =
          PlacesAutocompleteResponse.fromJson(response.data);

      predictions.clear();
      if (text.length == 0) {
        return [];
      }

      final validLength = subscriptionResponse.predictions!.length > 0;
      final query = text.toString().trim();
      if (validLength && query.isNotEmpty) {
        predictions.addAll(subscriptionResponse.predictions!);
      }
      return predictions;
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      throw {
        'error': e,
        'message': errorHandler.message,
      };
    }
  }

  static Future<Map<String, dynamic>> getPlaceDetailsFromPlaceId(
    String placeId,
    String language,
  ) async {
    final apiKey = _getApiKey();
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=$apiKey&language=$language";

    try {
      final response = await _dio.get(url);
      final placeDetails = PlaceDetails.fromJson(response.data);
      final result = placeDetails.result!;
      final lat = result.geometry!.location!.lat;
      final lng = result.geometry!.location!.lng;
      final photoRef = result.photos?.isNotEmpty == true
          ? result.photos![0].photoReference
          : null;

      // Extracting address components
      final components = result.addressComponents;

      String? getComponentByType(String type) {
        final comp = components?.where((c) => c.types!.contains(type)).toList();
        return comp!.isNotEmpty ? comp.first.longName : null;
      }

      final ward = getComponentByType('sublocality_level_1');
      final street = getComponentByType('route');
      final number = getComponentByType('street_number');
      final building = getComponentByType('premise');

      final userAddress = [ward, street, number, building]
          .where((e) => e != null && e.isNotEmpty)
          .join(' ');

      return {
        'place_id': placeId,
        'latitude': lat,
        'longitude': lng,
        'name': userAddress.isNotEmpty ? userAddress : result.vicinity,
        'photo_ref': photoRef,
      };
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      throw {
        'error': e,
        'message': errorHandler.message,
      };
    }
  }
}
