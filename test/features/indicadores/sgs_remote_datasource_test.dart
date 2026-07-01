import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/indicadores/data/datasources/sgs_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  late _MockDio dio;
  late SgsRemoteDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = SgsRemoteDatasource(dio);
  });

  Response<dynamic> resp(dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        data: data,
        statusCode: 200,
      );

  test('ultimos parseia o array JSON', () async {
    when(
      () => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => resp([
          {'data': '17/06/2026', 'valor': '14.50'},
        ]));

    final pts = await ds.ultimos(432);
    expect(pts, hasLength(1));
    expect(pts.single.valor, '14.50');
    expect(pts.single.data, '17/06/2026');
  });

  test('dataFim presente em séries 226/195', () async {
    when(
      () => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => resp([
          {'data': '16/06/2026', 'dataFim': '16/07/2026', 'valor': '0.6729'},
        ]));

    final pts = await ds.ultimos(195);
    expect(pts.single.dataFim, '16/07/2026');
  });

  test('resposta não-lista (HTML de erro) lança FormatException', () async {
    when(
      () => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => resp('<html>Requisição inválida</html>'));

    expect(() => ds.ultimos(12), throwsFormatException);
  });

  test('batchUltimos agrega por código', () async {
    when(
      () => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => resp([
          {'data': '17/06/2026', 'valor': '1.00'},
        ]));

    final res = await ds.batchUltimos([432, 12, 433]);
    expect(res.keys, containsAll([432, 12, 433]));
  });
}
