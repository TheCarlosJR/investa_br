import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/result/result.dart';
import 'package:investa_br/src/features/renda_fixa/data/datasources/cnpj_remote_datasource.dart';
import 'package:investa_br/src/features/renda_fixa/domain/emissor.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio brasil;
  late _MockDio open;
  late _MockDio receita;
  late CnpjRemoteDatasource ds;

  setUp(() {
    brasil = _MockDio();
    open = _MockDio();
    receita = _MockDio();
    ds = CnpjRemoteDatasource(
      brasilApi: brasil,
      openCnpj: open,
      receitaWs: receita,
    );
  });

  Response<dynamic> resp(dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        data: data,
        statusCode: 200,
      );

  DioException erro() => DioException(requestOptions: RequestOptions(path: '/x'));

  const cnpj = '11.222.333/0001-44';

  test('usa BrasilAPI quando ela responde', () async {
    when(() => brasil.get<dynamic>(any())).thenAnswer(
      (_) async => resp({'razao_social': 'Banco X SA', 'nome_fantasia': 'X'}),
    );

    final r = await ds.consultar(cnpj);
    expect(r, isA<Success<Emissor>>());
    expect((r as Success<Emissor>).value.razaoSocial, 'Banco X SA');
    expect(r.value.cnpj, '11222333000144');
  });

  test('cai para OpenCNPJ quando BrasilAPI falha', () async {
    when(() => brasil.get<dynamic>(any())).thenThrow(erro());
    when(() => open.get<dynamic>(any()))
        .thenAnswer((_) async => resp({'razao_social': 'Y SA'}));

    final r = await ds.consultar(cnpj);
    expect(r, isA<Success<Emissor>>());
    expect((r as Success<Emissor>).value.razaoSocial, 'Y SA');
  });

  test('todas as fontes falham → FailureResult', () async {
    when(() => brasil.get<dynamic>(any())).thenThrow(erro());
    when(() => open.get<dynamic>(any())).thenThrow(erro());
    when(() => receita.get<dynamic>(any())).thenThrow(erro());

    final r = await ds.consultar(cnpj);
    expect(r, isA<FailureResult<Emissor>>());
  });

  test('CNPJ inválido não chama a rede', () async {
    final r = await ds.consultar('123');
    expect(r, isA<FailureResult<Emissor>>());
    verifyNever(() => brasil.get<dynamic>(any()));
  });
}
