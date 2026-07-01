# Etapas de Implementação — Investa BR

Checklist vivo do roadmap (§18 do [PLANEJAMENTO.md](PLANEJAMENTO.md)). Marca o
que está pronto e detalha o que falta por fase. Atualizado em **18/06/2026**.

> **Regras transversais (toda fase):** `flutter analyze` zero issues · testes da
> fase verdes · `domain/` puro (sem Flutter/Dio/sembast) · nenhum teste na rede
> real · nenhum dado de mercado hardcoded em runtime. Sem commits (versionamento
> a cargo do usuário).

**Estado atual:** F0–F7 + núcleo de F8/F9 concluídos · **142 testes** · `analyze` limpo. Resta o checklist de release (assets/assinatura/builds), que exige o ambiente do usuário.

---

## ✅ F0 — Fundação
- [x] Projeto Flutter 5 plataformas, FVM (3.41.9), `pubspec` com a stack, lints `very_good_analysis`, estrutura `lib/src` feature-first.

## ✅ F1 — Domínio & Motor Financeiro
- [x] Value objects `Money`/`Percentual`; enums `Indexador`/`ClasseAtivo`/`BaseDias`/`Capitalizacao`/`Tributacao`; union `TipoRendimento`.
- [x] Motor puro: juros 252/360/365, %CDI, IPCA+/IGPM+, prefixado, IR/IOF regressivos, conversor (líquida anual + gross-up), `projetar`.

## ✅ F2 — Persistência Local & Import/Export
- [x] `LocalDb` (sembast), 4 stores, `schemaVersion`/migração; repositórios CRUD de RF/ações/config.
- [x] Import/Export JSON: checksum SHA-256, 4 gates de validação, migração de payload, REPLACE/MERGE atômico.

## ✅ F3 — Camada de Dados & Cache Diário (núcleo de indicadores)
- [x] `DioFactory` + interceptors (User-Agent SGS, token brapi, logging debug); `ApiEndpoints` centralizado.
- [x] Datasource SGS (batch, detecção de HTML de erro), DTO + mappers; `Result`/`Failure` sealed.
- [x] `DailyCacheService` (cache do dia, TTL, `stale`, refresh manual, fallback offline) + `IndicadoresRepository`.
- [ ] **Adiado p/ F7** (features que os consomem): `brapi_remote`, CNPJ (`brasilapi`→`opencnpj`→`receitaws`), `awesomeapi`, Tesouro CSV.

## ✅ F4 — Navegação & Tela Inicial
- [x] DI por Riverpod (`databaseProvider`/`clockProvider` + cadeias de indicadores/RF/ações/patrimônio).
- [x] `go_router` `StatefulShellRoute.indexedStack` (5 abas) + `RootShell` responsivo (600/840dp) + FAB contextual.
- [x] Dashboard: cards de indicadores, patrimônio consolidado, donut + legenda acessível, `StaleBanner`, estados loading/erro/vazio, pull-to-refresh.
- [x] Anualização pura do snapshot SGS; formatters pt-BR; widgets comuns.
- [ ] **Stretch adiado:** tap no card → bottom-sheet com histórico da série (`LineChart`, busca SGS por período). Requer datasource de série histórica.

---

## ✅ F5 — Carteira & Cadastro
- [x] `CarteiraScreen` real: seções RF + ações com totais, valor atual/rentabilidade por item (RF marcada na curva), tap → detalhe, editar/excluir por item.
- [x] `CadastroRfScreen` (form único novo/editar): classe, tipo de rendimento (chips), taxa (sufixo dinâmico), valor, base de dias, datas (`showDatePicker` pt-BR), isenção derivada da classe; preview de projeção ao vivo (motor F1).
- [x] `MoneyField`/`PercentField` + parser pt-BR (`parseNumeroPtBr`) e validação de formulário.
- [x] `DetalheRfScreen` (projeção completa) + `CadastroAcaoScreen` (ticker, qtd, preço médio, corretora, data).
- [x] Notifiers de CRUD (`rendaFixaListProvider`/`acoesListProvider`); o `patrimonioProvider` observa as listas e se recompõe (sem dependência reversa).
- [x] Testes: parser, descrição de taxa, CRUD→patrimônio, widget de lista. **114 testes**, `analyze` limpo.
- **DoD:** registrar RF + ação atualiza patrimônio e donut na Home; editar/excluir persiste. ✔
- _Stretch adiado:_ cotação ao vivo/P-L de ações e busca CNPJ no cadastro (dependem dos datasources da F7); tela de detalhe de ação (F7).

## ✅ F6 — Conversor / Comparador de Renda
- [x] `ConversorScreen`: valor + prazo, linhas de opção dinâmicas (tipo + taxa + isento), índices do dia (cache) → rentabilidade líquida anual efetiva + gross-up de isentos.
- [x] Comparação de N cenários (add/remover) + `BarComparador` (`fl_chart` `BarChart`) com legenda textual e banner informativo CVM.
- [x] `TipoRendimentoUi` extraído e compartilhado (cadastro RF + conversor); função pura `compararOpcoes` (motor F1).
- [x] Testes: comparador (110% CDI × IPCA+6% × 13,5% pré × LCI 95% isenta — a isenta vence; gross-up só p/ isentos) + widget do conversor. **120 testes**, `analyze` limpo.
- **DoD:** comparação reproduz o caso-chave do plano (isento supera tributável; gross-up calculado). ✔

