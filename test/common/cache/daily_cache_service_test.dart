import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/cache/daily_cache_service.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database db;
  final store = stringMapStoreFactory.store('cache_indicadores');
  const key = 'k';

  List<String> fromJson(Object? j) => (j! as List).cast<String>();
  Object? toJson(List<String> l) => l;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('c.db');
  });

  test('gravar e lerSeDeHoje no mesmo dia retorna os dados', () async {
    final now = DateTime.utc(2026, 6, 17, 12);
    final svc = DailyCacheService(db, store, now: () => now);
    await svc.gravar<List<String>>(key, ['a', 'b'], toJson: toJson);

    final snap = await svc.lerSeDeHoje<List<String>>(key, fromJson);
    expect(snap, isNotNull);
    expect(snap!.dados, ['a', 'b']);
    expect(snap.dataUltimaAtualizacao, '2026-06-17');
    expect(snap.stale, isFalse);
  });

  test('lerSeDeHoje em outro dia retorna null', () async {
    final dia1 = DateTime.utc(2026, 6, 17, 12);
    await DailyCacheService(db, store, now: () => dia1)
        .gravar<List<String>>(key, ['a'], toJson: toJson);

    final dia2 = DateTime.utc(2026, 6, 18, 12);
    final snap = await DailyCacheService(db, store, now: () => dia2)
        .lerSeDeHoje<List<String>>(key, fromJson);
    expect(snap, isNull);
  });

  test('lerSeDeHoje fora do TTL retorna null', () async {
    final gravou = DateTime.utc(2026, 6, 17, 5); // SP 02:00 (06-17)
    await DailyCacheService(db, store, now: () => gravou)
        .gravar<List<String>>(key, ['a'], toJson: toJson);

    final leu = DateTime.utc(2026, 6, 17, 20); // SP 17:00 (06-17), +15h
    final snap = await DailyCacheService(db, store, now: () => leu)
        .lerSeDeHoje<List<String>>(key, fromJson);
    expect(snap, isNull); // mesma data, mas fora do TTL de 12h
  });

  test('lerQualquer retorna mesmo cache vencido', () async {
    final dia1 = DateTime.utc(2026, 6, 17, 12);
    await DailyCacheService(db, store, now: () => dia1)
        .gravar<List<String>>(key, ['a'], toJson: toJson);

    final dia2 = DateTime.utc(2026, 6, 25, 12);
    final snap = await DailyCacheService(db, store, now: () => dia2)
        .lerQualquer<List<String>>(key, fromJson);
    expect(snap, isNotNull);
    expect(snap!.dados, ['a']);
  });

  test('lerSeDeHoje sem nada gravado retorna null', () async {
    final svc = DailyCacheService(db, store, now: DateTime.now);
    expect(await svc.lerSeDeHoje<List<String>>(key, fromJson), isNull);
  });
}
