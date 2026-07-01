# Investa BR

App **Flutter** (Android, iOS, Windows, macOS, Linux — **sem Web**) de auxílio a investimentos em **renda fixa** e **ações da B3** (Brasil).

📄 Plano de engenharia completo: [`docs/PLANEJAMENTO.md`](docs/PLANEJAMENTO.md).
✅ Checklist de etapas (o que falta, por fase): [`docs/ETAPAS.md`](docs/ETAPAS.md).

## Status da implementação

Implementação faseada conforme o roadmap (§18 do plano):

- ✅ **F0 — Fundação**: projeto criado nas 5 plataformas, FVM (Flutter 3.41.9), `pubspec` com a stack (Riverpod, sembast, dio, go_router, fl_chart, dynamic_color), lints `very_good_analysis`, estrutura `lib/src` feature-first.
- ✅ **F1 — Domínio & Motor Financeiro** (puro Dart, 100% testável):
  - Value objects `Money` (centavos) e `Percentual` (fração).
  - Enums `Indexador`, `ClasseAtivo`, `BaseDias`, `Capitalizacao`, `Tributacao`.
  - Union selada `TipoRendimento` (prefixado / pós-fixado / IPCA+ / percentual puro).
  - `RegraTributaria` datada (IR regressivo + IOF + isenção por classe — vigência 2026).
  - Motor: juros (base 252/360/365, %CDI, híbrido), contagem de dias úteis, conversor (taxa líquida anual efetiva + gross-up) e projeção (`projetar`).
  - Entidades `InvestimentoRendaFixa`, `TaxaContratada`, `Emissor`, `ProjecaoRendaFixa`.
- ✅ **F2 — Persistência Local & Import/Export**:
  - `LocalDb` (sembast `databaseFactoryIo`), 4 stores, `schemaVersion` + migração `onVersionChanged` (semeia config padrão).
  - Repositórios CRUD: `RendaFixaRepository`, `PosicoesAcoesRepository`, `ConfigRepository`.
  - Entidades `PosicaoAcao` e `ConfiguracaoTema`.
  - Import/Export JSON: codec com **checksum SHA-256 canônico**, 4 gates de validação (identidade/versão/integridade/estrutura), migração de payload, modos **REPLACE/MERGE** (last-write-wins por `updatedAt`) em **transação atômica** (rollback), backup em arquivo (`dart:io`). `cache_indicadores` fica fora do export.
- ✅ **F3 — Camada de Dados & Cache Diário** (núcleo de indicadores):
  - `DioFactory` por API + interceptors (User-Agent obrigatório do SGS, token brapi, log só em debug); `ApiEndpoints` centraliza URLs.
  - Datasource BCB SGS (`/ultimos/n`, batch de cortesia, detecção de HTML de erro → `FormatException`), DTO + mappers (parse `String`/data `dd/MM/yyyy`).
  - `DailyCacheService` (cache "primeira requisição do dia", chave por data America/Sao_Paulo + TTL), `IndicadoresRepository` com fallback offline `stale` e mapeamento `DioException → Failure` (`sealed`).
  - Datasources de brapi/CNPJ/Tesouro ficam para as fases das features que os consomem (F7).
- ✅ **F4 — Navegação & Tela Inicial**:
  - DI por Riverpod (`Provider` + `overrideWith`): `databaseProvider`/`clockProvider` injetados no bootstrap; cadeias de providers de indicadores, renda fixa, ações e patrimônio.
  - `go_router` com `StatefulShellRoute.indexedStack` (5 abas, estado preservado por branch) + `RootShell` responsivo (`NavigationBar` < 600dp · `NavigationRail` 600–840dp · `NavigationRail(extended)` ≥ 840dp) com FAB contextual em Início/Carteira.
  - **Dashboard**: cards SELIC/CDI/IPCA/IGP-M (cache do dia), patrimônio consolidado (RF marcada na curva pelo motor; ações pelo custo), donut da carteira com legenda textual acessível, `StaleBanner` offline, estados loading/erro/vazio e pull-to-refresh.
  - Anualização pura do snapshot SGS → entrada do motor; telas de Carteira/Conversor/Ações/Ajustes como placeholders honestos das próximas fases.