## ✅ F7 — Ações & CNPJ
- [x] `brapi_remote` (quote + available) com DTO/mapper e mapeamento 401/429/null; token brapi em `ConfiguracaoTema` (runtime); `CotacaoRepository` com cache diário por ticker + fallback offline `stale`.
- [x] CNPJ encadeado (BrasilAPI→OpenCNPJ→ReceitaWS) → `Result<Emissor>`; provider de consulta.
- [x] `BuscaAcoesScreen` (busca por ticker, debounce) + `DetalheAcaoScreen` (cotação, fundamentos com `—`, **sinais próprios** P/L/P-VP/DY/ROE, degradação sem token/rating); rota `/acoes/:ticker`.
- [x] `mapDioError` compartilhado (refatorado também no repo de indicadores); `AuthFailure` adicionado.
- [x] Testes: parse brapi (429/null/FormatException), fallback de CNPJ, heurística de sinais, round-trip do token, widget do detalhe. **137 testes**, `analyze` limpo.
- **DoD:** buscar ticker mostra cotação+fundamentos; CNPJ resolve com fallback. ✔
- _Adiado:_ `CandlestickChart` (histórico brapi), Tesouro CSV datasource, **marcação a mercado no patrimônio** (ações seguem pelo custo até a cotação ser puxada para a carteira), busca de CNPJ no cadastro de RF, e UI de token (F8).

## 🟡 F8 — Tema, i18n & Polimento  *(núcleo concluído)*
- [x] Tema customizável: seed editável, claro/escuro/sistema, `dynamic_color` (Material You quando disponível), **persistência** em `configuracoes` via `ConfiguracaoNotifier` observado pelo `app.dart`.
- [x] `ConfiguracoesScreen` real: Aparência (modo, Material You, seed), Dados (token brapi, export `share_plus`, import `file_picker` replace/merge, status do cache + refresh), Sobre.
- [x] Testes: persistência do tema entre sessões + token→`brapiTokenProvider`; widget do Ajustes. **140 testes**, `analyze` limpo.
- **DoD (núcleo):** trocar tema/seed persiste entre sessões. ✔
- [ ] **Adiado:** l10n pt-BR completo (`.arb` + gen-l10n) — refator cross-cutting de strings; o app já é pt-BR.
- [ ] **Adiado:** `flutter_launcher_icons` + `flutter_native_splash` (geração de assets) e auditoria formal de a11y (telas já usam `Semantics`, cor+ícone+texto e layouts tolerantes a `textScaler`).

## 🟡 F9 — Testes, Hardening & Release  *(automatizável concluído)*
- [x] Testes ponta-a-ponta (headless, em `test/e2e/`, app real + DB em memória + repo de indicadores falso): navegação pelas 5 abas do shell; cadastro de RF → item na carteira → patrimônio na Home. Export/import já coberto por teste de serviço (F2).
- [x] Hardening de layout: corrigido overflow das linhas rótulo↔valor (projeção, detalhe RF, fundamentos) em telas estreitas (rótulo `Expanded`).
- **140+ testes; `analyze` limpo.**

### Checklist de release (manual — requer ambiente/credenciais do usuário)
- [ ] **Bundle/Application ID inconsistente entre plataformas** — corrigir antes de publicar:
  - Android (`android/app/build.gradle[.kts]`) e Linux (`linux/CMakeLists.txt`): `br.com.fiduciascm.investa_br`.
  - iOS/macOS (`PRODUCT_BUNDLE_IDENTIFIER`): `br.com.fiduciascm.investaBr` (camelCase gerado pelo Xcode).
  - Decidir o ID canônico e uniformizar (editar no Xcode para não quebrar assinatura).
- [ ] `flutter_launcher_icons` + `flutter_native_splash` — exigem um PNG de logo (asset de design ainda não fornecido).
- [ ] `window_manager` no desktop (título/tamanho mínimo), isolado atrás de um `DesktopWindowService` — adicionar dependência + init em `main` só no desktop.
- [ ] Assinatura por plataforma: keystore Android (Play App Signing), certificado/provisioning iOS/macOS; bundle, ícones/splash.
- [ ] Builds `flutter build {apk|appbundle|ipa|windows|macos|linux}` em release + smoke manual nos 5 SO.
- **DoD (release):** artefatos release abrindo em Android, iOS, Windows, macOS e Linux.

---

## Dívidas técnicas / deferrals transversais
- [ ] Smoke real em device/desktop por fase (até aqui só `analyze` + `flutter test` validam a compilação da árvore).
- [ ] `IndicadorCard.variacao` oculto por ora (precisa de série histórica para inferir alta/baixa).
- [ ] Patrimônio: ações marcadas pelo custo até a cotação da brapi existir (F7).
