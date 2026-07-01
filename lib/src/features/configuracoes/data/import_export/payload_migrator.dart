typedef Payload = Map<String, Object?>;

/// Migra o bloco `data` do backup de [fileVersion] -> [currentVersion],
/// encadeando transformações. Sem migrações ainda (schema atual = 1).
Payload migratePayload(Payload data, int fileVersion, int currentVersion) {
  var v = fileVersion;
  var out = Map<String, Object?>.from(data);
  while (v < currentVersion) {
    out = switch (v) {
      // 1 => _migrate1to2(out), // exemplo futuro
      _ => out,
    };
    v++;
  }
  return out;
}
