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
  ) async {
    final apiKey = _getApiKey();
    var url =
        "https://maps.googleapis.com/maps/api/place/details/json?placeid=${placeId}&key=${apiKey}";
    try {
      final response = await _dio.get(url);
      final placeDetails = PlaceDetails.fromJson(response.data);
      final lat = placeDetails.result!.geometry!.location!.lat;
      final lng = placeDetails.result!.geometry!.location!.lng;
      final photoRef = placeDetails.result!.photos != null
          ? placeDetails.result!.photos![0].photoReference
          : null;
      return {
        'place_id': placeId,
        'latitude': lat,
        'longitude': lng,
        'name': placeDetails.result!.formattedAddress,
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