- ✅ **F5 — Carteira & Cadastro**:
  - `CarteiraScreen`: seções RF + ações com totais; RF marcada na curva (valor atual + rentabilidade por item), ações pelo custo; editar/excluir; tap → detalhe.
  - `CadastroRfScreen` (novo/editar): classe, tipo de rendimento, taxa com sufixo dinâmico, valor, base de dias, datas pt-BR, isenção derivada da classe e **preview de projeção ao vivo** (motor F1); `CadastroAcaoScreen`; `DetalheRfScreen` com projeção completa.
  - `MoneyField`/`PercentField` + parser pt-BR; notifiers de CRUD (`rendaFixaListProvider`/`acoesListProvider`) que o `patrimonioProvider` observa para se recompor.
- ✅ **F6 — Conversor / Comparador de Renda**:
  - `ConversorScreen`: valor + prazo e linhas de opção dinâmicas (tipo de rendimento + taxa + isento); converte tudo para **rentabilidade líquida anual efetiva (base 252)** com índices do dia e mostra **gross-up** de isentos.
  - Ranking com `BarComparador` (`fl_chart`) + legenda textual acessível e banner informativo (CVM); `TipoRendimentoUi` compartilhado com o cadastro; função pura `compararOpcoes` (motor F1).
- ✅ **F7 — Ações & CNPJ**:
  - Datasource brapi (cotação + busca) com cache diário por ticker e fallback offline; token brapi em `ConfiguracaoTema` (runtime); CNPJ com fallback encadeado (BrasilAPI→OpenCNPJ→ReceitaWS).
  - `BuscaAcoesScreen` (busca com debounce) + `DetalheAcaoScreen` (cotação, fundamentos com `—`, **sinais próprios** de P/L/P-VP/DY/ROE) — degrada graciosamente sem token/rating; rota `/acoes/:ticker`.
  - `mapDioError` compartilhado + `AuthFailure`.
- 🟡 **F8 — Tema & Polimento (núcleo)**:
  - Tema customizável persistido: cor-semente editável, modo claro/escuro/sistema e Material You (`dynamic_color`) quando disponível; `ConfiguracaoNotifier` observado pelo `app.dart` (preferências sobrevivem entre sessões).
  - `ConfiguracoesScreen` real: Aparência, Dados (token brapi, export via `share_plus`, import via `file_picker` com Substituir/Mesclar, status do cache), Sobre.
  - Adiados: l10n `.arb` (app já é pt-BR), ícones/splash e auditoria formal de a11y.
- 🟡 **F9 — Testes & Hardening (automatizável)**:
  - Testes ponta-a-ponta headless (`test/e2e/`): navegação pelas 5 abas e cadastro de RF → carteira → patrimônio.
  - Correção de overflow das linhas rótulo↔valor em telas estreitas.
  - Resta o **checklist de release** (uniformizar bundle id, ícones/splash, `window_manager`, assinatura e builds por plataforma) — exige ambiente/credenciais; ver [`docs/ETAPAS.md`](docs/ETAPAS.md).
- **142 testes passando**; `flutter analyze` sem issues.

## Desvios do plano (registrados)

- **Flutter 3.41.9** (Dart 3.11.5) em vez de 3.44 — é o stable mais recente instalado via FVM; o código usa apenas recursos suportados.
- **Classes imutáveis escritas à mão** em vez de `freezed`/`json_serializable` — evita fricção de code-gen e mantém o domínio puro; mesma forma (const + `copyWith` + `toJson/fromJson`).
- **`TipoRendimento` unificado** como union selada (o plano tinha duas modelagens divergentes; adotada a do §Domínio, com o motor adaptado a ela).
- **Roteamento e estado escritos à mão** — `go_router` configurado por código (sem `go_router_builder`/`TypedGoRoute`) e `flutter_riverpod` puro (sem `@riverpod`), coerente com a decisão de evitar code-gen. `window_manager` não foi adicionado (não está nas dependências); o ajuste de janela no desktop fica para a F9.
- **`IndicadorCard.variacao` é opcional** — enquanto só buscamos o último ponto (`/ultimos/1`) não há base para inferir alta/baixa, então o rótulo de variação fica oculto em vez de exibir algo enganoso.

## Rodando

```bash
fvm flutter pub get
fvm flutter test       # testes do motor financeiro e domínio
fvm flutter run        # app (fundação)
```
