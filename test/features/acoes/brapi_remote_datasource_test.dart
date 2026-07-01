import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/acoes/data/datasources/brapi_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  late _MockDio dio;
  late BrapiRemoteDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = BrapiRemoteDatasource(dio);
  });

  Response<dynamic> resp(dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        data: data,
        statusCode: 200,
      );

  group('cotacao', () {
    test('parseia o primeiro result', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'results': [
            {
              'symbol': 'PETR4',
              'longName': 'Petrobras PN',
              'regularMarketPrice': 38.54,
              'regularMarketChangePercent': 1.33,
              'priceEarnings': 4.62,
            },
          ],
        }),
      );

      final dto = await ds.cotacao('PETR4');
      expect(dto.symbol, 'PETR4');
      expect(dto.regularMarketPrice, 38.54);
      expect(dto.regularMarketChangePercent, 1.33);
      expect(dto.priceEarnings, 4.62);
    });

    test('results vazio lança FormatException', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp({'results': <dynamic>[]}));
      expect(() => ds.cotacao('XPTO9'), throwsFormatException);
    });

    test('corpo sem results lança FormatException', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp({'error': true}));
      expect(() => ds.cotacao('PETR4'), throwsFormatException);
    });
  });

  group('buscar', () {
    test('extrai a lista de stocks', () async {
      when(
        () => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => resp({
          'indexes': ['IBOV'],
          'stocks': ['PETR3', 'PETR4'],
        }),
      );

      final r = await ds.buscar('petr');
      expect(r, ['PETR3', 'PETR4']);
    });
  });
}
