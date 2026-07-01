# Plano de Implementacao — Investa BR

> **Documento de planejamento** para implementacao por **Claude Opus 4.8**.
> App **Flutter** (todas as plataformas **exceto Web**) de auxilio a investimentos em **renda fixa e acoes** (Brasil).
> Package: `investa_br`. Idioma do app: pt-BR.

## Sumario

1. Visao Geral & Objetivos
2. Requisitos & Plataformas Alvo
3. Stack Tecnologica & Decisoes de Arquitetura
4. Estrutura de Pastas (feature-first)
5. Modelo de Dominio & Entidades
6. Matematica Financeira, Tributacao & Conversor de Renda
7. Camada de Dados, APIs Gratuitas & Cache Diario
8. Persistencia Local NoSQL/JSON & Import/Export
9. Gerencia de Estado & Navegacao
10. Telas & Fluxos de UX
11. Tematizacao Customizavel (Material 3)
12. Busca de Acoes, CNPJ & Recomendacoes
13. Tratamento de Erros, Offline & Resiliencia
14. Seguranca & Privacidade dos Dados Locais
15. Internacionalizacao Multi-idioma & Formatacao
16. Testes & Qualidade de Codigo
17. Build & Release por Plataforma
18. Roadmap de Implementacao em Fases
19. Riscos & Mitigacoes
20. Apendices

---

## Visao Geral & Objetivos

### 1. Proposito do app

O **Investa BR** (package `investa_br`) e um aplicativo Flutter multiplataforma (Android, iOS, Windows, macOS, Linux — **sem web**) para **registro, acompanhamento e comparacao de investimentos brasileiros de renda fixa e acoes da B3**, com motor de calculo financeiro local fiel as convencoes do mercado nacional (base 252 dias uteis, IR regressivo, IOF dos 30 dias) e dados de indicadores buscados em APIs publicas gratuitas (Banco Central, BrasilAPI, brapi.dev, Tesouro Transparente, AwesomeAPI).

O app resolve uma dor concreta do investidor PF brasileiro: **"quanto eu realmente tenho, quanto vou receber liquido e qual produto rende mais"** — sem planilhas manuais, sem depender de uma corretora especifica e funcionando offline depois do primeiro carregamento do dia.

> **Premissa regulatoria (load-bearing):** o app **NAO** e consultoria de investimento (aspecto CVM). Toda projecao e comparacao e **informativa**. A UI deve exibir aviso datado de que valores sao estimativas e nao recomendacao. Isso condiciona o tom de toda a feature de "sinais" de acoes (ver Secao 5, escopo).

### 2. Publico-alvo

| Persona | Perfil | Necessidade central no app |
|---|---|---|
| **Investidor PF iniciante/intermediario** | Tem CDB/LCI/Tesouro/poupanca, comeca em acoes; usa celular | Ver patrimonio consolidado, entender rendimento liquido, comparar produtos |
| **Investidor "planilheiro"** | Hoje controla tudo em Excel; quer portabilidade | Importar/exportar JSON, usar em desktop, manter o dado sob seu controle |
| **Usuario multi-dispositivo** | Alterna celular + desktop (Windows/macOS/Linux) | Mesma base via export/import; UI responsiva (NavigationBar/Rail) |

Caracteristicas comuns: foco no **mercado brasileiro** (pt-BR, R$, dd/MM/yyyy), valoriza **privacidade** (dados locais, sem servidor proprio, sem login) e tolera **dados D-1** (indicadores atualizam 1x/dia).

> **Decisao de produto derivada:** como nao ha backend proprio nem autenticacao, **toda a fonte de verdade e local** (sembast) e a sincronizacao entre dispositivos e **manual via arquivo JSON**. Isso e um principio, nao uma limitacao temporaria.

### 3. Resumo das funcionalidades (MVP)

```
Investa BR
├── [Inicio]      Dashboard: cards SELIC/CDI/IPCA/IGP-M + patrimonio total + donut da carteira
├── [Carteira]    CRUD de renda fixa e posicoes em acoes; projecao bruta/liquida por posicao
├── [Conversor]   Comparador multi-produto -> rentabilidade liquida anual efetiva + gross-up
├── [Acoes]       Busca brapi.dev; detalhe com candlestick; sinais proprios de fundamentos
└── [Ajustes]     Tema (seed/Material You/claro-escuro), import/export JSON, refresh manual
```

| # | Funcionalidade | Fontes de dados | Calculo local |
|---|---|---|---|
| F1 | **Dashboard de indicadores** (cards SELIC meta/CDI/IPCA/IGP-M, com data) | BCB SGS `/ultimos/1` series [432,11,12,433,189,226,195] | — |
| F2 | **Patrimonio consolidado** (bruto + modo liquido se resgatasse hoje) | Local + cotacoes brapi | Marcacao na curva (RF) + cotacao (acoes) |
| F3 | **Donut da carteira** (RF x acoes x Tesouro, por classe/indexador) | Local | Agregacao por `ClasseAtivo` |
| F4 | **CRUD renda fixa** (CDB/LCI/LCA/CRI/CRA/Tesouro/debenture) | Local + CNPJ do emissor (BrasilAPI/OpenCNPJ) | Value object de taxa |
| F5 | **CRUD acoes** (ticker, qtd, preco medio) | Local + brapi cotacao | P/L da posicao |
| F6 | **Projecao de valor futuro** (VF bruto, IOF, IR, VF liquido) | Local + indicadores em cache + feriados | base 252, juros compostos |
| F7 | **Conversor/Comparador** (110% CDI vs IPCA+ vs prefixado vs LCI isenta) | Indicadores em cache | Rentab. liquida anual efetiva + gross-up |
| F8 | **Busca/detalhe de acoes** (candlestick, P/L, P/VP, DY, ROE) | brapi.dev (token free) | Sinais proprios de fundamentos |
| F9 | **Import/Export JSON** (backup completo do usuario) | Local | checksum SHA-256, REPLACE/MERGE |
| F10 | **Temas Material 3** (seed personalizavel, Material You, claro/escuro/sistema) | Local (store configuracoes) | — |
| F11 | **Cache "primeira requisicao do dia"** (offline, stale-while-revalidate) | Todas as APIs criticas | Chave por indicador+data SP |

**Mapa feature -> camada (feature-first + Clean pragmatica):**

```
lib/
  main.dart
  src/
    app.dart                 # MaterialApp.router + ThemeController acima do MaterialApp
    routing/                 # go_router 17 + TypedGoRoute (go_router_builder); GoRouter como provider
    localization/            # .arb + gen-l10n (pt_BR default)
    constants/               # series SGS, endpoints, codigos de titulos Tesouro
    common/                  # widgets, theme (flex_color_scheme), utils (formatters intl), Result<T>
    features/
      indicadores/           # presentation | application | domain | data  (BCB SGS + cache diario)
      renda_fixa/            # presentation | application | domain | data  (motor de calculo)
      acoes/                 # presentation | application | domain | data  (brapi, sob demanda)
      patrimonio/            # agrega renda_fixa + acoes
      conversor_taxas/       # comparador (depende do motor + indicadores)
      configuracoes/         # tema, import/export
```

Cada feature tem 4 camadas: `presentation` (telas + Riverpod Notifiers/AsyncNotifiers), `application` (use-cases/services entre features), `domain` (entidades freezed imutaveis + sealed unions), `data` (repositorios + datasources remoto/local sembast). DI e feita **pelo proprio Riverpod** (Provider + `overrideWith`) — sem `get_it`/`injectable`.

**Modelo de dominio central (nunca um `double` solto para taxa):**

```dart
enum TipoRendimento { prefixado, percentualCdi, percentualSelic, ipcaMais, igpmMais, percentualPuro }
enum ClasseAtivo {
  cdb, lci, lca, cri, cra, debenture, debentureIncentivada,
  tesouroSelic, tesouroPre, tesouroIpca, poupanca,
}

/// Taxa como value object datado — NUNCA persistir a taxa efetiva calculada,
/// apenas a contratada. base 252 + composta e o PADRAO de mercado.
@freezed
class TaxaContratada with _$TaxaContratada {
  const factory TaxaContratada({
    required TipoRendimento tipo,
    required double valorContratado,   // 0.13 (13% a.a.) | 1.10 (110% CDI) | 0.06 (IPCA+6%)
    String? indexador,                 // CDI | SELIC | IPCA | IGP-M | null (prefixado)
    @Default(252) int baseDias,        // 252 (padrao) | 360 | 365 configuravel por produto
    @Default(true) bool composta,      // capitalizacao composta padrao
  }) = _TaxaContratada;
}
```

**Resultado unico do comparador (a metrica que tudo converge):**

```
iLiqAnual = (VF_liquido / VI) ^ (252 / diasUteis) - 1        // rentab. liquida anual efetiva, base 252
taxaBrutaEquivalente = iLiqAnual_isento / (1 - aliquotaIr(prazoDias))   // gross-up dos isentos
```

### 4. Principios de produto

1. **Local-first e privacidade por padrao.** Sem login, sem servidor proprio, sem telemetria de dados financeiros. A base de verdade e o sembast no diretorio de documentos do app. Sincronizar = exportar/importar JSON. Implicacao: o export e texto-claro; se houver requisito de sigilo, oferecer criptografia opcional do arquivo.

2. **Offline-first com dado datado e honesto.** O cache "primeira requisicao do dia" serve do disco se `data == hoje` (fuso America/Sao_Paulo, UTC-3). Em falha de rede, serve o ultimo snapshot bom marcando `stale=true` na UI. Todo card mostra **"Atualizado em dd/MM/yyyy"** e oferece **refresh manual** que ignora o cache. Nunca esconder que o dado pode estar velho.

3. **Calculo fiel ao mercado brasileiro, datado e versionado.** base 252 dias uteis com juros compostos como padrao (CDB/LCI/LCA/prefixado/pos-CDI); contagem **real** de dias uteis usando feriados (BrasilAPI `/feriados/v1/{ano}`), nunca aproximacao `du = dc * 252/365`. Regras tributarias (IR regressivo, IOF dos 30 dias, isencoes) ficam numa **config versionada e DATADA** (`TaxRuleSet`), porque sao o ponto mais sujeito a mudanca legislativa.

   ```
   IR regressivo (rendimento):  <=180d 22,5% | <=360d 20% | <=720d 17,5% | >720d 15%
   IOF (resgate <30d):          aliquota = trunc((30 - dias)/30 * 100)/100 ; >=30d -> 0
   ISENTOS de IR-PF (2026):     LCI, LCA, CRI, CRA, debentures incentivadas, poupanca
                                (MP 1.303/2025 caducou em out/2025 -> isencao mantida)
   ```

4. **Sem ambiguidade de fonte: SGS para calcular, headline so para exibir.** Os calculos exatos usam BCB SGS (valor como **string**, parse cuidadoso de virgula/ponto; series 226/195 trazem `dataFim`). BrasilAPI `/taxas/v1` (anualizado) so como atalho "headline", nunca para precificacao.

5. **Degradar graciosamente.** Recomendacoes de analistas da brapi (`recommendationKey`, `targetMeanPrice` etc.) vem **null** no plano free (HTTP 200, sem 401). A UI nunca quebra com campo ausente: oculta o bloco ou mostra "indisponivel" e usa **sinais proprios** calculados de fundamentos (P/L, P/VP, DY, ROE). Idem para 429 (backoff) e respostas HTML de erro do SGS.

6. **Acessibilidade nao e opcional.** Contraste AA Material 3; `Semantics` em cards e graficos; alvos de toque >=48dp; suporte a `textScaleFactor` sem overflow (Wrap/FittedBox); **variacao sempre com icone + texto, nunca so verde/vermelho**; legenda textual em todo grafico (donut/linha/barra/candle).

7. **pt-BR de ponta a ponta.** Locale padrao `pt_BR`; `NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')`, percentual e `DateFormat('dd/MM/yyyy', 'pt_BR')` centralizados em `common/utils`. Strings via gen-l10n (.arb).

8. **Estado assincrono explicito.** `AsyncValue` (sealed) para data/loading/error em toda fronteira de UI; `AsyncNotifier` + `AsyncValue.guard`; nas camadas data/domain, `Result<T>` (sealed Success/Failure) mapeando `DioException -> Failure` tipado. Sem `fpdart`/`dartz` obrigatorios.

9. **Reprodutibilidade e qualidade.** Flutter 3.44 / Dart 3.12 fixados via FVM (`.fvmrc`); lints `very_good_analysis` (proibe `print`, exige imutabilidade); code-gen unico via `build_runner` (freezed + json_serializable + riverpod_generator + go_router_builder), com `*.g.dart`/`*.freezed.dart` commitados.

10. **Cortesia com APIs publicas e gratuitas.** Cache diario agressivo; ~5 requisicoes paralelas no boot como cortesia ao SGS; User-Agent padrao em todas as chamadas (o SGS rejeita alguns clientes sem UA); CNPJ com TTL longo e fallback encadeado (BrasilAPI -> OpenCNPJ -> ReceitaWS pontual).

### 5. Escopo — dentro / fora / desejavel

#### Dentro do escopo (MVP — obrigatorio)

- **Plataformas:** Android, iOS, Windows, macOS, Linux. Comando de criacao:
  ```
  flutter create --platforms=android,ios,windows,macos,linux investa_br
  ```
- **Renda fixa:** CRUD completo; classes CDB/LCI/LCA/CRI/CRA/debenture/debenture incentivada/Tesouro (Selic/Pre/IPCA+)/poupanca; tipos de rendimento prefixado, % CDI, % Selic, IPCA+, IGP-M+, percentual puro; projecao bruta e liquida (IR + IOF).
- **Acoes B3:** CRUD de posicoes; busca e cotacao via brapi.dev (token free obrigatorio na pratica; sem token apenas PETR4/VALE3/MGLU3/ITUB4); detalhe com CandlestickChart; sob demanda com cache proprio (nao pesa o boot).
- **Indicadores:** BCB SGS direto (sem auth) para os cards e o motor de calculo; cache "primeira requisicao do dia" com batch paralelo no boot.
- **Conversor/Comparador:** converte qualquer produto para rentabilidade liquida anual efetiva (base 252) + gross-up dos isentos; BarChart comparativo.
- **Patrimonio:** consolidado bruto + modo liquido estimado; donut por classe.
- **Tesouro Direto:** via CSV do Tesouro Transparente (CKAN), `~13,5 MiB`, 1x/dia, filtro local pela `Data Base` mais recente; titulos por extenso ("Tesouro Selic"/"Tesouro Prefixado"/"Tesouro IPCA+"). **Nao** usar `datastore_search` (HTTP 400) nem o legado `tesourodireto.com.br` (410 Gone).
- **CNPJ do emissor:** BrasilAPI principal + OpenCNPJ fallback; cache local por CNPJ com TTL longo.
- **Persistencia NoSQL/JSON:** sembast (`databaseFactoryIo`), 4 stores (`investimentos_rf`, `posicoes_acoes`, `cache_indicadores`, `configuracoes`), IDs UUID, versionado via `openDatabase(version, onVersionChanged)`.
- **Import/Export:** arquivo JSON unico `{app, schemaVersion, exportedAt, appVersion, checksum sha256, data}`; `cache_indicadores` **fora** do export (derivado); import valida app+schemaVersion (bloqueia versao mais nova) + checksum, em transacao atomica REPLACE (default) ou MERGE por id (last-write-wins por `updatedAt`).
- **Temas:** Material 3 (flex_color_scheme + keyColors), dynamic_color/Material You com fallback obrigatorio para seed manual; light/dark/system; persistidos no sembast e expostos via ThemeController Riverpod.
- **Navegacao responsiva:** RootShell com 3 breakpoints (NavigationBar <600dp, NavigationRail compacto 600-840dp, NavigationRail extended/Drawer >=840dp), `IndexedStack` para preservar estado, FAB contextual em Inicio/Carteira.
- **Graficos:** fl_chart (PieChart donut, LineChart, BarChart, CandlestickChart) sempre com legenda textual.

#### Desejavel (nice-to-have, ativavel/futuro — NAO bloqueia MVP)

- **Recomendacoes de acoes (compra/venda/manter):** **desejavel, nao core.** Os campos da brapi so vem populados no plano PRO pago. No MVP gratuito, derivar **sinais proprios** locais de fundamentos (P/L, P/VP, DY, ROE) — apresentados como indicadores informativos, jamais como "recomendacao de analista". Ativavel se o usuario fornecer token pago.
- **Cambio (secundario):** AwesomeAPI Economia (USD-BRL etc.) com cache 1min sem chave; PTAX oficial via BrasilAPI `/cambio` (boletim de **FECHAMENTO**). Util para exibir, nao critico ao calculo.
- **Projecoes Focus (Expectativas de Mercado, BCB Olinda):** mostrar mediana de SELIC/IPCA no dashboard e no comparador.
- **Historico longo de indicadores** no LineChart (fragmentar consultas SGS em janelas de ate 10 anos e concatenar).
- **Criptografia opcional do arquivo de export** (senha).
- **Calendario ANBIMA/B3 completo** validado contra a lista de feriados nacionais da BrasilAPI (que so traz `type=national`).

#### Fora do escopo (explicitamente NAO faremos)

- **Plataforma web** (libera escolha de libs puro-Dart sem restricao de compatibilidade web).
- **Backend proprio, login, conta na nuvem ou sincronizacao automatica** entre dispositivos (sync = JSON manual).
- **Execucao de ordens / corretagem / integracao com corretora.** O app nao compra nem vende; so registra e projeta.
- **Consultoria/recomendacao de investimento no sentido regulatorio (CVM).** Todo numero e informativo.
- **`get_it`/`injectable`** (DI e do Riverpod), **Hive/Isar/isar_community** (storage e sembast), **Drift como storage principal** (so opcional/futuro se surgirem series historicas massivas, mantendo sembast para documentos do usuario).
- **Series historicas massivas** (centenas de milhares de cotacoes) no MVP — sembast carrega em memoria; volume previsto e de dezenas a poucos milhares de registros.
- **Tributacao de pessoa juridica, come-cotas de fundos, e produtos fora da lista de classes do MVP.**

### 6. Criterios de "pronto" do MVP

| Eixo | Criterio mensuravel |
|---|---|
| Funcional | F1-F11 implementadas; app abre offline servindo cache do dia |
| Calculo | Testes unitarios cobrindo cada `TipoRendimento`, IR/IOF/isencao e gross-up batem com exemplos conhecidos |
| Parsing | Testes do parse SGS (string, `dataFim`, resposta HTML de erro) e do CSV do Tesouro (`;`, decimal virgula) |
| Cache | Teste da logica diaria (data SP, stale-while-revalidate, refresh forcado, fallback offline) |
| Import/Export | Teste REPLACE/MERGE/checksum + bloqueio de schemaVersion mais nova |
| Multiplataforma | Import/export validado em Windows, macOS e Linux (file_picker + share_plus + window_manager) |
| Qualidade | `very_good_analysis` sem violacoes; sem `print`; `*.g.dart`/`*.freezed.dart` gerados e commitados |
| Acessibilidade | Contraste AA, Semantics em cards/graficos, sem overflow a 2x textScale, variacao com icone+texto |

> Resumo de uma linha para o implementador: **um cofre local de investimentos brasileiros, pt-BR, offline-first, que calcula rendimento liquido fiel ao mercado (base 252 + IR/IOF), compara produtos numa metrica unica, busca indicadores gratuitos com cache diario, e exporta tudo como JSON — sem web, sem backend, sem prometer recomendacao de analista.**

---

## Requisitos & Plataformas Alvo

Esta seção define **o que** o Investa BR (`investa_br`) deve fazer e **onde** deve rodar. É a base contratual do plano: cada requisito é numerado e rastreável, e cada decisão de plataforma vem com sua implicação técnica concreta. Quando um requisito tocar cálculo financeiro, tributação ou consumo de API, a regra exata está aqui ou referenciada na seção correspondente do plano.

> Convenção: `[RF-n]` = Requisito Funcional, `[RNF-n]` = Requisito Não-Funcional, `[PL-x]` = decisão de plataforma. IDs são estáveis e devem ser citados em PRs/commits/testes.

---

### 1. Visão e escopo do produto

O Investa BR é um app **pessoal de acompanhamento de investimentos brasileiros** (renda fixa + ações B3), **offline-first**, **sem backend próprio** (consome apenas APIs públicas gratuitas) e **sem login/conta** (todos os dados ficam no dispositivo). O usuário cadastra suas posições, vê indicadores macro do dia, projeta rendimentos com tributação correta, compara produtos numa métrica única e exporta/importa tudo como JSON.

**Está no escopo (MVP):** indicadores BCB, carteira de renda fixa, carteira de ações, patrimônio agregado, conversor/comparador de renda fixa, configurações/tema, import/export.

**Fora de escopo (MVP):** plataforma **web** (decisão fixada — ver §4), sincronização em nuvem, autenticação, recomendações de analistas pagas (degradar para sinais próprios — `[RF-19]`), corretagem/ordens reais, notificações push.

---

### 2. Requisitos Funcionais

Lista numerada, agrupada por feature. As features mapeiam 1:1 com os diretórios `lib/src/features/<feature>/`.

#### 2.1 Indicadores (feature `indicadores`)

1. **[RF-1] Dashboard de indicadores macro.** Exibir cards com os indicadores oficiais do BCB SGS: **SELIC meta (série 432)**, **CDI/DI diário (12)**, **IPCA mensal (433)** e **IGP-M mensal (189)**. Adicionalmente disponíveis para telas de detalhe: SELIC diária (11), TR (226), poupança (195).
2. **[RF-2] Origem e parsing do dado.** Buscar via `GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados/ultimos/1?formato=json`. O endpoint `/ultimos/{N}` **não** sofre o limite de janela de 10 anos. O campo `valor` vem como **string** com ponto ou vírgula decimal e **deve** ser parseado defensivamente (nunca `double` direto do JSON). As séries 226 (TR) e 195 (poupança) trazem campo adicional `dataFim` — modelar e exibir o período de validade.

   ```dart
   /// Parse robusto do `valor` do SGS: aceita "14.50", "14,50", "0.053400".
   /// Lança FormatException controlada para virar Failure tipado (ver Tratamento de Erro).
   double parseValorSgs(String raw) {
     final normalizado = raw.trim().replaceAll('.', '').replaceAll(',', '.');
     // Nota: o SGS usa ponto como separador decimal no formato=json ("14.50").
     // A normalização acima cobre o caso pt-BR ("14,50"); detectar qual veio:
     final usaVirgula = raw.contains(',');
     final s = usaVirgula
         ? raw.trim().replaceAll('.', '').replaceAll(',', '.')
         : raw.trim();
     final v = double.tryParse(s);
     if (v == null) throw FormatException('Valor SGS inválido: "$raw"');
     return v;
   }
   ```

3. **[RF-3] Histórico de indicador.** Ao tocar num card, abrir tela de histórico com `LineChart` (fl_chart). Consultas por período usam `&dataInicial=DD/MM/AAAA&dataFinal=DD/MM/AAAA`; séries longas (> 10 anos) **devem** ser fragmentadas em janelas de até 10 anos e concatenadas (limite oficial do BCB desde 26/03/2025).
4. **[RF-4] Refresh manual.** Botão de atualização que força o refetch ignorando o cache do dia (ver `[RF-22]`).

#### 2.2 Renda Fixa (feature `renda_fixa`)

5. **[RF-5] CRUD de posições de renda fixa.** Cadastrar, editar, listar e excluir investimentos. Campos mínimos: apelido, emissor, classe do ativo, tipo de rendimento, valor contratado, indexador, base de dias, capitalização, valor inicial, data de início, data de vencimento, flag de isenção (derivada da classe).
6. **[RF-6] Modelagem da taxa como value object.** Nunca persistir um `double` solto. A taxa é um objeto `{tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}`. `TipoRendimento` e `ClasseAtivo` são `sealed`/enums freezed com pattern matching.

   | Classe (`ClasseAtivo`) | Isento IR-PF (2026) | Base padrão |
   |---|---|---|
   | CDB, LC, LF | Não | 252 |
   | Tesouro Selic/Pré/IPCA+ | Não | 252 |
   | Debênture comum | Não | 252 |
   | LCI, LCA, CRI, CRA | **Sim** | 252 |
   | Debênture incentivada | **Sim** | 252 |
   | Poupança | **Sim** | regra própria (TR + juro) |

7. **[RF-7] Projeção de valor futuro.** Calcular VF bruto, rendimento bruto, IOF, IR e VF líquido para qualquer posição, usando o motor base 252 dias úteis com juros compostos como padrão (360/365 configurável por produto). Contagem de dias úteis usa feriados nacionais reais (BrasilAPI `/feriados/v1/{ano}`).
8. **[RF-8] Enriquecimento por CNPJ do emissor.** Campo opcional de busca de CNPJ que preenche razão social/nome fantasia/situação cadastral. Fonte principal **BrasilAPI** (`/api/cnpj/v1/{cnpj}`), fallback **OpenCNPJ** (`api.opencnpj.org/{cnpj}`, schema com array `QSA` e endereço plano). CNPJ normalizado (só dígitos) antes da chamada; cache local por CNPJ com TTL longo.
9. **[RF-9] Marcação na curva.** Cada posição mostra o valor bruto atualizado "marcado na curva" pela taxa contratada na data de hoje (dias úteis decorridos).

#### 2.3 Ações (feature `acoes`)

10. **[RF-10] CRUD de posições de ações.** Cadastrar ticker, quantidade, preço médio, data de compra, corretora. Calcular P/L (lucro/prejuízo) contra a última cotação.
11. **[RF-11] Cotações brapi.dev.** Buscar cotação via `GET /api/quote/{ticker}` com **token gratuito obrigatório** (header `Authorization: Bearer` ou `?token=`). Sem token, apenas PETR4, VALE3, MGLU3, ITUB4 funcionam. Plano free: 15.000 req/mês, 1 ticker/req, atualização ~30 min, histórico ~3 meses. Tratar **HTTP 429** com backoff exponencial.
12. **[RF-12] Busca de ações.** Tela de busca/autocomplete (`/api/available?search=` ou `/api/quote/list`) e tela de detalhe com `CandlestickChart`.
13. **[RF-13] Cache sob demanda.** Cotações de ações têm cache diário próprio e **não** entram no batch de boot (para não pesar a inicialização nem consumir cota brapi à toa).

#### 2.4 Patrimônio (feature `patrimonio`)

14. **[RF-14] Patrimônio total.** Somar valor bruto atualizado de renda fixa (marcado na curva) + ações (última cotação × quantidade). Exibir variação no período com ícone + texto (nunca só cor — ver `[RNF-12]`).
15. **[RF-15] Distribuição da carteira.** `PieChart` em modo donut (fl_chart) por classe de ativo, **sempre acompanhado de legenda textual acessível**.
16. **[RF-16] Modo líquido.** Alternar entre patrimônio bruto e líquido estimado (descontando IR/IOF como se resgatasse hoje).

#### 2.5 Conversor / Comparador (feature `conversor_taxas`)

17. **[RF-17] Comparador de produtos.** Comparar produtos de tipos diferentes (ex.: 110% CDI, IPCA+6%, 13% pré, LCI 95% CDI isenta) convertendo **tudo** para **rentabilidade líquida anual efetiva (% a.a., base 252)** para um prazo planejado, após IR e IOF. Exibir ranking + `BarChart`.
18. **[RF-18] Gross-up de isentos.** Para produtos isentos, calcular e exibir a **taxa bruta equivalente**: `taxaBrutaEquivalente = taxaLiquidaIsenta / (1 - aliquotaIR(prazoDias))`, usando a alíquota IR do prazo planejado. UI deixa explícito o prazo assumido.
19. **[RF-19] Tributação datada e versionada.** As regras de IR regressivo (22,5%/20%/17,5%/15%), IOF regressivo (Decreto 6.306/2007) e isenções (LCI/LCA/CRI/CRA/incentivadas/poupança isentos em 2026, pós MP 1.303/2025 caducada) ficam encapsuladas num `TaxRuleSet` **datado e versionado**. UI exibe aviso de que os valores são informativos e **não** constituem recomendação de investimento (aspecto CVM).

#### 2.6 Configurações e dados (feature `configuracoes`)

20. **[RF-20] Tema.** Selecionar `ThemeMode` (light/dark/system), cor-semente personalizável e flag "usar cor do sistema" (Material You). Persistir no sembast (store `configuracoes`).
21. **[RF-21] Import/Export JSON.** Exportar um arquivo JSON único `{app:'investa_br', schemaVersion, exportedAt, appVersion, checksum sha256, data:{investimentos_rf, posicoes_acoes, configuracoes}}` (cache de indicadores **não** entra — é derivado). Importar com validação de `app` + `schemaVersion` (bloqueia versão mais nova), checksum SHA-256, e aplicação em **transação atômica** nos modos **REPLACE** (default) ou **MERGE por id** (last-write-wins via `updatedAt`). `file_picker` para abrir, `share_plus` para salvar/compartilhar.
22. **[RF-22] Cache "primeira requisição do dia".** No boot, `DailyCacheService` checa a chave por indicador + data (`yyyy-MM-dd`, fuso **America/São_Paulo, UTC-3 fixo**). Se `data == hoje` e dentro do TTL, serve do cache. Senão, dispara batch **paralelo** (≤ 5 req): SGS `/ultimos/1` das séries `[432, 11, 12, 433, 189, 226, 195]` + feriados BrasilAPI do ano + cotações da carteira. Persiste snapshot com `dataUltimaAtualizacao` + `fetchedAt`. **Stale-while-revalidate**; fallback offline marcando `stale=true`.

#### Fluxo de boot (resumo acionável)

```
App start
  │
  ├─ LocalDb.open() (sembast, getApplicationDocumentsDirectory)
  │     └─ onVersionChanged → migrações de schema
  │
  ├─ DesktopWindowService.init() (só Windows/macOS/Linux)
  │
  ├─ ThemeController.load() (lê seed/themeMode/useDynamic do store config)
  │
  └─ DailyCacheService.bootstrap()
        ├─ chave indicadores_dia existe e data==hoje? → serve cache (stale=false)
        └─ não → batch paralelo (≤5 req):
              ├─ SGS /ultimos/1 × [432,11,12,433,189,226,195]
              ├─ BrasilAPI /feriados/v1/{anoAtual}
              └─ brapi cotações da carteira
              ├─ sucesso → persiste snapshot (dataUltimaAtualizacao, fetchedAt)
              └─ falha de rede → usa último snapshot bom, marca stale=true
```

---

### 3. Requisitos Não-Funcionais

#### 3.1 Offline-first e resiliência de rede

1. **[RNF-1] Funcionar sem internet.** O app **deve** abrir e operar offline com os últimos dados em cache. Toda leitura de indicador/cotação tem fallback para o último snapshot bom persistido no sembast, marcado com `stale=true` para a UI sinalizar "dado desatualizado".
2. **[RNF-2] Erros tipados, não exceções vazando.** Camadas data/domain retornam `Result<T>` (sealed `Success`/`Failure`). `DioException` → `Failure` tipado (timeout, semConexão, http4xx, http5xx, parsing, rateLimit429). Na fronteira Riverpod, `AsyncNotifier` + `AsyncValue.guard`; a UI faz pattern match em `AsyncValue` (data/loading/error).

   ```dart
   sealed class Result<T> {
     const Result();
   }
   final class Success<T> extends Result<T> {
     const Success(this.value);
     final T value;
   }
   final class Failure<T> extends Result<T> {
     const Failure(this.error);
     final AppFailure error;
   }

   sealed class AppFailure {
     const AppFailure();
   }
   final class NetworkFailure extends AppFailure { const NetworkFailure(); }
   final class RateLimitFailure extends AppFailure { const RateLimitFailure(); } // HTTP 429
   final class ParsingFailure extends AppFailure {
     const ParsingFailure(this.raw);
     final String raw;
   }
   final class ServerFailure extends AppFailure {
     const ServerFailure(this.status);
     final int status;
   }
   ```

3. **[RNF-3] Respeitar limites de API.** Máximo ~5 requisições paralelas ao BCB SGS (cortesia, evita bloqueio). `User-Agent` HTTP padrão obrigatório (o SGS rejeita alguns clientes sem UA, retornando HTML em vez de JSON — o parser deve detectar resposta HTML e convertê-la em `ServerFailure`). Backoff exponencial em 429/5xx. Cache diário agressivo como primeira linha de defesa.
4. **[RNF-4] Robustez de parsing.** Toda resposta de API é tratada defensivamente: `valor` do SGS é string (`[RF-2]`), CSV do Tesouro usa `;` e vírgula decimal, datas em `DD/MM/AAAA`. Respostas inesperadas (HTML, campos nulos) **nunca** devem crashar — viram `Failure` ou degradação graciosa.

#### 3.2 Performance

5. **[RNF-5] Boot rápido.** O batch de indicadores é paralelo e o app exibe esqueleto/shimmer enquanto carrega; ações e Tesouro Direto são **sob demanda**, fora do boot. Meta: primeiro frame interativo sem bloquear na rede.
6. **[RNF-6] Volume e armazenamento.** sembast carrega o banco em memória — adequado para dezenas a poucos milhares de registros (perfil deste app). **Não** persistir séries históricas massivas no sembast; se isso surgir no futuro, migrar **apenas** essas séries para Drift/SQLite, mantendo sembast para documentos do usuário.
7. **[RNF-7] UI fluida.** Preservar estado das abas com `IndexedStack` (sem rebuild ao trocar de aba). Gráficos fl_chart com dados já agregados na camada `application` (não recalcular no `build`). 60 fps como alvo em todas as plataformas.
8. **[RNF-8] CSV grande do Tesouro.** O CSV de preços/taxas (~13,5 MiB, 1x/dia) é baixado e cacheado por dia, filtrado localmente pela `Data Base` mais recente. **Não** usar `datastore_search` (DataStore desabilitado, HTTP 400). **Não** usar o endpoint legado `tesourodireto.com.br` (HTTP 410 Gone).

#### 3.3 Privacidade e segurança

9. **[RNF-9] Dados ficam no dispositivo.** Sem conta, sem backend, sem telemetria. Os únicos dados que saem do dispositivo são as consultas anônimas às APIs públicas (indicadores, cotações, CNPJ). O token brapi é runtime config, não embutido em texto-claro versionado.
10. **[RNF-10] Export é texto-claro.** O arquivo JSON exportado contém dados financeiros legíveis. A UI **deve** avisar isso ao exportar. (Criptografia opcional do export — codec do sembast com senha — fica registrada como evolução futura, não MVP.)
11. **[RNF-11] Logging só em debug.** Interceptor de logging do dio ativo **apenas** em modo debug. Nenhum dado sensível em logs de release. `very_good_analysis` proíbe `print`.

#### 3.4 Acessibilidade e i18n

12. **[RNF-12] Acessibilidade AA.** Contraste AA do Material 3; `Semantics` em cards e gráficos (legenda textual no donut/candle, não só cor); alvos de toque ≥ 48dp; suporte a `textScaleFactor` sem overflow (`Wrap`/`FittedBox`); **variação sempre com ícone + texto**, nunca só verde/vermelho.
13. **[RNF-13] Localização pt-BR.** `flutter_localizations` + gen-l10n (`.arb`), locale padrão `pt_BR`. `intl` para `NumberFormat.currency(locale:'pt_BR', symbol:'R$')`, percentual e `DateFormat('dd/MM/yyyy','pt_BR')`. Formatadores centralizados em `common/utils`.

#### 3.5 Qualidade e manutenibilidade

14. **[RNF-14] Lints rigorosos.** `very_good_analysis` em `analysis_options.yaml`; imutabilidade obrigatória; sem `print`.
15. **[RNF-15] Testabilidade.** `flutter_test` + `mocktail` + `ProviderContainer`/`overrideWith`. Cobertura obrigatória: cálculo de rendimento por tipo de taxa, parsing das APIs (incl. SGS string + `dataFim`), lógica de cache diário, import/export (REPLACE/MERGE/checksum). E2E com `integration_test` + `patrol` (file picker/permissões nativas).
16. **[RNF-16] Reprodutibilidade.** Versão do Flutter fixada via FVM (`.fvmrc`) para dev/CI. Code-gen único via `build_runner` (freezed, json_serializable, riverpod_generator, go_router_builder); `*.g.dart` e `*.freezed.dart` commitados.

---

### 4. Plataformas Alvo

**Decisão fixada:** Android, iOS, Windows, macOS, Linux. **Web está fora de escopo.**

```bash
flutter create --platforms=android,ios,windows,macos,linux investa_br
```

#### 4.1 Por que sem web (e o que isso libera)

`[PL-web]` A ausência de web **libera escolha de libs puro-Dart sem restrição de compilação para JS/Wasm**. É o que permite adotar **sembast com `databaseFactoryIo`** (acesso a arquivo via `dart:io`) como camada de storage principal, e `path_provider` para o diretório de documentos. Em web isso não funcionaria (`dart:io` indisponível) e exigiria `sembast_web` + IndexedDB. **Não** adicionar `sembast_web` ao projeto.

#### 4.2 Matriz de plataformas, versões mínimas e implicações

| Plataforma | Versão mínima de SO | UI de navegação primária | Implicações técnicas principais |
|---|---|---|---|
| **Android** | **API 21 (Android 5.0 Lollipop)** | `NavigationBar` (compact) | Material You (cores dinâmicas) só em **Android 12+ / API 31**; abaixo disso, fallback para seed manual. `file_picker`/`share_plus` usam intents/SAF nativos — testar com `patrol`. |
| **iOS** | **iOS 13** | `NavigationBar` (compact) | **Sem** Material You (não há paleta dinâmica do sistema) → sempre seed manual. `share_plus` usa share sheet nativo. Sem permissões especiais de arquivo (sandbox de Documents). |
| **Windows** | **Windows 10 (1809 / build 17763)** | `NavigationRail` (medium/expanded) | `window_manager` controla título/tamanho mínimo/centralização. `dart:io` + `path_provider` para `Documents`. Material You via **accent color** do sistema (não wallpaper). Testar import/export. |
| **macOS** | **macOS 11 (Big Sur)** | `NavigationRail` (medium/expanded) | App sandbox: capability de leitura/escrita de arquivos do usuário **deve** ser habilitada no entitlements para `file_picker`/export. Accent color do sistema para dynamic_color. |
| **Linux** | **Ubuntu 20.04 LTS** (glibc/GTK 3 equivalente) | `NavigationRail` (medium/expanded) | Requer GTK 3. `window_manager` em 0.x — **isolar atrás de `DesktopWindowService`** (API pode mudar). Accent color via tema do desktop quando disponível. Testar import/export em distro alvo. |

> As versões mínimas seguem os pisos suportados pelo Flutter 3.44 stable e pelas dependências (sembast, dio, window_manager). Fixar essas mínimas em `android/app/build.gradle` (`minSdk = 21`), `ios/Podfile` (`platform :ios, '13.0'`) e nos `CMakeLists`/entitlements desktop.

#### 4.3 Implicações transversais por agrupamento

**Mobile (Android + iOS) — `[PL-1]`**
- Navegação **compact** (`< 600dp`): `NavigationBar` na base, 5 destinos (Início, Carteira, Conversor, Ações, Ajustes). FAB contextual em Início/Carteira.
- `patrol` é necessário para testar file picker e permissões nativas de arquivo.
- iOS: nenhuma cor dinâmica do sistema → `dynamic_color` retorna `null`, **deve** cair no seed manual sem erro.

**Desktop (Windows + macOS + Linux) — `[PL-2]`**
- Navegação **medium** (600–840dp): `NavigationRail` compacto (só ícones); **expanded** (≥ 840dp): `NavigationRail(extended)` ou `NavigationDrawer`.
- `window_manager` (0.x) controla janela; **isolado** atrás de `DesktopWindowService` para troca fácil quando a API mudar:

  ```dart
  abstract interface class DesktopWindowService {
    Future<void> init();
  }

  /// Implementação real usa window_manager; em mobile injeta-se um no-op.
  final class WindowManagerDesktopService implements DesktopWindowService {
    @override
    Future<void> init() async {
      // título, tamanho mínimo, centralização — chamadas isoladas aqui.
    }
  }

  final class NoopWindowService implements DesktopWindowService {
    @override
    Future<void> init() async {}
  }
  ```

- macOS exige entitlements de acesso a arquivos do usuário (sandbox) para `file_picker` e `share_plus` salvarem o JSON de export.
- Linux exige GTK 3 presente; documentar no README de build.

**Detecção de plataforma na injeção (Riverpod como DI)**

```dart
@riverpod
DesktopWindowService windowService(Ref ref) {
  final isDesktop = !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  return isDesktop ? WindowManagerDesktopService() : NoopWindowService();
}
```

> `kIsWeb` permanece sempre `false` neste app (web fora de escopo), mas é mantido na guarda por defesa em profundidade e para que o lint não acuse acesso a `Platform` sem proteção.

#### 4.4 Material You / `dynamic_color` por plataforma

| Plataforma | Fonte da cor dinâmica | Fallback obrigatório |
|---|---|---|
| Android 12+ | Wallpaper (Material You) | Seed manual persistido |
| Android < 12 | — (indisponível) | Seed manual |
| iOS | — (indisponível) | Seed manual |
| Windows | Accent color do sistema | Seed manual |
| macOS | Accent color do sistema | Seed manual |
| Linux | Accent do tema do desktop (quando exposto) | Seed manual |

`DynamicColorBuilder` **sempre** com fallback para `FlexThemeData`/`ColorScheme.fromSeed` com a cor-semente persistida (`[RF-20]`). Quando `useDynamic == false` ou a paleta dinâmica vier `null`, usa-se o seed manual sem qualquer erro visível.

---

### 5. Árvore de arquivos (escopo desta seção)

Estrutura feature-first + Clean Architecture pragmática que materializa os requisitos acima:

```
lib/
  main.dart
  src/
    app.dart                          # MaterialApp.router + ThemeController acima
    routing/                          # go_router 17 + TypedGoRoute (go_router_builder)
    localization/                     # .arb + gen-l10n (pt_BR padrão)
    constants/                        # códigos SGS, base URLs, séries do batch
    common/
      utils/                          # formatters intl (R$, %, dd/MM/yyyy)
      result/                         # Result<T>, AppFailure (RNF-2)
      platform/                       # DesktopWindowService (PL-2)
      widgets/                        # cards, gráficos acessíveis (RNF-12)
    features/
      indicadores/                    # RF-1..RF-4
        presentation/ application/ domain/ data/
      renda_fixa/                     # RF-5..RF-9
        presentation/ application/ domain/ data/
      acoes/                          # RF-10..RF-13
        presentation/ application/ domain/ data/
      patrimonio/                     # RF-14..RF-16
        presentation/ application/ domain/ data/
      conversor_taxas/                # RF-17..RF-19
        presentation/ application/ domain/ data/
      configuracoes/                  # RF-20..RF-22
        presentation/ application/ domain/ data/
```

---

### 6. Rastreabilidade (requisito → onde resolve)

| Requisito | Feature / componente | Decisão de plataforma relacionada |
|---|---|---|
| RF-1..RF-4 | `indicadores` + `DailyCacheService` | BCB SGS sem auth; UA obrigatório (RNF-3) |
| RF-5..RF-9 | `renda_fixa` + motor 252 + CNPJ | sembast (PL-web); BrasilAPI/OpenCNPJ |
| RF-10..RF-13 | `acoes` + brapi token | cache sob demanda; 429 backoff (RNF-3) |
| RF-14..RF-16 | `patrimonio` + fl_chart | acessibilidade (RNF-12) |
| RF-17..RF-19 | `conversor_taxas` + `TaxRuleSet` datado | aviso CVM (informativo) |
| RF-20 | `configuracoes` + `ThemeController` | dynamic_color por plataforma (§4.4) |
| RF-21 | `ImportExportService` | `file_picker`/`share_plus`; entitlements macOS (PL-2) |
| RF-22 | `DailyCacheService` | fuso America/São_Paulo; ≤5 req paralelas |
| RNF-6 | sembast em memória | migração futura Drift se volume crescer |
| RNF-8 | Tesouro CKAN CSV | só CSV; sem datastore_search/legado |

Esta seção é o contrato de **o quê** e **onde**. O **como** (motor financeiro, modelagem de dados, camada de rede, cache, temas, telas) é detalhado nas seções seguintes do plano.

---

## Stack Tecnologica & Decisoes de Arquitetura

Esta secao e a fonte de verdade para a fundacao tecnica do **Investa BR** (package `investa_br`). Tudo aqui e decisao fechada: o implementador deve seguir as versoes, a estrutura de pastas e os padroes descritos, sem reabrir trade-offs ja resolvidos. Onde houver opcao, ela esta marcada explicitamente como `OPCIONAL`.

---

### 1. SDK base: Flutter 3.44 / Dart 3.12

- **Flutter 3.44.0 (canal stable)** + **Dart 3.12** (par oficial do release, Google I/O mai/2026).
- **Plataformas**: `android, ios, windows, macos, linux`. **Web esta FORA de escopo** — isso libera o uso de pacotes puro-Dart sem restricao de compatibilidade web (ex.: `sembast` com `databaseFactoryIo`, `dart:io`).
- Comando de criacao do projeto (executar UMA vez, na raiz):

```bash
flutter create --platforms=android,ios,windows,macos,linux \
  --org br.com.fiduciascm \
  --project-name investa_br \
  investa_br
```

- **Fixar a versao do Flutter via FVM** para reprodutibilidade entre dev e CI. Criar `.fvmrc` na raiz:

```json
{
  "flutter": "3.44.0"
}
```

Comandos de bootstrap do ambiente:

```bash
fvm install 3.44.0
fvm use 3.44.0
fvm flutter pub get
```

> A partir daqui, todo comando `flutter`/`dart` deve ser prefixado com `fvm` (ex.: `fvm dart run build_runner watch -d`). O `.fvmrc` e `.fvm/` (exceto `.fvm/flutter_sdk`) devem ser commitados; ignorar apenas o symlink do SDK no `.gitignore`.

Recorte do `pubspec.yaml` (ambiente):

```yaml
name: investa_br
description: "Investa BR — renda fixa e acoes B3 (mobile + desktop)."
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
```

---

### 2. Gerenciamento de estado: Riverpod 3 com code-gen

**Decisao fechada: Riverpod 3** (`flutter_riverpod`) com geracao de codigo (`@riverpod` via `riverpod_generator` + `riverpod_annotation`). **Bloc esta descartado.**

#### Justificativa (load-bearing)

| Criterio | Por que Riverpod 3 vence aqui |
|---|---|
| Time | App solo / time pequeno — Riverpod tem menos boilerplate que Bloc (sem eventos + estados separados). |
| Assincronismo | App e fortemente async (5+ APIs: BCB SGS, brapi, BrasilAPI/OpenCNPJ, AwesomeAPI, Tesouro CKAN) + cache diario + calculos. `AsyncValue` (sealed) modela `data`/`loading`/`error` com pattern matching nativo do Dart 3. |
| DI | Riverpod **e** o container de DI. `Provider` + `overrideWith` cobrem todo o grafo, sem `get_it`. |
| Riverpod 3 | `Ref` unificado (fim de AutoDispose/Family manuais), offline caching, auto-retry e mutations nativas — diretamente uteis para o cache "primeira requisicao do dia". |
| Teste | `ProviderContainer` + `overrideWith` injetam fakes sem `BuildContext`. |

Bloc so seria preferivel com time grande + necessidade de **event-sourcing / audit trail** — o que **nao** e o caso deste app.

#### Padrao de provider (code-gen)

```dart
// lib/src/features/indicadores/application/indicadores_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'indicadores_controller.g.dart';

@riverpod
class IndicadoresController extends _$IndicadoresController {
  @override
  Future<SnapshotIndicadores> build() async {
    // Ref unificado; sem AutoDispose manual.
    final repo = ref.watch(indicadoresRepositoryProvider);
    return repo.obterSnapshotDoDia();
  }

  Future<void> refreshManual() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(indicadoresRepositoryProvider).obterSnapshotDoDia(forcar: true);
    });
  }
}
```

Consumo na UI (pattern match em `AsyncValue`):

```dart
final asyncSnapshot = ref.watch(indicadoresControllerProvider);
return switch (asyncSnapshot) {
  AsyncData(:final value) => CardsIndicadores(snapshot: value),
  AsyncError(:final error) => ErroComRetry(erro: error),
  _ => const SkeletonIndicadores(),
};
```

---

### 3. Injecao de dependencia: o proprio Riverpod

**NAO adicionar `get_it` nem `injectable`.** A DI e feita inteiramente pelo Riverpod (`Provider` + `override`). Isso reduz uma dependencia e mantem **um unico grafo testavel** via `ProviderContainer`/`overrideWith`.

```dart
// Datasource/cliente expostos como providers — substituiveis em teste.
@riverpod
Dio dioBcb(Ref ref) => ref.watch(dioFactoryProvider).create(BaseApi.bcbSgs);

@riverpod
IndicadoresRepository indicadoresRepository(Ref ref) =>
    IndicadoresRepositoryImpl(
      remote: ref.watch(indicadoresRemoteDataSourceProvider),
      cache: ref.watch(dailyCacheServiceProvider),
    );
```

```dart
// Em teste: override sem mexer no app.
final container = ProviderContainer(overrides: [
  indicadoresRepositoryProvider.overrideWithValue(FakeIndicadoresRepository()),
]);
addTearDown(container.dispose);
```

---

### 4. Arquitetura: feature-first + Clean Architecture pragmatica

Cada feature tem 4 camadas. As dependencias apontam **para dentro**: `presentation -> application -> domain <- data`. O `domain` nao conhece Flutter, Dio nem sembast.

| Camada | Responsabilidade | Conhece |
|---|---|---|
| `presentation` | Telas, widgets, `ConsumerWidget`/`Notifier` da UI | application, domain |
| `application` | Controllers Riverpod (`AsyncNotifier`), use-cases, orquestracao entre features | domain, data (via interfaces) |
| `domain` | Entidades imutaveis (freezed), value objects, interfaces de repositorio, `Result<T>` | nada externo |
| `data` | Implementacao de repositorios, datasources remotos (Dio) e locais (sembast), DTOs + mappers | domain |

#### Arvore de arquivos (canonica)

```
investa_br/
├─ .fvmrc
├─ analysis_options.yaml
├─ build.yaml
├─ pubspec.yaml
├─ l10n.yaml
├─ lib/
│  ├─ main.dart                       # bootstrap: WidgetsFlutterBinding, LocalDb.open, window_manager, runApp(ProviderScope)
│  └─ src/
│     ├─ app.dart                     # MaterialApp.router + ThemeController + l10n
│     ├─ bootstrap.dart               # inicializacao async (db, desktop window, batch de boot)
│     ├─ constants/
│     │  ├─ series_bcb.dart           # codigos SGS: 432,11,12,433,189,226,195
│     │  ├─ api_endpoints.dart        # base URLs por API
│     │  └─ tributacao_2026.dart      # TaxRuleSet datado/versionado (IR/IOF/isencao)
│     ├─ common/
│     │  ├─ widgets/                  # cards, charts wrappers, root_shell
│     │  ├─ theme/                    # flex_color_scheme + dynamic_color builder
│     │  ├─ utils/                    # formatters pt-BR (intl), dias uteis, sha256
│     │  ├─ network/                  # DioFactory + interceptors
│     │  └─ result.dart               # sealed Result<T> (Success/Failure)
│     ├─ routing/
│     │  ├─ app_router.dart           # GoRouter provider + TypedGoRoute
│     │  └─ routes.dart               # @TypedGoRoute (go_router_builder)
│     ├─ localization/
│     │  └─ l10n/                     # *.arb (app_pt.arb) -> gen-l10n
│     └─ features/
│        ├─ indicadores/
│        │  ├─ presentation/
│        │  ├─ application/
│        │  ├─ domain/
│        │  └─ data/
│        ├─ renda_fixa/
│        │  ├─ presentation/  application/  domain/  data/
│        ├─ acoes/
│        ├─ patrimonio/
│        ├─ conversor_taxas/
│        └─ configuracoes/
├─ test/                              # unit + widget (flutter_test + mocktail)
└─ integration_test/                  # E2E (patrol)
```

Features: **indicadores, renda_fixa, acoes, patrimonio, conversor_taxas, configuracoes**.

---

### 5. Roteamento: go_router 17 com rotas tipadas

- `go_router ^17.3.0` com **TypedGoRoute** via `go_router_builder` (rotas geradas, navegacao type-safe).
- O `GoRouter` e **exposto como provider Riverpod** para suportar guards e `refreshListenable`.
- `RootShell` usa `StatefulShellRoute` (ou shell + `IndexedStack`) para preservar estado das abas.

```dart
// routing/routes.dart
part 'routes.g.dart';

@TypedShellRoute<RootShellRoute>(
  routes: [
    TypedGoRoute<DashboardRoute>(path: '/'),
    TypedGoRoute<CarteiraRoute>(path: '/carteira'),
    TypedGoRoute<ConversorRoute>(path: '/conversor'),
    TypedGoRoute<AcoesRoute>(path: '/acoes', routes: [
      TypedGoRoute<DetalheAcaoRoute>(path: 'detalhe/:ticker'),
    ]),
    TypedGoRoute<AjustesRoute>(path: '/ajustes'),
  ],
)
class RootShellRoute extends ShellRouteData {
  const RootShellRoute();
  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) =>
      RootShell(child: navigator);
}

class DetalheAcaoRoute extends GoRouteData {
  const DetalheAcaoRoute({required this.ticker});
  final String ticker;
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DetalheAcaoScreen(ticker: ticker);
}
```

```dart
// routing/app_router.dart
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: const DashboardRoute().location,
    routes: $appRoutes, // gerado por go_router_builder
  );
}
```

Navegacao tipada: `const DetalheAcaoRoute(ticker: 'PETR4').go(context);`

---

### 6. Imutabilidade + serializacao: freezed 3 / json_serializable 6

- `freezed ^3.2.0` + `freezed_annotation ^3.0.0` para entidades imutaveis e **unions/sealed classes**.
- `json_serializable ^6.x` + `json_annotation ^4.x` para serializacao JSON (DTOs da camada data).
- Usar **`sealed class` do freezed 3 / Dart 3** para unions de dominio (`TipoRendimento`, `ClasseAtivo`) com pattern matching exaustivo.

```dart
// domain: union de tipo de rendimento (sealed -> switch exaustivo).
@freezed
sealed class TipoRendimento with _$TipoRendimento {
  const factory TipoRendimento.prefixado({required double taxaAnual}) = Prefixado;
  const factory TipoRendimento.percentualCdi({required double percentual}) = PercentualCdi;
  const factory TipoRendimento.percentualSelic({required double percentual}) = PercentualSelic;
  const factory TipoRendimento.ipcaMais({required double taxaReal}) = IpcaMais;
  const factory TipoRendimento.igpmMais({required double taxaReal}) = IgpmMais;
  const factory TipoRendimento.percentualPuro({required double taxaPeriodo}) = PercentualPuro;
}
```

```dart
// data: DTO com json_serializable (parse do SGS — valor como STRING).
@freezed
abstract class SgsPontoDto with _$SgsPontoDto {
  const factory SgsPontoDto({
    required String data,        // "17/06/2026"
    String? dataFim,             // presente em TR (226) e poupanca (195)
    required String valor,       // STRING: "14.50" / "0.053400"
  }) = _SgsPontoDto;

  factory SgsPontoDto.fromJson(Map<String, dynamic> json) =>
      _$SgsPontoDtoFromJson(json);
}
```

> **Value object obrigatorio:** a taxa de um produto de renda fixa NUNCA e um `double` solto. Modelar como `{tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}`.

---

### 7. Tratamento de erro: Result<T> sealed + AsyncValue.guard

- Nas camadas **data/domain**: `Result<T>` como `sealed class` do Dart 3 (`Success`/`Failure`), mapeando `DioException -> Failure` tipado.
- Na **fronteira Riverpod**: `AsyncNotifier` + `AsyncValue.guard`; a UI faz pattern match em `AsyncValue`.
- **NAO adotar `fpdart`/`dartz` como dependencia obrigatoria** (`fpdart` fica `OPCIONAL`, somente se quiser `Either`/`TaskEither`).

```dart
// common/result.dart
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.erro);
  final AppFailure erro;
}

// Falhas tipadas do dominio.
sealed class AppFailure {
  const AppFailure(this.mensagem);
  final String mensagem;
}
class FalhaRede extends AppFailure { const FalhaRede(super.m); }
class FalhaTimeout extends AppFailure { const FalhaTimeout(super.m); }
class FalhaRateLimit extends AppFailure { const FalhaRateLimit(super.m); } // HTTP 429
class FalhaParse extends AppFailure { const FalhaParse(super.m); }         // SGS devolveu HTML/invalido
class FalhaServidor extends AppFailure { const FalhaServidor(super.m); }   // 5xx
```

Mapeamento `DioException -> AppFailure` (centralizado no interceptor de normalizacao de erro — ver secao 8).

---

### 8. Rede: dio 5.9 com Interceptors

`dio ^5.9.0`. Como sao **5 APIs com base URLs diferentes**, a estrategia e uma `DioFactory` que cria um `Dio` por API, encadeando interceptors.

| API | Base URL | Auth | Observacao critica |
|---|---|---|---|
| BCB SGS | `https://api.bcb.gov.br/dados/serie/` | nenhuma | exige User-Agent; valor vem STRING; pode retornar HTML em erro |
| brapi | `https://brapi.dev/api` | Bearer token | HTTP 429 -> backoff; sem token so 4 tickers |
| BrasilAPI | `https://brasilapi.com.br/api` | nenhuma | CNPJ throttled; feriados/taxas/PTAX |
| OpenCNPJ | `https://api.opencnpj.org` | nenhuma | fallback de CNPJ (50 req/s) |
| AwesomeAPI | `https://economia.awesomeapi.com.br` | opcional | cambio (secundario) |
| Tesouro CKAN | `https://www.tesourotransparente.gov.br/ckan` | nenhuma | **so CSV** (datastore_search = 400) |

Interceptors obrigatorios (na ordem):

1. **Base URL por API** — definida na criacao de cada `Dio`.
2. **Injecao do token brapi** — `Authorization: Bearer <token>` apenas nas requests brapi.
3. **Logging em debug** — `LogInterceptor` so quando `kDebugMode`.
4. **Normalizacao de erro** — converte `DioException` em `AppFailure`.
5. **User-Agent padrao** — **obrigatorio** (BCB SGS rejeita alguns clientes sem UA, retornando HTML "Requisicao Invalida").

```dart
// common/network/dio_factory.dart
class DioFactory {
  DioFactory(this._brapiToken);
  final String? _brapiToken;

  Dio create(BaseApi api) {
    final dio = Dio(BaseOptions(
      baseUrl: api.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        // (e) User-Agent padrao — BCB rejeita clientes sem UA.
        'User-Agent': 'InvestaBR/1.0 (Flutter; +contato@fiduciascm.com.br)',
        'Accept': 'application/json',
      },
    ));

    // (b) token brapi
    if (api == BaseApi.brapi && _brapiToken != null) {
      dio.options.headers['Authorization'] = 'Bearer $_brapiToken';
    }
    // (d) normalizacao de erro
    dio.interceptors.add(ErroNormalizerInterceptor());
    // (c) logging so em debug
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
    return dio;
  }
}
```

**Parse defensivo do SGS** (a resposta pode vir como HTML em erro, e `valor` e STRING com ponto OU virgula decimal):

```dart
double parseValorSgs(String bruto) {
  // SGS normalmente usa ponto ("14.50"); normalizar virgula por seguranca.
  final normalizado = bruto.trim().replaceAll(',', '.');
  final v = double.tryParse(normalizado);
  if (v == null) throw const FalhaParse('SGS retornou valor nao numerico (possivel HTML).');
  return v;
}
```

> **Limites do SGS a respeitar (oficiais):** janela maxima de **10 anos** por consulta de periodo (fragmentar series longas em janelas <=10 anos e concatenar); `/ultimos/{N}` limitado a **20 registros**; filtros obrigatorios desde 26/03/2025; usar **~5 requisicoes paralelas** como teto de cortesia. Os cards da home usam `/ultimos/1` e **nao** sofrem o limite de 10 anos.

---

### 9. Persistencia local: sembast (NoSQL/JSON)

**Decisao fechada: `sembast ^3.8.9`** com `databaseFactoryIo` (puro Dart). **NAO usar `hive_ce`, `isar`/`isar_community`.**

#### Por que sembast (resolve a divergencia da pesquisa)

O requisito explicito e "**NoSQL em JSON**" + "**importar/exportar tudo como JSON**". O sembast grava cada registro como JSON nativo (export = dump trivial, import = `put`), e e 100% Dart sem plugin nativo (sem atrito de build em desktop).

| Criterio | sembast | Hive CE | Isar/isar_community | Drift |
|---|---|---|---|---|
| Paradigma | NoSQL documentos | key-value | objetos indexados | SQL relacional |
| Grava como JSON nativo | **Sim** | Nao (binario) | Nao | Nao |
| 100% Dart (sem plugin nativo) | **Sim** | Sim | Nao | Nao |
| Export/import JSON | **Trivial** | Manual (toJson paralelo) | Manual | Manual |
| Decisao | **ESCOLHIDO** | 2a opcao | abandonado/fork c/ binarios | overkill p/ NoSQL |

- Path do arquivo via `path_provider` (`getApplicationDocumentsDirectory`).
- **4 stores**: `investimentos_rf`, `posicoes_acoes`, `cache_indicadores`, `configuracoes`.
- IDs = **UUID** (`uuid ^4.0.0`).
- Versionar com `openDatabase(version, onVersionChanged)`.

```dart
class LocalDb {
  LocalDb._();
  static final instance = LocalDb._();
  static const int schemaVersion = 1;

  static final investimentosRf = stringMapStoreFactory.store('investimentos_rf');
  static final posicoesAcoes   = stringMapStoreFactory.store('posicoes_acoes');
  static final cacheIndicadores = stringMapStoreFactory.store('cache_indicadores');
  static final configuracoes   = stringMapStoreFactory.store('configuracoes');

  late final Database db;

  Future<void> open() async {
    final dir = await getApplicationDocumentsDirectory();
    db = await databaseFactoryIo.openDatabase(
      p.join(dir.path, 'investa_br.db'),
      version: schemaVersion,
      onVersionChanged: (db, oldV, newV) async {
        if (oldV < 1) {
          await configuracoes.record('app').put(db, {
            'themeMode': 'system',
            'seedArgb': 0xFF1565C0,
            'useDynamic': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      },
    );
  }
}
```

> Se um dia houver **series historicas massivas** (centenas de milhares de pontos), migrar **somente essas** para `drift`/SQLite (`drift ^2.34.x`, marcado `OPCIONAL/futuro`), mantendo sembast para os documentos do usuario.

#### Import/Export (arquivo JSON unico)

- `file_picker ^11.0.0` para abrir; `share_plus ^10.0.0` para compartilhar/salvar; `crypto ^3.x` para checksum SHA-256.
- `cache_indicadores` **NAO entra** no export (e dado derivado).
- Envelope:

```json
{
  "app": "investa_br",
  "schemaVersion": 1,
  "exportedAt": "2026-06-17T10:00:00-03:00",
  "appVersion": "1.0.0",
  "checksum": "sha256:<hex do bloco data>",
  "data": {
    "investimentos_rf": [ /* ... */ ],
    "posicoes_acoes":   [ /* ... */ ],
    "configuracoes":    { "app": { /* ... */ } }
  }
}
```

- Import valida `app == "investa_br"`, valida `schemaVersion` (**bloqueia** arquivo de versao mais nova que o app), confere checksum, roda `migratePayload(oldV -> currentV)` e aplica em **transacao atomica**:
  - `REPLACE` (default): limpa stores do usuario e regrava (estado final == arquivo).
  - `MERGE`: `put` por `id` (UUID), com **last-write-wins** comparando `updatedAt`.
- `migratePayload` e **independente** do `onVersionChanged` do banco (um adapta arquivos importados; o outro evolui o banco em disco).

---

### 10. Cache "primeira requisicao do dia"

`DailyCacheService` com chave por **indicador + data** (`yyyy-MM-dd`, fuso **America/Sao_Paulo, UTC-3 fixo** — sem horario de verao desde 2019).

Fluxo no boot:

```
┌─────────────────────────────────────────────────────────────┐
│ App abre → DailyCacheService.obter()                          │
│   ├─ le cache_indicadores/indicadores_dia                     │
│   ├─ se dataUltimaAtualizacao == hoje(SP) e dentro do TTL     │
│   │     → serve do cache (stale=false)                        │
│   └─ senao → batch paralelo (~5 req):                         │
│         • SGS /ultimos/1 series [432,11,12,433,189,226,195]   │
│         • BrasilAPI /feriados/v1/{ano}                        │
│         • cotacoes da carteira (brapi)                        │
│       persiste snapshot {dataUltimaAtualizacao, fetchedAt}    │
│       em erro de rede → usa cache antigo, marca stale=true    │
└─────────────────────────────────────────────────────────────┘
```

- **stale-while-revalidate**: nao bloquear a UI; servir cache enquanto revalida.
- **Fallback offline**: persistir sempre o ultimo snapshot bom; em falha, servir marcando `stale=true` (UI mostra aviso "dado desatualizado").
- **Refresh manual**: botao na home forca `forcar: true`, ignorando cache.
- **Acoes / Tesouro**: sob demanda, com cache proprio, para **nao pesar o boot**.

```dart
String _hojeSP() {
  final agora = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  return agora.toIso8601String().substring(0, 10); // yyyy-MM-dd
}
```

---

### 11. APIs externas (resumo acionavel)

| Dominio | API (papel) | Detalhe critico |
|---|---|---|
| Indicadores | **BCB SGS** (primaria) | series 432/11/12/433/189/226/195; sem auth; valor STRING; 226/195 trazem `dataFim` |
| Indicadores | BrasilAPI `/taxas/v1` (headline) | valores **anualizados** — so para exibicao, **nunca** para calculo exato |
| Acoes | **brapi** (token gratuito 15k/mes) | sem token so PETR4/VALE3/MGLU3/ITUB4; 429 -> backoff; campos de analista vem `null` no free |
| CNPJ | **BrasilAPI** (principal) + **OpenCNPJ** (fallback) | normalizar CNPJ (so digitos); OpenCNPJ: socios em `QSA`, endereco PLANO; cache TTL longo |
| Tesouro | Tesouro CKAN **CSV** | so CSV (~13,5 MiB); `;` separador, decimal virgula; titulos por extenso; datastore_search = 400 |
| Cambio | AwesomeAPI / BrasilAPI `/cambio` (secundario) | PTAX usar boletim de **FECHAMENTO** |

> **Recomendacoes de analistas NAO sao feature core.** No free os campos `recommendationKey/recommendationMean/targetMeanPrice/numberOfAnalystOpinions` retornam `null` (HTTP 200). No MVP, derivar sinais proprios localmente a partir de fundamentos (P/L, P/VP, DY, ROE). A UI deve **degradar graciosamente** quando os campos estiverem ausentes/nulos.

---

### 12. Temas (Material 3)

- **Material 3** (`useMaterial3: true`).
- `flex_color_scheme ^8.4.0` (`FlexThemeData.light/dark` com `keyColors`) sobre `ColorScheme.fromSeed` puro — entrega `onColors`/surfaces mais polidos.
- `dynamic_color ^1.8.1` (`DynamicColorBuilder`) para Material You, com **fallback obrigatorio** para seed manual (Material You so em Android 12+; accent no desktop).
- `ThemeMode` light/dark/system + seed personalizavel.
- Persistir `seedArgb` (int ARGB) + `themeMode` + `useDynamic` no sembast (store `configuracoes`) e expor via `ThemeController` (Riverpod) **acima** do `MaterialApp`.

```dart
DynamicColorBuilder(builder: (lightDyn, darkDyn) {
  final usarDyn = config.useDynamic && lightDyn != null;
  final light = usarDyn
      ? FlexThemeData.light(colorScheme: lightDyn!.harmonized(), useMaterial3: true)
      : FlexThemeData.light(keyColors: FlexKeyColors(useKeyColors: true),
          colors: FlexSchemeColor.from(primary: Color(config.seedArgb)),
          useMaterial3: true);
  final dark = usarDyn && darkDyn != null
      ? FlexThemeData.dark(colorScheme: darkDyn.harmonized(), useMaterial3: true)
      : FlexThemeData.dark(keyColors: FlexKeyColors(useKeyColors: true),
          colors: FlexSchemeColor.from(primary: Color(config.seedArgb)),
          useMaterial3: true);
  return MaterialApp.router(theme: light, darkTheme: dark, themeMode: config.themeMode, /* ... */);
});
```

---

### 13. i18n / l10n e formatacao pt-BR

- Nativo: `flutter_localizations` (SDK) + **gen-l10n** (`.arb`), locale padrao `pt_BR`.
- `intl ^0.20.0` para formatadores, **centralizados em `common/utils`**.

`l10n.yaml`:

```yaml
arb-dir: lib/src/localization/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: [pt]
```

```dart
// common/utils/formatters.dart
final moedaBr = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final percentualBr = NumberFormat.decimalPercentPattern(locale: 'pt_BR', decimalDigits: 2);
final dataBr = DateFormat('dd/MM/yyyy', 'pt_BR');
```

---

### 14. UX / navegacao responsiva e graficos (vinculo com a stack)

- `RootShell` com 3 breakpoints Material 3: compact `<600dp` (`NavigationBar`), medium `600–840dp` (`NavigationRail` compacto), expanded `>=840dp` (`NavigationRail` extended/Drawer). `IndexedStack` preserva estado das abas. Destinos: **Inicio, Carteira, Conversor, Acoes, Ajustes**.
- `fl_chart ^1.2.0`: `PieChart` donut (distribuicao da carteira), `LineChart` (historico indicador/patrimonio), `BarChart` (comparador), `CandlestickChart` (detalhe da acao). **Sempre com legenda textual acessivel** (nao depender so de cor).
- Acessibilidade: contraste AA, `Semantics` em cards/graficos, alvos de toque `>=48dp`, suporte a `textScaleFactor` sem overflow (`Wrap`/`FittedBox`), variacao **sempre com icone + texto** (nunca so verde/vermelho).

---

### 15. Desktop

- `window_manager ^0.5.0` para titulo / tamanho minimo / centralizacao. Esta em `0.x` (API pode mudar) — **isolar atras de um servico** (`DesktopWindowService`) para troca facil.
- `path_provider ^2.1.0` (docs dir para sembast e export) + `file_picker` (importar/exportar JSON).
- **Testar import/export em Windows, macOS e Linux.**

```dart
// Chamado em bootstrap.dart apenas em desktop.
Future<void> initDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    title: 'Investa BR',
    minimumSize: Size(420, 640),
    center: true,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
```

---

### 16. Lista completa de pacotes (versao + papel)

**`dependencies`:**

| Pacote | Versao | Papel |
|---|---|---|
| `flutter_riverpod` | ^3.3.0 | gerenciamento de estado + container de DI |
| `riverpod_annotation` | ^4.0.0 | anotacao `@riverpod` |
| `go_router` | ^17.3.0 | roteamento declarativo (exposto via provider) |
| `freezed_annotation` | ^3.0.0 | anotacoes freezed (imutabilidade/unions) |
| `json_annotation` | ^4.x | anotacoes JSON |
| `dio` | ^5.9.0 | cliente HTTP + interceptors |
| `sembast` | ^3.8.9 | persistencia NoSQL/JSON (databaseFactoryIo) |
| `path_provider` | ^2.1.0 | diretorio de documentos (db + export) |
| `path` | ^1.9.0 | manipulacao de caminhos |
| `file_picker` | ^11.0.0 | importar/exportar `.json` |
| `share_plus` | ^10.0.0 | compartilhar/salvar export JSON |
| `uuid` | ^4.0.0 | IDs estaveis (UUID) |
| `crypto` | ^3.x | checksum SHA-256 do payload |
| `window_manager` | ^0.5.0 | janela desktop (isolado atras de servico) |
| `intl` | ^0.20.0 | formatacao pt-BR (moeda/percentual/data) |
| `flutter_localizations` | SDK | i18n/l10n nativo |
| `flex_color_scheme` | ^8.4.0 | temas Material 3 (FlexThemeData + keyColors) |
| `dynamic_color` | ^1.8.1 | Material You (com fallback p/ seed) |
| `fl_chart` | ^1.2.0 | graficos (Pie/Line/Bar/Candlestick) |

**`dev_dependencies`:**

| Pacote | Versao | Papel |
|---|---|---|
| `riverpod_generator` | ^4.0.0 | code-gen dos providers |
| `go_router_builder` | ^3.x | rotas tipadas (TypedGoRoute) |
| `freezed` | ^3.2.0 | code-gen de imutabilidade/unions |
| `json_serializable` | ^6.x | code-gen de serializacao JSON |
| `build_runner` | ultima | runner unico de code-gen |
| `very_good_analysis` | ^10.2.0 | lints rigorosos |
| `mocktail` | ^1.0.0 | mocks sem code-gen |
| `patrol` | ^4.6.0 | E2E + interacoes nativas |
| `flutter_test` | SDK | unit/widget tests |
| `integration_test` | SDK | testes de integracao |

**`OPCIONAL` (nao adicionar salvo necessidade explicita):** `fpdart ^1.x` (composicao funcional), `drift ^2.34.x` (futuro, series historicas massivas).

**PROIBIDOS (decisao fechada):** `get_it`/`injectable` (DI via Riverpod), `hive_ce`/`isar`/`isar_community` (storage e sembast).

---

### 17. Geracao de codigo e tooling

- **Um unico `build_runner`** cobre freezed, json_serializable, riverpod_generator e go_router_builder.
- Comando de desenvolvimento:

```bash
fvm dart run build_runner watch -d
```

(`-d` = `--delete-conflicting-outputs`). Para build limpo em CI: `fvm dart run build_runner build -d`.

- **Commitar** os arquivos gerados: `*.g.dart` e `*.freezed.dart`.
- `build.yaml` (ordem/escopo dos geradores, evita conflito freezed x json_serializable):

```yaml
targets:
  $default:
    builders:
      freezed:
        options:
          # freezed 3: unions sealed por padrao
      json_serializable:
        options:
          explicit_to_json: true
          field_rename: snake
```

- **Lints**: `very_good_analysis` (mais rigoroso que `flutter_lints`), com regras de imutabilidade e **proibicao de `print`**.

`analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/src/localization/l10n/app_localizations*.dart"
  errors:
    avoid_print: error

linter:
  rules:
    prefer_const_constructors: true
    require_trailing_commas: true
```

---

### 18. Estrategia de testes

- `flutter_test` + `mocktail` (mocks sem code-gen) + `ProviderContainer`/`overrideWith` para fakes.
- `integration_test` + `patrol` para E2E e interacoes nativas (file picker, permissoes de import/export).
- Cobertura **minima obrigatoria**:
  1. **Calculo de rendimento** por tipo de taxa (prefixado, %CDI, %Selic, IPCA+, percentual puro; base 252 com dias uteis reais).
  2. **Parsing das APIs** — incluindo SGS (valor STRING, `dataFim` em 226/195) e resposta HTML em erro.
  3. **Logica de cache diario** (mesma data -> cache; data diferente -> refetch; offline -> `stale=true`).
  4. **Import/Export** — `REPLACE` vs `MERGE`, validacao de `schemaVersion`, checksum SHA-256.

```dart
// Exemplo: teste de controller com override Riverpod + mocktail.
class _FakeRepo extends Mock implements IndicadoresRepository {}

void main() {
  test('serve do cache quando a data e hoje', () async {
    final repo = _FakeRepo();
    when(() => repo.obterSnapshotDoDia(forcar: any(named: 'forcar')))
        .thenAnswer((_) async => snapshotDeHoje);

    final container = ProviderContainer(overrides: [
      indicadoresRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final value = await container.read(indicadoresControllerProvider.future);
    expect(value.stale, isFalse);
  });
}
```

---

### 19. Aviso regulatorio (CVM) — obrigatorio na UI

O comparador/conversor e as telas de acoes devem exibir aviso de que os valores sao **informativos e nao constituem recomendacao de investimento**. As regras de **tributacao (IR regressivo, IOF, isencao de LCI/LCA/CRI/CRA/incentivadas)** devem ser encapsuladas em **config versionada e DATADA** (`constants/tributacao_2026.dart`), pois sao ponto sujeito a mudanca legislativa (ex.: MP 1.303/2025 caducou em out/2025 — isencao permanece em 2026).

---

## Estrutura de Pastas (feature-first)

Esta seção define a organização física do código-fonte do **Investa BR** (package `investa_br`). A regra mestra é **feature-first + Clean Architecture pragmática**: o eixo primário de divisão é o **domínio de negócio** (feature), e dentro de cada feature aplicamos as **4 camadas** (`presentation`, `application`, `domain`, `data`). Tudo que é transversal a duas ou mais features vive em `lib/src/common`, `lib/src/routing`, `lib/src/localization` e `lib/src/constants`.

> **Regra de ouro para o implementador:** se um arquivo é usado por **exatamente uma** feature, ele mora **dentro** dessa feature. Se é usado por **duas ou mais**, sobe para `common/` (ou `constants/`, `routing/`, `localization/` conforme o tipo). Nunca crie dependência horizontal entre features (`features/acoes` **não** importa de `features/renda_fixa`); o compartilhamento acontece via `common/` ou via providers Riverpod expostos.

### 1. Árvore de diretórios completa

```text
investa_br/
├── .fvmrc                              # fixa Flutter 3.44.0 (FVM) p/ reprodutibilidade dev/CI
├── analysis_options.yaml               # include: very_good_analysis + regras extras (proibir print, prefer-const)
├── build.yaml                          # config única do build_runner (freezed/json/riverpod/go_router_builder)
├── pubspec.yaml
├── pubspec.lock                        # COMMITAR (app, não package publicável)
├── l10n.yaml                           # config do gen-l10n (arb-dir, template, output)
├── android/  ios/  windows/  macos/  linux/   # 5 plataformas (SEM web)
│
├── lib/
│   ├── main.dart                       # entrypoint: bootstrap() + runApp(ProviderScope(child: InvestaBrApp()))
│   ├── bootstrap.dart                  # inicialização assíncrona: sembast.open(), window_manager, overrides
│   │
│   └── src/
│       ├── app.dart                    # InvestaBrApp: MaterialApp.router + ThemeController + DynamicColorBuilder
│       │
│       ├── constants/                  # valores fixos do domínio, sem lógica e sem dependência de Flutter
│       │   ├── series_sgs.dart         # códigos BCB SGS (432, 11, 12, 433, 189, 226, 195) como enum/const
│       │   ├── api_endpoints.dart      # base URLs por API (BCB, brapi, BrasilAPI, OpenCNPJ, AwesomeAPI, CKAN)
│       │   ├── tickers_teste_brapi.dart# PETR4, VALE3, MGLU3, ITUB4 (acesso sem token)
│       │   ├── tributacao_2026.dart    # TaxRuleSet DATADO: IR regressivo, IOF, isenções (versionado)
│       │   └── app_meta.dart           # nome, schemaVersion local, defaults de tema
│       │
│       ├── localization/               # i18n nativo (flutter_localizations + gen-l10n)
│       │   ├── arb/
│       │   │   ├── app_pt.arb          # locale padrão pt_BR (template/fonte da verdade)
│       │   │   ├── app_en.arb          # inglês (mesmas chaves)
│       │   │   └── app_es.arb          # espanhol (mesmas chaves)
│       │   └── l10n_extension.dart     # extension BuildContext.l10n => AppLocalizations.of(context)!
│       │
│       ├── routing/                    # go_router 17 + rotas tipadas (TypedGoRoute)
│       │   ├── app_router.dart         # @riverpod GoRouter goRouter(Ref) — exposto como provider
│       │   ├── routes.dart             # @TypedGoRoute<...> (entrada do go_router_builder)
│       │   ├── routes.g.dart           # GERADO (commitar)
│       │   └── root_shell.dart         # StatefulShellRoute responsivo (NavigationBar/Rail) + IndexedStack
│       │
│       ├── common/                     # CÓDIGO TRANSVERSAL a 2+ features
│       │   ├── theme/
│       │   │   ├── app_theme.dart      # FlexThemeData.light/dark + keyColors; fallback fromSeed
│       │   │   ├── theme_controller.dart  # @riverpod Notifier: seed/themeMode/useDynamic (persiste no sembast)
│       │   │   └── chart_palette.dart  # cores acessíveis p/ fl_chart (com rótulo textual, nunca só cor)
│       │   ├── network/
│       │   │   ├── dio_client.dart     # @riverpod Dio por API (BaseOptions + interceptors)
│       │   │   ├── interceptors/
│       │   │   │   ├── user_agent_interceptor.dart   # UA padrão (BCB SGS rejeita clientes sem UA)
│       │   │   │   ├── brapi_token_interceptor.dart  # injeta Authorization: Bearer <token runtime>
│       │   │   │   ├── logging_interceptor.dart      # só em kDebugMode
│       │   │   │   └── error_normalizer_interceptor.dart # DioException -> AppFailure (inclui HTML/SGS)
│       │   │   └── result.dart         # sealed class Result<T> = Success<T> | Failure<T>
│       │   ├── errors/
│       │   │   ├── app_failure.dart    # sealed: NetworkFailure | ParseFailure | RateLimitFailure | ...
│       │   │   └── failure_mappers.dart
│       │   ├── persistence/
│       │   │   ├── local_db.dart       # singleton sembast: open(version, onVersionChanged) + StoreRefs
│       │   │   ├── daily_cache_service.dart # @riverpod cache "primeira req. do dia" (chave indicador+yyyy-MM-dd)
│       │   │   └── import_export_service.dart # JSON único {app,schemaVersion,checksum,data}; REPLACE/MERGE
│       │   ├── utils/
│       │   │   ├── formatters.dart     # NumberFormat.currency R$, percentual, DateFormat dd/MM/yyyy (pt_BR)
│       │   │   ├── parsing.dart        # parseDecimalBr (vírgula/ponto), parseDataBr (dd/MM/yyyy), guard HTML
│       │   │   ├── dias_uteis.dart     # contagem base 252 com feriados (BrasilAPI /feriados)
│       │   │   ├── date_only.dart      # DateOnly + "hoje" no fuso America/Sao_Paulo (UTC-3)
│       │   │   └── checksum.dart       # sha256 do payload de export/import (package:crypto)
│       │   ├── value_objects/
│       │   │   ├── taxa_contratada.dart   # {tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}
│       │   │   └── dinheiro.dart          # wrapper de valor monetário (evita double solto)
│       │   ├── domain/                 # tipos de domínio COMPARTILHADOS entre features
│       │   │   ├── tipo_rendimento.dart   # sealed/enum: prefixado|percentualCdi|percentualSelic|ipcaMais|igpmMais|percentualPuro
│       │   │   ├── classe_ativo.dart      # sealed/enum: cdb|lci|lca|cri|cra|debenture|...|poupanca
│       │   │   └── indicadores.dart       # freezed: snapshot {selic, cdi, ipca, igpm, tr, poupanca}
│       │   ├── desktop/
│       │   │   └── window_service.dart    # isola window_manager (0.x) atrás de interface trocável
│       │   └── widgets/
│       │       ├── async_value_widget.dart # pattern match em AsyncValue (data/loading/error)
│       │       ├── adaptive_scaffold.dart  # decide NavigationBar vs Rail por breakpoint
│       │       ├── indicador_card.dart
│       │       ├── empty_state.dart  error_state.dart  loading_shimmer.dart
│       │       └── charts/
│       │           ├── donut_carteira.dart      # PieChart + legenda textual
│       │           ├── line_historico.dart
│       │           ├── bar_comparador.dart
│       │           └── candlestick_acao.dart
│       │
│       └── features/
│           ├── indicadores/            # BCB SGS + cache diário (CRÍTICO)
│           │   ├── presentation/
│           │   │   ├── dashboard_screen.dart     # cards SELIC/CDI/IPCA/IGP-M + patrimônio + donut
│           │   │   ├── indicador_detalhe_screen.dart # histórico (LineChart)
│           │   │   └── controllers/
│           │   │       ├── indicadores_controller.dart   # @riverpod AsyncNotifier (AsyncValue.guard)
│           │   │       └── indicadores_controller.g.dart # GERADO
│           │   ├── application/
│           │   │   └── indicadores_service.dart   # orquestra batch paralelo SGS + cache + stale-while-revalidate
│           │   ├── domain/
│           │   │   ├── serie_temporal.dart        # freezed (data, dataFim?, valor)
│           │   │   ├── serie_temporal.freezed.dart serie_temporal.g.dart  # GERADOS
│           │   │   └── repositories/
│           │   │       └── indicadores_repository.dart   # interface (abstract)
│           │   └── data/
│           │       ├── repositories/
│           │       │   └── indicadores_repository_impl.dart
│           │       ├── datasources/
│           │       │   ├── sgs_remote_datasource.dart    # /ultimos/1 e /dados?dataInicial&dataFinal
│           │       │   └── indicadores_local_datasource.dart # store cache_indicadores
│           │       └── dtos/
│           │           ├── sgs_ponto_dto.dart            # parse string->double, dd/MM/yyyy, dataFim
│           │           └── sgs_ponto_dto.g.dart          # GERADO
│           │
│           ├── renda_fixa/             # CDB/LCI/LCA/Tesouro/debêntures + motor de cálculo
│           │   ├── presentation/
│           │   │   ├── lista_rf_screen.dart
│           │   │   ├── cadastro_rf_screen.dart           # Form + preview de projeção ao vivo
│           │   │   └── controllers/{rf_list_controller.dart, rf_form_controller.dart}(+ .g.dart)
│           │   ├── application/
│           │   │   ├── motor_rendimento.dart    # base 252 composta (padrão); 360/365 configurável
│           │   │   ├── tributacao_service.dart  # aplica TaxRuleSet datado (IR/IOF/isenção)
│           │   │   └── projecao_service.dart    # VF bruto/líquido, gross-up
│           │   ├── domain/
│           │   │   ├── posicao_renda_fixa.dart  # freezed (+ .freezed.dart / .g.dart)
│           │   │   ├── projecao.dart
│           │   │   └── repositories/renda_fixa_repository.dart
│           │   └── data/
│           │       ├── repositories/renda_fixa_repository_impl.dart
│           │       ├── datasources/rf_local_datasource.dart   # store investimentos_rf
│           │       └── dtos/posicao_rf_dto.dart (+ .g.dart)
│           │
│           ├── acoes/                  # brapi.dev (token) + busca + detalhe
│           │   ├── presentation/
│           │   │   ├── busca_acoes_screen.dart
│           │   │   ├── acao_detalhe_screen.dart          # CandlestickChart + fundamentos
│           │   │   ├── cadastro_posicao_screen.dart
│           │   │   └── controllers/{busca_controller.dart, posicoes_controller.dart}(+ .g.dart)
│           │   ├── application/
│           │   │   ├── acoes_service.dart       # cache próprio, sob demanda; backoff em 429
│           │   │   └── sinais_fundamentos.dart  # sinais locais (P/L,P/VP,DY,ROE) p/ degradar sem PRO
│           │   ├── domain/
│           │   │   ├── cotacao.dart  posicao_acao.dart  fundamentos.dart (+ gerados)
│           │   │   └── repositories/acoes_repository.dart
│           │   └── data/
│           │       ├── repositories/acoes_repository_impl.dart
│           │       ├── datasources/{brapi_remote_datasource.dart, acoes_local_datasource.dart}
│           │       └── dtos/{quote_dto.dart, financial_data_dto.dart}(+ .g.dart)
│           │
│           ├── patrimonio/             # AGREGA renda_fixa + acoes (sem importar entre elas: usa providers)
│           │   ├── presentation/controllers/patrimonio_controller.dart (+ .g.dart)
│           │   ├── application/patrimonio_service.dart   # soma bruto/líquido; modo "se resgatasse hoje"
│           │   └── domain/{resumo_patrimonio.dart, distribuicao.dart}(+ gerados)
│           │
│           ├── conversor_taxas/        # comparador "rentabilidade líquida anual efetiva" + gross-up
│           │   ├── presentation/{conversor_screen.dart, controllers/conversor_controller.dart(+ .g.dart)}
│           │   ├── application/comparador_service.dart   # reusa motor_rendimento + tributacao
│           │   └── domain/{opcao_comparada.dart, resultado_comparacao.dart}(+ gerados)
│           │
│           └── configuracoes/          # tema, import/export, token brapi, fonte de dados
│               ├── presentation/{ajustes_screen.dart, aparencia_screen.dart, dados_screen.dart}
│               │   └── controllers/config_controller.dart (+ .g.dart)
│               ├── application/config_service.dart
│               ├── domain/configuracao_app.dart (+ gerados)
│               └── data/{repositories/config_repository_impl.dart, datasources/config_local_datasource.dart}
│
├── assets/
│   └── feriados/feriados_fallback.json # fallback offline de feriados nacionais (BrasilAPI é a fonte)
│
└── test/
    ├── helpers/{provider_container.dart, fakes.dart, fixtures/}  # overrideWith + mocktail + payloads reais
    ├── unit/
    │   ├── renda_fixa/{motor_rendimento_test.dart, tributacao_test.dart}
    │   ├── indicadores/{sgs_parsing_test.dart, daily_cache_test.dart}
    │   ├── conversor/comparador_test.dart
    │   └── common/import_export_test.dart   # REPLACE/MERGE/checksum
    ├── widget/{dashboard_test.dart, cadastro_rf_test.dart}
    └── integration_test/{import_export_e2e_test.dart}  # patrol: file picker/permissões nativas
```

### 2. Mapa feature × camada

Cada feature replica as quatro camadas. Esta tabela fixa **o que entra em cada uma** e **a direção das dependências** (uma camada só pode depender das camadas à sua direita; `domain` não depende de ninguém):

| Camada | Depende de | Conteúdo | Conhece Flutter? | Conhece Riverpod? | Conhece dio/sembast? |
|---|---|---|---|---|---|
| `presentation/` | `application`, `domain` | Telas (`*_screen.dart`), widgets da feature e `controllers/` (`@riverpod` Notifier/AsyncNotifier). Faz `pattern match` em `AsyncValue`. | **Sim** | **Sim** | Não |
| `application/` | `domain` | Services / use-cases: lógica de orquestração entre repositórios e regras de negócio puras (motor de cálculo, tributação, comparador, cache). | Não | Apenas como provider exposto¹ | Não |
| `domain/` | — (nada) | Entidades imutáveis `freezed`, value objects, `enum`/`sealed class` e **interfaces** de repositório (`abstract class ...Repository`). | Não | Não | Não |
| `data/` | `domain` | Implementações de repositório (`*_repository_impl.dart`), `datasources/` (remoto via dio, local via sembast) e `dtos/` (`toJson/fromJson` json_serializable). Mapeia DTO → entidade e `DioException → AppFailure`. | Não | Apenas como provider exposto¹ | **Sim** |

¹ *Services e repositórios são **expostos** como providers Riverpod (DI nativa), mas a classe em si recebe dependências por construtor — não chama `ref.read` no corpo da regra de negócio, para permanecer testável com `ProviderContainer`/`overrideWith` sem `BuildContext`.*

**Fluxo de dependência (uma direção só):**

```text
presentation ──▶ application ──▶ domain ◀── data
     │                              ▲        │
     └──────────────────────────────┘        │  (data implementa as interfaces de domain)
        (UI lê controllers; controllers      │
         leem services/repos via Riverpod)   ▼
                                       sembast / dio (detalhes externos)
```

Exemplo concreto da feature `renda_fixa` (a seta indica "importa de"):

```text
cadastro_rf_screen.dart
   └─▶ rf_form_controller.dart            (presentation/controllers)
          └─▶ projecao_service.dart       (application)
                 ├─▶ motor_rendimento.dart   (application, puro)
                 ├─▶ tributacao_service.dart  (application, lê TaxRuleSet de constants/)
                 └─▶ renda_fixa_repository.dart (domain/interface)
                        ▲
                        └── renda_fixa_repository_impl.dart (data) implementa
                               └─▶ rf_local_datasource.dart → LocalDb (sembast)
```

### 3. Onde fica `core` / `shared` / `utils`

Neste projeto **não** existe pasta `core/` nem `shared/` no topo — esse papel é cumprido por **`lib/src/common/`** (código transversal) e **`lib/src/constants/`** (valores fixos). Mantemos um nome único (`common`) para evitar a ambiguidade clássica "isto vai em core ou em shared?". Regras de destino:

| Pergunta | Vai para… |
|---|---|
| É um valor fixo/literal do domínio (códigos SGS, base URLs, tabela de IR/IOF datada, defaults)? | `lib/src/constants/` |
| É um helper sem estado e sem Flutter (parse de decimal br, dias úteis, sha256, DateOnly)? | `lib/src/common/utils/` |
| É um widget reutilizado por 2+ features (cards, charts, `AsyncValueWidget`)? | `lib/src/common/widgets/` |
| É infraestrutura compartilhada (Dio + interceptors, `Result<T>`, `AppFailure`, `LocalDb`, cache diário, import/export, `WindowService`)? | `lib/src/common/{network,errors,persistence,desktop}/` |
| É um tipo de domínio usado por 2+ features (`TipoRendimento`, `ClasseAtivo`, `Indicadores`, value objects)? | `lib/src/common/domain/` ou `lib/src/common/value_objects/` |
| É tema / formatação pt-BR? | `lib/src/common/theme/` e `lib/src/common/utils/formatters.dart` |
| É roteamento / l10n? | `lib/src/routing/` e `lib/src/localization/` (irmãos de `common`, não dentro) |

> **Critério de promoção (single → common):** um símbolo nasce dentro da sua feature. No instante em que uma **segunda** feature precisa dele, ele é **movido** para o local de `common` correspondente na tabela acima (e somente então). Isso evita inflar `common/` com código especulativo e mantém as features coesas.

### 4. Convenção de nomes

| Elemento | Convenção | Exemplo |
|---|---|---|
| Arquivos e pastas | `snake_case`, em **português** (alinhado ao domínio), sufixo de papel | `cadastro_rf_screen.dart`, `indicadores_controller.dart` |
| Sufixo por papel | `_screen` (tela), `_controller` (Notifier Riverpod), `_service` (use-case/application), `_repository` (interface domain), `_repository_impl` (data), `_datasource`, `_dto`, `_interceptor` | `acoes_repository_impl.dart` |
| Classes / enums / typedefs | `UpperCamelCase` | `PosicaoRendaFixa`, `TipoRendimento`, `IndicadoresController` |
| Membros, variáveis, providers gerados | `lowerCamelCase` | `valorContratado`, `goRouter`, `indicadoresController` |
| Constantes de topo | `lowerCamelCase` com `const` (lint very_good) — **não** `SCREAMING_CAPS` | `const seriesSelicMeta = 432;` |
| Arquivos gerados | mesmo nome + `.g.dart` (json/riverpod/go_router_builder) ou `.freezed.dart` (freezed) | `posicao_rf_dto.g.dart`, `serie_temporal.freezed.dart` |
| `part` / `part of` | todo arquivo com code-gen declara `part '<nome>.g.dart';` e/ou `part '<nome>.freezed.dart';` | — |
| Imports internos | **sempre** `package:investa_br/src/...` (proibir `import '../../...'` relativo cruzando features via lint) | `import 'package:investa_br/src/common/network/result.dart';` |
| Chaves ARB (l10n) | `lowerCamelCase` | `dashboardTituloPatrimonio` |
| Chaves de store/doc no sembast | `snake_case` (igual ao export JSON) | `investimentos_rf`, `cache_indicadores`, doc-key `indicadores_dia` |

Esqueleto mínimo de um controller (mostra o casamento `@riverpod` ↔ `part .g.dart` ↔ camadas):

```dart
// lib/src/features/indicadores/presentation/controllers/indicadores_controller.dart
import 'package:investa_br/src/common/domain/indicadores.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'indicadores_controller.g.dart'; // GERADO por riverpod_generator (commitar)

@riverpod
class IndicadoresController extends _$IndicadoresController {
  @override
  Future<Indicadores> build() =>
      // service injetado via DI nativa do Riverpod; nada de get_it
      ref.watch(indicadoresServiceProvider).carregarSnapshotDoDia();

  Future<void> atualizar({bool forcarRefresh = false}) async {
    state = const AsyncLoading();
    // AsyncValue.guard converte exceções em AsyncError automaticamente
    state = await AsyncValue.guard(
      () => ref.read(indicadoresServiceProvider).carregarSnapshotDoDia(
            forcarRefresh: forcarRefresh,
          ),
    );
  }
}
```

E a interface de repositório (em `domain/`, sem nenhum import de Flutter, dio ou sembast):

```dart
// lib/src/features/indicadores/domain/repositories/indicadores_repository.dart
import 'package:investa_br/src/common/network/result.dart';
import 'package:investa_br/src/common/domain/indicadores.dart';

abstract interface class IndicadoresRepository {
  /// Snapshot do dia (cards da home). Implementação em data/ decide cache vs rede.
  Future<Result<Indicadores>> snapshotDoDia({bool forcarRefresh = false});
}
```

### 5. Code generation: o que é gerado e onde

Todos os artefatos gerados ficam **ao lado** do arquivo-fonte (mesma pasta) e são **commitados** (decisão global). Um único `build.yaml` orquestra os quatro geradores; o comando de desenvolvimento é `dart run build_runner watch -d`.

| Origem | Anotação | Arquivo gerado | Pasta |
|---|---|---|---|
| Entidades/value objects/unions | `@freezed` | `*.freezed.dart` (+ `*.g.dart` se `fromJson`) | `domain/` ou `common/domain/` |
| DTOs de API | `@JsonSerializable` | `*.g.dart` | `data/dtos/` |
| Controllers / providers de service/repo | `@riverpod` | `*.g.dart` | `presentation/controllers/`, `application/`, `data/` |
| Rotas tipadas | `@TypedGoRoute` | `routes.g.dart` | `routing/` |
| l10n | (arb) | `AppLocalizations` (em `.dart_tool/`, **não** versionado) | gerado por `flutter gen-l10n` |

> **Importante para o implementador:** `freezed`, `json_serializable` e `riverpod_generator` exigem `part '<arquivo>.g.dart';` / `part '<arquivo>.freezed.dart';` no topo do arquivo-fonte. Como cada feature isola seus modelos em `domain/` e seus DTOs em `data/dtos/`, os arquivos gerados nunca colidem entre features.

### 6. Padrão de barril (exports) — opcional e restrito

Para reduzir ruído de imports na UI, **cada feature pode** expor um barril público apenas com o que outras camadas/telas consomem legitimamente. Não criamos barril em `common/` (importar direto evita ciclos de geração):

```text
features/renda_fixa/renda_fixa.dart   # export 'presentation/...'; export 'domain/posicao_renda_fixa.dart';
```

Regra: o barril **só** reexporta `presentation` (rotas/telas) e tipos de `domain` necessários ao `patrimonio`/`routing`. **Nunca** reexporta `data/` (datasources e DTOs são privados da feature) — isso é verificado em revisão e reforçado pelo lint `very_good_analysis`.

---

## Modelo de Dominio & Entidades

Esta secao define o **modelo de dominio** do Investa BR: as entidades imutaveis, os value objects, os enums e os relacionamentos que sustentam renda fixa, acoes, indicadores, patrimonio e configuracao de tema. Todo o dominio e escrito com **freezed 3** (classes/sealed/unions + `==`/`hashCode`/`copyWith`) e **json_serializable 6** (serializacao para o sembast, que grava `Map<String, Object?>` JSON puro).

Principios de modelagem (load-bearing — seguir a risca):

1. **Nunca representar uma taxa como `double` solto.** Uma taxa contratada e sempre o value object `TaxaContratada { tipoRendimento, indexador, valorContratado: Percentual, baseDias, capitalizacao }`. Prefixado, %CDI e IPCA+ tem matematica e tributacao diferentes; perder essa informacao quebra o motor de calculo.
2. **Persistir o contratado, nunca o calculado.** Valor futuro, rendimento liquido e taxa efetiva sao *derivados* em runtime a partir dos indicadores buscados — entidades guardam apenas o que o usuario digitou (taxa contratada, datas, valor inicial).
3. **Dinheiro e Percentual sao value objects**, nunca `double` cru na API publica do dominio. `double` so aparece dentro deles e nas formulas do motor.
4. **`isento` e regra versionada e datada**, derivada de `ClasseAtivo` por um `RegraTributaria` datado — nunca um booleano hardcodado dentro da entidade (a legislacao muda; a MP 1.303/2025 caducou em out/2025).
5. **`fromJson`/`toJson` defensivos**: o snapshot do SGS chega com `valor` como **string** (`"14.50"`, virgula ou ponto) e data `dd/MM/yyyy`; o parse vive na camada `data`, mas as entidades de dominio ja recebem tipos limpos (`Percentual`, `DateTime`).

---

### 1. Arvore de arquivos do dominio

O dominio e **feature-first**. Value objects e enums transversais ficam em `common/domain`; entidades especificas ficam em `features/<feature>/domain`.

```
lib/src/
├── common/
│   └── domain/
│       ├── money.dart                 # value object Dinheiro (Money)
│       ├── money.freezed.dart
│       ├── money.g.dart
│       ├── percentual.dart            # value object Percentual
│       ├── percentual.freezed.dart
│       ├── percentual.g.dart
│       ├── result.dart                # sealed Result<T> (Success/Failure)
│       └── enums/
│           ├── tipo_rendimento.dart   # enum TipoRendimento
│           ├── indexador.dart         # enum Indexador
│           ├── classe_ativo.dart      # enum ClasseAtivo
│           ├── base_dias.dart         # enum BaseDias (252/360/365)
│           ├── capitalizacao.dart     # enum Capitalizacao (composta/simples)
│           └── tributacao.dart        # enum Tributacao + RegraTributaria
├── features/
│   ├── renda_fixa/domain/
│   │   ├── investimento_renda_fixa.dart   # entidade InvestimentoRendaFixa
│   │   ├── investimento_renda_fixa.freezed.dart
│   │   ├── investimento_renda_fixa.g.dart
│   │   ├── taxa_contratada.dart           # value object TaxaContratada
│   │   ├── emissor.dart                   # value object Emissor (CNPJ)
│   │   └── projecao_renda_fixa.dart       # value object Projecao (derivado)
│   ├── acoes/domain/
│   │   ├── posicao_acao.dart              # entidade PosicaoAcao
│   │   ├── cotacao.dart                   # value object Cotacao (brapi)
│   │   └── fundamentos_acao.dart          # value object Fundamentos (P/L, DY...)
│   ├── indicadores/domain/
│   │   ├── indicador.dart                 # entidade Indicador
│   │   └── snapshot_indicadores.dart      # agregado do cache diario
│   ├── patrimonio/domain/
│   │   ├── carteira.dart                  # agregado Carteira
│   │   └── alocacao.dart                  # value object Alocacao (donut)
│   └── configuracoes/domain/
│       └── configuracao_tema.dart         # entidade ConfiguracaoTema
```

> Convencao: cada arquivo `.dart` de dominio gera `.freezed.dart` (sempre) e `.g.dart` (quando ha `fromJson`). Todos commitados no repo, gerados por `dart run build_runner watch -d`.

---

### 2. Diagrama de relacionamentos

```
                          ┌──────────────────────────┐
                          │        Carteira          │  (agregado, derivado em runtime)
                          │  - posicoesRf: List<RF>   │
                          │  - posicoesAcoes: List<>  │
                          │  - snapshot: Snapshot     │
                          │  + patrimonioBruto()      │
                          │  + patrimonioLiquido()    │
                          │  + alocacoes(): List<>    │
                          └─────────┬───────┬─────────┘
                            1..*    │       │   1..*
              ┌─────────────────────┘       └─────────────────────┐
              ▼                                                    ▼
┌────────────────────────────┐                      ┌──────────────────────────┐
│   InvestimentoRendaFixa     │                      │       PosicaoAcao         │
│  (entidade persistida)      │                      │  (entidade persistida)    │
│  - id: String (UUID)        │                      │  - id: String (UUID)      │
│  - classe: ClasseAtivo      │                      │  - ticker: String         │
│  - valorInicial: Money ─────┼──◇ Money             │  - quantidade: int        │
│  - taxa: TaxaContratada ─┐  │                      │  - precoMedio: Money ──◇  │
│  - emissor: Emissor?     │  │                      │  - cotacao: Cotacao? ──◇  │
└──────────────────────────┼──┘                      └──────────┬────────────────┘
                           │                                    │ 0..1
                ┌──────────▼───────────┐              ┌─────────▼──────────┐
                │   TaxaContratada      │ (VO)         │      Cotacao        │ (VO, brapi)
                │  - tipoRendimento ◆   │              │  - preco: Money     │
                │  - indexador: Indexador?             │  - variacaoPct: %   │
                │  - valorContratado: Percentual ◇     │  - atualizadoEm     │
                │  - baseDias: BaseDias                │  + fundamentos? ◇   │
                │  - capitalizacao      │              └─────────────────────┘
                └───────────────────────┘

┌──────────────────────────┐        ┌──────────────────────────┐
│   SnapshotIndicadores     │ 1..*   │        Indicador          │  (entidade, cache diario)
│  (agregado do cache)      ├───────▶│  - serieSgs: int          │
│  - dataReferencia         │        │  - tipo: TipoIndicador    │
│  - fetchedAt / stale      │        │  - valor: Percentual ──◇  │
│  - indicadores: Map<>     │        │  - dataFim: DateTime?     │
└──────────────────────────┘        └──────────────────────────┘

┌──────────────────────────┐
│    ConfiguracaoTema       │  (entidade, singleton id="app")
│  - themeMode              │
│  - seedArgb: int          │
│  - useDynamic: bool       │
└──────────────────────────┘

Legenda:  ◇ composicao por value object   ◆ union sealed (TipoRendimento)
```

Cardinalidades e regras:

| Relacao | Cardinalidade | Natureza |
|---|---|---|
| `Carteira` → `InvestimentoRendaFixa` | 1 → 0..* | agregacao (derivada, nao persistida como tal) |
| `Carteira` → `PosicaoAcao` | 1 → 0..* | agregacao |
| `Carteira` → `SnapshotIndicadores` | 1 → 1 | usa o snapshot do dia para marcar a curva |
| `InvestimentoRendaFixa` → `TaxaContratada` | 1 → 1 | composicao (VO embutido) |
| `InvestimentoRendaFixa` → `Emissor` | 1 → 0..1 | composicao opcional (CNPJ) |
| `InvestimentoRendaFixa` → `Money` | 1 → 1 | `valorInicial` |
| `PosicaoAcao` → `Cotacao` | 1 → 0..1 | composicao opcional (preenchida sob demanda) |
| `Cotacao` → `FundamentosAcao` | 1 → 0..1 | composicao opcional (degrada se brapi free retornar null) |
| `SnapshotIndicadores` → `Indicador` | 1 → 1..* | agregacao por serie SGS |
| `TaxaContratada` → `TipoRendimento` | 1 → 1 | union sealed |
| `Tributacao` / `isento` | derivado | calculado de `ClasseAtivo` via `RegraTributaria` datada |

---

### 3. Value Objects

#### 3.1 `Money` (Dinheiro)

Dinheiro e armazenado **em centavos como `int`** internamente para evitar erro de ponto flutuante na soma do patrimonio. A API expoe `reais` (double) apenas para o motor de calculo e a UI. Sempre `BRL` neste app.

```dart
// common/domain/money.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'money.freezed.dart';
part 'money.g.dart';

@freezed
sealed class Money with _$Money {
  const Money._();

  /// Construtor canonico: valor em CENTAVOS (fonte da verdade).
  const factory Money({
    required int centavos,
    @Default('BRL') String moeda,
  }) = _Money;

  factory Money.fromJson(Map<String, Object?> json) => _$MoneyFromJson(json);

  /// Helper para criar a partir de reais (UI/forms). Arredonda para o centavo.
  factory Money.reais(double valor, {String moeda = 'BRL'}) =>
      Money(centavos: (valor * 100).round(), moeda: moeda);

  static const Money zero = Money(centavos: 0);

  double get reais => centavos / 100.0;

  Money operator +(Money other) {
    assert(moeda == other.moeda, 'Soma de moedas diferentes');
    return Money(centavos: centavos + other.centavos, moeda: moeda);
  }

  Money operator -(Money other) =>
      Money(centavos: centavos - other.centavos, moeda: moeda);

  Money operator *(num fator) =>
      Money(centavos: (centavos * fator).round(), moeda: moeda);

  bool get isPositivo => centavos > 0;

  /// Formatacao pt-BR. NUNCA formatar manualmente fora daqui.
  String formatar({String locale = 'pt_BR'}) =>
      NumberFormat.currency(locale: locale, symbol: r'R$').format(reais);
}
```

> JSON gravado no sembast: `{"centavos": 1000000, "moeda": "BRL"}`. Soma de patrimonio = somar `centavos` (inteiros), nunca `double`.

#### 3.2 `Percentual`

Percentual guarda a **fracao decimal** (`0.1450` = 14,50%), que e a forma usada nas formulas (`pow(1 + i, du/252)`). A UI digita "14,5" e o factory converte. Para `% do CDI` (110%), guarde `Percentual.fracao(1.10)`; para taxa a.a. (13%), `Percentual.percentual(13)`.

```dart
// common/domain/percentual.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'percentual.freezed.dart';
part 'percentual.g.dart';

@freezed
sealed class Percentual with _$Percentual {
  const Percentual._();

  /// Fonte da verdade: FRACAO decimal. 0.1450 = 14,50%; 1.10 = 110%.
  const factory Percentual({required double fracao}) = _Percentual;

  factory Percentual.fromJson(Map<String, Object?> json) =>
      _$PercentualFromJson(json);

  /// A partir de um numero percentual (14.5 -> fracao 0.145).
  factory Percentual.percentual(double valor) => Percentual(fracao: valor / 100);

  static const Percentual zero = Percentual(fracao: 0);

  double get aPercentual => fracao * 100;

  /// Parse defensivo do SGS: aceita "14.50", "14,50", "0.053400".
  factory Percentual.parseSgs(String raw) =>
      Percentual.percentual(double.parse(raw.replaceAll(',', '.')));

  /// Formatacao pt-BR. 0.145 -> "14,50%".
  String formatar({int casas = 2, String locale = 'pt_BR'}) {
    final fmt = NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: casas,
    );
    return fmt.format(fracao);
  }
}
```

> Regra: o **SGS de TR (226) e poupanca (195)** vem como `% no periodo` (com `dataFim`), nao anualizado — guardar a fracao crua e anotar o periodo no `Indicador`, sem anualizar no parse.

---

### 4. Enums e unions

#### 4.1 `TipoRendimento` (union sealed do freezed)

A decisao global pede `TipoRendimento` cobrindo **prefixado / posfixado / percentual puro**. Modelamos como **sealed union do freezed** (e nao enum simples), porque cada variante carrega *dados diferentes* e a UI/motor fazem **pattern matching exaustivo** (Dart 3 `switch`). Posfixado se subdivide por indexador via o campo `Indexador`.

```dart
// common/domain/enums/tipo_rendimento.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../percentual.dart';
import 'indexador.dart';

part 'tipo_rendimento.freezed.dart';
part 'tipo_rendimento.g.dart';

@freezed
sealed class TipoRendimento with _$TipoRendimento {
  const TipoRendimento._();

  /// Taxa fixa conhecida na compra. Ex.: 13% a.a.
  const factory TipoRendimento.prefixado({
    required Percentual taxaAnual, // 0.13
  }) = Prefixado;

  /// Posfixado = PERCENTUAL de um indexador que varia (CDI/SELIC).
  /// Ex.: 110% do CDI -> indexador=CDI, percentualDoIndice=1.10.
  const factory TipoRendimento.posfixado({
    required Indexador indexador, // CDI | SELIC
    required Percentual percentualDoIndice, // fracao 1.10 = 110%
  }) = Posfixado;

  /// Hibrido: indice + juro real. Ex.: IPCA+6% -> IPCA, taxaReal=0.06.
  const factory TipoRendimento.indexadoMais({
    required Indexador indexador, // IPCA | IGPM
    required Percentual taxaReal, // 0.06
  }) = IndexadoMais;

  /// Percentual puro: taxa-alvo bruta lancada manualmente,
  /// com periodo e capitalizacao configuraveis (a.m./a.a., simples/composto).
  const factory TipoRendimento.percentualPuro({
    required Percentual taxa,
    @Default(PeriodoTaxa.aoAno) PeriodoTaxa periodo,
  }) = PercentualPuro;

  factory TipoRendimento.fromJson(Map<String, Object?> json) =>
      _$TipoRendimentoFromJson(json);
}

enum PeriodoTaxa { aoMes, aoAno }
```

Uso no motor (pattern matching exaustivo — o compilador exige todos os casos):

```dart
double fatorBruto(TipoRendimento t, Indicadores idx, int du, int dc) =>
    switch (t) {
      Prefixado(:final taxaAnual) =>
        pow(1 + taxaAnual.fracao, du / 252).toDouble(),
      Posfixado(:final indexador, :final percentualDoIndice) =>
        pow(1 + idx.anual(indexador).fracao,
            percentualDoIndice.fracao * du / 252).toDouble(),
      IndexadoMais(:final indexador, :final taxaReal) =>
        (1 + idx.acumuladoPeriodo(indexador, dc).fracao) *
            pow(1 + taxaReal.fracao, du / 252).toDouble(),
      PercentualPuro(:final taxa, :final periodo) =>
        periodo == PeriodoTaxa.aoMes
            ? pow(1 + taxa.fracao, dc / 30).toDouble()
            : pow(1 + taxa.fracao, dc / 365).toDouble(),
    };
```

> JSON do freezed union grava um discriminador `runtimeType`: `{"runtimeType":"posfixado","indexador":"cdi","percentualDoIndice":{"fracao":1.10}}`. O discriminador e configuravel via `@Freezed(unionKey: 'tipo')` se preferir a chave `tipo` no payload de export.

#### 4.2 `Indexador`

```dart
// common/domain/enums/indexador.dart
import 'package:freezed_annotation/freezed_annotation.dart';

enum Indexador {
  @JsonValue('cdi') cdi,
  @JsonValue('selic') selic,
  @JsonValue('ipca') ipca,
  @JsonValue('igpm') igpm,
  @JsonValue('prefixado') prefixado; // "sem indexador" / taxa fixa

  /// Codigo da serie SGS do BCB para o valor diario/mensal usado em calculo.
  int? get serieSgs => switch (this) {
        Indexador.cdi => 12, // CDI/DI diario (% ao dia)
        Indexador.selic => 11, // SELIC diaria (% ao dia)
        Indexador.ipca => 433, // IPCA mensal (%)
        Indexador.igpm => 189, // IGP-M mensal (%)
        Indexador.prefixado => null,
      };

  String get rotulo => switch (this) {
        Indexador.cdi => 'CDI',
        Indexador.selic => 'SELIC',
        Indexador.ipca => 'IPCA',
        Indexador.igpm => 'IGP-M',
        Indexador.prefixado => 'Prefixado',
      };
}
```

#### 4.3 `ClasseAtivo`

```dart
// common/domain/enums/classe_ativo.dart
enum ClasseAtivo {
  @JsonValue('cdb') cdb,
  @JsonValue('lci') lci,
  @JsonValue('lca') lca,
  @JsonValue('cri') cri,
  @JsonValue('cra') cra,
  @JsonValue('lc') lc,                       // Letra de Cambio
  @JsonValue('debenture') debenture,         // comum (tributada)
  @JsonValue('debenture_incentivada') debentureIncentivada,
  @JsonValue('tesouro_selic') tesouroSelic,
  @JsonValue('tesouro_prefixado') tesouroPrefixado,
  @JsonValue('tesouro_ipca') tesouroIpca,
  @JsonValue('poupanca') poupanca;

  String get rotulo => switch (this) {
        ClasseAtivo.cdb => 'CDB',
        ClasseAtivo.lci => 'LCI',
        ClasseAtivo.lca => 'LCA',
        ClasseAtivo.cri => 'CRI',
        ClasseAtivo.cra => 'CRA',
        ClasseAtivo.lc => 'Letra de Cambio',
        ClasseAtivo.debenture => 'Debenture',
        ClasseAtivo.debentureIncentivada => 'Debenture incentivada',
        ClasseAtivo.tesouroSelic => 'Tesouro Selic',
        ClasseAtivo.tesouroPrefixado => 'Tesouro Prefixado',
        ClasseAtivo.tesouroIpca => 'Tesouro IPCA+',
        ClasseAtivo.poupanca => 'Poupanca',
      };
}
```

#### 4.4 `BaseDias` e `Capitalizacao`

```dart
// common/domain/enums/base_dias.dart
enum BaseDias {
  @JsonValue(252) duteis252,   // PADRAO: CDB/LCI/LCA/prefixado/pos-CDI
  @JsonValue(360) corridos360, // comercial
  @JsonValue(365) corridos365; // ano civil

  int get dias => switch (this) {
        BaseDias.duteis252 => 252,
        BaseDias.corridos360 => 360,
        BaseDias.corridos365 => 365,
      };

  bool get usaDiasUteis => this == BaseDias.duteis252;
}

// common/domain/enums/capitalizacao.dart
enum Capitalizacao {
  @JsonValue('composta') composta, // PADRAO de mercado
  @JsonValue('simples') simples,
}
```

#### 4.5 `Tributacao` + `RegraTributaria` (regra DATADA e versionada)

`Tributacao` e o enum do *regime*; a aliquota e a isencao vem de um `RegraTributaria` **datado** (config versionada), conforme a decisao global. Isso isola a mudanca legislativa (a MP 1.303/2025 caducou em out/2025; LCI/LCA/CRI/CRA/incentivadas/poupanca seguem **isentas** de IR-PF em 2026).

```dart
// common/domain/enums/tributacao.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'classe_ativo.dart';

part 'tributacao.freezed.dart';

enum Tributacao {
  @JsonValue('ir_regressivo') irRegressivo, // CDB, Tesouro, LC, debenture comum
  @JsonValue('isento_ir_pf') isentoIrPf,    // LCI/LCA/CRI/CRA/incentivada/poupanca
}

/// Regra tributaria DATADA. Trocar -> nova instancia com vigencia diferente.
@freezed
sealed class RegraTributaria with _$RegraTributaria {
  const RegraTributaria._();

  const factory RegraTributaria({
    required DateTime vigenteDesde, // ex.: 2025-10-01 (pos-caducidade MP 1.303)
    required String descricao,      // exibido no aviso da UI
  }) = _RegraTributaria;

  /// Classes isentas de IR-PF nesta vigencia.
  static const Set<ClasseAtivo> _isentas = {
    ClasseAtivo.lci,
    ClasseAtivo.lca,
    ClasseAtivo.cri,
    ClasseAtivo.cra,
    ClasseAtivo.debentureIncentivada,
    ClasseAtivo.poupanca,
  };

  Tributacao tributacaoDe(ClasseAtivo c) =>
      _isentas.contains(c) ? Tributacao.isentoIrPf : Tributacao.irRegressivo;

  bool isento(ClasseAtivo c) => tributacaoDe(c) == Tributacao.isentoIrPf;

  /// IR regressivo por dias corridos. Isento -> 0.
  double aliquotaIr(ClasseAtivo c, int diasCorridos) {
    if (isento(c)) return 0;
    if (diasCorridos <= 180) return 0.225;
    if (diasCorridos <= 360) return 0.20;
    if (diasCorridos <= 720) return 0.175;
    return 0.15;
  }

  /// IOF regressivo (Decreto 6.306/2007): trunc((30-d)/30*100)/100, 0 a partir de 30 dias.
  double aliquotaIof(int diasCorridos) => diasCorridos >= 30
      ? 0
      : ((30 - diasCorridos) / 30 * 100).truncate() / 100;
}

/// Regra vigente embutida no app (atualizar com nova lei).
const regraTributariaVigente2026 = RegraTributaria(
  vigenteDesde: null, // placeholder; usar DateTime(2025, 10, 1) na constante real
  descricao:
      'Em 2026, LCI/LCA/CRI/CRA/debentures incentivadas e poupanca isentas '
      'de IR-PF (MP 1.303/2025 caducou em out/2025). Valores informativos, '
      'nao constituem recomendacao (CVM).',
);
```

> A UI do comparador **deve** exibir `regraTributariaVigente2026.descricao` como aviso datado. `isento` da entidade e sempre `regra.isento(classe)` — nunca um booleano armazenado.

---

### 5. Entidade `InvestimentoRendaFixa`

Entidade persistida no store `investimentos_rf`. Composta por `Money`, `TaxaContratada` e `Emissor?`. Guarda **apenas dados contratados**; projecao e derivada.

```dart
// features/renda_fixa/domain/taxa_contratada.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../common/domain/enums/base_dias.dart';
import '../../../common/domain/enums/capitalizacao.dart';
import '../../../common/domain/enums/tipo_rendimento.dart';

part 'taxa_contratada.freezed.dart';
part 'taxa_contratada.g.dart';

@freezed
sealed class TaxaContratada with _$TaxaContratada {
  const factory TaxaContratada({
    required TipoRendimento tipoRendimento,
    @Default(BaseDias.duteis252) BaseDias baseDias,
    @Default(Capitalizacao.composta) Capitalizacao capitalizacao,
  }) = _TaxaContratada;

  factory TaxaContratada.fromJson(Map<String, Object?> json) =>
      _$TaxaContratadaFromJson(json);
}
```

```dart
// features/renda_fixa/domain/emissor.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'emissor.freezed.dart';
part 'emissor.g.dart';

@freezed
sealed class Emissor with _$Emissor {
  const Emissor._();

  const factory Emissor({
    required String cnpj, // somente digitos (normalizado)
    String? razaoSocial,
    String? nomeFantasia,
  }) = _Emissor;

  factory Emissor.fromJson(Map<String, Object?> json) => _$EmissorFromJson(json);

  /// Normaliza qualquer entrada de CNPJ para 14 digitos.
  factory Emissor.normalizado(String raw, {String? razaoSocial}) =>
      Emissor(cnpj: raw.replaceAll(RegExp(r'\D'), ''), razaoSocial: razaoSocial);
}
```

```dart
// features/renda_fixa/domain/investimento_renda_fixa.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../common/domain/enums/classe_ativo.dart';
import '../../../common/domain/enums/tributacao.dart';
import '../../../common/domain/money.dart';
import 'emissor.dart';
import 'taxa_contratada.dart';

part 'investimento_renda_fixa.freezed.dart';
part 'investimento_renda_fixa.g.dart';

@freezed
sealed class InvestimentoRendaFixa with _$InvestimentoRendaFixa {
  const InvestimentoRendaFixa._();

  const factory InvestimentoRendaFixa({
    required String id,                 // UUID v4 (chave do sembast)
    required ClasseAtivo classe,
    required String apelido,            // "CDB Banco X 2027"
    required Money valorInicial,
    required TaxaContratada taxa,
    required DateTime dataInicio,
    DateTime? dataVencimento,           // null = liquidez diaria / sem vencimento
    Emissor? emissor,                   // opcional (enriquecido via CNPJ)
    String? observacoes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _InvestimentoRendaFixa;

  factory InvestimentoRendaFixa.fromJson(Map<String, Object?> json) =>
      _$InvestimentoRendaFixaFromJson(json);

  /// DERIVADO: nunca persistido. Usa a regra tributaria vigente.
  bool isento(RegraTributaria regra) => regra.isento(classe);

  Tributacao tributacao(RegraTributaria regra) => regra.tributacaoDe(classe);

  bool vigenteEm(DateTime d) =>
      !d.isBefore(dataInicio) &&
      (dataVencimento == null || !d.isAfter(dataVencimento!));
}
```

JSON gravado no store `investimentos_rf` (exemplo CDB 110% CDI):

```json
{
  "id": "8f3c1e2a-...-uuid",
  "classe": "cdb",
  "apelido": "CDB Banco X 2027",
  "valorInicial": { "centavos": 1000000, "moeda": "BRL" },
  "taxa": {
    "tipoRendimento": {
      "runtimeType": "posfixado",
      "indexador": "cdi",
      "percentualDoIndice": { "fracao": 1.10 }
    },
    "baseDias": 252,
    "capitalizacao": "composta"
  },
  "dataInicio": "2026-01-10T00:00:00.000-03:00",
  "dataVencimento": "2027-01-10T00:00:00.000-03:00",
  "emissor": { "cnpj": "00000000000191", "razaoSocial": "BANCO X SA" },
  "observacoes": null,
  "createdAt": "2026-06-17T09:00:00.000-03:00",
  "updatedAt": "2026-06-17T09:00:00.000-03:00"
}
```

`ProjecaoRendaFixa` e um value object **derivado** (resultado do motor, nao persistido):

```dart
// features/renda_fixa/domain/projecao_renda_fixa.dart
@freezed
sealed class ProjecaoRendaFixa with _$ProjecaoRendaFixa {
  const factory ProjecaoRendaFixa({
    required Money valorBruto,
    required Money rendimentoBruto,
    required Money iof,
    required Money ir,
    required Money valorLiquido,
    required Percentual taxaLiquidaAnualEfetiva, // base 252
    Percentual? taxaBrutaEquivalente,            // gross-up (so isentos)
    required int diasUteis,
    required int diasCorridos,
  }) = _ProjecaoRendaFixa;
}
```

---

### 6. Entidade `PosicaoAcao`

Persistida no store `posicoes_acoes`. Guarda o que o usuario comprou; `Cotacao` (e `FundamentosAcao`) sao preenchidas sob demanda pela brapi e **degradam graciosamente** quando o plano free retorna `null` (P/L, DY etc. e recomendacoes de analista vem nulos no free).

```dart
// features/acoes/domain/cotacao.dart
@freezed
sealed class Cotacao with _$Cotacao {
  const factory Cotacao({
    required String ticker,
    required Money preco,
    required Percentual variacaoDiaPct,
    required DateTime atualizadoEm,
    String? logoUrl,
    FundamentosAcao? fundamentos, // pode ser null (free) -> UI degrada
  }) = _Cotacao;

  factory Cotacao.fromJson(Map<String, Object?> json) => _$CotacaoFromJson(json);
}

// features/acoes/domain/fundamentos_acao.dart
// TODOS os campos sao NULLABLE: no plano free da brapi vem null com HTTP 200.
@freezed
sealed class FundamentosAcao with _$FundamentosAcao {
  const FundamentosAcao._();

  const factory FundamentosAcao({
    double? precoLucro,        // P/L
    double? precoValorPatr,    // P/VP
    double? dividendYield,     // DY
    double? roe,
    // Campos de analista (so populados no plano PRO; tratar como ausentes):
    String? recommendationKey,
    double? targetMeanPrice,
    int? numberOfAnalystOpinions,
  }) = _FundamentosAcao;

  factory FundamentosAcao.fromJson(Map<String, Object?> json) =>
      _$FundamentosAcaoFromJson(json);

  /// Sinal proprio derivado de fundamentos quando NAO ha rating de analista.
  bool get temRatingAnalista => recommendationKey != null;
}
```

```dart
// features/acoes/domain/posicao_acao.dart
@freezed
sealed class PosicaoAcao with _$PosicaoAcao {
  const PosicaoAcao._();

  const factory PosicaoAcao({
    required String id,           // UUID v4
    required String ticker,       // "PETR4" (uppercase)
    required int quantidade,
    required Money precoMedio,
    required DateTime dataCompra,
    String? corretora,
    Cotacao? cotacao,             // nao persistida no doc do usuario; runtime
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PosicaoAcao;

  factory PosicaoAcao.fromJson(Map<String, Object?> json) =>
      _$PosicaoAcaoFromJson(json);

  Money get custoTotal => precoMedio * quantidade;

  /// Valor de mercado (requer cotacao). Sem cotacao -> cai no custo.
  Money get valorAtual =>
      cotacao == null ? custoTotal : cotacao!.preco * quantidade;

  Money get lucroPrejuizo => valorAtual - custoTotal;
}
```

> Persistencia: o doc gravado em `posicoes_acoes` **nao inclui** `cotacao` (dado derivado/volatil — fica no store `cache_indicadores`/cache de cotacoes). Use `@JsonKey(includeToJson: false, includeFromJson: false)` em `cotacao` ou serialize um `toJsonPersistencia()` que omita o campo.

---

### 7. Entidade `Indicador` e agregado `SnapshotIndicadores`

`Indicador` representa um valor de serie SGS no cache diario (store `cache_indicadores`). `SnapshotIndicadores` e o agregado do "primeira requisicao do dia".

```dart
// features/indicadores/domain/indicador.dart
import '../../../common/domain/percentual.dart';

enum TipoIndicador {
  @JsonValue('selic_meta') selicMeta,       // SGS 432, % a.a.
  @JsonValue('selic_diaria') selicDiaria,   // SGS 11, % ao dia
  @JsonValue('cdi_diario') cdiDiario,       // SGS 12, % ao dia
  @JsonValue('ipca_mensal') ipcaMensal,     // SGS 433, % mes
  @JsonValue('igpm_mensal') igpmMensal,     // SGS 189, % mes
  @JsonValue('tr') tr,                      // SGS 226, % periodo (+ dataFim)
  @JsonValue('poupanca') poupanca;          // SGS 195, % periodo (+ dataFim)

  int get serieSgs => switch (this) {
        TipoIndicador.selicMeta => 432,
        TipoIndicador.selicDiaria => 11,
        TipoIndicador.cdiDiario => 12,
        TipoIndicador.ipcaMensal => 433,
        TipoIndicador.igpmMensal => 189,
        TipoIndicador.tr => 226,
        TipoIndicador.poupanca => 195,
      };

  /// Indica se a serie traz "dataFim" (periodo) no payload do SGS.
  bool get temDataFim =>
      this == TipoIndicador.tr || this == TipoIndicador.poupanca;
}

@freezed
sealed class Indicador with _$Indicador {
  const factory Indicador({
    required TipoIndicador tipo,
    required Percentual valor,    // ja parseado da string do SGS
    required DateTime data,       // dd/MM/yyyy -> DateTime
    DateTime? dataFim,            // TR e poupanca
  }) = _Indicador;

  factory Indicador.fromJson(Map<String, Object?> json) =>
      _$IndicadorFromJson(json);
}
```

```dart
// features/indicadores/domain/snapshot_indicadores.dart
@freezed
sealed class SnapshotIndicadores with _$SnapshotIndicadores {
  const SnapshotIndicadores._();

  const factory SnapshotIndicadores({
    required String dataReferencia,   // "yyyy-MM-dd" America/Sao_Paulo
    required DateTime fetchedAt,
    @Default(false) bool stale,        // true = veio de fallback offline
    @Default(<Indicador>[]) List<Indicador> indicadores,
  }) = _SnapshotIndicadores;

  factory SnapshotIndicadores.fromJson(Map<String, Object?> json) =>
      _$SnapshotIndicadoresFromJson(json);

  Indicador? byTipo(TipoIndicador t) =>
      indicadores.where((i) => i.tipo == t).firstOrNull;

  /// Snapshot e do dia atual?
  bool ehDeHoje(String hojeSp) => dataReferencia == hojeSp;
}
```

> O store `cache_indicadores` grava 1 doc `SnapshotIndicadores` por chave `indicadores_dia` e **nao entra no export** (dado derivado). A serie diaria CDI/SELIC vem como `% ao dia` (ex.: `0.0534`) — para anualizar no calculo use `(1+diaria)^252 - 1`, feito no motor, nao na entidade.

---

### 8. Agregado `Carteira` e value object `Alocacao`

`Carteira` e um **agregado de leitura** (nao persistido como documento unico): e montado em runtime pelos providers Riverpod a partir das listas de RF + acoes + snapshot do dia. Calcula patrimonio bruto/liquido e as fatias do donut.

```dart
// features/patrimonio/domain/alocacao.dart
@freezed
sealed class Alocacao with _$Alocacao {
  const factory Alocacao({
    required String rotulo,    // "Renda Fixa", "Acoes", "Tesouro"...
    required Money valor,
    required Percentual fatia, // proporcao do total (0..1)
  }) = _Alocacao;
}
```

```dart
// features/patrimonio/domain/carteira.dart
@freezed
sealed class Carteira with _$Carteira {
  const Carteira._();

  const factory Carteira({
    @Default(<InvestimentoRendaFixa>[]) List<InvestimentoRendaFixa> rendaFixa,
    @Default(<PosicaoAcao>[]) List<PosicaoAcao> acoes,
    SnapshotIndicadores? snapshot,
  }) = _Carteira;

  /// Patrimonio bruto = RF marcada na curva (taxa contratada) + acoes a mercado.
  /// Requer o motor para projetar a RF ate hoje; aqui assinatura simplificada.
  Money patrimonioBrutoComProjecao(
    Money Function(InvestimentoRendaFixa) valorRfHoje,
  ) {
    final rf = rendaFixa.fold<Money>(Money.zero, (a, i) => a + valorRfHoje(i));
    final ac = acoes.fold<Money>(Money.zero, (a, p) => a + p.valorAtual);
    return rf + ac;
  }
}
```

---

### 9. Entidade `ConfiguracaoTema`

Persistida no store `configuracoes` com chave fixa `app` (singleton). Espelha a decisao de tema: `themeMode`, seed ARGB personalizavel e flag de Material You (`useDynamic`).

```dart
// features/configuracoes/domain/configuracao_tema.dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'configuracao_tema.freezed.dart';
part 'configuracao_tema.g.dart';

@freezed
sealed class ConfiguracaoTema with _$ConfiguracaoTema {
  const factory ConfiguracaoTema({
    @Default(ThemeMode.system)
    @JsonKey(unknownEnumValue: ThemeMode.system)
    ThemeMode themeMode,
    @Default(0xFF1565C0) int seedArgb,   // cor-semente (ARGB int)
    @Default(true) bool useDynamic,       // Material You quando disponivel
    @Default('pt_BR') String locale,
    required DateTime updatedAt,
  }) = _ConfiguracaoTema;

  factory ConfiguracaoTema.fromJson(Map<String, Object?> json) =>
      _$ConfiguracaoTemaFromJson(json);

  /// Default usado na migracao onVersionChanged v0->v1.
  factory ConfiguracaoTema.padrao() =>
      ConfiguracaoTema(updatedAt: DateTime.now());
}
```

JSON gravado em `configuracoes/app`:

```json
{
  "themeMode": "system",
  "seedArgb": 4283215552,
  "useDynamic": true,
  "locale": "pt_BR",
  "updatedAt": "2026-06-17T09:00:00.000-03:00"
}
```

> `ConfiguracaoTema` **entra no export** (`data.configuracoes`). `ThemeMode` e enum do Flutter; `json_serializable` serializa pelo nome (`"system"/"light"/"dark"`) — use `@JsonKey(unknownEnumValue:)` para resiliencia na importacao de backups antigos.

---

### 10. Resumo de stores x entidades (persistencia)

| Store sembast | Entidade raiz | Chave | Entra no export? |
|---|---|---|---|
| `investimentos_rf` | `InvestimentoRendaFixa` | `id` (UUID) | Sim |
| `posicoes_acoes` | `PosicaoAcao` (sem `cotacao`) | `id` (UUID) | Sim |
| `cache_indicadores` | `SnapshotIndicadores` | `indicadores_dia` | **Nao** (derivado) |
| `configuracoes` | `ConfiguracaoTema` | `app` | Sim |

Mapa de value objects reutilizados:

| Value Object | Onde aparece |
|---|---|
| `Money` | `InvestimentoRendaFixa.valorInicial`, `PosicaoAcao.precoMedio`, `Cotacao.preco`, `Alocacao.valor`, `ProjecaoRendaFixa.*` |
| `Percentual` | `TipoRendimento.*`, `Indicador.valor`, `Cotacao.variacaoDiaPct`, `Alocacao.fatia`, `ProjecaoRendaFixa.taxa*` |
| `TaxaContratada` | `InvestimentoRendaFixa.taxa` |
| `Emissor` | `InvestimentoRendaFixa.emissor` |
| `Cotacao` / `FundamentosAcao` | `PosicaoAcao.cotacao` (runtime) |

---

### 11. Regras de geracao de codigo (build_runner)

- Toda classe de dominio usa `@freezed` + `sealed class ... with _$X`. Para value objects com metodos (`Money`, `Percentual`, `Indicador`) inclua o construtor privado `const X._();` antes do factory, senao freezed nao gera os getters customizados.
- `fromJson`/`toJson`: gerados por `json_serializable` (declarar `factory X.fromJson` + `part 'x.g.dart'`).
- Unions (`TipoRendimento`): o discriminador padrao e `runtimeType`. Para o JSON de export ser estavel entre versoes, fixe a chave com `@Freezed(unionKey: 'tipo', unionValueCase: FreezedUnionCase.snake)`.
- Comando dev unico: `dart run build_runner watch -d`. Commitar `*.freezed.dart` e `*.g.dart`.
- Testes de dominio (mocktail + flutter_test) devem cobrir: `Money.+`/soma de centavos, `Percentual.parseSgs` (virgula/ponto), pattern matching exaustivo de `TipoRendimento`, `RegraTributaria.aliquotaIr/aliquotaIof`, e round-trip `toJson/fromJson` de cada entidade (incluindo o union de `TipoRendimento`).

---

## Matematica Financeira, Tributacao & Conversor de Renda

Esta secao especifica o **motor de calculo financeiro** do Investa BR: formulas, regras tributarias, algoritmo do conversor/comparador e projecao de valor futuro. Tudo deve ser implementado como **funcoes Dart puras e deterministicas** (sem I/O, sem `DateTime.now()` interno, sem dependencia de Riverpod/dio) na camada `domain` da feature `conversor_taxas`, de modo a serem 100% testaveis com `flutter_test` sem mocks. Os indicadores (CDI, SELIC, IPCA, IGP-M, TR) entram como **parametros de entrada**, fornecidos pela camada `data` (BCB SGS) ja parseados de `String` para `double`.

> **Aviso CVM (load-bearing, obrigatorio na UI):** Todo resultado deste modulo e **informativo e estimativo**, NAO constitui recomendacao de investimento. As regras tributarias estao **datadas e versionadas** (`TaxRuleSet`) porque sao o ponto mais sujeito a mudanca legislativa. Exibir rodape datado nas telas de conversor e projecao.

---

### 1. Arvore de arquivos do modulo

```
lib/src/features/conversor_taxas/
  domain/
    value_objects/
      taxa_contratada.dart        # value object {tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}
      indicadores.dart            # snapshot de CDI/SELIC/IPCA/IGP-M/TR (freezed)
    entities/
      produto_comparavel.dart     # entrada do comparador (1 linha)
      resultado_comparacao.dart   # saida do comparador (ranqueada)
      projecao.dart               # vfBruto, rendimentoBruto, iof, ir, vfLiquido
    enums/
      tipo_rendimento.dart        # sealed/enum: prefixado, percentualCdi, percentualSelic, ipcaMais, igpmMais, percentualPuro
      base_dias.dart              # b252, b360, b365
      capitalizacao.dart          # composta, simples
    tributacao/
      tax_rule_set.dart           # config DATADA e versionada de IR/IOF/isencao
      ir.dart                     # aliquotaIr() pura
      iof.dart                    # aliquotaIof() pura
    motor/
      juros.dart                  # fatorDiario252, vfBase252, vfBase360/365, vfHibrido, vfPercentualCdi...
      dias_uteis.dart             # contagem de dias uteis com feriados (recebe Set<DateTime>)
      conversor.dart              # taxaLiquidaAnualEfetiva, taxaBrutaEquivalenteDeIsento, grossUp
      projetar.dart               # projetar(): orquestra motor + tributacao
  application/
    comparador_service.dart       # ordena ProdutoComparavel -> ResultadoComparacao (usa snapshot Indicadores)
  presentation/
    ...                           # telas (ver secao UX)
test/features/conversor_taxas/
  juros_test.dart
  ir_test.dart
  iof_test.dart
  conversor_test.dart
  projecao_test.dart
  dias_uteis_test.dart
```

---

### 2. Formulas explicitas

Notacao: `VI` = valor inicial, `VF` = valor futuro bruto, `i` = taxa **anual** (decimal, ex.: 0,1440 para 14,40% a.a.), `du` = dias uteis, `dc` = dias corridos, `p` = percentual do indexador (ex.: 1,10 para 110%), `Π` = produtorio.

#### 2.1 Juros compostos base 252 dias uteis (PADRAO para CDB/LCI/LCA/prefixado/pos-CDI)

Esta e a convencao de mercado/B3 e o **default do app**. Capitalizacao **exponencial** sobre dias uteis:

```
fatorDiario = (1 + i) ^ (1 / 252)
VF          = VI * fatorDiario ^ du   =   VI * (1 + i) ^ (du / 252)
```

#### 2.2 Fator diario do CDI e acumulacao % do CDI (convencao B3)

O CDI diario (serie SGS 12) ja vem expresso como **taxa percentual ao dia** (ex.: `0.053400` = 0,0534% a.d.). Para um titulo que rende **p% do CDI**, a convencao B3 e:

```
// CDI_t = taxa DI do dia t (anual, decimal)
fatorDiaCDI_t      = (1 + CDI_t) ^ (1/252)
fatorAplicadoDia_t = (fatorDiaCDI_t - 1) * p + 1
VF (exato)         = VI * Π_t [ fatorAplicadoDia_t ]      // produtorio dia a dia (historico real, serie SGS 12)
VF (projecao)      ≈ VI * (1 + CDI) ^ (p * du / 252)      // aproximacao com CDI fixo (uso no conversor/projecao)
```

> **Importante:** no calculo de **projecao futura** (CDI constante assumido) use a forma fechada `(1 + CDI)^(p·du/252)`. No calculo de **historico exato** (marcacao na curva com a serie diaria real) use o produtorio `fatorAplicadoDia` dia a dia. O app MVP usa a forma fechada; o produtorio fica documentado para evolucao futura.

#### 2.3 Base 360 / 365 dias corridos (configuravel por produto)

Alguns titulos usam ano civil. A base e um parametro do produto (`BaseDias`):

```
VF = VI * (1 + i) ^ (dc / 365)   // exponencial 365
VF = VI * (1 + i) ^ (dc / 360)   // comercial 360
```

#### 2.4 Hibrido IPCA+ (e IGP-M+)

O principal e corrigido pelo indice acumulado no periodo **e** rende um juro real prefixado composto base 252:

```
fatorIndice = Π (1 + indiceMensal_m)            // IPCA/IGP-M acumulado do periodo (decimal)
fatorReal   = (1 + taxaReal) ^ (du / 252)        // ex.: taxaReal = 0,06 para IPCA+6%
VF          = VI * fatorIndice * fatorReal
```

#### 2.5 "Percentual puro" (taxa-alvo manual)

Para lancar um rendimento informal/alvo. Capitalizacao configuravel (composta ou simples) sobre numero de periodos:

```
composta: VF = VI * (1 + taxaPeriodo) ^ nPeriodos
simples:  VF = VI * (1 + taxaPeriodo * nPeriodos)
```

#### 2.6 Bruto, IOF, IR e liquido

```
rendimentoBruto = VF - VI
IOF             = rendimentoBruto * aliquotaIof(dc)        // so se dc < 30 e produto tributavel
baseIR          = rendimentoBruto - IOF
IR              = baseIR * aliquotaIr(dc, isento)          // 0 se produto isento
VF_liquido      = VI + rendimentoBruto - IOF - IR
```

> A ordem importa: **IOF incide primeiro** e reduz a base do IR (a legislacao tributa o rendimento liquido de IOF).

#### 2.7 Conversao final para taxa liquida anual efetiva (metrica unica do comparador)

```
iLiqAnual = (VF_liquido / VI) ^ (252 / du) - 1
```

---

### 3. Funcoes Dart puras do motor de juros

`lib/src/features/conversor_taxas/domain/motor/juros.dart`

```dart
import 'dart:math';

/// Fator diario base 252 a partir de taxa anual (decimal).
double fatorDiario252(double iAnual) => pow(1 + iAnual, 1 / 252).toDouble();

/// VF base 252 dias uteis (juros compostos) - PADRAO do app.
double vfBase252(double vi, double iAnual, int diasUteis) =>
    vi * pow(1 + iAnual, diasUteis / 252).toDouble();

/// VF base 360/365 dias corridos.
double vfBase360(double vi, double iAnual, int diasCorridos) =>
    vi * pow(1 + iAnual, diasCorridos / 360).toDouble();

double vfBase365(double vi, double iAnual, int diasCorridos) =>
    vi * pow(1 + iAnual, diasCorridos / 365).toDouble();

/// VF de pos-fixado em % do CDI (projecao com CDI constante).
/// pct = 1.10 para 110% do CDI.
double vfPercentualCdi(double vi, double cdiAnual, double pct, int du) =>
    vi * pow(1 + cdiAnual, pct * du / 252).toDouble();

/// VF de pos-fixado em % da SELIC (projecao com SELIC constante).
double vfPercentualSelic(double vi, double selicAnual, double pct, int du) =>
    vi * pow(1 + selicAnual, pct * du / 252).toDouble();

/// VF hibrido IPCA+/IGP-M+ : principal corrigido pelo indice * juro real composto.
double vfHibrido(double vi, double indiceAcumulado, double taxaReal, int du) =>
    vi * (1 + indiceAcumulado) * pow(1 + taxaReal, du / 252).toDouble();

/// VF acumulado dia a dia para % do CDI usando a serie diaria real (historico exato).
/// cdisDiarios = lista de taxas DI diarias (anuais, decimal) de cada dia util.
double vfPercentualCdiHistorico(double vi, List<double> cdisDiarios, double pct) {
  var fator = 1.0;
  for (final cdiDia in cdisDiarios) {
    final fatorDiaCdi = pow(1 + cdiDia, 1 / 252).toDouble();
    final fatorAplicado = (fatorDiaCdi - 1) * pct + 1;
    fator *= fatorAplicado;
  }
  return vi * fator;
}
```

#### 3.1 Contagem de dias uteis (base 252)

NUNCA aproximar `du = dc * 252/365` (acumula erro em prazos longos). Contar dias uteis reais excluindo sabados, domingos e feriados. Os feriados sao injetados (vindos de BrasilAPI `/feriados/v1/{ano}`), mantendo a funcao pura.

`lib/src/features/conversor_taxas/domain/motor/dias_uteis.dart`

```dart
/// Conta dias uteis no intervalo [inicio, fim) (exclui o dia final, convencao de
/// contagem de prazo). feriados = datas normalizadas (ano/mes/dia, hora zero).
/// FUNCAO PURA: recebe os feriados, nao busca em API.
int diasUteisEntre(DateTime inicio, DateTime fim, Set<DateTime> feriados) {
  var dia = DateTime(inicio.year, inicio.month, inicio.day);
  final ultimo = DateTime(fim.year, fim.month, fim.day);
  var count = 0;
  while (dia.isBefore(ultimo)) {
    final ehFimDeSemana =
        dia.weekday == DateTime.saturday || dia.weekday == DateTime.sunday;
    if (!ehFimDeSemana && !feriados.contains(dia)) count++;
    dia = dia.add(const Duration(days: 1));
  }
  return count;
}
```

> **Nota de precificacao:** BrasilAPI retorna apenas feriados **nacionais** (`type=national`). O mercado segue o calendario **ANBIMA/B3**, que pode divergir (ex.: feriados estaduais/municipais e datas que so viraram nacionais recentemente). Para o MVP usamos feriados nacionais; documentar que a precificacao exata exigiria o calendario ANBIMA. O `Set<DateTime>` de feriados deve agregar todos os anos cobertos pelo intervalo do investimento.

---

### 4. Tributacao vigente (2026) — `TaxRuleSet` datado e versionado

A regra de isencao caduca/muda por lei. Encapsular tudo em um `TaxRuleSet` com data de vigencia e versao, persistido como config (NAO hardcodar nas entidades de dominio).

`lib/src/features/conversor_taxas/domain/tributacao/tax_rule_set.dart`

```dart
/// Conjunto de regras tributarias DATADO. Permite trocar a regra se a lei mudar
/// sem reescrever o motor. Persistir versao + vigencia.
class TaxRuleSet {
  const TaxRuleSet({
    required this.versao,
    required this.vigenteDesde,
    required this.descricao,
  });

  final int versao;
  final DateTime vigenteDesde;
  final String descricao;

  /// Regra vigente em 2026 (MP 1.303/2025 CADUCOU em out/2025 -> isentos seguem isentos).
  static final v2026 = TaxRuleSet(
    versao: 1,
    vigenteDesde: DateTime(2026, 1, 1),
    descricao:
        'Em 2026: LCI/LCA/CRI/CRA/debentures incentivadas e poupanca ISENTOS de '
        'IR-PF (MP 1.303/2025 nao foi convertida em lei e caducou em out/2025). '
        'IR regressivo 22,5%/20%/17,5%/15%. IOF regressivo 96%->0% nos 30 dias.',
  );
}
```

#### 4.1 IR regressivo (incide so sobre o rendimento, base liquida de IOF)

| Prazo (dias corridos) | Aliquota IR |
|---|---|
| ate 180 | **22,5%** |
| 181 a 360 | **20,0%** |
| 361 a 720 | **17,5%** |
| acima de 720 | **15,0%** |

Aplica-se a: **CDB, Tesouro Direto, LC, LF, debentures comuns**. Cobrado no resgate/vencimento.

`lib/src/features/conversor_taxas/domain/tributacao/ir.dart`

```dart
/// Aliquota de IR regressivo. Retorna 0 se o produto for isento.
/// dias = dias corridos entre aplicacao e resgate/vencimento.
double aliquotaIr(int dias, {required bool isento}) {
  if (isento) return 0;
  if (dias <= 180) return 0.225;
  if (dias <= 360) return 0.20;
  if (dias <= 720) return 0.175;
  return 0.15;
}
```

#### 4.2 IOF regressivo (Decreto 6.306/2007) — so em resgate < 30 dias corridos

Incide sobre o rendimento, **antes** do IR. Formula fechada: `aliquotaIOF = trunc((30 - dias) / 30 * 100) / 100`, com `dias >= 30 => 0`.

Tabela completa (verificada contra o Decreto):

| Dia | % | Dia | % | Dia | % |
|---|---|---|---|---|---|
|1|96|11|63|21|30|
|2|93|12|60|22|26|
|3|90|13|56|23|23|
|4|86|14|53|24|20|
|5|83|15|50|25|16|
|6|80|16|46|26|13|
|7|76|17|43|27|10|
|8|73|18|40|28|6|
|9|70|19|36|29|3|
|10|66|20|33|30|**0**|

`lib/src/features/conversor_taxas/domain/tributacao/iof.dart`

```dart
/// Aliquota de IOF regressivo (Decreto 6.306/2007).
/// dias = dias corridos. Zera a partir do 30o dia.
double aliquotaIof(int dias) {
  if (dias >= 30) return 0;
  if (dias < 1) return 0.96; // resgate no mesmo dia: aplica a maior aliquota
  return ((30 - dias) / 30 * 100).truncate() / 100;
}
```

> **Nota de produto:** LCI/LCA possuem carencia minima legal (em geral 90 dias para pos-fixadas), entao o IOF de 30 dias raramente se aplica a elas. Na pratica o IOF impacta sobretudo **CDB de liquidez diaria** e fundos de curto prazo. O motor calcula corretamente em qualquer caso; a UI pode esconder a linha de IOF quando `dc >= 30`.

#### 4.3 Produtos isentos de IR-PF (em 2026)

| Produto | IR-PF | IOF (<30d) | Observacao |
|---|---|---|---|
| CDB | regressivo | sim | tributavel |
| LC / LF | regressivo | sim | tributavel |
| Tesouro Selic/Prefixado/IPCA+ | regressivo | sim | tributavel |
| Debenture comum | regressivo | sim | tributavel |
| **LCI / LCA** | **ISENTO** | raro (carencia) | isento PF |
| **CRI / CRA** | **ISENTO** | raro | isento PF |
| **Debenture incentivada** | **ISENTO** | raro | isento PF |
| **Poupanca** | **ISENTO** | nao | isento PF |

A flag `isento` deve ser **derivada da `ClasseAtivo` + `TaxRuleSet` datado**, nunca um booleano solto gravado na posicao (pois a lei pode mudar):

```dart
const _classesIsentas2026 = {
  ClasseAtivo.lci,
  ClasseAtivo.lca,
  ClasseAtivo.cri,
  ClasseAtivo.cra,
  ClasseAtivo.debentureIncentivada,
  ClasseAtivo.poupanca,
};

bool isentoIrPf(ClasseAtivo classe, TaxRuleSet regras) =>
    _classesIsentas2026.contains(classe); // regras.versao seleciona o conjunto
```

---

### 5. Algoritmo do conversor / comparador

**Objetivo:** comparar produtos de tipos de taxa heterogeneos (ex.: `110% CDI`, `IPCA+6%`, `13% prefixado`, `LCI 95% CDI isenta`) numa **unica metrica final**: **rentabilidade liquida anual efetiva (% a.a., base 252)** para um **prazo planejado** comum. Para isentos, calcular tambem a **taxa bruta equivalente (gross-up)**.

#### 5.1 Passo a passo

1. **Cenario comum:** `vi` (valor), `prazoDias` (corridos planejados), `du` (dias uteis correspondentes), e o snapshot `Indicadores` (cdi, selic, ipcaProj, igpmProj) — buscado em runtime, nunca hardcodado.
2. Para cada produto, derivar a **taxa anual bruta equivalente** `iBrutaAnual`:
   - Prefixado 13% → `0,13`.
   - 110% CDI → `(1 + cdi)^1,10 − 1` (forma composta; preferir sobre a aproximacao linear `cdi*1,10`).
   - IPCA+6% → `(1 + ipcaProj) * (1 + 0,06) − 1`.
   - LCI 95% CDI → `(1 + cdi)^0,95 − 1` (mesma matematica do pos-fixado; muda so a tributacao).
3. Calcular **VF bruto** no prazo (base 252) e o **rendimento bruto**.
4. Descontar **IOF** (se `prazoDias < 30`) e **IR** (0 se isento; senao pela tabela do prazo).
5. Converter o liquido em **taxa liquida anual efetiva** `(VF_liq/VI)^(252/du) − 1`.
6. **Ranquear** por `iLiqAnual` decrescente. Para isentos, calcular **gross-up**.

#### 5.2 Funcoes Dart puras do conversor

`lib/src/features/conversor_taxas/domain/motor/conversor.dart`

```dart
import 'dart:math';
import '../tributacao/ir.dart';
import '../tributacao/iof.dart';

/// Rentabilidade liquida anual efetiva (% a.a., base 252) de um produto.
/// FUNCAO PURA: todos os indicadores e prazos sao parametros.
double taxaLiquidaAnualEfetiva({
  required double vi,
  required double iBrutaAnual, // taxa anual bruta equivalente do produto (decimal)
  required int prazoDias,      // dias corridos planejados
  required int diasUteis,      // du correspondentes (contados com feriados)
  required bool isento,
}) {
  final vf = vi * pow(1 + iBrutaAnual, diasUteis / 252).toDouble();
  final rendBruto = vf - vi;
  final iof = aliquotaIof(prazoDias) * rendBruto;
  final ir = aliquotaIr(prazoDias, isento: isento) * (rendBruto - iof);
  final vfLiq = vi + rendBruto - iof - ir;
  return pow(vfLiq / vi, 252 / diasUteis).toDouble() - 1;
}

/// Taxa bruta equivalente (gross-up) de um produto ISENTO: quanto um produto
/// TRIBUTAVEL precisaria render (a.a. bruto) para empatar com o isento, dado o
/// prazo planejado e a aliquota de IR correspondente.
double taxaBrutaEquivalenteDeIsento(double iLiqAnualIsento, int prazoDias) =>
    iLiqAnualIsento / (1 - aliquotaIr(prazoDias, isento: false));

/// Taxa anual bruta equivalente a partir do tipo de rendimento contratado.
double iBrutaAnualDe({
  required TipoRendimento tipo,
  required double valorContratado, // 0.13 | 1.10 | 0.06 ...
  required double cdiAnual,
  required double selicAnual,
  required double ipcaProj, // acumulado projetado para o prazo (decimal)
  required double igpmProj,
}) {
  switch (tipo) {
    case TipoRendimento.prefixado:
    case TipoRendimento.percentualPuro:
      return valorContratado;
    case TipoRendimento.percentualCdi:
      return pow(1 + cdiAnual, valorContratado).toDouble() - 1;
    case TipoRendimento.percentualSelic:
      return pow(1 + selicAnual, valorContratado).toDouble() - 1;
    case TipoRendimento.ipcaMais:
      return (1 + ipcaProj) * (1 + valorContratado) - 1;
    case TipoRendimento.igpmMais:
      return (1 + igpmProj) * (1 + valorContratado) - 1;
  }
}
```

#### 5.3 Servico de comparacao (camada application)

```dart
class ComparadorService {
  ResultadoComparacao comparar({
    required double valor,
    required int prazoDias,
    required int diasUteis,
    required List<ProdutoComparavel> produtos,
    required Indicadores indicadores,
  }) {
    final linhas = produtos.map((p) {
      final iBruta = iBrutaAnualDe(
        tipo: p.tipo,
        valorContratado: p.valorContratado,
        cdiAnual: indicadores.cdi,
        selicAnual: indicadores.selic,
        ipcaProj: indicadores.ipcaProjPrazo(prazoDias),
        igpmProj: indicadores.igpmProjPrazo(prazoDias),
      );
      final iLiq = taxaLiquidaAnualEfetiva(
        vi: valor,
        iBrutaAnual: iBruta,
        prazoDias: prazoDias,
        diasUteis: diasUteis,
        isento: p.isento,
      );
      final grossUp =
          p.isento ? taxaBrutaEquivalenteDeIsento(iLiq, prazoDias) : null;
      return LinhaResultado(
        produto: p,
        taxaLiquidaAnual: iLiq,
        taxaBrutaEquivalente: grossUp,
      );
    }).toList()
      ..sort((a, b) => b.taxaLiquidaAnual.compareTo(a.taxaLiquidaAnual));
    return ResultadoComparacao(linhas: linhas, melhor: linhas.first);
  }
}
```

#### 5.4 Wireframe da tela do comparador

```
+--------------------------------------------------------------+
| Conversor / Comparador de renda                               |
+--------------------------------------------------------------+
| Valor [ R$ 10.000,00 ]      Prazo [ 730 dias ]  (IR 15%)      |
| du calculados: 502 dias uteis  (feriados nacionais 2026/27)   |
| -------------------------------------------------------------- |
| Opcao A  ( Pos ▾ )       110% do CDI                          |
| Opcao B  ( Indexador ▾ ) IPCA + 6,00%                         |
| Opcao C  ( Prefixado ▾ ) 13,00% a.a.                         |
| Opcao D  ( LCI ▾ )       95% do CDI   [ISENTO]               |
| -------------------------------------------------------------- |
| Resultado (liquido apos IR/IOF, base 252 d.u.)                |
|   D ▸ 13,63% a.a.  ISENTO   gross-up 16,04%  ⭐ melhor        |
|   A ▸ 13,57% a.a.            ████████████████░                |
|   C ▸ 11,05% a.a.            ████████████░░░░░                |
|   B ▸  9,35% a.a.* (* protege da inflacao; indice variavel)   |
|   [ BarChart fl_chart - comparacao visual + legenda textual ] |
| -------------------------------------------------------------- |
| ⓘ Valores informativos, nao recomendacao. Regras IR/IOF 2026. |
+--------------------------------------------------------------+
```

#### 5.5 Exemplo numerico de referencia (para validar testes)

Cenario: CDI 14,40% a.a., prazo 730 dias (>720 → IR 15%), `du` ≈ 502, `vi` = R$ 10.000. Numeros ilustrativos do modelo (o app recalcula com indices de runtime):

| Produto | Bruto a.a. | IR | Liquido a.a. | Gross-up |
|---|---|---|---|---|
| 13% prefixado | 13,00% | 15% | ≈ 11,05% | — |
| 110% CDI | ≈ 15,96% | 15% | ≈ 13,57% | — |
| LCI 95% CDI (isenta) | ≈ 13,63% | 0% | **≈ 13,63%** | **≈ 16,04%** |
| IPCA+6% (IPCA 12m 4,72%) | ≈ 11,00% | 15% | ≈ 9,35% | — |

Leitura para o usuario: *"a LCI 95% CDI isenta rende liquido 13,63% a.a.; um CDB tributavel precisaria render 16,04% bruto a.a. para empatar"*. Reforcar que IPCA+ tem indice variavel e deve ser comparado com cautela (protege da inflacao).

---

### 6. Projecao de valor futuro

Dado inicio/fim/valor/tipo, produzir `Projecao(vfBruto, rendimentoBruto, iof, ir, vfLiquido)`.

`lib/src/features/conversor_taxas/domain/motor/projetar.dart`

```dart
import 'dart:math';
import 'dias_uteis.dart';
import '../tributacao/ir.dart';
import '../tributacao/iof.dart';

class Projecao {
  const Projecao({
    required this.vfBruto,
    required this.rendimentoBruto,
    required this.iof,
    required this.ir,
    required this.vfLiquido,
  });
  final double vfBruto;
  final double rendimentoBruto;
  final double iof;
  final double ir;
  final double vfLiquido;
}

/// Projeta valor futuro de uma posicao. FUNCAO PURA: feriados e indicadores
/// sao injetados; nenhuma chamada a API ou DateTime.now() interna.
Projecao projetar({
  required double vi,
  required DateTime inicio,
  required DateTime fim,
  required TipoRendimento tipo,
  required double valorContratado, // 0.13 | 1.10 | 0.06 ...
  required double cdiAnual,
  required double selicAnual,
  required double ipcaAcumuladoPeriodo, // decimal, p/ ipcaMais
  required double igpmAcumuladoPeriodo, // decimal, p/ igpmMais
  required Set<DateTime> feriados,
  required bool isento,
}) {
  final dc = fim.difference(inicio).inDays;
  final du = diasUteisEntre(inicio, fim, feriados);

  final double vf;
  switch (tipo) {
    case TipoRendimento.prefixado:
      vf = vi * pow(1 + valorContratado, du / 252).toDouble();
    case TipoRendimento.percentualCdi:
      vf = vi * pow(1 + cdiAnual, valorContratado * du / 252).toDouble();
    case TipoRendimento.percentualSelic:
      vf = vi * pow(1 + selicAnual, valorContratado * du / 252).toDouble();
    case TipoRendimento.ipcaMais:
      vf = vi *
          (1 + ipcaAcumuladoPeriodo) *
          pow(1 + valorContratado, du / 252).toDouble();
    case TipoRendimento.igpmMais:
      vf = vi *
          (1 + igpmAcumuladoPeriodo) *
          pow(1 + valorContratado, du / 252).toDouble();
    case TipoRendimento.percentualPuro:
      // taxa simples ao mes sobre dias corridos; ajustar base conforme cadastro
      vf = vi * (1 + valorContratado * (dc / 30));
  }

  final rend = vf - vi;
  final iof = aliquotaIof(dc) * rend;
  final ir = aliquotaIr(dc, isento: isento) * (rend - iof);
  return Projecao(
    vfBruto: vf,
    rendimentoBruto: rend,
    iof: iof,
    ir: ir,
    vfLiquido: vi + rend - iof - ir,
  );
}
```

#### 6.1 Value object da taxa (NUNCA um double solto)

```dart
@freezed
sealed class TipoRendimento with _$TipoRendimento { ... }
// prefixado | percentualCdi | percentualSelic | ipcaMais | igpmMais | percentualPuro

@freezed
class TaxaContratada with _$TaxaContratada {
  const factory TaxaContratada({
    required TipoRendimento tipoRendimento,
    required double valorContratado,   // 0.13 (13% a.a.) | 1.10 (110% CDI) | 0.06 (IPCA+6%)
    Indexador? indexador,              // cdi | selic | ipca | igpm | null (prefixado)
    @Default(BaseDias.b252) BaseDias baseDias,
    @Default(Capitalizacao.composta) Capitalizacao capitalizacao,
  }) = _TaxaContratada;
}
```

---

### 7. Indicadores de entrada (BCB SGS) consumidos pelo motor

O motor **recebe** os indicadores ja parseados. A camada `data` busca de BCB SGS (`/ultimos/1`, sem auth, valor vem como **String** com ponto/virgula — fazer parse defensivo) e monta o snapshot:

| Indicador | Serie SGS | Forma | Uso no motor |
|---|---|---|---|
| SELIC meta | 432 | % a.a. (`"14.50"`) | `selicAnual` (card + pos-SELIC) |
| SELIC diaria | 11 | % a.d. | acumulacao historica |
| CDI/DI diario | 12 | % a.d. (`"0.053400"`) | produtorio % CDI exato |
| CDI anualizado | 4389 | % a.a. | `cdiAnual` (projecao % CDI) |
| IPCA mensal | 433 | % mes | `ipcaAcumuladoPeriodo` (compor) |
| IGP-M mensal | 189 | % mes | `igpmAcumuladoPeriodo` (compor) |
| TR | 226 | % periodo (`dataFim`) | poupanca |
| Poupanca | 195 | % periodo (`dataFim`) | rendimento poupanca |

> Para `cdiAnual` na projecao, preferir a serie **4389 (CDI anualizado base 252)** ou anualizar a serie 12 via `(1 + cdiDia)^252 − 1`. Para IPCA/IGP-M acumulados do periodo, compor as variacoes mensais: `Π(1 + mensal_m) − 1`. **Sempre converter `String` → `double`** tratando virgula e ponto, e tratar resposta que pode vir HTML em erro.

---

### 8. Plano de testes (flutter_test, sem mocks — funcoes puras)

Casos minimos obrigatorios (`test/features/conversor_taxas/`):

```dart
group('aliquotaIof (Decreto 6.306/2007)', () {
  test('dia 1 = 96%',  () => expect(aliquotaIof(1),  0.96));
  test('dia 10 = 66%', () => expect(aliquotaIof(10), 0.66));
  test('dia 29 = 3%',  () => expect(aliquotaIof(29), 0.03));
  test('dia 30 = 0%',  () => expect(aliquotaIof(30), 0.0));
  test('dia 45 = 0%',  () => expect(aliquotaIof(45), 0.0));
});

group('aliquotaIr regressivo', () {
  test('180d = 22,5%',   () => expect(aliquotaIr(180, isento: false), 0.225));
  test('360d = 20%',     () => expect(aliquotaIr(360, isento: false), 0.20));
  test('720d = 17,5%',   () => expect(aliquotaIr(720, isento: false), 0.175));
  test('721d = 15%',     () => expect(aliquotaIr(721, isento: false), 0.15));
  test('isento = 0',     () => expect(aliquotaIr(100, isento: true),  0.0));
});

group('vfBase252 juros compostos', () {
  test('252 du = +i exato', () {
    expect(vfBase252(10000, 0.144, 252), closeTo(11440, 0.01));
  });
});

group('diasUteisEntre exclui fds e feriados', () {
  test('semana cheia sem feriado = 5 du', () {
    final feriados = <DateTime>{};
    // segunda a segunda seguinte (exclusivo)
    expect(diasUteisEntre(DateTime(2026,6,15), DateTime(2026,6,22), feriados), 5);
  });
});

group('taxaBrutaEquivalenteDeIsento (gross-up)', () {
  test('isento liquido 13,63% com IR 15% -> ~16,04% bruto', () {
    expect(taxaBrutaEquivalenteDeIsento(0.1363, 730), closeTo(0.1604, 0.0005));
  });
});

group('comparador ranqueia por liquido anual', () { /* isento vence tributavel equivalente */ });
group('projecao desconta IOF antes de IR', () { /* dc<30: base IR = rend - iof */ });
```

Diretrizes: comparar `double` sempre com `closeTo` (tolerancia ~1e-6 a 1e-2 conforme o caso); cobrir cada `TipoRendimento`; cobrir fronteiras das faixas de IR (180/181, 360/361, 720/721) e de IOF (0, 1, 29, 30); validar o gross-up; validar contagem de dias uteis com feriado dentro do intervalo.

---

### 9. Resumo de invariantes para o implementador

- **Default = base 252 dias uteis + juros compostos** para CDB/LCI/LCA/prefixado/pos-CDI. Base 360/365 e parametro por produto.
- **Taxa = value object** `{tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}`, nunca um `double` solto. Persistir a **taxa contratada**, nao a efetiva.
- **IOF incide antes do IR** e reduz a base do IR.
- **IOF so quando `dc < 30`**; **IR regressivo** pela tabela; **isentos** (LCI/LCA/CRI/CRA/incentivadas/poupanca) com IR = 0 derivado de `ClasseAtivo` + `TaxRuleSet` datado.
- **Gross-up usa a aliquota de IR do prazo planejado**, nao 15% fixo; deixar o prazo assumido explicito na UI.
- **Comparador converte tudo para rentabilidade liquida anual efetiva (% a.a., base 252)** + gross-up para isentos.
- **Dias uteis reais** com feriados injetados; nunca aproximar por `dc*252/365`.
- **Funcoes puras e testaveis**: indicadores, feriados e datas sao parametros; sem I/O nem `DateTime.now()` interno.
- **Aviso CVM datado** obrigatorio nas telas de conversor e projecao.

---

## Camada de Dados, APIs Gratuitas & Cache Diario

Esta secao especifica, sem ambiguidade, **como o Investa BR busca, normaliza, cacheia e persiste dados de mercado**. O modelo de persistencia (sembast), o motor financeiro e o formato de import/export sao descritos em outras secoes; aqui o foco e a **camada `data/` de cada feature** (datasource remoto + local), os **clientes Dio por API**, o **`DailyCacheService`** da primeira requisicao do dia e o **fallback offline / tratamento de limites**.

Principio arquitetural: **toda chamada de rede passa por um datasource remoto que retorna DTOs (freezed + json_serializable); o repository decide cache/fallback e devolve `Result<Entidade>` para a `application/`; a fronteira Riverpod usa `AsyncValue.guard`.** Nenhum widget toca em Dio ou em sembast diretamente.

---

### 1. Tabela das APIs gratuitas (verificadas em 17/06/2026)

Todas as URLs e limites abaixo foram confirmados por fetch real na data indicada. Os valores numericos de mercado citados sao apenas para validar o parsing — **em runtime, sempre buscar da fonte**.

| # | API | base_url | auth | limite (real) | free_tier | uso no app |
|---|-----|----------|------|---------------|-----------|------------|
| 1 | **BCB SGS** (Sistema Gerenciador de Series Temporais) | `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados` | Nenhuma (publica) | Janela max **10 anos** por consulta de periodo; `/ultimos/{N}` max **20**; filtros obrigatorios desde 26/03/2025; rate limiting de servidor (sem numero oficial; **≤5 req paralelas** como cortesia); pode rejeitar por User-Agent ausente | 100% gratuita, sem cota por usuario | **CRITICO** — indicadores SELIC/CDI/IPCA/IGP-M/TR/poupanca |
| 2 | **brapi.dev** | `https://brapi.dev/api` (v1), `https://brapi.dev/api/v2` (v2) | Token gratuito obrigatorio (`Authorization: Bearer` ou `?token=`) | Free: **15.000 req/mes**, 1 ticker/req, update ~30min, historico ~3 meses. Sem token: so PETR4/MGLU3/VALE3/ITUB4. HTTP **429** ao estourar | Sim (token gratuito apos cadastro) | Acoes B3 (cotacao + fundamentos) |
| 3 | **BrasilAPI** | `https://brasilapi.com.br/api` | Nenhuma | Fair use (sem numero oficial); `/cnpj` e o mais throttled; tratar **429/5xx** | 100% gratuita | Feriados nacionais, taxas headline, CNPJ (principal), PTAX |
| 4 | **OpenCNPJ** | `https://api.opencnpj.org/{cnpj}` | Nenhuma | **50 req/s por IP**; cache Cloudflare `max-age=86400` | 100% gratuita, uso comercial livre | CNPJ — **fallback** de alto volume |
| 5 | **ReceitaWS** | `https://receitaws.com.br/v1/cnpj/{cnpj}` | Nenhuma (free) | **3 req/min** (free); aguardar ~20s entre chamadas | Sim (`billing.free=true`) | CNPJ — fallback pontual |
| 6 | **AwesomeAPI Economia** | `https://economia.awesomeapi.com.br` | Opcional (chave gratuita) | Sem chave: cache 1min, max **100 resultados/consulta** em series. Com chave: **100k req/mes**, 1.500 resultados; `daily` max 360 dias | Sim | Cambio (USD-BRL etc.) — **secundario** |
| 7 | **Tesouro Transparente (CKAN)** | `https://www.tesourotransparente.gov.br/ckan/.../precotaxatesourodireto.csv` | Nenhuma | CSV ~13,5 MiB, atualizado 1x/dia (manha). **datastore_search NAO existe** (HTTP 400) — apenas CSV | 100% gratuita (ODbL) | Tesouro Direto (precos/taxas) — sob demanda |
| 8 | **BCB Olinda / Focus** | `https://olinda.bcb.gov.br/olinda/servico/Expectativas/versao/v1/odata` | Nenhuma | OData: max **1000 registros/chamada** (paginar `$skip`/`$top`); sem rate limit oficial | 100% gratuita | Projecoes (opcional/futuro) |

> **Atencao critica brapi/recomendacoes:** os campos `recommendationKey`, `recommendationMean`, `targetMeanPrice`, `numberOfAnalystOpinions` retornam **`null` no plano free com HTTP 200** (sem erro de auth). So o plano PRO os popula. No MVP gratuito, derivar sinais proprios de fundamentos (P/L, P/VP, DY, ROE). A UI degrada graciosamente quando ausentes.

---

### 2. Codigos de serie do BCB SGS

Os 7 codigos do batch de boot estao em **negrito**. `formato=json` recomendado. Series **226** (TR) e **195** (poupanca) trazem o campo extra **`dataFim`** (periodo de vigencia).

| Codigo | Serie | Unidade | Formato resposta | Uso no app |
|--------|-------|---------|------------------|------------|
| **432** | SELIC meta (Copom) | % a.a. | `{data, valor}` | Card "Selic atual"; gross-up |
| **11** | SELIC diaria (efetiva) | % ao dia (base 252) | `{data, valor}` | Motor financeiro |
| **12** | CDI / taxa DI diaria | % ao dia (base 252) | `{data, valor}` | Pos-fixados %CDI |
| **433** | IPCA — variacao mensal | % mes | `{data, valor}` | Hibridos IPCA+ |
| **189** | IGP-M — variacao mensal | % mes | `{data, valor}` | Card / indexador |
| **226** | TR — Taxa Referencial | % no periodo | `{data, dataFim, valor}` | Poupanca/TR |
| **195** | Poupanca — rendimento | % no periodo | `{data, dataFim, valor}` | Card poupanca |
| 1178 | SELIC anualizada base 252 | % a.a. | `{data, valor}` | Exibir Selic diaria anualizada |
| 4389 | CDI anualizado base 252 | % a.a. | `{data, valor}` | Headline CDI a.a. |
| 4390 | SELIC acumulada no mes | % | `{data, valor}` | Auxiliar |
| 13522 | IPCA acumulado 12 meses | % | `{data, valor}` | Card "IPCA 12m" |
| 188 | IGP-DI (alternativa) | % mes | `{data, valor}` | Opcional |

```dart
// lib/src/constants/series_bcb.dart
/// Codigos de serie do BCB SGS usados pelo Investa BR.
abstract final class SeriesBcb {
  static const int selicMeta = 432;
  static const int selicDiaria = 11;
  static const int cdiDiario = 12;
  static const int ipcaMensal = 433;
  static const int igpmMensal = 189;
  static const int tr = 226;        // traz dataFim
  static const int poupanca = 195;  // traz dataFim

  // Auxiliares (sob demanda, fora do boot)
  static const int cdiAnualizado = 4389;
  static const int ipcaAcum12m = 13522;

  /// Series carregadas no batch de boot (cards da home).
  static const List<int> boot = <int>[
    selicMeta, selicDiaria, cdiDiario, ipcaMensal, igpmMensal, tr, poupanca,
  ];

  /// Series cuja resposta inclui o campo dataFim.
  static const Set<int> comDataFim = <int>{tr, poupanca};
}
```

**Padrao de URL** (cards da home usam `/ultimos/1`, que **nao** sofre o limite de 10 anos):
```
GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados/ultimos/1?formato=json
GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=json&dataInicial=01/01/2026&dataFinal=31/05/2026
```

**Pegadinhas confirmadas do parse SGS:**
1. `valor` vem como **STRING** (`"14.50"`, `"0.053400"`) — nunca tipar como `num` no DTO.
2. `data`/`dataFim` em **`dd/MM/yyyy`**.
3. O ponto decimal vem como **`.`** no JSON (`"0.053400"`), mas **trate defensivamente virgula** (alguns formatos/erros e o CSV do Tesouro usam `,`).
4. Erro pode vir como **HTML** (`Requisicao Invalida`) com `Content-Type: text/html` — detectar e mapear para `Failure.parse`.
5. **User-Agent obrigatorio** — sem ele a serie 12 ja retornou HTML; o interceptor injeta UA padrao.
6. Para series longas (conversor/comparador), **fragmentar em janelas ≤10 anos** e concatenar.

---

### 3. Arquitetura repository + datasource (remote/local)

#### 3.1 Arvore de arquivos da camada de dados

```
lib/src/
  common/
    network/
      dio_factory.dart            # cria Dio por API + interceptors compartilhados
      api_endpoints.dart          # base URLs (constantes)
      interceptors/
        user_agent_interceptor.dart
        brapi_token_interceptor.dart
        error_normalizer_interceptor.dart
        logging_interceptor.dart  # so em kDebugMode
    result/
      result.dart                 # sealed Result<T> (Success/Failure)
      failure.dart                # sealed Failure (network/rateLimit/parse/notFound/unknown)
    cache/
      daily_cache_service.dart    # cache "primeira requisicao do dia"
      cache_snapshot.dart         # freezed: dados + dataUltimaAtualizacao + fetchedAt + stale
  features/
    indicadores/
      data/
        dto/
          serie_sgs_ponto_dto.dart      # {data, dataFim?, valor:String}
        datasources/
          sgs_remote_datasource.dart    # Dio -> List<SerieSgsPontoDto>
          indicadores_local_datasource.dart  # sembast store cache_indicadores
        mappers/
          serie_sgs_mapper.dart         # DTO -> Indicador (parse String->double, data)
        indicadores_repository_impl.dart
      domain/
        entities/indicador.dart         # freezed
        repositories/indicadores_repository.dart  # interface
      application/
        indicadores_controller.dart     # @riverpod AsyncNotifier
    acoes/
      data/
        dto/ cotacao_dto.dart  fundamentos_dto.dart
        datasources/ brapi_remote_datasource.dart  acoes_local_datasource.dart
        acoes_repository_impl.dart
      domain/ ...  application/ ...
    renda_fixa/
      data/
        datasources/ cnpj_remote_datasource.dart  # BrasilAPI->OpenCNPJ->ReceitaWS
        ...
```

#### 3.2 `Result<T>` e `Failure` (sealed, Dart 3)

```dart
// lib/src/common/result/failure.dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}
class NetworkFailure   extends Failure { const NetworkFailure(super.m); }
class RateLimitFailure extends Failure { const RateLimitFailure(super.m, {this.retryAfter}); final Duration? retryAfter; }
class ParseFailure     extends Failure { const ParseFailure(super.m); }
class NotFoundFailure  extends Failure { const NotFoundFailure(super.m); }
class UnknownFailure   extends Failure { const UnknownFailure(super.m); }

// lib/src/common/result/result.dart
sealed class Result<T> {
  const Result();
}
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}
final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
```

#### 3.3 Interface do repository (domain) e contrato dos datasources

```dart
// domain/repositories/indicadores_repository.dart
abstract interface class IndicadoresRepository {
  /// Le do cache do dia; se ausente/expirado, busca remoto e persiste.
  /// [forcarRefresh] ignora o cache (botao de refresh manual).
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  });
}
```

```dart
// data/datasources/sgs_remote_datasource.dart
class SgsRemoteDatasource {
  SgsRemoteDatasource(this._dio);
  final Dio _dio; // base = https://api.bcb.gov.br/dados/serie

  /// Busca os ultimos [n] pontos de uma serie. Lanca DioException;
  /// o repository converte em Failure.
  Future<List<SerieSgsPontoDto>> ultimos(int codigo, {int n = 1}) async {
    final r = await _dio.get<dynamic>(
      '/bcdata.sgs.$codigo/dados/ultimos/$n',
      queryParameters: const {'formato': 'json'},
    );
    final data = r.data;
    if (data is! List) {
      // Resposta HTML de erro chega como String -> ParseFailure no repo.
      throw const FormatException('Resposta SGS nao e JSON array');
    }
    return data
        .cast<Map<String, dynamic>>()
        .map(SerieSgsPontoDto.fromJson)
        .toList();
  }

  /// Batch paralelo, respeitando o limite de cortesia (~5 simultaneas).
  Future<Map<int, List<SerieSgsPontoDto>>> batchUltimos(
    List<int> codigos, {
    int concorrencia = 5,
  }) async {
    final out = <int, List<SerieSgsPontoDto>>{};
    for (var i = 0; i < codigos.length; i += concorrencia) {
      final lote = codigos.skip(i).take(concorrencia);
      final res = await Future.wait(
        lote.map((c) async => MapEntry(c, await ultimos(c))),
      );
      out.addEntries(res);
    }
    return out;
  }
}
```

#### 3.4 DTO do ponto SGS e mapper (parse defensivo)

```dart
// data/dto/serie_sgs_ponto_dto.dart
@freezed
abstract class SerieSgsPontoDto with _$SerieSgsPontoDto {
  const factory SerieSgsPontoDto({
    required String data,        // dd/MM/yyyy
    String? dataFim,             // so 226 e 195
    required String valor,       // STRING: "14.50" / "0.053400"
  }) = _SerieSgsPontoDto;
  factory SerieSgsPontoDto.fromJson(Map<String, dynamic> j) =>
      _$SerieSgsPontoDtoFromJson(j);
}

// data/mappers/serie_sgs_mapper.dart
double parseValorSgs(String raw) {
  // Aceita "14.50" e, defensivamente, "14,50".
  final normalizado = raw.trim().replaceAll(',', '.');
  final v = double.tryParse(normalizado);
  if (v == null) throw const FormatException('valor SGS invalido');
  return v;
}

DateTime parseDataSgs(String raw) {
  final p = raw.split('/'); // dd/MM/yyyy
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}
```

#### 3.5 Implementacao do repository (orquestra remote + local + Result)

```dart
// data/indicadores_repository_impl.dart
class IndicadoresRepositoryImpl implements IndicadoresRepository {
  IndicadoresRepositoryImpl(this._remote, this._cache);
  final SgsRemoteDatasource _remote;
  final DailyCacheService _cache;
  static const _key = 'indicadores_dia';

  @override
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  }) async {
    // 1) Servir do cache se valido e nao for refresh manual.
    final emCache = await _cache.lerSeDeHoje<List<Indicador>>(
      _key,
      (json) => (json as List).map(Indicador.fromJson).toList(),
    );
    if (!forcarRefresh && emCache != null) {
      return Success(emCache);
    }

    // 2) Buscar remoto.
    try {
      final bruto = await _remote.batchUltimos(SeriesBcb.boot);
      final indicadores = bruto.entries.map((e) {
        final ponto = e.value.first;
        return Indicador(
          codigo: e.key,
          valor: parseValorSgs(ponto.valor),
          data: parseDataSgs(ponto.data),
          dataFim: ponto.dataFim == null ? null : parseDataSgs(ponto.dataFim!),
        );
      }).toList();

      final snap = await _cache.gravar(
        _key,
        indicadores,
        toJson: (l) => l.map((i) => i.toJson()).toList(),
      );
      return Success(snap);
    } on DioException catch (e) {
      final failure = _mapDio(e);
      // 3) Fallback offline: cache antigo (mesmo vencido) marcado stale.
      final stale = await _cache.lerQualquer<List<Indicador>>(
        _key,
        (json) => (json as List).map(Indicador.fromJson).toList(),
      );
      if (stale != null) {
        return Success(stale.copyWith(stale: true));
      }
      return FailureResult(failure);
    } on FormatException catch (e) {
      return FailureResult(ParseFailure(e.message));
    }
  }

  Failure _mapDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == 429) {
      final h = e.response?.headers.value('retry-after');
      return RateLimitFailure(
        'Limite de requisicoes',
        retryAfter: h == null ? null : Duration(seconds: int.tryParse(h) ?? 60),
      );
    }
    if (status == 404) return const NotFoundFailure('Recurso nao encontrado');
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure('Sem conexao');
    }
    // SGS as vezes responde HTML de erro com 200 -> ja tratado em FormatException.
    return UnknownFailure(e.message ?? 'Erro desconhecido');
  }
}
```

#### 3.6 Fronteira Riverpod (`application/`)

```dart
// application/indicadores_controller.dart
@riverpod
class IndicadoresController extends _$IndicadoresController {
  @override
  Future<CacheSnapshot<List<Indicador>>> build() async {
    return _carregar(forcar: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<CacheSnapshot<List<Indicador>>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _carregar(forcar: true));
  }

  Future<CacheSnapshot<List<Indicador>>> _carregar({required bool forcar}) async {
    final repo = ref.read(indicadoresRepositoryProvider);
    final res = await repo.obterIndicadores(forcarRefresh: forcar);
    return switch (res) {
      Success(:final value) => value,
      FailureResult(:final failure) => throw failure, // guard -> AsyncError
    };
  }
}
```

#### 3.7 Providers como container de DI (sem get_it)

```dart
// common/network/network_providers.dart
@riverpod
Dio sgsDio(Ref ref) => DioFactory.criar(
      baseUrl: ApiEndpoints.sgsBase, // https://api.bcb.gov.br/dados/serie
      comUserAgent: true,
    );

@riverpod
Dio brapiDio(Ref ref) => DioFactory.criar(
      baseUrl: ApiEndpoints.brapiV1,
      token: ref.watch(brapiTokenProvider), // injetado pelo interceptor
    );

@riverpod
IndicadoresRepository indicadoresRepository(Ref ref) =>
    IndicadoresRepositoryImpl(
      SgsRemoteDatasource(ref.watch(sgsDioProvider)),
      ref.watch(dailyCacheServiceProvider),
    );
```

Em testes: `ProviderContainer(overrides: [indicadoresRepositoryProvider.overrideWith((_) => FakeRepo())])`.

---

### 4. Interceptors Dio (por API)

```dart
// common/network/dio_factory.dart
abstract final class DioFactory {
  static Dio criar({
    required String baseUrl,
    bool comUserAgent = false,
    String? token,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      // Aceita texto: o SGS pode devolver HTML em erro; queremos inspecionar.
      responseType: ResponseType.json,
    ));
    if (comUserAgent) dio.interceptors.add(UserAgentInterceptor());
    if (token != null) dio.interceptors.add(BrapiTokenInterceptor(token));
    dio.interceptors.add(ErrorNormalizerInterceptor());
    if (kDebugMode) dio.interceptors.add(LoggingInterceptor());
    return dio;
  }
}

// interceptors/user_agent_interceptor.dart
class UserAgentInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    // BCB SGS rejeita clientes sem UA "comum".
    o.headers['User-Agent'] = 'InvestaBR/1.0 (Flutter; +app)';
    h.next(o);
  }
}

// interceptors/brapi_token_interceptor.dart
class BrapiTokenInterceptor extends Interceptor {
  BrapiTokenInterceptor(this._token);
  final String _token;
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    if (_token.isNotEmpty) o.headers['Authorization'] = 'Bearer $_token';
    h.next(o);
  }
}
```

| Interceptor | Aplica em | Funcao |
|-------------|-----------|--------|
| `UserAgentInterceptor` | **SGS** (e demais) | Injeta UA — SGS rejeita alguns clientes sem ele |
| `BrapiTokenInterceptor` | **brapi** | `Authorization: Bearer <token>` em runtime config |
| `ErrorNormalizerInterceptor` | todas | Detecta HTML de erro, mapeia status para `Failure` |
| `LoggingInterceptor` | todas (so `kDebugMode`) | Log de request/response |

---

### 5. Estrategia de cache "primeira requisicao do dia"

**Regra:** chave por **indicador + data (`yyyy-MM-dd`, fuso America/Sao_Paulo = UTC-3, sem horario de verao desde 2019)**. No boot, **batch paralelo** das series SGS `[432,11,12,433,189,226,195]` + feriados BrasilAPI do ano + cotacoes da carteira. Persistir snapshot com `dataUltimaAtualizacao` + `fetchedAt`. Servir do cache se `data == hoje`; **stale-while-revalidate**; fallback offline marca `stale=true`; botao de refresh manual forca refetch. Acoes/Tesouro sob demanda com cache proprio para nao pesar o boot.

```
                         BOOT DO APP
                             │
                  ┌──────────▼───────────┐
                  │ DailyCacheService     │
                  │ lerSeDeHoje(key)      │
                  └──────────┬───────────┘
              hit (hoje)     │      miss / expirado / forcarRefresh
        ┌──────────────◄─────┴─────►──────────────┐
        │ serve cache                              │
        │ stale=false                              ▼
        │                                  batch paralelo (≤5)
        │                                  SGS boot + feriados + cotacoes
        │                                          │
        │                              ┌───────────┴───────────┐
        │                          sucesso                  erro rede
        │                              │                        │
        │                       grava snapshot          existe cache antigo?
        │                       data=hoje, stale=false    ┌─────┴─────┐
        │                              │                 sim         nao
        │                              ▼                  │           │
        └──────────►  exibe ◄──────────┘        serve stale=true   Failure
```

```dart
// common/cache/cache_snapshot.dart
@freezed
abstract class CacheSnapshot<T> with _$CacheSnapshot<T> {
  const factory CacheSnapshot({
    required T dados,
    required String dataUltimaAtualizacao, // yyyy-MM-dd (SP)
    required DateTime fetchedAt,
    @Default(false) bool stale,
    @Default(12) int ttlHoras,
  }) = _CacheSnapshot<T>;
}

// common/cache/daily_cache_service.dart
class DailyCacheService {
  DailyCacheService(this._db, this._store);
  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store; // cache_indicadores

  /// Data corrente em America/Sao_Paulo (UTC-3 fixo).
  String hojeSp() => DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 10);

  /// Retorna o snapshot somente se for de hoje E dentro do TTL.
  Future<CacheSnapshot<T>?> lerSeDeHoje<T>(
    String key,
    T Function(Object? json) fromJson,
  ) async {
    final raw = await _store.record(key).get(_db);
    if (raw == null) return null;
    final mesmaData = raw['dataUltimaAtualizacao'] == hojeSp();
    final fetchedAt = DateTime.tryParse(raw['fetchedAt'] as String? ?? '');
    final ttl = Duration(hours: (raw['ttlHoras'] as num?)?.toInt() ?? 12);
    final dentroTtl =
        fetchedAt != null && DateTime.now().difference(fetchedAt) < ttl;
    if (!mesmaData || !dentroTtl) return null;
    return _hidratar(raw, fromJson);
  }

  /// Le qualquer snapshot existente, mesmo vencido (fallback offline).
  Future<CacheSnapshot<T>?> lerQualquer<T>(
    String key,
    T Function(Object? json) fromJson,
  ) async {
    final raw = await _store.record(key).get(_db);
    return raw == null ? null : _hidratar(raw, fromJson);
  }

  Future<CacheSnapshot<T>> gravar<T>(
    String key,
    T dados, {
    required Object? Function(T) toJson,
  }) async {
    final snap = CacheSnapshot<T>(
      dados: dados,
      dataUltimaAtualizacao: hojeSp(),
      fetchedAt: DateTime.now(),
    );
    await _store.record(key).put(_db, {
      'dataUltimaAtualizacao': snap.dataUltimaAtualizacao,
      'fetchedAt': snap.fetchedAt.toIso8601String(),
      'ttlHoras': snap.ttlHoras,
      'stale': false,
      'payload': toJson(dados),
    });
    return snap;
  }

  CacheSnapshot<T> _hidratar<T>(
    Map<String, Object?> raw,
    T Function(Object? json) fromJson,
  ) =>
      CacheSnapshot<T>(
        dados: fromJson(raw['payload']),
        dataUltimaAtualizacao: raw['dataUltimaAtualizacao'] as String,
        fetchedAt: DateTime.parse(raw['fetchedAt'] as String),
        ttlHoras: (raw['ttlHoras'] as num?)?.toInt() ?? 12,
        stale: raw['stale'] as bool? ?? false,
      );
}
```

**TTL diario + TTL intra-dia:** `dataUltimaAtualizacao` garante refetch a cada novo dia; `ttlHoras` (default 12) permite um refresh intra-dia opcional. **Refresh manual** chama `obterIndicadores(forcarRefresh: true)` ignorando ambos. Como as series SGS atualizam ~1x/dia (D-1 util), a chave por data e suficiente na pratica.

**Chaves por dominio:**

| Dominio | Chave | TTL | Quando |
|---------|-------|-----|--------|
| Indicadores SGS | `indicadores_dia` | dia + 12h | Boot |
| Feriados | `feriados_{ano}` | **estatico** (1 ano) | Boot, 1x por ano |
| Cotacoes carteira | `cotacoes_dia` | dia + 12h | Boot (so tickers da carteira) |
| Cotacao avulsa (busca) | `cotacao_{ticker}_dia` | dia | Sob demanda |
| Fundamentos acao | `fund_{ticker}_dia` | dia | Sob demanda |
| Tesouro CSV | `tesouro_csv_dia` | dia | Sob demanda |
| CNPJ | `cnpj_{cnpj}` | **TTL longo (30 dias)** | Sob demanda |

---

### 6. Fallback offline e tratamento de limites de requisicao

#### 6.1 Fallback offline (regra geral)
1. Sempre persistir o **ultimo snapshot bom**.
2. Em erro de rede/timeout, devolver o cache existente **mesmo vencido**, com `stale: true`.
3. A UI exibe selo "Atualizado em dd/MM/yyyy" e, se `stale`, um aviso "Dados podem estar desatualizados (offline)" + botao retry.
4. Se nao houver **nenhum** cache, retornar `FailureResult(NetworkFailure)` e a UI mostra estado vazio com retry.

#### 6.2 Limites por API e mitigacao

| API | Limite | Mitigacao no app |
|-----|--------|------------------|
| **SGS** | 10 anos/consulta; `/ultimos` ≤20; ~5 req paralelas; rejeita sem UA | `batchUltimos(concorrencia:5)`; cards usam `/ultimos/1`; fragmentar series longas em janelas ≤10 anos; UA via interceptor; parse defensivo de HTML de erro |
| **brapi** | 15k/mes; 1 ticker/req; 429 | Cache diario agressivo; so atualiza tickers **da carteira** no boot; busca avulsa cacheada por ticker+dia; backoff exponencial em 429 (respeitar `Retry-After`) |
| **BrasilAPI /cnpj** | mais throttled; 429/5xx | Cache por CNPJ (TTL 30 dias); cair para OpenCNPJ; backoff |
| **OpenCNPJ** | 50 req/s | Folga ampla; usado como fallback de volume |
| **ReceitaWS** | 3 req/min | Ultimo fallback; espacar ~20s; nunca em loop |
| **AwesomeAPI** | sem chave: cache 1min, 100 resultados | `daily` ≤360 dias; agrupar pares numa chamada `/json/last` |
| **Tesouro CSV** | ~13,5 MiB, 1x/dia | Baixar 1x/dia, cachear, filtrar localmente pela `Data Base` mais recente; **nunca** usar `datastore_search` (HTTP 400) |

#### 6.3 Backoff exponencial para 429/5xx

```dart
Future<T> comBackoff<T>(
  Future<T> Function() acao, {
  int maxTentativas = 3,
  Duration base = const Duration(milliseconds: 800),
}) async {
  var tentativa = 0;
  while (true) {
    try {
      return await acao();
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final retentavel = status == 429 || (status >= 500 && status < 600);
      tentativa++;
      if (!retentavel || tentativa >= maxTentativas) rethrow;
      // Respeita Retry-After quando presente; senao backoff exponencial.
      final retryAfter = e.response?.headers.value('retry-after');
      final espera = retryAfter != null
          ? Duration(seconds: int.tryParse(retryAfter) ?? 1)
          : base * (1 << (tentativa - 1)); // 800ms, 1.6s, 3.2s
      await Future<void>.delayed(espera);
    }
  }
}
```

#### 6.4 Cadeia de fallback do CNPJ

```dart
// data/datasources/cnpj_remote_datasource.dart
Future<Result<EmpresaDto>> consultarCnpj(String cnpjBruto) async {
  final cnpj = cnpjBruto.replaceAll(RegExp(r'\D'), ''); // so digitos
  // 1) Cache local (TTL 30 dias)
  final cached = await _local.lerSeFresco('cnpj_$cnpj', maxIdade: const Duration(days: 30));
  if (cached != null) return Success(EmpresaDto.fromJson(cached));

  // 2) BrasilAPI -> 3) OpenCNPJ -> 4) ReceitaWS
  for (final fonte in [_brasilApi, _openCnpj, _receitaWs]) {
    try {
      final dto = await comBackoff(() => fonte.buscar(cnpj));
      await _local.gravar('cnpj_$cnpj', dto.toJson());
      return Success(dto);
    } on DioException catch (_) {
      continue; // tenta a proxima fonte
    }
  }
  return const FailureResult(NetworkFailure('CNPJ indisponivel em todas as fontes'));
}
```

> **Atencao schema OpenCNPJ:** array de socios e **`QSA`** (nao `socios`); endereco e **plano** (`tipo_logradouro`, `logradouro`, `numero`, `bairro`, `cep`, `uf`, `municipio`), nao aninhado; `cnaes[]` traz `is_principal`. O mapper de cada fonte normaliza para a mesma `EmpresaDto` interna. **ReceitaWS:** `ultima_atualizacao` vem em **ISO 8601** (nao `dd/MM/yyyy`).

---

### 7. Exemplos de payload JSON (confirmados)

**SGS 432 — SELIC meta** (`/ultimos/1`):
```json
[{"data":"17/06/2026","valor":"14.50"}]
```

**SGS 12 — CDI diario:**
```json
[{"data":"16/06/2026","valor":"0.053400"}]
```

**SGS 226 — TR (com `dataFim`):**
```json
[{"data":"16/06/2026","dataFim":"16/07/2026","valor":"0.1720"}]
```

**SGS 195 — Poupanca (com `dataFim`):**
```json
[{"data":"16/06/2026","dataFim":"16/07/2026","valor":"0.6729"}]
```

**SGS 433 — IPCA mensal** (janela com `dataInicial`/`dataFinal`):
```json
[{"data":"01/01/2026","valor":"0.42"},{"data":"01/02/2026","valor":"0.51"},{"data":"01/05/2026","valor":"0.58"}]
```

**brapi `/api/quote/PETR4`** (free; campos de analista vem `null`):
```json
{
  "results": [{
    "symbol": "PETR4",
    "longName": "Petroleo Brasileiro SA Pfd",
    "currency": "BRL",
    "regularMarketPrice": 38.54,
    "regularMarketChange": -0.52,
    "regularMarketChangePercent": -1.33,
    "regularMarketDayHigh": 38.78,
    "regularMarketDayLow": 38.2,
    "marketCap": 532981244102,
    "fiftyTwoWeekLow": 29.31,
    "fiftyTwoWeekHigh": 50.69,
    "priceEarnings": 4.617,
    "earningsPerShare": 8.347,
    "logourl": "https://icons.brapi.dev/icons/PETR4.svg"
  }],
  "requestedAt": "2026-06-17T12:21:14.095Z",
  "took": 2
}
```

**brapi `?modules=financialData` (free — note os `null`):**
```json
{"results":[{"symbol":"PETR4","financialData":{
  "recommendationKey": null,
  "recommendationMean": null,
  "targetMeanPrice": null,
  "numberOfAnalystOpinions": null
}}]}
```

**BrasilAPI `/feriados/v1/2026`:**
```json
[
  {"date":"2026-01-01","name":"Confraternização mundial","type":"national"},
  {"date":"2026-02-17","name":"Carnaval","type":"national"},
  {"date":"2026-04-03","name":"Sexta-feira Santa","type":"national"}
]
```

**BrasilAPI `/cnpj/v1/{cnpj}` (recorte):**
```json
{
  "razao_social": "BANCO DO BRASIL SA",
  "nome_fantasia": "",
  "situacao_cadastral": "ATIVA",
  "cnae_fiscal": 6422100,
  "cnae_fiscal_descricao": "Bancos múltiplos, com carteira comercial",
  "uf": "DF",
  "capital_social": 90000000000,
  "qsa": [{"nome_socio": "...", "qualificacao_socio": "..."}],
  "regime_tributario": [{"ano": 2025, "forma_de_tributacao": "LUCRO REAL"}],
  "opcao_pelo_mei": null
}
```

**OpenCNPJ `/{cnpj}` (recorte — schema PLANO + `QSA`):**
```json
{
  "cnpj": "11222333000181",
  "razao_social": "...",
  "tipo_logradouro": "AVENIDA",
  "logradouro": "...", "numero": "100", "bairro": "...",
  "cep": "70000000", "uf": "DF", "municipio": "BRASILIA",
  "cnaes": [{"codigo": "6422100", "descricao": "...", "is_principal": true}],
  "QSA": [{"nome_socio": "...", "qualificacao_socio": "...", "faixa_etaria": "..."}]
}
```

**AwesomeAPI `/json/last/USD-BRL`:**
```json
{"USDBRL":{"code":"USD","codein":"BRL","name":"Dólar Americano/Real Brasileiro",
  "high":"5.1306","low":"5.0655","bid":"5.10883","ask":"5.12096",
  "pctChange":"0.13185","timestamp":"1781699436","create_date":"2026-06-17 09:30:36"}}
```

**Tesouro CKAN — CSV** (NAO ha JSON; `;` separador, decimal `,`, datas `dd/mm/aaaa`, titulos por extenso):
```
Tipo Titulo;Data Vencimento;Data Base;Taxa Compra Manha;Taxa Venda Manha;PU Compra Manha;PU Venda Manha;PU Base Manha
Tesouro Selic;01/03/2031;17/06/2026;0,0500;0,1000;14820,12;14815,33;14817,72
Tesouro IPCA+;15/05/2035;17/06/2026;6,8400;6,9000;3210,55;3205,11;3207,80
Tesouro Prefixado;01/01/2029;17/06/2026;13,8500;13,9500;780,21;778,90;779,55
```

---

### 8. Checklist de implementacao (resumo acionavel)

1. Criar `lib/src/constants/series_bcb.dart` e `api_endpoints.dart` com os codigos/URLs acima.
2. Implementar `DioFactory` + 4 interceptors; expor um `Dio` por API via `@riverpod`.
3. Implementar `Result<T>` / `Failure` sealed e o mapper `DioException -> Failure` (status 429 -> `RateLimitFailure` com `Retry-After`).
4. DTOs freezed com `valor: String` (SGS) e mappers com `parseValorSgs` (virgula/ponto) + `parseDataSgs` (`dd/MM/yyyy`).
5. `DailyCacheService` sobre o store `cache_indicadores` do sembast, chave por `yyyy-MM-dd` em UTC-3.
6. Repository orquestra **boot batch** (`SeriesBcb.boot`, concorrencia 5) + feriados + cotacoes da carteira; acoes/Tesouro/CNPJ sob demanda com cache proprio.
7. Fallback offline retornando snapshot `stale: true`; UI mostra selo de data + retry.
8. `comBackoff` em torno de toda chamada brapi e BrasilAPI/cnpj.
9. Cadeia CNPJ BrasilAPI -> OpenCNPJ -> ReceitaWS, normalizando para `EmpresaDto`; CNPJ so-digitos antes da chamada.
10. Tesouro: baixar CSV 1x/dia, cachear, filtrar pela `Data Base` mais recente; nunca `datastore_search`.
11. `cache_indicadores` **fica fora** do export (dado derivado).
12. Testes (mocktail + `ProviderContainer`): parsing SGS (String/`dataFim`/HTML de erro), logica de cache diario (hit/miss/stale), backoff 429, cadeia de fallback CNPJ.

---

## Persistencia Local NoSQL/JSON & Import/Export

Esta secao especifica, sem ambiguidade, como o **Investa BR** persiste dados localmente e como exporta/importa o backup completo do usuario em JSON unico. O leitor (Opus 4.8) deve conseguir implementar a partir daqui: dependencias, arquivos, classes, schema, migracao, transacoes e testes.

### 1. Banco local escolhido + justificativa

**Decisao: `sembast` (`^3.8.9`) com `databaseFactoryIo`.** Camada principal e UNICA de storage de documentos do usuario e de cache. Nao adicionar Hive, Isar, Drift ou `shared_preferences`.

Por que sembast (e nao os outros), dado o requisito explicito "NoSQL em JSON" + "exportar/importar tudo como JSON":

| Criterio | **sembast** (escolhido) | Hive CE | Isar / isar_community | Drift |
|---|---|---|---|---|
| Paradigma | NoSQL de documentos | NoSQL key-value | NoSQL objetos indexados | SQL relacional |
| Armazena registro como JSON nativo | **Sim** (cada record e `Map<String,Object?>`) | Nao (binario via `TypeAdapter`) | Nao (formato proprio) | Nao (linhas SQL) |
| Export = dump trivial | **Sim** (`find()` -> lista de Maps) | Nao (precisa `toJson` paralelo aos adapters) | Nao | Nao (mapear linhas) |
| 100% Dart, sem plugin nativo | **Sim** | Sim | **Nao** (binarios por plataforma) | Nao (SQLite nativo) |
| Atrito de build desktop (Win/macOS/Linux) | **Nenhum** | Nenhum | Alto | Medio |
| Manutencao (jun/2026) | Ativo (tekartik) | Ativo | Original abandonado; fork comunitario | Ativo |
| Transacoes atomicas | **Sim** (`db.transaction`) | Limitado | Sim | Sim |

Pontos decisivos:
1. **Export/import e trivial**: sembast ja guarda cada documento como JSON. Exportar = `store.find(db)` e despejar `record.value`; importar = `record(id).put(...)`. Nenhuma camada de serializacao binaria paralela (dor do Hive CE com `TypeAdapter` + `toJson/fromJson` duplicados).
2. **Zero plugin nativo** = sem atrito de build em desktop (ponto fraco de Isar/Drift). Como **web esta fora de escopo**, `databaseFactoryIo` cobre 100% das plataformas exigidas (Android, iOS, Windows, macOS, Linux). **Nao** incluir `sembast_web`.
3. **Volume**: o app lida com dezenas a poucos milhares de documentos (posicoes RF, posicoes de acoes, 1 snapshot de cache, 1 config). sembast carrega o DB em memoria — perfeito para esse volume.

> **Limite conhecido e plano de saida**: sembast carrega tudo em memoria; **nao** e adequado para centenas de milhares de registros (ex.: series historicas massivas SGS dia-a-dia, ou o CSV do Tesouro com anos de historico). Se isso surgir, migrar **somente essas series** para Drift/SQLite, mantendo sembast para documentos do usuario. As series longas hoje sao tratadas como cache derivado e nao entram no DB persistente do usuario.

### 2. Dependencias (pubspec.yaml)

```yaml
dependencies:
  sembast: ^3.8.9          # banco NoSQL/JSON 100% Dart (databaseFactoryIo)
  path_provider: ^2.1.0    # getApplicationDocumentsDirectory()
  path: ^1.9.0             # p.join de caminhos
  file_picker: ^11.0.0     # abrir arquivo .json no import
  share_plus: ^10.0.0      # compartilhar/salvar arquivo .json no export
  uuid: ^4.0.0             # IDs estaveis (UUID v4) dos documentos
  crypto: ^3.0.0           # checksum SHA-256 do payload
```

> **NAO** adicionar `sembast_web` (web fora de escopo). **NAO** usar `hive`, `isar`, `drift`, `get_it`, `shared_preferences`.

### 3. Arvore de arquivos

```
lib/src/
  common/
    persistence/
      local_db.dart                 # singleton LocalDb: open(), stores, schemaVersion, migracao
      db_factory_provider.dart      # Provider Riverpod expondo Database e LocalDb
  features/
    renda_fixa/data/
      renda_fixa_repository.dart     # CRUD store investimentos_rf
    acoes/data/
      posicoes_acoes_repository.dart # CRUD store posicoes_acoes
    indicadores/data/
      cache_indicadores_repository.dart  # CRUD store cache_indicadores
    configuracoes/data/
      config_repository.dart         # CRUD store configuracoes (tema/seed/locale)
      import_export/
        backup_payload.dart          # modelo freezed do arquivo de backup
        backup_codec.dart            # encode/decode + checksum SHA-256
        payload_migrator.dart        # migratePayload(oldV -> currentV)
        import_export_service.dart   # exportar() / importar() (file_picker + share_plus)
        import_modo.dart             # enum ModoImport { replace, merge }
        backup_validation.dart       # erros tipados de validacao
```

### 4. Inicializacao do banco, stores e `schemaVersion`

Quatro stores tipados como JSON (`Map<String,Object?>`). IDs = string UUID v4. O `cache_indicadores` e `configuracoes` usam **chaves fixas** (documento unico).

```dart
// lib/src/common/persistence/local_db.dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  /// Versao do schema LOCAL (controla onVersionChanged do sembast).
  /// MESMA constante usada no payload de export (campo schemaVersion).
  static const int schemaVersion = 1;

  // Stores tipados (chave String, valor Map<String,Object?> == JSON puro).
  static final investimentosRf =
      stringMapStoreFactory.store('investimentos_rf');
  static final posicoesAcoes = stringMapStoreFactory.store('posicoes_acoes');
  static final cacheIndicadores =
      stringMapStoreFactory.store('cache_indicadores');
  static final configuracoes = stringMapStoreFactory.store('configuracoes');

  // Chaves fixas dos documentos singleton.
  static const String configKey = 'app';
  static const String cacheKey = 'indicadores_dia';

  late final Database db;
  bool _opened = false;

  Future<Database> open({DatabaseFactory? factory, String? overridePath}) async {
    if (_opened) return db;
    final dbFactory = factory ?? databaseFactoryIo;
    final path = overridePath ??
        p.join((await getApplicationDocumentsDirectory()).path,
            'investa_br.db');

    db = await dbFactory.openDatabase(
      path,
      version: schemaVersion,
      onVersionChanged: _onVersionChanged,
    );
    _opened = true;
    return db;
  }

  Future<void> _onVersionChanged(Database db, int oldV, int newV) async {
    // Migracoes INCREMENTAIS do banco em disco (idempotentes).
    if (oldV < 1) {
      // v0 -> v1: garante documento de configuracao com defaults.
      await configuracoes.record(configKey).put(db, {
        'temaMode': 'system',     // system | light | dark
        'seedColor': 0xFF1565C0,  // int ARGB
        'useDynamic': true,       // Material You quando disponivel
        'locale': 'pt_BR',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    // if (oldV < 2) { /* ex.: renomear campo, popular novo default */ }
  }
}
```

Exposicao via Riverpod (DI = proprio Riverpod; sem get_it):

```dart
// lib/src/common/persistence/db_factory_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';
import 'local_db.dart';
part 'db_factory_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Database> database(Ref ref) async => LocalDb.instance.open();
```

> Em `main()`, chamar `await LocalDb.instance.open()` antes de `runApp`, ou inicializar via `overrideWith` em testes (ver secao 10). Em testes usar `databaseFactoryMemory` + `overridePath: 'test.db'`.

### 5. Modelagem dos documentos (stores) — todos JSON puro

Convencao de campos comuns em **todo** documento de usuario: `id` (UUID v4), `createdAt`, `updatedAt` (ISO 8601 com offset `-03:00`, fuso America/Sao_Paulo). `updatedAt` e usado no MERGE (last-write-wins). Datas de negocio (`dataInicio`, `dataFim`, `dataCompra`) sao `yyyy-MM-dd` (string), facilitando `Filter` por comparacao lexicografica.

#### 5.1 `investimentos_rf` (renda fixa) — key = UUID

```json
{
  "id": "8f3c1d2e-...-uuid",
  "classe": "CDB",
  "apelido": "CDB Banco X 2027",
  "emissorCnpj": "00000000000191",
  "emissorRazaoSocial": "BANCO X S.A.",
  "dataInicio": "2026-01-10",
  "dataFim": "2027-01-10",
  "valorInicial": 10000.00,
  "tipoRendimento": "PERCENTUAL_CDI",
  "indexador": "CDI",
  "valorContratado": 1.10,
  "baseDias": 252,
  "capitalizacao": "COMPOSTA",
  "isentoIr": false,
  "observacoes": "",
  "createdAt": "2026-06-17T09:00:00-03:00",
  "updatedAt": "2026-06-17T09:00:00-03:00"
}
```

Dominios (alinhados aos enums do dominio / unions freezed):
- `classe`: `CDB | LCI | LCA | CRI | CRA | DEBENTURE | DEBENTURE_INCENTIVADA | TESOURO_SELIC | TESOURO_PRE | TESOURO_IPCA | POUPANCA | LC | LF`
- `tipoRendimento`: `PREFIXADO | PERCENTUAL_CDI | PERCENTUAL_SELIC | IPCA_MAIS | IGPM_MAIS | PERCENTUAL_PURO`
- `indexador`: `CDI | SELIC | IPCA | IGPM | null`
- `valorContratado`: numero unico interpretado conforme `tipoRendimento` (`0.13` => 13% a.a. prefixado; `1.10` => 110% do CDI; `0.06` => IPCA+6%).
- `baseDias`: `252 | 360 | 365`; `capitalizacao`: `COMPOSTA | SIMPLES`.
- `isentoIr`: **persistido** (deriva da classe pela regra tributaria datada, mas gravado para auditoria/offline).

#### 5.2 `posicoes_acoes` — key = UUID

```json
{
  "id": "a1b2c3d4-...-uuid",
  "ticker": "PETR4",
  "quantidade": 100,
  "precoMedio": 38.42,
  "dataCompra": "2026-05-02",
  "corretora": "XP",
  "createdAt": "2026-06-17T09:00:00-03:00",
  "updatedAt": "2026-06-17T09:00:00-03:00"
}
```

#### 5.3 `cache_indicadores` — key fixa `indicadores_dia` (NAO exportado)

```json
{
  "dataUltimaAtualizacao": "2026-06-17",
  "fetchedAt": "2026-06-17T08:55:10-03:00",
  "ttlHoras": 12,
  "stale": false,
  "fonte": "bcb_sgs",
  "indicadores": {
    "selicMeta": "14.50", "selicDiaria": "0.053400", "cdiDiario": "0.053400",
    "ipcaMensal": "0.58", "igpmMensal": "0.84",
    "tr": {"valor": "0.1720", "dataFim": "2026-07-16"},
    "poupanca": {"valor": "0.6729", "dataFim": "2026-07-16"}
  },
  "feriadosAno": ["2026-01-01", "2026-02-17", "..."],
  "cotacoes": {"PETR4": 38.54, "VALE3": 61.20}
}
```

> Valores do SGS sao gravados como **string** (conforme retorno da API; parse so no momento de calculo). Documento de cache e **derivado** e por isso **fica fora** do export (secao 7).

#### 5.4 `configuracoes` — key fixa `app`

```json
{
  "temaMode": "system",
  "seedColor": 4283063616,
  "useDynamic": true,
  "locale": "pt_BR",
  "moeda": "BRL",
  "brapiToken": null,
  "updatedAt": "2026-06-17T09:00:00-03:00"
}
```

> `seedColor` e `int` ARGB. `brapiToken` opcional (token brapi do usuario). Tema, seed e `useDynamic` consumidos pelo `ThemeController` (Riverpod) acima do `MaterialApp`.

#### 5.5 Repositorio de exemplo (CRUD + consulta NoSQL)

```dart
// lib/src/features/renda_fixa/data/renda_fixa_repository.dart
class RendaFixaRepository {
  RendaFixaRepository(this._db);
  final Database _db;
  final _store = LocalDb.investimentosRf;
  final _uuid = const Uuid();

  Future<String> upsert(Map<String, Object?> doc) async {
    final id = (doc['id'] as String?) ?? _uuid.v4();
    final now = _nowSp();
    doc['id'] = id;
    doc['createdAt'] ??= now;
    doc['updatedAt'] = now;
    await _store.record(id).put(_db, doc, merge: true);
    return id;
  }

  Future<void> delete(String id) => _store.record(id).delete(_db);

  Future<List<Map<String, Object?>>> ativosVigentes(DateTime hoje) async {
    final finder = Finder(
      filter: Filter.greaterThanOrEquals('dataFim', _fmtDate(hoje)),
      sortOrders: [SortOrder('dataFim')],
    );
    final recs = await _store.find(_db, finder: finder);
    return recs.map((r) => r.value).toList();
  }

  String _fmtDate(DateTime d) => d.toIso8601String().substring(0, 10);
  String _nowSp() =>
      DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String();
}
```

### 6. `schemaVersion` e migracao (DUAS dimensoes independentes)

Existem **dois** mecanismos de versionamento que NAO se confundem:

| Dimensao | Onde vive | Quando roda | Funcao |
|---|---|---|---|
| **Banco em disco** | `openDatabase(version, onVersionChanged)` | Ao abrir o app apos subir `schemaVersion` | Evoluir o DB local instalado (renomear campo, popular default) |
| **Payload de import** | campo `schemaVersion` no arquivo + `migratePayload()` | Ao importar um arquivo `.json` | Adaptar um backup antigo (de outra instalacao) ao schema atual |

Ambos usam a **mesma constante** `LocalDb.schemaVersion` como "versao atual", mantendo-os sincronizados.

Regra de versao no banco (`_onVersionChanged`, secao 4): migracoes incrementais, idempotentes, encadeadas por `if (oldV < N)`. Nunca apagar dados do usuario numa migracao de banco.

Migrador de payload (independente):

```dart
// lib/src/features/configuracoes/data/import_export/payload_migrator.dart
typedef Payload = Map<String, Object?>;

/// Migra o bloco "data" do backup de fileVersion -> currentVersion.
/// Encadeia transformacoes 1->2, 2->3, ... ate currentVersion.
Payload migratePayload(Payload data, int fileVersion, int currentVersion) {
  var v = fileVersion;
  var out = Map<String, Object?>.from(data);
  while (v < currentVersion) {
    out = switch (v) {
      // 1 => _migrate1to2(out),  // exemplo futuro: renomear 'taxa'->'valorContratado'
      _ => out,
    };
    v++;
  }
  return out;
}
```

> **Bloqueio de versao mais nova**: se `fileVersion > LocalDb.schemaVersion`, o import e **recusado** (o app nao sabe migrar para frente). Mensagem: "Backup de versao mais nova (X). Atualize o Investa BR." Versoes `<=` atual sao aceitas e migradas.

### 7. Formato do arquivo de backup (exemplo completo)

Arquivo JSON unico. **`cache_indicadores` NAO entra** (derivado). `checksum` = SHA-256 do `data` serializado de forma **canonica** (chaves ordenadas) para ser reproduzivel no import.

```json
{
  "app": "investa_br",
  "schemaVersion": 1,
  "exportedAt": "2026-06-17T10:00:00-03:00",
  "appVersion": "1.0.0",
  "checksum": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
  "data": {
    "investimentos_rf": [
      {
        "id": "8f3c1d2e-1a2b-4c3d-9e8f-0a1b2c3d4e5f",
        "classe": "CDB",
        "apelido": "CDB Banco X 2027",
        "emissorCnpj": "00000000000191",
        "emissorRazaoSocial": "BANCO X S.A.",
        "dataInicio": "2026-01-10",
        "dataFim": "2027-01-10",
        "valorInicial": 10000.0,
        "tipoRendimento": "PERCENTUAL_CDI",
        "indexador": "CDI",
        "valorContratado": 1.1,
        "baseDias": 252,
        "capitalizacao": "COMPOSTA",
        "isentoIr": false,
        "observacoes": "",
        "createdAt": "2026-06-17T09:00:00-03:00",
        "updatedAt": "2026-06-17T09:00:00-03:00"
      },
      {
        "id": "b7e2f4a0-9c8d-4e2f-a1b2-c3d4e5f60718",
        "classe": "LCI",
        "apelido": "LCI Banco Y",
        "emissorCnpj": "11111111000111",
        "dataInicio": "2026-03-01",
        "dataFim": "2027-09-01",
        "valorInicial": 5000.0,
        "tipoRendimento": "PERCENTUAL_CDI",
        "indexador": "CDI",
        "valorContratado": 0.95,
        "baseDias": 252,
        "capitalizacao": "COMPOSTA",
        "isentoIr": true,
        "observacoes": "",
        "createdAt": "2026-06-17T09:05:00-03:00",
        "updatedAt": "2026-06-17T09:05:00-03:00"
      }
    ],
    "posicoes_acoes": [
      {
        "id": "a1b2c3d4-5e6f-4071-8293-a4b5c6d7e8f9",
        "ticker": "PETR4",
        "quantidade": 100,
        "precoMedio": 38.42,
        "dataCompra": "2026-05-02",
        "corretora": "XP",
        "createdAt": "2026-06-17T09:00:00-03:00",
        "updatedAt": "2026-06-17T09:00:00-03:00"
      }
    ],
    "configuracoes": {
      "app": {
        "temaMode": "dark",
        "seedColor": 4283063616,
        "useDynamic": false,
        "locale": "pt_BR",
        "moeda": "BRL",
        "brapiToken": null,
        "updatedAt": "2026-06-17T09:00:00-03:00"
      }
    }
  }
}
```

Cabecalho (campos de topo):

| Campo | Tipo | Obrigatorio | Funcao |
|---|---|---|---|
| `app` | string | sim | Identidade do arquivo; deve ser `"investa_br"`. Senao -> rejeita |
| `schemaVersion` | int | sim | Versao do payload; `> atual` -> rejeita; `<= atual` -> migra |
| `exportedAt` | string ISO 8601 | sim | Data/hora do export (informativo) |
| `appVersion` | string | sim | Versao do app que exportou (informativo/diagnostico) |
| `checksum` | string `sha256:<hex>` | sim | Integridade do bloco `data`; divergencia -> rejeita |
| `data` | objeto | sim | As 3 colecoes do usuario |

### 8. Codec + checksum (serializacao canonica)

```dart
// lib/src/features/configuracoes/data/import_export/backup_codec.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Serializa de forma DETERMINISTICA (chaves ordenadas recursivamente),
/// para que o checksum seja reproduzivel no export e no import.
String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonicalize(value[k])};
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}

String sha256Of(Object? data) =>
    sha256.convert(utf8.encode(canonicalJson(data))).toString();

String buildChecksum(Map<String, Object?> data) => 'sha256:${sha256Of(data)}';

bool verifyChecksum(Map<String, Object?> data, String checksum) {
  final expected = checksum.split(':').last;
  return sha256Of(data) == expected;
}
```

> O checksum cobre **apenas** `data`. Assim, alterar `exportedAt`/`appVersion` no cabecalho nao invalida o arquivo, mas qualquer adulteracao nos dados do usuario e detectada.

### 9. Fluxo de EXPORT (file_picker / share_plus)

Sequencia:

```
[Ajustes > Dados > Exportar]
      |
      v
1. Ler as 3 stores do usuario (find) -> Maps
2. Montar bloco "data" (investimentos_rf, posicoes_acoes, configuracoes.app)
3. checksum = SHA-256(data canonico)
4. Montar payload com cabecalho (app/schemaVersion/exportedAt/appVersion/checksum)
5. Escrever arquivo temporario investa_br_backup_<yyyyMMdd_HHmmss>.json (indentado)
6. share_plus -> Share.shareXFiles([XFile(path)])  (usuario escolhe destino: Drive, e-mail, Arquivos, etc.)
```

```dart
// import_export_service.dart  (trecho de export)
Future<void> exportar() async {
  final inv = await LocalDb.investimentosRf.find(_db);
  final acoes = await LocalDb.posicoesAcoes.find(_db);
  final cfg = await LocalDb.configuracoes.record(LocalDb.configKey).get(_db);

  final data = <String, Object?>{
    'investimentos_rf': inv.map((r) => r.value).toList(),
    'posicoes_acoes': acoes.map((r) => r.value).toList(),
    'configuracoes': {'app': cfg},
    // cache_indicadores: intencionalmente OMITIDO (derivado).
  };

  final payload = <String, Object?>{
    'app': 'investa_br',
    'schemaVersion': LocalDb.schemaVersion,
    'exportedAt': _nowSpIso(),
    'appVersion': await _appVersion(),
    'checksum': buildChecksum(data),
    'data': data,
  };

  final dir = await getTemporaryDirectory();
  final stamp = DateFormat('yyyyMMdd_HHmmss', 'pt_BR').format(DateTime.now());
  final file = File(p.join(dir.path, 'investa_br_backup_$stamp.json'));
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    subject: 'Backup Investa BR',
    text: 'Backup do Investa BR em $stamp',
  );
}
```

> **Desktop**: `share_plus` em Windows/macOS/Linux abre dialogo de salvar/compartilhar nativo. Caso uma plataforma nao suporte share de arquivo, fallback: `FilePicker.platform.saveFile(...)` para escolher o caminho e gravar diretamente. Testar export em todas as plataformas desktop (Patrol/integration_test).

### 10. Fluxo de IMPORT (validacao, REPLACE vs MERGE, integridade)

Pipeline com gates de validacao **antes** de qualquer escrita, e aplicacao em **transacao atomica**:

```
[Ajustes > Dados > Importar]
      |
      v
1. file_picker -> seleciona .json
2. Ler conteudo + jsonDecode
3. GATE identidade:   app == "investa_br"            -> senao FALHA "nao e backup do Investa BR"
4. GATE versao:       schemaVersion <= atual          -> senao FALHA "versao mais nova"
5. GATE integridade:  verifyChecksum(data)            -> senao FALHA "backup corrompido"
6. GATE estrutura:    data tem as listas/objetos esperados, tipos validos por documento
7. migratePayload(data, fileVersion, atual)
8. Escolha do usuario: REPLACE (default) ou MERGE
9. db.transaction { aplicar } -> ATOMICO (tudo ou nada)
10. Invalidar providers Riverpod (carteira/patrimonio/tema recarregam)
```

```dart
// import_modo.dart
enum ModoImport { replace, merge }

// import_export_service.dart (trecho de import)
Future<ImportResultado> importar({ModoImport modo = ModoImport.replace}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom, allowedExtensions: ['json'],
  );
  if (picked == null) return ImportResultado.cancelado();

  final content = await File(picked.files.single.path!).readAsString();
  final Map<String, Object?> root;
  try {
    root = jsonDecode(content) as Map<String, Object?>;
  } catch (_) {
    throw const BackupInvalido('Arquivo JSON invalido.');
  }

  // GATE 1: identidade
  if (root['app'] != 'investa_br') {
    throw const BackupInvalido('Arquivo nao e um backup do Investa BR.');
  }
  // GATE 2: versao
  final fileVersion = (root['schemaVersion'] as num?)?.toInt();
  if (fileVersion == null) throw const BackupInvalido('schemaVersion ausente.');
  if (fileVersion > LocalDb.schemaVersion) {
    throw BackupVersaoMaisNova(fileVersion, LocalDb.schemaVersion);
  }
  final data = root['data'] as Map<String, Object?>?;
  if (data == null) throw const BackupInvalido('Bloco "data" ausente.');

  // GATE 3: integridade (checksum obrigatorio)
  final checksum = root['checksum'];
  if (checksum is! String || !verifyChecksum(data, checksum)) {
    throw const BackupCorrompido('Checksum nao confere; backup corrompido.');
  }

  // GATE 4: estrutura/tipos por documento
  validarEstrutura(data); // lanca BackupInvalido em campo obrigatorio ausente/tipo errado

  // Migracao do payload
  final migrated = migratePayload(data, fileVersion, LocalDb.schemaVersion);
  final invList = (migrated['investimentos_rf'] as List? ?? const []);
  final acoesList = (migrated['posicoes_acoes'] as List? ?? const []);
  final cfg = (migrated['configuracoes'] as Map?)?['app'];

  var inseridos = 0, atualizados = 0, ignorados = 0;

  // Aplicacao ATOMICA
  await _db.transaction((txn) async {
    if (modo == ModoImport.replace) {
      await LocalDb.investimentosRf.delete(txn);
      await LocalDb.posicoesAcoes.delete(txn);
      // configuracoes: sempre sobrescreve no replace (se vier no arquivo).
    }

    for (final raw in invList) {
      final r = await _aplicarDoc(
          txn, LocalDb.investimentosRf, raw as Map, modo);
      r == _Op.insert ? inseridos++ : r == _Op.update ? atualizados++ : ignorados++;
    }
    for (final raw in acoesList) {
      final r = await _aplicarDoc(
          txn, LocalDb.posicoesAcoes, raw as Map, modo);
      r == _Op.insert ? inseridos++ : r == _Op.update ? atualizados++ : ignorados++;
    }
    if (cfg != null) {
      await LocalDb.configuracoes.record(LocalDb.configKey)
          .put(txn, Map<String, Object?>.from(cfg as Map));
    }
  });

  return ImportResultado.ok(
      modo: modo, inseridos: inseridos, atualizados: atualizados, ignorados: ignorados);
}

enum _Op { insert, update, skip }

/// MERGE por id com last-write-wins via updatedAt.
Future<_Op> _aplicarDoc(
  DatabaseClient txn,
  StoreRef<String, Map<String, Object?>> store,
  Map raw,
  ModoImport modo,
) async {
  final doc = Map<String, Object?>.from(raw);
  final id = doc['id'] as String?;
  if (id == null || id.isEmpty) throw const BackupInvalido('Documento sem id.');

  if (modo == ModoImport.replace) {
    await store.record(id).put(txn, doc); // store ja foi limpa
    return _Op.insert;
  }

  // MERGE: comparar updatedAt
  final atual = await store.record(id).get(txn);
  if (atual == null) {
    await store.record(id).put(txn, doc);
    return _Op.insert;
  }
  final atualU = DateTime.tryParse(atual['updatedAt'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final novoU = DateTime.tryParse(doc['updatedAt'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  if (novoU.isAfter(atualU)) {
    await store.record(id).put(txn, doc); // arquivo mais novo vence
    return _Op.update;
  }
  return _Op.skip; // registro local e igual ou mais novo: preserva
}
```

Diferenca entre os dois modos:

| | **REPLACE** (default, recomendado) | **MERGE** |
|---|---|---|
| Pre-acao | Limpa `investimentos_rf` e `posicoes_acoes` | Nao limpa nada |
| Por documento | `put` (estado final == arquivo) | `put` por `id` so se `updatedAt` do arquivo for mais novo |
| Resultado | Carteira final identica ao backup | Uniao local + arquivo, conflitos por last-write-wins |
| Risco | Perde dados locais nao presentes no arquivo | Pode preservar/duplicar conforme `id` |
| Quando usar | Restaurar dispositivo / migrar | Mesclar dois dispositivos |

> **Por que REPLACE e o default**: e o comportamento previsivel ("restaurar backup"). MERGE so e seguro porque os `id` sao UUID estaveis e usamos `updatedAt` como desempate. A UI deve **avisar** antes do REPLACE: "Isso substitui sua carteira atual. Deseja fazer um export antes?" — e oferecer botao de export rapido.

Erros tipados (Result/sealed na fronteira; UI faz pattern match e mostra mensagem pt-BR):

```dart
// backup_validation.dart
sealed class BackupError implements Exception { const BackupError(this.mensagem); final String mensagem; }
class BackupInvalido extends BackupError { const BackupInvalido(super.m); }
class BackupCorrompido extends BackupError { const BackupCorrompido(super.m); }
class BackupVersaoMaisNova extends BackupError {
  BackupVersaoMaisNova(this.fileV, this.appV)
      : super('Backup de versao mais nova ($fileV). Atualize o Investa BR (versao $appV).');
  final int fileV; final int appV;
}
```

### 11. Wireframe — tela Ajustes > Dados

```
+----------------------------------------------------------+
|  Ajustes > Dados                                          |
+----------------------------------------------------------+
|  Backup                                                   |
|  Exporte ou restaure toda a sua carteira em um arquivo    |
|  JdSON (renda fixa, acoes e preferencias).                |
|                                                           |
|   [  Exportar backup (.json)        ]  share_plus         |
|   [  Importar backup (.json)        ]  file_picker        |
|                                                           |
|  Modo de importacao:                                      |
|   ( • Substituir )  ( o Mesclar )                         |
|   Substituir apaga a carteira atual e usa o arquivo.      |
|   Mesclar combina por id (mantem o registro mais recente).|
|                                                           |
|  Ultimo export: 17/06/2026 10:00                          |
+----------------------------------------------------------+
|  [i] O arquivo de backup NAO e criptografado e contem     |
|      seus dados financeiros em texto. Guarde com cuidado. |
+----------------------------------------------------------+
```

### 12. Riscos e mitigacoes

- **Backup em texto-claro**: dados financeiros legiveis no `.json`. Avisar na UI (wireframe acima). Se surgir requisito de privacidade, sembast suporta `codec` de criptografia do DB e o arquivo pode ser cifrado com senha do usuario (fora do MVP).
- **MERGE com `id` colidindo entre dispositivos**: mitigado por UUID v4 estavel + last-write-wins por `updatedAt`. REPLACE permanece o default.
- **DB em memoria do sembast**: adequado ao volume atual; series historicas massivas NAO devem ir para as stores do usuario — sao cache derivado (e fora do export). Plano de saida documentado (Drift para series).
- **Import de arquivo malicioso/corrompido**: 4 gates (identidade, versao, checksum, estrutura) antes de qualquer escrita; aplicacao em transacao atomica (rollback automatico em excecao dentro de `db.transaction`).
- **Cache no export**: `cache_indicadores` propositalmente excluido; apos import o cache e revalidado no proximo boot (stale-while-revalidate), evitando exportar dado vencido/incoerente.

### 13. Cobertura de testes (obrigatoria)

Usar `flutter_test` + `mocktail`; banco em testes via `databaseFactoryMemory` (sem disco). Injetar com `LocalDb.instance.open(factory: databaseFactoryMemory, overridePath: 'test.db')` ou `overrideWith` no `databaseProvider`.

| Caso | Verifica |
|---|---|
| Export -> Import round-trip (REPLACE) | Estado final == backup; checksum confere |
| Import REPLACE limpa locais | Registros locais ausentes no arquivo desaparecem |
| Import MERGE last-write-wins | `updatedAt` mais novo do arquivo vence; mais antigo e ignorado (`skip`) |
| Checksum adulterado | Lanca `BackupCorrompido`, **nenhuma** escrita ocorre |
| `schemaVersion` maior que o app | Lanca `BackupVersaoMaisNova`, **nenhuma** escrita |
| `app` diferente de `investa_br` | Lanca `BackupInvalido` |
| Transacao com doc invalido no meio | Rollback total (nada gravado) |
| `migratePayload` (quando houver v2) | Backup antigo migra para schema atual |
| `cache_indicadores` no DB | Nao aparece no arquivo exportado |
| Desktop (Patrol/integration_test) | file_picker abre e share_plus salva em Windows/macOS/Linux |

---

## Gerência de Estado & Navegação

Esta seção define, sem ambiguidade, **como o estado flui no Investa BR** (Riverpod 3 com code-gen), **como a navegação é estruturada** (go_router 17 tipado, exposto via provider, com shell responsivo Material 3) e **como os estados de loading/erro/vazio** são modelados e renderizados. Tudo aqui é vinculante para a implementação.

Stack relevante a esta seção:

| Pacote | Versão | Papel |
|---|---|---|
| `flutter_riverpod` | ^3.3.0 | Estado + container único de DI |
| `riverpod_annotation` | ^4.0.0 | Anotação `@riverpod` |
| `riverpod_generator` (dev) | ^4.0.0 | Code-gen dos providers |
| `go_router` | ^17.3.0 | Roteamento declarativo |
| `go_router_builder` (dev) | ^3.x | Rotas tipadas (`TypedGoRoute`) |
| `freezed` / `freezed_annotation` | ^3.2.0 / ^3.0.0 | Imutabilidade + unions sealed |

Princípios inegociáveis:

1. **Riverpod é o ÚNICO container de DI.** Nada de `get_it`/`injectable`. Toda dependência (Dio, sembast `Database`, repositórios, services) é exposta como provider e sobrescrita em testes via `overrideWith`.
2. **Code-gen sempre.** Todo provider/notifier usa `@riverpod`; nada de `StateNotifierProvider`/`ChangeNotifierProvider` manual (legado do Riverpod 2). Comando: `dart run build_runner watch -d`. Commitar `*.g.dart`.
3. **Fluxo unidirecional estrito.** `data layer → domain (Result<T>) → application/notifier (AsyncValue) → UI (pattern match) → intenção do usuário → método do notifier → data layer`. A UI **nunca** muta estado diretamente nem chama repositório direto; sempre passa pelo notifier.
4. **`Result<T>` nas camadas data/domain; `AsyncValue<T>` na fronteira Riverpod.** O notifier converte `Result` em `AsyncValue` (ou usa `AsyncValue.guard`). A UI só conhece `AsyncValue`.

---

### 1. Padrão de providers / controllers

#### 1.1 Taxonomia de providers (qual usar quando)

| Tipo de provider | Anotação | Quando usar no Investa BR | Exemplos |
|---|---|---|---|
| **Provider síncrono** | `@riverpod` retornando valor não-`Future` | DI de objetos sem estado mutável: Dio, `Database` sembast, repositórios, services, formatadores | `dioProvider`, `databaseProvider`, `rendaFixaRepositoryProvider` |
| **FutureProvider** | `@riverpod` retornando `Future<T>` (função, sem classe) | Leitura assíncrona derivada/read-only, sem mutações: detalhe de ação por ticker, CNPJ por emissor | `acaoDetalheProvider(ticker)`, `cnpjProvider(cnpj)` |
| **AsyncNotifier** | `@riverpod` em **classe** com `build()` async | Estado assíncrono **com mutações** (CRUD, refresh manual): lista de renda fixa, dashboard de indicadores, carteira | `RendaFixaListController`, `IndicadoresController`, `CarteiraController` |
| **Notifier síncrono** | `@riverpod` em **classe** com `build()` sync | Estado de UI puro/local, sem I/O: filtros do comparador, formulário, índice de aba | `ComparadorFormController`, `ThemeController` (parte sync) |

Regra de bolso: **se há mutação, use uma classe Notifier/AsyncNotifier; se é só leitura derivada, use a função `@riverpod`.**

#### 1.2 Convenção de nomes e arquivos

- Providers de **DI/infra**: sufixo `Provider`, função minúscula → `dioProvider`, `databaseProvider`.
- **Controllers** (classes com mutação): sufixo `Controller` → `RendaFixaListController`. O provider gerado se chama `rendaFixaListControllerProvider`.
- Um arquivo `*.dart` por controller dentro de `presentation/controllers/` (ou `application/` quando o service é compartilhado entre features).
- `part 'arquivo.g.dart';` sempre presente.

#### 1.3 Camadas de DI (grafo de providers)

O grafo segue a Clean Architecture pragmática já decidida. Providers de camadas internas **não** dependem de providers de camadas externas.

```
infra (singletons)            data                      application/presentation
─────────────────────         ─────────────────         ─────────────────────────
databaseProvider  ───────►  rendaFixaRepository  ──►  RendaFixaListController
dioProvider (família       (sembast datasource)        (AsyncNotifier)
  por API base)   ───────►  bcbSgsRepository    ──►   IndicadoresController
brapiTokenProvider ─────►   brapiRepository     ──►   AcoesController
                            dailyCacheService   ──►   (usado por Indicadores/Carteira)
feriadosRepository ─────►   diasUteisService    ──►   ComparadorController / projeções
```

#### 1.4 Providers de infraestrutura (DI) — código

```dart
// lib/src/common/providers/infra_providers.dart
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

part 'infra_providers.g.dart';

/// Banco sembast aberto uma única vez. keepAlive: vive o app inteiro.
@Riverpod(keepAlive: true)
Future<Database> database(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'investa_br.db');
  final db = await databaseFactoryIo.openDatabase(
    path,
    version: 1,
    onVersionChanged: (db, oldV, newV) async {
      // migrações incrementais (ver seção de Persistência)
    },
  );
  ref.onDispose(db.close); // fecha ao descartar o container (testes)
  return db;
}

/// Identifica cada API para selecionar a base URL no interceptor.
enum ApiTarget { bcbSgs, brapi, brasilApi, openCnpj, awesomeApi, tesouroCkan }

/// Dio único, com interceptors. base URL é resolvida POR REQUISIÇÃO
/// via options.extra['apiTarget'] (interceptor preenche a baseUrl).
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        // BCB SGS rejeita alguns clientes sem User-Agent.
        'User-Agent': 'InvestaBR/1.0 (+app)',
      },
      responseType: ResponseType.plain, // SGS pode vir HTML em erro; parse manual
    ),
  );
  dio.interceptors.addAll([
    BaseUrlInterceptor(),                       // (a) base URL por ApiTarget
    BrapiTokenInterceptor(ref.watch(brapiTokenProvider)), // (b) token brapi
    if (kDebugMode) LogInterceptor(responseBody: false),  // (c) log em debug
    ErrorNormalizerInterceptor(),               // (d) DioException -> Failure
  ]);
  return dio;
}

/// Token brapi vindo da config runtime (sembast store configuracoes).
@riverpod
String? brapiToken(Ref ref) {
  // lê do ConfigController; null => só 4 tickers de teste liberados
  return ref.watch(configControllerProvider).valueOrNull?.brapiToken;
}
```

#### 1.5 Controller com mutações — padrão AsyncNotifier

Este é o padrão **canônico** para qualquer tela que lê e modifica dados. Use `AsyncValue.guard` para nunca deixar uma exceção escapar e para transicionar automaticamente para `AsyncError`.

```dart
// lib/src/features/renda_fixa/presentation/controllers/renda_fixa_list_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/posicao_renda_fixa.dart';
import '../../domain/renda_fixa_repository.dart';
import '../../../../common/result.dart';

part 'renda_fixa_list_controller.g.dart';

@riverpod
class RendaFixaListController extends _$RendaFixaListController {
  RendaFixaRepository get _repo => ref.read(rendaFixaRepositoryProvider);

  /// build() define o estado INICIAL e é re-executado em invalidate().
  @override
  Future<List<PosicaoRendaFixa>> build() async {
    final result = await _repo.listarTodos();
    // Converte Result<T> (domain) em valor; lança em Failure -> AsyncError.
    return switch (result) {
      Success(:final value) => value,
      Failure(:final error) => throw error,
    };
  }

  /// Mutação: adiciona e re-lê. Padrão optimistic NÃO usado aqui (CRUD local).
  Future<void> adicionar(PosicaoRendaFixa nova) async {
    state = const AsyncLoading<List<PosicaoRendaFixa>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final r = await _repo.upsert(nova);
      if (r case Failure(:final error)) throw error;
      final lista = await _repo.listarTodos();
      return (lista as Success<List<PosicaoRendaFixa>>).value;
    });
  }

  Future<void> remover(String id) async {
    state = const AsyncLoading<List<PosicaoRendaFixa>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.remover(id);
      final lista = await _repo.listarTodos();
      return (lista as Success<List<PosicaoRendaFixa>>).value;
    });
  }

  /// Refresh manual (botão "atualizar"): força nova leitura.
  Future<void> refresh() => ref.refresh(rendaFixaListControllerProvider.future);
}
```

Notas de implementação obrigatórias:

- **`copyWithPrevious(state)`** preserva os dados antigos durante o reload, permitindo à UI mostrar `isRefreshing` sem piscar tela vazia. Use sempre em mutações.
- Mutações **nunca** retornam `T`; retornam `Future<void>` e empurram o resultado para `state`. A UI reage ao `state`.
- Em mutações que podem falhar com feedback ao usuário (snackbar), a UI lê o resultado via `ref.listen` (ver 1.7).

#### 1.6 Provider de leitura derivada com argumento (família) — FutureProvider

Para detalhe de ação ou CNPJ (read-only, parametrizado), use a função `@riverpod`. O argumento vira parte da chave automaticamente (Riverpod 3 unificou `Family`).

```dart
// lib/src/features/acoes/presentation/controllers/acao_detalhe_controller.dart
@riverpod
Future<AcaoDetalhe> acaoDetalhe(Ref ref, String ticker) async {
  final repo = ref.watch(brapiRepositoryProvider);
  final result = await repo.cotacaoComFundamentos(ticker);
  return switch (result) {
    Success(:final value) => value,
    Failure(:final error) => throw error,
  };
}
// Uso: ref.watch(acaoDetalheProvider('PETR4'))
```

`keepAlive` padrão é **auto-dispose** no Riverpod 3 (o provider some quando ninguém o escuta). Para CNPJ (cache de TTL longo) e indicadores, marque `@Riverpod(keepAlive: true)` ou faça o cache na camada data (sembast), o que é a decisão preferida — a camada de cache diário fica fora do ciclo de vida do provider.

#### 1.7 Como a UI consome providers

```dart
class RendaFixaListPage extends ConsumerWidget {
  const RendaFixaListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (a) escuta efeitos colaterais (erros de mutação -> snackbar)
    ref.listen(rendaFixaListControllerProvider, (prev, next) {
      if (next is AsyncError && prev is! AsyncError) {
        ScaffolderMessenger.maybeShow(context, next.error);
      }
    });

    // (b) lê o estado para renderizar
    final async = ref.watch(rendaFixaListControllerProvider);

    return async.when(
      data: (lista) => lista.isEmpty
          ? const EmptyState(/* ... */)
          : RendaFixaListView(itens: lista),
      loading: () => const LoadingState(),
      error: (e, st) => ErrorState(
        erro: e,
        onRetry: () => ref.invalidate(rendaFixaListControllerProvider),
      ),
    );
  }
}
```

Regras de consumo:

- `ref.watch` em `build` para **renderizar** (reativo).
- `ref.read` dentro de callbacks (`onPressed`) para **disparar ações** → `ref.read(controller.notifier).adicionar(...)`.
- `ref.listen` para **efeitos colaterais** (snackbar, navegação imperativa pós-mutação).
- Nunca `ref.read` para renderizar (perde reatividade).

---

### 2. Fluxo de dados unidirecional

O fluxo é **sempre** uma única direção. Eventos de UI sobem como chamadas de método no notifier; estado desce como `AsyncValue` imutável.

```
        ┌──────────────────────────── DADOS DESCEM (estado imutável) ─────────────────────────────┐
        │                                                                                          ▼
┌───────────────┐   ┌────────────────────┐   ┌──────────────────────┐   ┌──────────────────────────┐
│  Data source  │   │     Repository     │   │   Notifier/Controller │   │            UI             │
│ (Dio/sembast) │   │  retorna Result<T> │   │  expõe AsyncValue<T>  │   │  pattern match em         │
│               │──►│  (Success/Failure) │──►│  via AsyncValue.guard │──►│  AsyncValue (.when)       │
└───────────────┘   └────────────────────┘   └──────────────────────┘   └──────────────────────────┘
        ▲                                              ▲                              │
        │                                              │   método do notifier         │ intenção do usuário
        └──────────── EVENTOS SOBEM (chamadas de método, nunca mutação direta) ───────┘ (onPressed -> ref.read(...).metodo())
```

#### 2.1 Contrato entre camadas

| Camada | Entrada | Saída | Tipo de erro |
|---|---|---|---|
| **data** (datasource) | parâmetros primitivos | DTO / lança `DioException` | exceções brutas |
| **data** (repository) | parâmetros de domínio | `Result<T>` (Success/Failure) | `Failure` tipado (mapeado de `DioException`) |
| **application/notifier** | intenção (método) | `AsyncValue<T>` (`state`) | `AsyncError` (via `guard`) |
| **presentation/UI** | `AsyncValue<T>` | widgets | renderiza `ErrorState` |

#### 2.2 `Result<T>` (sealed class do Dart 3) — fronteira data/domain

```dart
// lib/src/common/result.dart
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final AppFailure error;
  final StackTrace? stackTrace;
}

/// Erro de domínio tipado (mapeado de DioException no interceptor/repo).
sealed class AppFailure implements Exception {
  const AppFailure(this.mensagem);
  final String mensagem;
}
final class RedeFailure        extends AppFailure { const RedeFailure(super.m); } // timeout/offline
final class RateLimitFailure   extends AppFailure { const RateLimitFailure(super.m); } // 429
final class ParseFailure       extends AppFailure { const ParseFailure(super.m); }  // HTML/JSON inválido (SGS)
final class NaoEncontradoFailure extends AppFailure { const NaoEncontradoFailure(super.m); } // 404
final class TokenFailure       extends AppFailure { const TokenFailure(super.m); }  // brapi 401 sem token
final class DesconhecidoFailure extends AppFailure { const DesconhecidoFailure(super.m); }
```

Mapeamento `DioException → AppFailure` (no `ErrorNormalizerInterceptor` ou no repositório):

```dart
AppFailure mapDioError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const RedeFailure('Sem conexão. Verifique a internet.');
  }
  final status = e.response?.statusCode;
  return switch (status) {
    429 => const RateLimitFailure('Muitas requisições. Tente novamente em instantes.'),
    401 => const TokenFailure('Token brapi ausente ou inválido.'),
    404 => const NaoEncontradoFailure('Recurso não encontrado.'),
    _   => DesconhecidoFailure('Erro inesperado (${status ?? 'sem status'}).'),
  };
}
```

> **SGS (BCB):** o `valor` vem como **string** (vírgula/ponto) e respostas de erro podem ser **HTML**. O repositório do SGS deve, ao receber `ResponseType.plain`, tentar `jsonDecode`; se falhar (HTML), retornar `Failure(ParseFailure(...))` — nunca lançar para a UI.

#### 2.3 Da intenção ao estado (sequência completa de uma mutação)

```
Usuário toca "Salvar" no formulário
        │
        ▼
onPressed: ref.read(rendaFixaListControllerProvider.notifier).adicionar(posicao)
        │
        ▼
Controller.adicionar():
   state = AsyncLoading().copyWithPrevious(state)   // UI mostra overlay/refresh
   state = await AsyncValue.guard(() async {
       repo.upsert(posicao)   // sembast put (transação)
       repo.listarTodos()     // re-leitura
   })
        │
        ├── sucesso ► state = AsyncData(novaLista) ► UI re-renderiza ► ref.listen navega de volta
        └── falha   ► state = AsyncError(failure)  ► ref.listen mostra snackbar; lista anterior preservada
```

#### 2.4 Derivação e composição (sem duplicar fonte de verdade)

O **patrimônio** e o **dashboard** são **derivados** das fontes primárias (renda fixa + ações + indicadores). Nunca armazene o total; calcule via provider que observa as fontes — assim qualquer mutação propaga automaticamente.

```dart
@riverpod
Future<Patrimonio> patrimonio(Ref ref) async {
  final rf     = await ref.watch(rendaFixaListControllerProvider.future);
  final acoes  = await ref.watch(acoesListControllerProvider.future);
  final indic  = await ref.watch(indicadoresControllerProvider.future);
  // soma valor na curva (RF marcada pela taxa contratada) + ações (última cotação)
  return PatrimonioCalculator.calcular(rf: rf, acoes: acoes, indicadores: indic);
}
```

Como `patrimonio` faz `watch` das três fontes, **adicionar um CDB recalcula o donut e o total da home automaticamente** — fluxo unidirecional puro, sem callbacks cruzados.

---

### 3. Rotas (go_router) e estrutura de navegação responsiva

#### 3.1 GoRouter exposto como provider Riverpod

O `GoRouter` é um provider `keepAlive` para permitir guards e `refreshListenable` reagindo a estado Riverpod (ex.: re-renderizar quando a config de tema/token muda, ou futuros guards de onboarding).

```dart
// lib/src/routing/router.dart
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  return GoRouter(
    initialLocation: const InicioRoute().location,
    debugLogDiagnostics: kDebugMode,
    routes: $appRoutes, // gerado por go_router_builder
    // refreshListenable: ponte Riverpod -> Listenable (reage a mudanças de estado)
    refreshListenable: _RouterRefresh(ref, [
      // adicione providers que devem forçar reavaliação de rotas/guards
    ]),
    errorBuilder: (context, state) => RotaNaoEncontradaPage(uri: state.uri),
  );
}

/// Adapta providers Riverpod para o refreshListenable do go_router.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref, List<ProviderListenable> deps) {
    for (final d in deps) {
      ref.listen(d, (_, __) => notifyListeners());
    }
  }
}
```

`MaterialApp.router` consome o provider:

```dart
class InvestaBrApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final tema = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: tema.light,
      darkTheme: tema.dark,
      themeMode: tema.mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales, // pt-BR, en, es
      locale: ref.watch(localeControllerProvider),         // null = seguir o sistema
    );
  }
}
```

#### 3.2 Rotas tipadas (TypedGoRoute) e árvore de navegação

Usamos `StatefulShellRoute` para o shell de 5 abas (preserva estado/pilha por branch). Cada branch tem seu `navigatorKey`, e o shell renderiza o `RootShell` responsivo.

```dart
// lib/src/routing/routes.dart
part 'routes.g.dart';

// Shell com 5 branches (uma por aba). go_router_builder gera $appRoutes.
@TypedStatefulShellRoute<RootShellRoute>(
  branches: [
    TypedStatefulShellBranch<InicioBranch>(routes: [
      TypedGoRoute<InicioRoute>(path: '/inicio'),
    ]),
    TypedStatefulShellBranch<CarteiraBranch>(routes: [
      TypedGoRoute<CarteiraRoute>(path: '/carteira', routes: [
        TypedGoRoute<RendaFixaFormRoute>(path: 'rf/novo'),
        TypedGoRoute<RendaFixaEditRoute>(path: 'rf/:id'),
        TypedGoRoute<AcaoFormRoute>(path: 'acao/novo'),
      ]),
    ]),
    TypedStatefulShellBranch<ConversorBranch>(routes: [
      TypedGoRoute<ConversorRoute>(path: '/conversor'),
    ]),
    TypedStatefulShellBranch<AcoesBranch>(routes: [
      TypedGoRoute<AcoesBuscaRoute>(path: '/acoes', routes: [
        TypedGoRoute<AcaoDetalheRoute>(path: ':ticker'),
      ]),
    ]),
    TypedStatefulShellBranch<AjustesBranch>(routes: [
      TypedGoRoute<AjustesRoute>(path: '/ajustes'),
    ]),
  ],
)
class RootShellRoute extends StatefulShellRouteData {
  const RootShellRoute();
  @override
  Widget builder(BuildContext c, GoRouterState s, StatefulNavigationShell shell) =>
      RootShell(navigationShell: shell);
}

class InicioRoute extends GoRouteData with _$InicioRoute {
  const InicioRoute();
  @override
  Widget build(BuildContext c, GoRouterState s) => const DashboardPage();
}

class AcaoDetalheRoute extends GoRouteData with _$AcaoDetalheRoute {
  const AcaoDetalheRoute({required this.ticker});
  final String ticker;
  @override
  Widget build(BuildContext c, GoRouterState s) => AcaoDetalhePage(ticker: ticker);
}

class RendaFixaEditRoute extends GoRouteData with _$RendaFixaEditRoute {
  const RendaFixaEditRoute({required this.id});
  final String id;
  @override
  Widget build(BuildContext c, GoRouterState s) => RendaFixaFormPage(id: id);
}
```

Navegação **sempre tipada** (sem strings soltas):

```dart
const AcaoDetalheRoute(ticker: 'PETR4').push(context);  // empilha no branch Ações
const RendaFixaFormRoute().go(context);                  // navega no branch Carteira
const RendaFixaEditRoute(id: posicao.id).push(context);
```

Mapa completo de rotas:

| Branch (aba) | Rota | Path | Tela |
|---|---|---|---|
| Início | `InicioRoute` | `/inicio` | Dashboard (cards + patrimônio + donut) |
| Carteira | `CarteiraRoute` | `/carteira` | Lista de posições (RF + ações) |
| Carteira | `RendaFixaFormRoute` | `/carteira/rf/novo` | Cadastro de renda fixa |
| Carteira | `RendaFixaEditRoute` | `/carteira/rf/:id` | Edição de renda fixa |
| Carteira | `AcaoFormRoute` | `/carteira/acao/novo` | Cadastro de posição em ação |
| Conversor | `ConversorRoute` | `/conversor` | Conversor/Comparador (BarChart) |
| Ações | `AcoesBuscaRoute` | `/acoes` | Busca de ações |
| Ações | `AcaoDetalheRoute` | `/acoes/:ticker` | Detalhe (CandlestickChart) |
| Ajustes | `AjustesRoute` | `/ajustes` | Tema, import/export, token brapi |

#### 3.3 Árvore de arquivos de roteamento e shell

```
lib/src/
  routing/
    router.dart            # goRouterProvider + refresh bridge
    routes.dart            # TypedGoRoute / StatefulShellRoute (+ routes.g.dart)
  common/
    layout/
      root_shell.dart      # NavigationBar / NavigationRail responsivo
      destinations.dart    # lista única de destinos (label, icon, route)
      adaptive_scaffold.dart
```

#### 3.4 RootShell responsivo (3 breakpoints Material 3)

Breakpoints (window size classes Material 3): **compact `< 600dp`** → `NavigationBar`; **medium `600–840dp`** → `NavigationRail` compacto (só ícones); **expanded `>= 840dp`** → `NavigationRail` estendido (ícone + label). O `StatefulNavigationShell` já preserva estado por branch (equivale ao `IndexedStack` exigido).

```dart
// lib/src/common/layout/root_shell.dart
class RootShell extends StatelessWidget {
  const RootShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _bpMedium = 600.0;
  static const _bpExpanded = 840.0;

  void _goBranch(int index) => navigationShell.goBranch(
        index,
        // re-toque na aba ativa volta à raiz do branch
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dests = AppDestinations.all; // fonte única (label, icon, selectedIcon)

    // COMPACT: NavigationBar na base
    if (width < _bpMedium) {
      return Scaffold(
        body: navigationShell,
        floatingActionButton: _fabContextual(context),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          destinations: [
            for (final d in dests)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // MEDIUM/EXPANDED: NavigationRail à esquerda
    final extended = width >= _bpExpanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            leading: _fabContextual(context), // FAB vira leading no rail
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// FAB "+ Investimento" só em Início (0) e Carteira (1).
  Widget? _fabContextual(BuildContext context) {
    final i = navigationShell.currentIndex;
    if (i != 0 && i != 1) return null;
    return FloatingActionButton(
      onPressed: () => const RendaFixaFormRoute().push(context),
      tooltip: 'Novo investimento',
      child: const Icon(Icons.add),
    );
  }
}
```

Wireframe dos dois extremos (compact e expanded):

```
COMPACT (<600dp)                          EXPANDED (>=840dp)
+--------------------------------+        +---------------------------------------------+
|  Investa BR              [...]  |        | 🏠 Início  | Investa BR            🔄 🌙 [...] |
|                                 |        | 📊 Carteira|                                  |
|        (conteúdo da aba)        |        | 🔁 Conversor      (conteúdo da aba)         |
|                                 |        | 🔎 Ações   |                                  |
|                          [ + ]  |        | ⚙️ Ajustes |                          [ + ]   |
+--------------------------------+        | (Rail extended: ícone + label)              |
| 🏠   📊   🔁   🔎   ⚙️          |        +---------------------------------------------+
| Iníc Cart Conv Açõe Ajus        |
+--------------------------------+        MEDIUM (600-840dp): Rail compacto (só ícones,
  NavigationBar (IndexedStack via         label só no destino selecionado)
  StatefulShell preserva estado)
```

Tabela de comportamento por breakpoint:

| Largura | Navegação | `labelType` | FAB | Estado das abas |
|---|---|---|---|---|
| `< 600dp` (compact) | `NavigationBar` (base) | — | `floatingActionButton` | preservado por branch |
| `600–840dp` (medium) | `NavigationRail` compacto | `selected` | `leading` do rail | preservado por branch |
| `>= 840dp` (expanded) | `NavigationRail` estendido | `none` (label inline) | `leading` do rail | preservado por branch |

`AppDestinations.all` é a **fonte única** (DRY) consumida tanto pelo `NavigationBar` quanto pelo `NavigationRail` — evita divergência de ícones/labels entre layouts.

Acessibilidade na navegação: todo destino tem `label` textual (nunca só ícone); o rail compacto mantém `Semantics` via `NavigationRailDestination.label`; alvos de toque respeitam o mínimo de 48dp dos componentes Material 3.

---

### 4. Estados de loading / erro / vazio

Toda tela assíncrona renderiza exatamente um de quatro estados: **loading**, **erro**, **vazio**, **dados**. O `AsyncValue` cobre loading/erro/dados; o estado **vazio** é um caso de `AsyncData` com coleção vazia (decidido pela UI).

#### 4.1 Matriz de estados → widget

| Estado | Origem | Widget padrão | Ação |
|---|---|---|---|
| **Loading (inicial)** | `AsyncLoading` sem dado anterior | `LoadingState` (skeleton/shimmer) | nenhuma |
| **Refreshing** | `AsyncLoading` com `valueOrNull != null` | conteúdo + `LinearProgressIndicator` no topo | nenhuma |
| **Erro (sem dado)** | `AsyncError` sem dado anterior | `ErrorState` (ícone + mensagem + "Tentar novamente") | `invalidate` |
| **Erro (stale)** | `AsyncError` com dado anterior + cache `stale=true` | conteúdo + banner "Dados de {data} (offline)" | `refresh` |
| **Vazio** | `AsyncData` com lista `.isEmpty` | `EmptyState` (ilustração + CTA) | CTA contextual |
| **Dados** | `AsyncData` com conteúdo | view da feature | — |

#### 4.2 Helper de renderização (componente reutilizável)

Para padronizar, todas as telas usam o `AsyncStateView`, que centraliza a árvore de decisão (evita repetir `.when` com tratamento de vazio/stale em cada tela).

```dart
// lib/src/common/widgets/async_state_view.dart
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value,
    required this.onData,
    required this.onRetry,
    this.isEmpty,
    this.emptyBuilder,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) onData;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;        // ex.: (lista) => lista.isEmpty
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    // Stale-while-revalidate: se há dado anterior, mostra-o mesmo em loading/erro.
    final previous = value.valueOrNull;

    if (value.isLoading && previous == null) {
      return const LoadingState();                 // loading inicial
    }
    if (value.hasError && previous == null) {
      return ErrorState(erro: value.error!, onRetry: onRetry); // erro sem dado
    }

    final data = previous as T; // garantido != null aqui
    final vazio = isEmpty?.call(data) ?? false;

    final conteudo = vazio
        ? (emptyBuilder?.call(context) ?? const EmptyState())
        : onData(data);

    // Faixa de "atualizando" sem esconder o conteúdo (refresh / stale)
    return Column(
      children: [
        if (value.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (value.hasError && previous != null)
          StaleBanner(erro: value.error!, onRetry: onRetry),
        Expanded(child: conteudo),
      ],
    );
  }
}
```

Uso por tela:

```dart
final async = ref.watch(rendaFixaListControllerProvider);
return AsyncStateView<List<PosicaoRendaFixa>>(
  value: async,
  isEmpty: (lista) => lista.isEmpty,
  onRetry: () => ref.invalidate(rendaFixaListControllerProvider),
  emptyBuilder: (_) => EmptyState(
    icone: Icons.savings_outlined,
    titulo: 'Nenhum investimento ainda',
    descricao: 'Cadastre seu primeiro CDB, LCI ou Tesouro.',
    acaoLabel: 'Adicionar investimento',
    onAcao: () => const RendaFixaFormRoute().push(context),
  ),
  onData: (lista) => RendaFixaListView(itens: lista),
);
```

#### 4.3 Widgets base de estado

```dart
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext c) => const Center(
        child: Semantics(
          label: 'Carregando',
          child: CircularProgressIndicator(),
        ),
      );
  // Em listas/cards: substituir por skeleton (placeholders cinza) p/ menos jank.
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.erro, required this.onRetry, super.key});
  final Object erro;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext c) {
    final msg = switch (erro) {
      RedeFailure()      => 'Sem conexão. Verifique sua internet.',
      RateLimitFailure() => 'Muitas requisições. Aguarde um instante.',
      TokenFailure()     => 'Configure seu token brapi em Ajustes para ver mais ações.',
      ParseFailure()     => 'Não foi possível ler os dados do servidor.',
      AppFailure(:final mensagem) => mensagem,
      _ => 'Algo deu errado.',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    this.icone = Icons.inbox_outlined,
    this.titulo = 'Nada por aqui',
    this.descricao = '',
    this.acaoLabel,
    this.onAcao,
    super.key,
  });
  final IconData icone;
  final String titulo, descricao;
  final String? acaoLabel;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(c).textTheme.titleMedium),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(descricao, textAlign: TextAlign.center),
            ],
            if (acaoLabel != null && onAcao != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAcao, child: Text(acaoLabel!)),
            ],
          ],
        ),
      );
}
```

#### 4.4 Casos específicos por tela

| Tela | Loading | Vazio | Erro | Stale (offline) |
|---|---|---|---|---|
| **Dashboard** | skeleton dos 4 cards + donut | "Cadastre investimentos para ver seu patrimônio" + CTA | banner por card que falhou (degrada por indicador) | "Atualizado em {data}" + ícone offline (cache diário) |
| **Carteira (RF/ações)** | skeleton de lista | `EmptyState` com CTA "Adicionar" | `ErrorState` com retry | lista do último snapshot + banner |
| **Busca de ações** | spinner sob a busca | "Nenhum resultado para '{termo}'" | 401 → `TokenFailure` (CTA Ajustes); 429 → mensagem de espera | n/a (sob demanda) |
| **Detalhe da ação** | skeleton do candlestick | campos de analista nulos → "Recomendação indisponível no plano gratuito" (degradação graciosa) | `ErrorState` | cache diário próprio |
| **Conversor** | n/a (cálculo local instantâneo) | "Adicione ao menos 2 opções para comparar" | erro só se faltar indicador do SGS → usa último cache | usa indicador em cache marcando data |

Regras de degradação obrigatórias:

- **Dashboard degrada por card:** se o SGS falhar para IPCA mas não para SELIC, mostre SELIC normalmente e um estado de erro **apenas** no card do IPCA. Cada card observa seu próprio sub-estado (ou um `AsyncValue` por indicador), nunca derruba a tela inteira.
- **brapi sem token:** ao buscar ticker fora dos 4 de teste, o `401` vira `TokenFailure`; a UI mostra CTA "Configurar token em Ajustes" (não um erro genérico).
- **Campos de analista nulos (free):** `recommendationKey`/`targetMeanPrice` nulos **não** são erro — renderize "indisponível" e, quando houver fundamentos, exiba sinais próprios calculados localmente (P/L, P/VP, DY, ROE).
- **Offline com cache do dia:** se a rede falha mas existe snapshot, sirva o cache marcando `stale=true` e exiba banner com a data — nunca bloqueie a UI. O botão de refresh manual sempre força `invalidate`/`refresh` ignorando o cache.

#### 4.5 Acessibilidade dos estados

- `LoadingState` tem `Semantics(label: 'Carregando')`.
- `ErrorState`/`EmptyState` expõem título e descrição como texto real (lido por leitores de tela), nunca só ícone.
- Banner de stale combina **ícone + texto** ("offline / dados de {data}"), nunca cor isolada.
- Botões de retry/CTA têm alvo de toque >= 48dp (componentes `FilledButton`/`FilledButton.tonal` já atendem).

---

### Resumo de regras vinculantes para a implementação

1. **Estado:** sempre `@riverpod` (code-gen). Mutação ⇒ classe `AsyncNotifier`/`Notifier` com `AsyncValue.guard`. Leitura derivada ⇒ função `@riverpod`.
2. **DI:** somente Riverpod (`Provider` + `overrideWith`). Sem `get_it`.
3. **Erro:** `Result<T>` (sealed) em data/domain → `AsyncValue` no notifier → `.when`/`AsyncStateView` na UI. `DioException` é mapeado para `AppFailure` tipado.
4. **Fluxo:** unidirecional — UI dispara método (`ref.read(...).metodo()`), estado desce imutável (`ref.watch`), efeitos via `ref.listen`. Nunca chamar repositório direto da UI; nunca armazenar derivados (patrimônio é calculado).
5. **Navegação:** `go_router` tipado (`TypedGoRoute`) exposto via `goRouterProvider`; `StatefulShellRoute` para preservar estado das 5 abas; `RootShell` alterna `NavigationBar`/`NavigationRail` nos breakpoints 600/840dp; FAB contextual só em Início/Carteira.
6. **Estados:** todas as telas assíncronas usam `AsyncStateView` (loading inicial / refreshing / erro-sem-dado / stale / vazio / dados); dashboard degrada por card; brapi degrada graciosamente sem token e com campos de analista nulos.

---

## Telas & Fluxos de UX

Esta seção especifica a camada de apresentação do **Investa BR** (`investa_br`) de forma que o implementador possa codificar diretamente. Convenções adotadas em toda a seção:

- **Tema/cores:** sempre via `Theme.of(context).colorScheme` (gerado por `flex_color_scheme` + `dynamic_color`); nunca cores hard-coded. Variação positiva usa `colorScheme.tertiary`/`primary` + ícone `Icons.arrow_upward`; negativa usa `colorScheme.error` + `Icons.arrow_downward`; estável usa `colorScheme.outline` + `Icons.remove`. **Nunca depender só de cor** (acessibilidade): cor + ícone + texto.
- **Formatação:** `common/utils/formatters.dart` centraliza `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')`, `NumberFormat.decimalPercentPattern(locale: 'pt_BR', decimalDigits: 2)` e `DateFormat('dd/MM/yyyy', 'pt_BR')`.
- **Estado:** todo widget de tela consome um `AsyncValue<T>` exposto por um `AsyncNotifier`/`@riverpod`; o `switch` exaustivo sobre `AsyncValue` (sealed) decide entre conteúdo, loading e erro.
- **Acessibilidade:** todo card/gráfico envolto em `Semantics(label: ...)`; alvos de toque `>= 48dp`; layouts toleram `MediaQuery.textScaler` via `Wrap`/`FittedBox`/`SingleChildScrollView`.

### Árvore de arquivos da camada de apresentação

```
lib/src/
  app.dart                         # MaterialApp.router + ThemeController
  routing/
    app_router.dart                # GoRouter (provider) + StatefulShellRoute
    routes.dart                    # TypedGoRoute (go_router_builder)
    routes.g.dart                  # gerado
  common/
    widgets/
      root_shell.dart              # NavigationBar/Rail responsivo (IndexedStack)
      indicador_card.dart          # card de SELIC/CDI/IPCA/IGP-M
      variacao_label.dart          # ícone+texto de variação (acessível)
      async_value_view.dart        # helper data/loading/error padrão
      empty_state.dart             # estado vazio reutilizável
      error_retry_view.dart        # estado de erro + botão "Tentar de novo"
      stale_banner.dart            # faixa "dados offline/desatualizados"
      money_field.dart             # TextFormField com máscara R$
      percent_field.dart           # TextFormField com máscara %
    charts/
      donut_carteira.dart          # PieChart (fl_chart) distribuição
      line_historico.dart          # LineChart histórico indicador/patrimônio
      bar_comparador.dart          # BarChart comparador
      candlestick_acao.dart        # CandlestickChart detalhe da ação
      chart_legend.dart            # legenda textual acessível
  features/
    patrimonio/presentation/
      dashboard_screen.dart
    renda_fixa/presentation/
      carteira_screen.dart
      cadastro_rf_screen.dart
      detalhe_rf_screen.dart
    acoes/presentation/
      busca_acoes_screen.dart
      detalhe_acao_screen.dart
      cadastro_acao_screen.dart
    conversor_taxas/presentation/
      conversor_screen.dart
    configuracoes/presentation/
      configuracoes_screen.dart
      aparencia_section.dart
      dados_section.dart
```

### Mapa de rotas (go_router 17 tipado)

As 5 abas vivem num `StatefulShellRoute.indexedStack` para preservar estado por aba. Telas de detalhe/cadastro são `push` por cima do shell.

| Rota | Tela | Aba | Observação |
|---|---|---|---|
| `/` | `DashboardScreen` | Início | branch 0 |
| `/carteira` | `CarteiraScreen` | Carteira | branch 1 |
| `/carteira/rf/novo` | `CadastroRfScreen` | (push) | FAB / botão "+" |
| `/carteira/rf/:id` | `DetalheRfScreen` | (push) | tap em posição RF |
| `/carteira/rf/:id/editar` | `CadastroRfScreen` | (push) | reaproveita o form |
| `/carteira/acao/novo` | `CadastroAcaoScreen` | (push) | |
| `/conversor` | `ConversorScreen` | Conversor | branch 2 |
| `/acoes` | `BuscaAcoesScreen` | Ações | branch 3 |
| `/acoes/:ticker` | `DetalheAcaoScreen` | (push) | candlestick |
| `/ajustes` | `ConfiguracoesScreen` | Ajustes | branch 4 |

---

### 1. Navegação responsiva (RootShell)

Três faixas de largura alinhadas às *window size classes* do Material 3, decididas por `MediaQuery.sizeOf(context).width`:

| Faixa | Largura | Componente | Detalhe |
|---|---|---|---|
| compact | `< 600dp` | `NavigationBar` (rodapé) | 5 destinos, `labelBehavior: onlyShowSelected` |
| medium | `600–839dp` | `NavigationRail` | `labelType: selected`, só ícones+label do selecionado |
| expanded | `>= 840dp` | `NavigationRail(extended: true)` | ícone+label sempre, leading com FAB |

Os destinos: **Início · Carteira · Conversor · Ações · Ajustes**. O FAB ("+ Investimento") aparece **somente** nas abas Início e Carteira.

```
COMPACT (< 600dp)                         EXPANDED (>= 840dp)
+----------------------------------+      +-----------------------------------------------+
|  Investa BR                [⚙]   |      | [ + ] |  Investa BR             🔄  🌙        |
|                                  |      |-------|                                       |
|                                  |      | 🏠 Iníc|                                       |
|        (conteúdo da aba)         |      | 📊 Cart|         (conteúdo da aba)            |
|                                  |      | 🔁 Conv|                                       |
|                                  |      | 🔎 Açõe|                                       |
|                          [ + ]   |      | ⚙ Conf |                                       |
+----------------------------------+      | (Rail  |                                       |
| 🏠    📊    🔁    🔎    ⚙        |      | exten.)|                                       |
| Iníc  Cart  Conv  Açõe  Conf     |      +-----------------------------------------------+
+----------------------------------+
```

**Implementação de referência:**

```dart
class RootShell extends StatelessWidget {
  const RootShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _destinos = <_Dest>[
    _Dest(Icons.home_outlined, Icons.home, 'Início'),
    _Dest(Icons.pie_chart_outline, Icons.pie_chart, 'Carteira'),
    _Dest(Icons.swap_horiz, Icons.swap_horiz, 'Conversor'),
    _Dest(Icons.search, Icons.search, 'Ações'),
    _Dest(Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  bool _mostraFab(int i) => i == 0 || i == 1; // Início e Carteira

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final idx = navigationShell.currentIndex;

    void go(int i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        );

    final fab = _mostraFab(idx)
        ? FloatingActionButton.extended(
            onPressed: () => context.go(
              idx == 0 ? '/carteira/rf/novo' : '/carteira/rf/novo',
            ),
            icon: const Icon(Icons.add),
            label: const Text('Investimento'),
          )
        : null;

    if (width < 600) {
      return Scaffold(
        body: navigationShell,
        floatingActionButton: fab,
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: go,
          labelBehavior:
              NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final d in _destinos)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= 840;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: idx,
            onDestinationSelected: go,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            leading: _mostraFab(idx)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: extended ? fab : FloatingActionButton(
                      onPressed: () => context.go('/carteira/rf/novo'),
                      child: const Icon(Icons.add),
                    ),
                  )
                : const SizedBox(height: 56),
            destinations: [
              for (final d in _destinos)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Dest {
  const _Dest(this.icon, this.selected, this.label);
  final IconData icon;
  final IconData selected;
  final String label;
}
```

> **Por que `StatefulShellRoute.indexedStack`:** preserva scroll/estado de cada aba sem reconstruir — equivale ao `IndexedStack` da decisão global, mas integrado ao go_router para deep-linking/guards.

---

### 2. Tela Inicial — Dashboard (`/`)

Agrega: 4 cards de indicadores (do cache do dia, série SGS), patrimônio total, donut de distribuição (`fl_chart`) e próximos vencimentos. Layout responsivo: cards em `Wrap`/`GridView` que passam de 2 colunas (compact) para 4 (expanded).

```
+--------------------------------------------------------------+
|  Olá 👋                                       🔄  (refresh)   |
|  Patrimônio total                                            |
|  R$ 128.450,77        ▲ 1,2% no mês                          |
+--------------------------------------------------------------+
|  Indicadores · Atualizado em 17/06/2026 08:55  ⚠ (se stale)  |
|  +-----------+ +-----------+ +-----------+ +-----------+      |
|  | SELIC meta| | CDI (dia) | | IPCA mês  | | IGP-M mês |      |
|  | 14,50% aa | | 0,0534%   | | 0,58%     | | 0,84%     |      |
|  | ▬ estável | | (16/06)   | | (mai/26)  | | (mai/26)  |      |
|  +-----------+ +-----------+ +-----------+ +-----------+      |
|     ↑ tap abre histórico (LineChart) da série                |
+--------------------------------------------------------------+
|  Distribuição da carteira                                    |
|        ╭──────╮          ● Renda Fixa     R$ 79.640  62%     |
|       ╱  62%   ╲         ● Ações          R$ 35.966  28%     |
|      │    ◍     │        ● Tesouro Direto R$ 12.845  10%     |
|       ╲ ______ ╱         (legenda textual obrigatória)       |
|         (donut)                                              |
+--------------------------------------------------------------+
|  Próximos vencimentos                                        |
|  • CDB Banco X    vence 20/08/2026   R$ 10.000  →            |
|  • LCI Banco Y    vence 02/12/2026   R$  5.000  →            |
+--------------------------------------------------------------+
```

**Widgets-chave:**
- `IndicadorCard` (em `common/widgets`) — recebe `titulo`, `valorFormatado`, `dataReferencia`, `variacao` (enum `Variacao { alta, baixa, estavel }`) e `onTap`. Usa `VariacaoLabel`. Envolto em `Semantics`.
- `DonutCarteira` (`common/charts`) — `PieChart` com `centerSpaceRadius` para donut; cada `PieChartSectionData.color` vem de uma paleta derivada do `colorScheme` (primary/secondary/tertiary + harmonizados). **Sempre acompanhado de `ChartLegend`** (lista textual com %), pois cor sozinha falha em acessibilidade.
- `RefreshIndicator` (mobile) + botão 🔄 no `AppBar` (desktop) chamam `ref.invalidate(indicadoresProvider)` e `ref.invalidate(patrimonioProvider)` forçando refetch (ignora cache do dia).
- `StaleBanner` — exibido quando o snapshot veio de fallback offline (`stale == true`): faixa com `Icons.cloud_off` + "Dados de DD/MM podem estar desatualizados".

**Card de indicador (referência):**

```dart
class IndicadorCard extends StatelessWidget {
  const IndicadorCard({
    required this.titulo,
    required this.valor,
    required this.dataRef,
    required this.variacao,
    this.onTap,
    super.key,
  });
  final String titulo;
  final String valor;       // já formatado pt-BR
  final String dataRef;     // ex: '16/06/2026' ou 'mai/2026'
  final Variacao variacao;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: '$titulo $valor, referência $dataRef, ${variacao.semantica}',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.labelMedium),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(valor,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  Row(
                    children: [
                      VariacaoLabel(variacao: variacao),
                      const Spacer(),
                      Text(dataRef,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.outline)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum Variacao {
  alta(Icons.arrow_upward, 'em alta'),
  baixa(Icons.arrow_downward, 'em baixa'),
  estavel(Icons.remove, 'estável');

  const Variacao(this.icone, this.semantica);
  final IconData icone;
  final String semantica;
}
```

**Donut com legenda textual:**

```dart
class DonutCarteira extends StatelessWidget {
  const DonutCarteira({required this.fatias, super.key});
  final List<FatiaCarteira> fatias; // {label, valor, percentual, cor}

  @override
  Widget build(BuildContext context) {
    final total = fatias.fold<double>(0, (s, f) => s + f.valor);
    return Semantics(
      label: 'Distribuição da carteira. ' +
          fatias.map((f) => '${f.label} ${f.percentualFmt}').join(', '),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 480;
        final chart = SizedBox(
          height: 180,
          child: PieChart(PieChartData(
            centerSpaceRadius: 48, // donut
            sectionsSpace: 2,
            sections: [
              for (final f in fatias)
                PieChartSectionData(
                  value: f.valor,
                  color: f.cor,
                  title: f.percentualFmt,
                  radius: 44,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
            ],
          )),
        );
        final legenda = ChartLegend(itens: [
          for (final f in fatias)
            LegendItem(f.cor, '${f.label}  ${f.valorFmt}  (${f.percentualFmt})'),
        ]);
        return wide
            ? Row(children: [Expanded(child: chart), Expanded(child: legenda)])
            : Column(children: [chart, const SizedBox(height: 8), legenda]);
      }),
    );
  }
}
```

> O `percentual` da fatia é calculado pelo `patrimonioProvider` somando o **valor bruto atualizado** de cada posição (RF marcada na curva pela taxa contratada + ações pela última cotação cacheada). O donut nunca recalcula finanças — só plota.

**Fluxo de abertura (passo a passo):**
1. App abre → `RootShell` monta `DashboardScreen` (branch 0).
2. `dashboardScreen` observa `indicadoresProvider` (AsyncNotifier que chama `DailyCacheService.obter()`).
3. `DailyCacheService` lê `cache_indicadores/indicadores_dia`. Se `dataUltimaAtualizacao == hoje (America/Sao_Paulo)` e dentro do TTL → retorna cache (estado `data` imediato).
4. Senão, dispara batch paralelo (≤5 req): SGS `/ultimos/1` das séries `[432, 11, 12, 433, 189, 226, 195]` + feriados BrasilAPI do ano + cotações da carteira. Enquanto isso a UI mostra `data` antigo (stale-while-revalidate) ou skeleton se vazio.
5. Sucesso → persiste snapshot (`fetchedAt`, `stale: false`) e `AsyncValue` emite `data` novo. Falha → mantém último snapshot com `stale: true` e exibe `StaleBanner`; se não há cache algum, emite `error`.
6. Tap em card de indicador → `push` bottom-sheet com `LineHistorico` (LineChart) da série (consulta SGS por período, fragmentando janelas de 10 anos quando necessário).

---

### 3. Cadastro / Edição de Renda Fixa (`/carteira/rf/novo`, `/carteira/rf/:id/editar`)

Formulário único reaproveitado para criação e edição. Modela a **taxa como value object** (nunca um `double` solto): `tipoRendimento` + `valorContratado` + `indexador?` + `baseDias` + `capitalizacao`. Mostra preview de projeção ao vivo.

```
+--------------------------------------------------------------+
| ←  Novo investimento — Renda Fixa                  [Salvar]  |
+--------------------------------------------------------------+
|  Emissor / Apelido                                           |
|  [ CDB Banco X 2027                          🔎 buscar CNPJ ]|
|                                                              |
|  Classe do ativo        ( CDB ▾ )                            |
|     CDB · LCI · LCA · CRI · CRA · Debênture ·                |
|     Deb. Incentivada · Tesouro Selic/Pré/IPCA+ · Poupança    |
|                                                              |
|  Tipo de rendimento                                          |
|  [ Pré-fix ][• Pós-CDI ][ Pós-Selic ][ IPCA+ ][ % puro ]    |
|     (SegmentedButton)                                        |
|                                                              |
|  Indexador  ( CDI ▾ )      Taxa  [ 110,00 ] % do CDI         |
|     (campo Taxa muda label/sufixo conforme tipo)            |
|                                                              |
|  Valor inicial   [ R$ 10.000,00 ]                            |
|  Base de dias    [• 252 ][ 360 ][ 365 ]                     |
|  Início    [ 17/06/2026 ]    Vencimento [ 17/06/2027 ]      |
|  Isento de IR    [ ⃝ ] (auto-marcado p/ LCI/LCA/incentiv.)  |
|--------------------------------------------------------------|
|  Projeção (du=251)                                           |
|   Valor bruto:    R$ 11.596,00   (+15,96%)                  |
|   IR (15%):       -R$  239,40                               |
|   IOF:            R$    0,00                                |
|   Valor líquido:  R$ 11.356,60   (líq. 13,57% a.a.)         |
+--------------------------------------------------------------+
```

**Widgets-chave e regras de campo:**

| Campo | Widget | Regra |
|---|---|---|
| Emissor/Apelido | `TextFormField` | obrigatório; ícone abre busca CNPJ (BrasilAPI → OpenCNPJ fallback) que preenche razão social |
| Classe | `DropdownMenu<ClasseAtivo>` | ao escolher LCI/LCA/CRI/CRA/debênture incentivada/poupança → marca `isento=true` e desabilita o switch |
| Tipo de rendimento | `SegmentedButton<TipoRendimento>` | controla visibilidade de Indexador e sufixo de Taxa |
| Indexador | `DropdownMenu<Indexador>` | visível só p/ pós-CDI, pós-Selic, IPCA+ |
| Taxa | `PercentField` | sufixo dinâmico: "% do CDI", "% a.a.", "IPCA + __%" |
| Valor inicial | `MoneyField` | máscara R$, `> 0` |
| Base de dias | `SegmentedButton<int>` | default 252 |
| Datas | `showDatePicker` (locale pt_BR) | vencimento `> início` |
| Isento IR | `Switch` | derivado da classe; editável só quando classe não força |

**Sufixo da taxa conforme tipo (lógica do form):**

```dart
String sufixoTaxa(TipoRendimento t) => switch (t) {
  TipoRendimento.prefixado     => '% a.a.',
  TipoRendimento.percentualCdi => '% do CDI',
  TipoRendimento.percentualSelic => '% da Selic',
  TipoRendimento.ipcaMais      => 'IPCA + __% a.a.',
  TipoRendimento.igpmMais      => 'IGP-M + __% a.a.',
  TipoRendimento.percentualPuro => '% (taxa total)',
};
```

**Preview ao vivo:** um `previewProjecaoProvider.family` recebe o rascunho do form e chama o motor de cálculo (`projetar(...)` base 252 com `diasUteisEntre` usando feriados do cache). O preview reage a cada mudança via `ref.watch`. Enquanto inválido (campos faltando), mostra placeholder "Preencha taxa, valor e datas".

**Fluxo de salvar:**
1. Usuário toca **Salvar** → `Form.validate()`.
2. Válido → monta `PosicaoRendaFixa` (freezed) → `rendaFixaNotifier.upsert(doc)` (gera UUID se novo, seta `updatedAt`).
3. `AsyncNotifier` usa `AsyncValue.guard`; em sucesso `pop` para `/carteira` e mostra `SnackBar` "Investimento salvo".
4. Erro de persistência → `SnackBar` com `colorScheme.error` + mantém o form preenchido.

**Estado de erro de busca CNPJ:** se ambas as APIs falharem, campo Emissor permanece editável manualmente e mostra `helperText` "Não foi possível consultar o CNPJ — preencha manualmente".

---

### 4. Posições de Ações na Carteira + Cadastro (`/carteira`, `/carteira/acao/novo`)

A aba **Carteira** lista posições de RF e de Ações em seções. As posições de ações exibem cotação atual (cache diário sob demanda) e P/L.

```
+--------------------------------------------------------------+
| Carteira                                            🔄       |
| [ Renda Fixa ]  [ Ações ]   (TabBar / filtros)              |
+--------------------------------------------------------------+
|  AÇÕES — 3 posições · total R$ 35.966,00                    |
|  +--------------------------------------------------------+ |
|  | PETR4   100 cotas · PM R$ 31,20                        | |
|  | Atual R$ 38,54   ▲ +R$ 734,00  (+23,5%)            →  | |
|  +--------------------------------------------------------+ |
|  | VALE3    50 cotas · PM R$ 61,80                        | |
|  | Atual R$ 61,20   ▼ -R$  30,00  (-0,97%)            →  | |
|  +--------------------------------------------------------+ |
|  (tap abre detalhe da ação; swipe → editar/excluir)         |
+--------------------------------------------------------------+
                  Cadastro de posição em ação:
+--------------------------------------------------------------+
| ←  Nova posição — Ações                            [Salvar]  |
+--------------------------------------------------------------+
|  Ativo (ticker)   [ PETR4               🔎 buscar ]          |
|  Quantidade       [ 100 ]                                    |
|  Preço médio      [ R$ 31,20 ]                               |
|  Corretora (opc.) [ XP ]                                     |
|  Data da compra   [ 02/05/2026 ]                             |
|--------------------------------------------------------------|
|  Cotação atual: R$ 38,54  ·  P/L: ▲ R$ 734,00 (+23,5%)     |
+--------------------------------------------------------------+
```

**Widgets-chave:**
- Item de posição: `Card` + `ListTile` com `VariacaoLabel` no P/L; `Dismissible` para editar/excluir em mobile, `PopupMenuButton` em desktop.
- Cálculo do P/L na UI: `pl = (cotacaoAtual - precoMedio) * quantidade`; cor/ícone por `Variacao` derivada do sinal.
- Campo ticker em `Autocomplete` que consulta `GET /api/available?search=` (brapi, sem token) para autocompletar; ao confirmar, busca `GET /api/quote/{ticker}` (com token brapi) e mostra cotação no preview.
- **Degradação sem token:** se o ticker não estiver em `[PETR4, MGLU3, VALE3, ITUB4]` e não houver token configurado, o preview mostra "Configure o token brapi em Ajustes para cotação ao vivo"; salvar ainda é permitido (cotação fica indisponível até haver token).

---

### 5. Conversor / Comparador de Renda (`/conversor`)

Converte produtos heterogêneos (% CDI, IPCA+, prefixado, isento) para **uma métrica única: rentabilidade líquida anual efetiva (% a.a., base 252)** após IR/IOF, e mostra **gross-up** para isentos. Visualização com `BarChart`.

```
+--------------------------------------------------------------+
|  Conversor / Comparador de renda                             |
+--------------------------------------------------------------+
|  Valor [ R$ 10.000,00 ]      Prazo [ 720 ] dias              |
|  CDI atual: 14,40% · IPCA proj. 12m: 4,72%  (do cache)       |
|--------------------------------------------------------------|
|  Opção A  [ Pós-CDI ▾ ]   110,00 % do CDI    [ ⃝ isento ]   |
|  Opção B  [ IPCA+ ▾   ]   6,00 % a.a.        [ ⃝ isento ]   |
|  Opção C  [ Prefixado ]   13,50 % a.a.       [ ⃝ isento ]   |
|  Opção D  [ Pós-CDI ▾ ]   95,00 % CDI        [ ✓ isento LCI ]|
|                                       [ + adicionar opção ]  |
|--------------------------------------------------------------|
|  Ranking (líquido a.a., base 252)                            |
|  ┌─────────────────────────────────────────────┐            |
|  │ D ████████████████████  13,63%  ⭐ melhor    │  BarChart  |
|  │ A ██████████████████    13,57%               │            |
|  │ C ████████████          11,05%               │            |
|  │ B ██████████            9,35%                │            |
|  └─────────────────────────────────────────────┘            |
|  D (LCI 95% CDI, isenta): líq 13,63% a.a.                    |
|     → gross-up: um CDB precisaria 16,04% a.a. bruto          |
|--------------------------------------------------------------|
|  ⚠ Valores informativos, base premissas de 2026.            |
|    Não é recomendação de investimento (CVM).                |
+--------------------------------------------------------------+
```

**Widgets-chave:**
- `MoneyField` (valor), `TextFormField`/`Slider` para prazo em dias.
- Linhas de opção dinâmicas (`ListView` de cards), cada uma com `SegmentedButton`/`DropdownMenu` (tipo), `PercentField` (taxa), `Switch` (isento).
- `BarComparador` (`fl_chart` `BarChart`): cada barra = uma opção; eixo Y = % líquida a.a.; barra vencedora destacada com `colorScheme.primary`, demais com `colorScheme.secondaryContainer`. **Legenda textual** lista cada opção com seu valor.
- Banner de aviso CVM fixo no rodapé (`colorScheme.surfaceContainerHighest` + `Icons.info_outline`).

**Motor (UI apenas dispara; cálculo no domínio):** para cada opção a UI chama `taxaLiquidaAnualEfetiva(...)` e, para isentos, `taxaBrutaEquivalenteDeIsento(...)`. O ranking é ordenado desc por `iLiqAnual`.

```dart
// Resultado por opção, consumido pelo BarChart e pela lista de ranking.
typedef ResultadoComparacao = ({
  String rotulo,        // 'A', 'B', ...
  double liquidoAnual,  // ex 0.1357
  double? grossUp,      // só p/ isentos
  bool isento,
});

List<BarChartGroupData> barras(List<ResultadoComparacao> rs, ColorScheme cs) {
  final melhor = rs.indexWhere(
    (r) => r.liquidoAnual == rs.map((e) => e.liquidoAnual).reduce(max));
  return [
    for (var i = 0; i < rs.length; i++)
      BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: rs[i].liquidoAnual * 100, // em pontos percentuais
          color: i == melhor ? cs.primary : cs.secondaryContainer,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ]),
  ];
}
```

**Fluxo:** alterar qualquer campo invalida `comparadorProvider` (debounce ~300ms) → recálculo síncrono (puro Dart, sem rede) → atualiza barras + ranking instantaneamente. Indicadores (CDI/IPCA) vêm do cache do dia.

---

### 6. Busca de Ações (`/acoes`) e Detalhe (`/acoes/:ticker`)

Busca por ticker/nome com autocomplete; detalhe com `CandlestickChart` (histórico ~3 meses no free) e fundamentos. **Recomendações de analistas degradam graciosamente** (campos brapi nulos no free → exibir sinais próprios derivados de fundamentos).

```
+--------------------------------------------------------------+
|  🔎 [ petr                                          ]        |
|  Resultados                                                  |
|  PETR4   Petróleo Brasileiro PN   R$ 38,54  ▲1,3%  [+ add]  |
|  PETR3   Petróleo Brasileiro ON   R$ 41,80  ▲0,9%  [+ add]  |
|     (tap no item → detalhe)                                  |
+--------------------------------------------------------------+
                  Detalhe — /acoes/PETR4
+--------------------------------------------------------------+
| ←  PETR4 · Petróleo Brasileiro PN                  [+ add]  |
|  R$ 38,54   ▲ +1,33%   |  Máx 38,78 / Mín 38,20            |
|  52sem: 29,31 — 50,69                                       |
|--------------------------------------------------------------|
|  Período  [ 1M ][ 3M ]   (CandlestickChart fl_chart)        |
|   ┌──────────────────────────────────────────┐             |
|   │      ▐ ╽    ╿▐                            │             |
|   │   ╿▐ █ █ ╽ ▐█ ▐╽                          │             |
|   │   █ █ █ █ █ █ █ █                         │             |
|   └──────────────────────────────────────────┘             |
|--------------------------------------------------------------|
|  Fundamentos                                                 |
|   P/L 4,62 · LPA R$ 8,35 · Market cap R$ 532,9 bi           |
|   DY — · P/VP — · ROE —     (— quando indisponível)         |
|--------------------------------------------------------------|
|  Sinal próprio (calculado localmente)  ℹ                    |
|   ● Atrativo por P/L baixo (4,62)                            |
|   ⚠ Sem dados de analistas no plano gratuito                |
+--------------------------------------------------------------+
```

**Widgets-chave:**
- Barra de busca `SearchBar`/`Autocomplete` → `GET /api/available?search=` (debounce 400ms). Resultados em `ListView` de `ListTile`.
- `CandlestickAcao` (`fl_chart` `CandlestickChart`): dados de `GET /api/quote/{ticker}?range=3mo&interval=1d` (com token). Velas de alta usam `colorScheme.tertiary`, de baixa `colorScheme.error`; tooltip com OHLC. Toggle de período `1M/3M` via `SegmentedButton`.
- Fundamentos: grid de `P/L`, `LPA`, `market cap`, `DY`, `P/VP`, `ROE`. Cada métrica nula renderiza "—" (não esconde a linha) — degradação graciosa.
- **Sinal próprio:** já que `recommendationKey/targetMeanPrice` vêm `null` no free, um `sinaisProvider` deriva sinais locais (P/L baixo, DY alto, ROE alto) e os exibe como chips informativos, com aviso "Sem dados de analistas no plano gratuito". **Nunca rotular como recomendação de compra/venda** (CVM).

**Tratamento HTTP 429 (rate limit brapi):** o repositório aplica backoff exponencial + serve cotação do cache diário; a UI mostra `SnackBar` "Limite de consultas atingido — exibindo último valor de DD/MM HH:mm".

---

### 7. Configurações / Ajustes (`/ajustes`)

Duas seções principais: **Aparência** (tema) e **Dados** (import/export, token brapi, status do cache).

```
+--------------------------------------------------------------+
|  Ajustes                                                     |
|  ── Aparência ──────────────────────────────────────────────|
|  Modo            [ Claro ][ Escuro ][• Sistema ]            |
|  [✓] Usar cor do sistema (Material You)                     |
|  Cor-semente     ● ● ● ● ● ●   [ mais cores… ]              |
|     Prévia:  [ Botão ]  [ Chip ]  [ Card ]                  |
|  ── Dados ──────────────────────────────────────────────────|
|  Token brapi     [ •••••••••••••              ] [ salvar ]   |
|     Sem token: apenas PETR4, MGLU3, VALE3, ITUB4            |
|  [ Exportar carteira (.json) ]                              |
|  [ Importar carteira (.json) ]                              |
|     Modo de import:  [• Substituir ][ Mesclar ]            |
|  Última atualização do cache: 17/06/2026 08:55  [ 🔄 ]     |
|  ── Sobre ──────────────────────────────────────────────────|
|  Investa BR v1.0.0 · Dados informativos, não recomendação.  |
+--------------------------------------------------------------+
```

**Widgets-chave:**
- Modo: `SegmentedButton<ThemeMode>`; "Usar cor do sistema": `SwitchListTile` (gravado em `configuracoes` como `useDynamic`).
- Cor-semente: linha de `ChoiceChip` circulares + opção de roda de cores; persistida como int ARGB. `ThemeController` (Riverpod, acima do `MaterialApp`) reage e regenera o tema.
- Token brapi: `TextFormField` (obscureText) + botão salvar → grava em `configuracoes` (runtime config).
- **Exportar:** botão chama `ImportExportService.exportar()` → gera JSON `{app, schemaVersion, exportedAt, appVersion, checksum, data:{investimentos_rf, posicoes_acoes, configuracoes}}` (cache **não** entra) → `share_plus`.
- **Importar:** `file_picker` (`.json`) → diálogo de confirmação com modo **Substituir** (default) ou **Mesclar** → valida `app`, `schemaVersion` (bloqueia versão mais nova), checksum SHA-256 → aplica em transação atômica.

**Fluxo de import (passo a passo + estados de erro):**
1. Toca **Importar** → `file_picker` abre seletor de `.json`.
2. Cancelou → nada acontece.
3. Lê arquivo → valida `app == 'investa_br'`; se falhar → diálogo de erro "Arquivo não é um backup do Investa BR".
4. `schemaVersion > LocalDb.schemaVersion` → erro "Backup de versão mais nova — atualize o app".
5. Checksum diverge → erro "Backup corrompido".
6. OK → `migratePayload` (se versão antiga) → `db.transaction` aplica REPLACE (limpa stores do usuário e regrava) ou MERGE por `id` (last-write-wins via `updatedAt`).
7. Sucesso → `SnackBar` "Carteira importada (N investimentos, M ações)" + `ref.invalidate` dos providers de dados.

---

### 8. Estados vazios e de erro (padrões reutilizáveis)

Toda tela que consome `AsyncValue` usa o helper `AsyncValueView` para um tratamento consistente dos três estados (sealed → `switch` exaustivo):

```dart
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    required this.onRetry,
    this.skeleton,
    super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) => data(value),
        AsyncError(:final error) =>
          ErrorRetryView(mensagem: _msg(error), onRetry: onRetry),
        _ => skeleton ?? const Center(child: CircularProgressIndicator()),
      };

  String _msg(Object e) => switch (e) {
        SemConexao() => 'Sem conexão. Verifique a internet e tente de novo.',
        RateLimit() => 'Muitas consultas. Aguarde um instante.',
        DadosInvalidos() => 'Não foi possível ler a resposta do servidor.',
        _ => 'Algo deu errado. Tente novamente.',
      };
}
```

**Catálogo de estados vazios por tela:**

| Tela | Condição | Componente `EmptyState` |
|---|---|---|
| Dashboard | Sem nenhuma posição cadastrada | Ícone `Icons.savings_outlined`, "Sua carteira está vazia", CTA "Adicionar investimento" → `/carteira/rf/novo`. Donut e patrimônio ocultos; cards de indicadores **ainda aparecem** (dependem só de API). |
| Carteira (RF) | Lista RF vazia | "Nenhum investimento em renda fixa", CTA "+ Renda fixa" |
| Carteira (Ações) | Lista ações vazia | "Nenhuma ação na carteira", CTA "+ Ação" |
| Conversor | Sem opções adicionadas | "Adicione ao menos 2 opções para comparar" |
| Busca de ações | Campo vazio | "Busque por código (ex: PETR4) ou nome" |
| Busca de ações | Termo sem resultados | `Icons.search_off`, "Nenhum ativo encontrado para \"<termo>\"" |
| Detalhe da ação | Sem token e ticker fora dos 4 livres | Banner "Cotação indisponível — configure o token brapi em Ajustes" |

**Componente de estado vazio (reutilizável):**

```dart
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icone,
    required this.titulo,
    this.descricao,
    this.acaoLabel,
    this.onAcao,
    super.key,
  });
  final IconData icone;
  final String titulo;
  final String? descricao;
  final String? acaoLabel;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView( // tolera textScaler grande
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (descricao != null) ...[
              const SizedBox(height: 8),
              Text(descricao!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
            if (acaoLabel != null && onAcao != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAcao,
                icon: const Icon(Icons.add),
                label: Text(acaoLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Estado de erro (`ErrorRetryView`):** ícone `Icons.cloud_off`/`Icons.error_outline`, mensagem humanizada (mapeada do `Failure` tipado), botão **"Tentar de novo"** que chama `ref.invalidate(provider)`. Quando há cache disponível mas a revalidação falhou, **não** se mostra tela de erro cheia — usa-se o `StaleBanner` no topo do conteúdo cacheado (stale-while-revalidate), preservando a navegabilidade.

**Loading:** preferir skeleton/shimmer nos cards e listas (placeholders com a forma final) a um `CircularProgressIndicator` solitário, evitando *layout shift*. No primeiro boot sem cache, o Dashboard mostra 4 skeletons de card + skeleton de donut.

---

### Resumo de mapeamento Tela → Provider → Gráfico

| Tela | Provider(s) principal(is) | Gráfico fl_chart | Estado vazio |
|---|---|---|---|
| Dashboard | `indicadoresProvider`, `patrimonioProvider`, `proximosVencimentosProvider` | `PieChart` (donut) + `LineChart` (histórico no tap) | carteira vazia |
| Carteira | `rendaFixaListProvider`, `acoesPosicoesProvider` | — | listas vazias por seção |
| Cadastro RF | `previewProjecaoProvider.family`, `cnpjLookupProvider.family` | — | n/a (form) |
| Conversor | `comparadorProvider` (puro) + indicadores do cache | `BarChart` | < 2 opções |
| Busca Ações | `buscaAcoesProvider.family`, `detalheAcaoProvider.family` | `CandlestickChart` | campo vazio / sem resultados |
| Ajustes | `themeControllerProvider`, `cacheStatusProvider`, `importExportProvider` | — | n/a |

---

## Tematizacao Customizavel (Material 3)

Esta secao especifica, de forma completa e acionavel, o subsistema de temas do **Investa BR**. O objetivo e um tema **Material 3** (`useMaterial3: true`) com (1) **cor-semente (seed) personalizavel** pelo usuario, (2) **modo claro/escuro/sistema**, (3) integracao com **Material You** via `dynamic_color` com **fallback obrigatorio** para seed manual, (4) **persistencia local** no sembast (store `configuracoes`) exposta via Riverpod **acima** do `MaterialApp`, e (5) **tokens de design e tipografia** centralizados.

Decisao base ja fixada nas Decisoes Globais:
- Usar **`flex_color_scheme` ^8.4.0** (`FlexThemeData.light/dark` com `keyColors`) por entregar `onColors`/`surfaces` mais polidos que `ColorScheme.fromSeed` puro.
- Integrar **`dynamic_color` ^1.8.1** (`DynamicColorBuilder`). Material You so existe em **Android 12+** (paleta do wallpaper) e como **accent de desktop** (Windows/macOS/Linux parcial); em iOS e Android antigos NAO ha paleta dinamica -> **sempre** cair para o seed manual.
- Persistir `seed` (int ARGB), `themeMode` e `useDynamic` no **sembast** (store `configuracoes`, key `app`), conforme schema ja definido na secao de Storage.

> Nota de versao: `ColorScheme.fromSeed` puro permanece descrito como **fallback minimo** e como referencia mental do que `FlexKeyColors` faz por baixo. A implementacao de producao usa `FlexThemeData`.

---

### 1. Arvore de arquivos

Toda a tematizacao vive em `lib/src/common/theme/` (camada comum, reutilizada por todas as features) + o controller em `lib/src/features/configuracoes/`.

```
lib/
  src/
    common/
      theme/
        app_theme.dart            # AppTheme: monta ThemeData light/dark (FlexThemeData)
        app_color_seeds.dart      # catalogo de seeds pre-definidas (paleta de escolha)
        app_typography.dart       # TextTheme base + fontFamily + escala
        design_tokens.dart        # tokens nao-cor: espacamentos, raios, duracoes, breakpoints
        theme_extensions.dart     # ThemeExtension<FinanceColors> (verde/vermelho de variacao)
    features/
      configuracoes/
        domain/
          theme_settings.dart     # freezed: ThemeSettings {seedArgb, themeMode, useDynamic}
        data/
          theme_settings_repository.dart   # le/grava em sembast store 'configuracoes'/'app'
        application/
          theme_controller.dart   # @riverpod ThemeController (AsyncNotifier) + provider
        presentation/
          aparencia_screen.dart   # tela Ajustes > Aparencia (toggle modo + seed + dynamic)
          widgets/
            seed_color_picker.dart
            theme_mode_selector.dart
    app.dart                      # MaterialApp.router envolto por DynamicColorBuilder
```

---

### 2. Modelo de dominio: `ThemeSettings` (freezed)

Persistimos apenas 3 campos. O `seedArgb` e um **int ARGB** (ex.: `0xFF1565C0`), que e como o sembast guarda cor em JSON sem perda. `themeMode` e serializado como string estavel.

`lib/src/features/configuracoes/domain/theme_settings.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme_settings.freezed.dart';
part 'theme_settings.g.dart';

@freezed
abstract class ThemeSettings with _$ThemeSettings {
  const factory ThemeSettings({
    /// Cor-semente em ARGB (ex.: 0xFF1565C0). Base do ColorScheme quando
    /// nao se usa Material You (ou quando este e indisponivel).
    @Default(0xFF1565C0) int seedArgb,

    /// 'system' | 'light' | 'dark'.
    @Default(AppThemeMode.system) AppThemeMode themeMode,

    /// Quando true E a plataforma fornecer paleta dinamica, usa Material You.
    @Default(false) bool useDynamic,
  }) = _ThemeSettings;

  const ThemeSettings._();

  factory ThemeSettings.fromJson(Map<String, Object?> json) =>
      _$ThemeSettingsFromJson(json);

  /// Conversao pronta para o MaterialApp.
  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  Color get seedColor => Color(seedArgb);
}

/// Enum proprio (serializa como string estavel; nao depende do index do
/// ThemeMode do Flutter, que poderia mudar).
@JsonEnum()
enum AppThemeMode { system, light, dark }
```

Por que `int ARGB` e nao `String hex`? Porque o sembast grava `Map<String,Object?>` JSON nativo e `int` e tipo JSON valido — evita parse de `#RRGGBB`. `Color(seedArgb)` reidrata direto. (Na secao de Storage o doc `configuracoes/app` ja tinha `corPrimaria: "#1565C0"`; **padronize aqui em `seedArgb: int`** para reidratacao trivial e atualize o `migratePayload`/`onVersionChanged` para converter `"#1565C0" -> 0xFF1565C0` se um backup antigo trouxer o formato string.)

---

### 3. Tokens de design (nao-cor) — `design_tokens.dart`

Centralize espacamentos, raios, duracoes e breakpoints como **constantes**. As cores NAO ficam aqui (vem do `ColorScheme`); aqui ficam apenas os tokens geometricos/temporais e os breakpoints Material 3 usados pelo RootShell responsivo.

`lib/src/common/theme/design_tokens.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Tokens geometricos e de movimento. Nomes alinhados ao Material 3.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Alvo minimo de toque (acessibilidade).
  static const double minTouchTarget = 48;
}

abstract final class Radii {
  static const Radius card = Radius.circular(16);
  static const Radius chip = Radius.circular(8);
  static const Radius dialog = Radius.circular(28); // M3 large
  static const BorderRadius cardBorder = BorderRadius.all(card);
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration emphasized = Duration(milliseconds: 500);
}

/// Breakpoints Material 3 (window size classes) usados pelo RootShell.
abstract final class Breakpoints {
  static const double compact = 600;   // < 600 => NavigationBar
  static const double medium = 840;    // 600..840 => NavigationRail compacto
  // >= 840 => NavigationRail extended / Drawer
}
```

#### Tokens semanticos de cor financeira (ThemeExtension)

Variacao de patrimonio/cotacao NAO pode depender do `ColorScheme` (que nao tem "verde/vermelho de mercado") nem de cor solta. Modele como `ThemeExtension` para que mude junto com claro/escuro e seja acessivel via `Theme.of(context).extension<FinanceColors>()`. **Regra de acessibilidade (ja decidida): variacao sempre com icone + texto, nunca so cor.**

`lib/src/common/theme/theme_extensions.dart`:

```dart
import 'package:flutter/material.dart';

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.positivo,   // alta
    required this.negativo,   // baixa
    required this.neutro,     // estavel
    required this.onPositivo,
    required this.onNegativo,
  });

  final Color positivo;
  final Color negativo;
  final Color neutro;
  final Color onPositivo;
  final Color onNegativo;

  static const light = FinanceColors(
    positivo: Color(0xFF1B7F3B),
    negativo: Color(0xFFB3261E),
    neutro: Color(0xFF6F6F6F),
    onPositivo: Colors.white,
    onNegativo: Colors.white,
  );

  static const dark = FinanceColors(
    positivo: Color(0xFF5CD17E),
    negativo: Color(0xFFF2B8B5),
    neutro: Color(0xFFB0B0B0),
    onPositivo: Color(0xFF00210B),
    onNegativo: Color(0xFF601410),
  );

  @override
  FinanceColors copyWith({
    Color? positivo,
    Color? negativo,
    Color? neutro,
    Color? onPositivo,
    Color? onNegativo,
  }) =>
      FinanceColors(
        positivo: positivo ?? this.positivo,
        negativo: negativo ?? this.negativo,
        neutro: neutro ?? this.neutro,
        onPositivo: onPositivo ?? this.onPositivo,
        onNegativo: onNegativo ?? this.onNegativo,
      );

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      positivo: Color.lerp(positivo, other.positivo, t)!,
      negativo: Color.lerp(negativo, other.negativo, t)!,
      neutro: Color.lerp(neutro, other.neutro, t)!,
      onPositivo: Color.lerp(onPositivo, other.onPositivo, t)!,
      onNegativo: Color.lerp(onNegativo, other.onNegativo, t)!,
    );
  }
}
```

Uso em widget de variacao (icone + texto + cor):

```dart
final fin = Theme.of(context).extension<FinanceColors>()!;
final cor = pct > 0 ? fin.positivo : (pct < 0 ? fin.negativo : fin.neutro);
final icone = pct > 0 ? Icons.arrow_upward : (pct < 0 ? Icons.arrow_downward : Icons.remove);
// Renderizar: Icon(icone, color: cor) + Text('${pct.abs()}%', style: ... color: cor)
```

---

### 4. Tipografia — `app_typography.dart`

Material 3 ja entrega a escala de tipos (display/headline/title/body/label). Aqui apenas (a) definimos a `fontFamily` (mantenha `null` para usar Roboto/SF nativo, ou aponte para uma fonte empacotada) e (b) ajustamos pesos/altura. Numeros monetarios devem usar **tabular figures** para alinhar colunas em tabelas/cards de patrimonio.

```dart
import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// null => usa a fonte default da plataforma (Roboto/SF). Para fonte propria,
  /// declare em pubspec (fonts:) e troque para o nome da family.
  static const String? fontFamily = null;

  /// FontFeature para alinhar digitos em colunas (R$ 1.234,56).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Ajustes finos sobre o TextTheme base do M3 (recebe o do ColorScheme).
  static TextTheme tune(TextTheme base) => base.copyWith(
        headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.1),
      );

  /// Estilo dedicado a valores monetarios (usar em cards/tabelas).
  static TextStyle money(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontFeatures: tabular,
            fontWeight: FontWeight.w600,
          );
}
```

Tabela de mapeamento de papeis de texto -> uso no app:

| Token M3 | Uso no Investa BR |
|---|---|
| `displaySmall` | Patrimonio total na Dashboard |
| `headlineSmall` | Titulos de tela |
| `titleMedium` | Valores monetarios (com `tabularFigures`) |
| `bodyMedium` | Texto corrido, descricoes |
| `labelLarge` | Botoes, chips, destinos de navegacao |
| `labelSmall` | "Atualizado em dd/MM/yyyy", rodapes de cards |

---

### 5. Catalogo de seeds — `app_color_seeds.dart`

O usuario escolhe a cor-semente de uma paleta curada (mais um "outro" via color picker livre). Cada item e so um `int ARGB`.

```dart
import 'package:flutter/material.dart';

class SeedOption {
  const SeedOption(this.nome, this.argb);
  final String nome;
  final int argb;
  Color get color => Color(argb);
}

abstract final class AppColorSeeds {
  static const int padrao = 0xFF1565C0; // azul Investa

  static const List<SeedOption> opcoes = [
    SeedOption('Azul Investa', 0xFF1565C0),
    SeedOption('Verde', 0xFF2E7D32),
    SeedOption('Indigo', 0xFF3949AB),
    SeedOption('Teal', 0xFF00796B),
    SeedOption('Roxo', 0xFF6A1B9A),
    SeedOption('Laranja', 0xFFEF6C00),
    SeedOption('Vermelho', 0xFFC62828),
    SeedOption('Grafite', 0xFF455A64),
  ];
}
```

---

### 6. Construcao do `ThemeData` — `app_theme.dart`

Esta e a peca central. `AppTheme.fromSeed(...)` monta o tema via **`FlexThemeData`** com `FlexKeyColors(useKeyColors: true)` (transforma o `primary` em **seed Material 3**, gerando `onColors`/`surfaces` tonais). `AppTheme.fromDynamic(...)` monta a partir de um `ColorScheme` ja entregue pelo SO (Material You), reaproveitando os mesmos sub-temas e tokens.

```dart
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'design_tokens.dart';
import 'theme_extensions.dart';

abstract final class AppTheme {
  // ---- Sub-temas compartilhados (mesmo visual em seed e dynamic) ----
  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    useM2StyleDividerInM3: false,
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnLevel: 8,
    defaultRadius: 12,
    cardRadius: 16,
    inputDecoratorRadius: 12,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer,
    navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
  );

  static const VisualDensity _density = VisualDensity.adaptivePlatformDensity;

  // ---------- Caminho A: seed manual (FlexColorScheme + keyColors) ----------
  static ThemeData lightFromSeed(Color seed) => _decorate(
        FlexThemeData.light(
          colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.light),
          keyColors: const FlexKeyColors(
            useKeyColors: true,
            useSecondary: true,
            useTertiary: true,
          ),
          subThemesData: _subThemes,
          visualDensity: _density,
          fontFamily: AppTypography.fontFamily,
          useMaterial3: true,
        ),
        Brightness.light,
      );

  static ThemeData darkFromSeed(Color seed) => _decorate(
        FlexThemeData.dark(
          colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
          keyColors: const FlexKeyColors(
            useKeyColors: true,
            useSecondary: true,
            useTertiary: true,
          ),
          subThemesData: _subThemes,
          visualDensity: _density,
          fontFamily: AppTypography.fontFamily,
          useMaterial3: true,
        ),
        Brightness.dark,
      );

  // ---------- Caminho B: Material You (ColorScheme vindo do SO) ----------
  static ThemeData lightFromDynamic(ColorScheme dynamicScheme) => _decorate(
        FlexThemeData.light(
          colorScheme: dynamicScheme, // ja harmonizado pelo chamador
          subThemesData: _subThemes,
          visualDensity: _density,
          fontFamily: AppTypography.fontFamily,
          useMaterial3: true,
        ),
        Brightness.light,
      );

  static ThemeData darkFromDynamic(ColorScheme dynamicScheme) => _decorate(
        FlexThemeData.dark(
          colorScheme: dynamicScheme,
          subThemesData: _subThemes,
          visualDensity: _density,
          fontFamily: AppTypography.fontFamily,
          useMaterial3: true,
        ),
        Brightness.dark,
      );

  /// Aplica tokens/tipografia/extensions comuns (chamado pelos dois caminhos).
  static ThemeData _decorate(ThemeData base, Brightness b) {
    final fin = b == Brightness.dark ? FinanceColors.dark : FinanceColors.light;
    return base.copyWith(
      textTheme: AppTypography.tune(base.textTheme),
      extensions: <ThemeExtension<dynamic>>[fin],
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
```

> **Por que `FlexKeyColors`?** Com `useKeyColors: true`, o `primary` informado vira a **chave (seed)** que o algoritmo tonal do Material 3 expande para a paleta completa. E exatamente o que `ColorScheme.fromSeed(seedColor: ...)` faria, porem com o blend/refinamento de `surfaces` e `onColors` do FlexColorScheme. `useSecondary`/`useTertiary: true` aqui mantemos `false` na pratica se passarmos so `primary` (o algoritmo deriva secundaria/terciaria do seed); deixe-os `true` apenas se for fornecer secundaria/terciaria explicitas.

#### Fallback minimo (referencia — NAO e o caminho de producao)

Se um dia for preciso remover `flex_color_scheme`, o equivalente direto e:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness, // light ou dark
  ),
  useMaterial3: true,
);
```

---

### 7. Controller Riverpod — `theme_controller.dart`

Le as configuracoes do sembast no boot (assincrono) e expoe um `AsyncNotifier`. Mutacoes (mudar modo, seed, toggle dynamic) persistem e atualizam o estado. O `MaterialApp` observa este provider **acima** dele.

`lib/src/features/configuracoes/application/theme_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/theme_settings.dart';
import '../data/theme_settings_repository.dart';

part 'theme_controller.g.dart';

@riverpod
class ThemeController extends _$ThemeController {
  @override
  Future<ThemeSettings> build() async {
    final repo = ref.watch(themeSettingsRepositoryProvider);
    return repo.load(); // le store 'configuracoes'/'app'; default se ausente
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      _update((s) => s.copyWith(themeMode: mode));

  Future<void> setSeed(int argb) =>
      _update((s) => s.copyWith(seedArgb: argb));

  Future<void> setUseDynamic(bool value) =>
      _update((s) => s.copyWith(useDynamic: value));

  Future<void> _update(ThemeSettings Function(ThemeSettings) mutate) async {
    final repo = ref.read(themeSettingsRepositoryProvider);
    // Mantem estado atual em loading curto, persiste, e reemite.
    final current = state.valueOrNull ?? const ThemeSettings();
    final next = mutate(current);
    state = AsyncData(next);          // otimista (UI reage na hora)
    await repo.save(next);            // persiste no sembast
  }
}
```

Repositorio (le/grava no sembast — usa o `LocalDb` e a store `configuracoes` ja definida na secao de Storage):

`lib/src/features/configuracoes/data/theme_settings_repository.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';

import '../../../common/storage/local_db.dart';
import '../domain/theme_settings.dart';

part 'theme_settings_repository.g.dart';

@riverpod
ThemeSettingsRepository themeSettingsRepository(Ref ref) =>
    ThemeSettingsRepository(ref.watch(databaseProvider));

class ThemeSettingsRepository {
  ThemeSettingsRepository(this._db);
  final Database _db;

  static const _key = 'app';
  final _store = LocalDb.config; // stringMapStoreFactory.store('configuracoes')

  Future<ThemeSettings> load() async {
    final raw = await _store.record(_key).get(_db);
    if (raw == null) return const ThemeSettings();
    // tolera doc legado com chaves extras (moeda/locale/updatedAt etc.)
    return ThemeSettings.fromJson({
      'seedArgb': raw['seedArgb'] ?? _legacyHexToArgb(raw['corPrimaria']),
      'themeMode': raw['themeMode'] ?? raw['temaId'] ?? 'system',
      'useDynamic': raw['useDynamic'] ?? false,
    });
  }

  Future<void> save(ThemeSettings s) async {
    await _store.record(_key).put(_db, {
      ...s.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, merge: true);
  }

  int _legacyHexToArgb(Object? hex) {
    if (hex is! String) return 0xFF1565C0;
    final h = hex.replaceAll('#', '');
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }
}
```

---

### 8. Montagem no `MaterialApp` — `app.dart` (DynamicColorBuilder + fallback)

O `DynamicColorBuilder` envolve o `MaterialApp.router`. A logica de decisao e:

```
SE settings.useDynamic E o SO forneceu lightDynamic/darkDynamic (nao-null)
   -> usa Material You: harmonized() + AppTheme.*FromDynamic
SENAO
   -> usa seed manual: AppTheme.*FromSeed(settings.seedColor)
```

`lib/src/app.dart`:

```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/theme/app_theme.dart';
import 'common/theme/app_color_seeds.dart';
import 'features/configuracoes/application/theme_controller.dart';
import 'features/configuracoes/domain/theme_settings.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';

class InvestaBrApp extends ConsumerWidget {
  const InvestaBrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(themeControllerProvider);
    final router = ref.watch(goRouterProvider);

    // Enquanto carrega do sembast, usa defaults para nao piscar.
    final settings = settingsAsync.valueOrNull ?? const ThemeSettings();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final canUseDynamic =
            settings.useDynamic && lightDynamic != null && darkDynamic != null;

        final ThemeData light;
        final ThemeData dark;

        if (canUseDynamic) {
          // harmonized() aproxima as cores semanticas das cores do sistema.
          light = AppTheme.lightFromDynamic(lightDynamic.harmonized());
          dark = AppTheme.darkFromDynamic(darkDynamic.harmonized());
        } else {
          final seed = settings.seedColor; // fallback OBRIGATORIO
          light = AppTheme.lightFromSeed(seed);
          dark = AppTheme.darkFromSeed(seed);
        }

        return MaterialApp.router(
          title: 'Investa BR',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: settings.materialThemeMode,
          routerConfig: router,
          locale: ref.watch(localeControllerProvider), // idioma do usuário (null = seguir o sistema)
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
```

> **Por que `DynamicColorBuilder` envolve o `MaterialApp` (e nao o contrario)?** Porque ele precisa fornecer os `ColorScheme` dinamicos ANTES da construcao do tema. O `ProviderScope` do Riverpod fica acima de tudo (em `main.dart`), entao `ref.watch(themeControllerProvider)` esta disponivel aqui — atendendo a decisao "expor via Riverpod **acima** do MaterialApp".

`main.dart` (apenas o esqueleto relevante):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await LocalDb.instance.open(); // abre sembast
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const InvestaBrApp(),
    ),
  );
}
```

---

### 9. Matriz de decisao do tema (seed x dynamic x plataforma)

| `useDynamic` | Plataforma fornece paleta? | Resultado |
|---|---|---|
| `false` | (irrelevante) | **Seed manual** (`AppTheme.*FromSeed(seedColor)`) |
| `true` | Sim (Android 12+, accent desktop) | **Material You** (`harmonized()` + `*FromDynamic`) |
| `true` | Nao (iOS, Android < 12, sem accent) | **Seed manual** (fallback — `lightDynamic == null`) |

Disponibilidade de Material You por plataforma alvo:

| Plataforma | Material You (dynamic_color) |
|---|---|
| Android 12+ | Sim (paleta do wallpaper) |
| Android < 12 | Nao -> fallback seed |
| iOS | Nao -> fallback seed |
| Windows | Parcial (accent do sistema) |
| macOS | Parcial (accent do sistema) |
| Linux | Parcial/Nao -> fallback seed |

A UI deve **desabilitar (ou ocultar) o switch "Usar cor do sistema"** quando `lightDynamic == null`, com legenda "Indisponivel neste dispositivo".

---

### 10. Tela Ajustes > Aparencia — wireframe e widgets

```
+--------------------------------------------------------------+
|  <-  Aparencia                                                |
+--------------------------------------------------------------+
|  Modo                                                         |
|   [ Claro ]  [ Escuro ]  [ • Sistema ]      (SegmentedButton) |
|                                                               |
|  [✓] Usar cor do sistema (Material You)                       |
|      Indisponivel neste dispositivo   (quando dynamic==null)  |
|                                                               |
|  Cor-semente              (desabilitado se Material You ativo)|
|   ( ● )( ● )( ● )( ● )( ● )( ● )( ● )( ● )  [ Outra... ]      |
|     azul verde indigo teal roxo laran verm graf              |
|                                                               |
|  Pre-visualizacao                                             |
|   +------------------------------------------------------+   |
|   |  [ FilledButton ]  [ Chip ]   AppBar / Card           |  |
|   |  Patrimonio: R$ 128.450,77   ▲ 1,2%  (verde + icone)  |  |
|   +------------------------------------------------------+   |
+--------------------------------------------------------------+
```

Mapeamento de widgets:

| Elemento | Widget | Notas |
|---|---|---|
| Seletor de modo | `SegmentedButton<AppThemeMode>` | 3 segmentos, `selected` reflete `settings.themeMode` |
| Toggle Material You | `SwitchListTile` | `onChanged: null` (desabilitado) quando `dynamic == null` |
| Paleta de seeds | `Wrap` de `InkWell`/`ChoiceChip` circulares | alvo >= 48dp; borda no selecionado |
| "Outra..." | `showDialog` + color picker | grava `setSeed(argb)` |
| Preview | `Card` + `FilledButton` + chip + linha de variacao | usa `Theme.of(context)` ja atualizado |

Esqueleto do seletor de modo (acionando o controller):

```dart
SegmentedButton<AppThemeMode>(
  segments: const [
    ButtonSegment(value: AppThemeMode.light,  icon: Icon(Icons.light_mode),  label: Text('Claro')),
    ButtonSegment(value: AppThemeMode.dark,   icon: Icon(Icons.dark_mode),   label: Text('Escuro')),
    ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistema')),
  ],
  selected: {settings.themeMode},
  onSelectionChanged: (sel) =>
      ref.read(themeControllerProvider.notifier).setThemeMode(sel.first),
);
```

---

### 11. Persistencia: o que entra e o que NAO entra

- **Store sembast:** `configuracoes`, record key `app` (ja definido na secao Storage). Campos relevantes ao tema: `seedArgb` (int), `themeMode` (string `system|light|dark`), `useDynamic` (bool), `updatedAt`.
- **Export/Import:** as configuracoes ENTRAM no payload de export (bloco `data.configuracoes.app`), conforme a secao Import/Export. Logo, **o tema do usuario viaja no backup**. `cache_indicadores` NAO entra (derivado) — isso nao afeta o tema.
- **Migracao:** se um backup antigo trouxer `corPrimaria: "#RRGGBB"` / `temaId`, o `migratePayload` e o `_legacyHexToArgb` convertem para `seedArgb` no import; o `onVersionChanged` do sembast faz o mesmo para o banco em disco. Mantenha `LocalDb.schemaVersion` sincronizado.

---

### 12. Acessibilidade e formatacao (interacao com o tema)

- **Contraste AA Material 3:** `FlexKeyColors` + `harmonized()` ja produzem `onColors` com contraste adequado; NAO sobrescreva `onPrimary`/`onSurface` manualmente. Validar `FinanceColors` (verde/vermelho) contra `surface` em claro e escuro.
- **`textScaleFactor`:** os cards de indicadores e o patrimonio devem usar `Wrap`/`FittedBox` (decisao de UX) — o tema nao fixa tamanhos absolutos de texto; usa a escala tipografica M3 que respeita o scale do SO.
- **Alvos de toque >= 48dp:** garantido por `VisualDensity.adaptivePlatformDensity` + `Spacing.minTouchTarget` nos seletores de seed.
- **Variacao nunca so por cor:** sempre `Icon + Text + cor` (item 3), reforcando o requisito de acessibilidade dos graficos/cards.

---

### 13. Checklist de implementacao (ordem sugerida)

1. Adicionar deps: `flex_color_scheme: ^8.4.0`, `dynamic_color: ^1.8.1` (Riverpod/freezed/sembast ja no projeto).
2. Criar `design_tokens.dart`, `theme_extensions.dart`, `app_typography.dart`, `app_color_seeds.dart`.
3. Criar `app_theme.dart` (caminhos seed e dynamic + `_decorate`).
4. Criar `ThemeSettings` (freezed) e rodar `build_runner` (`*.freezed.dart`/`*.g.dart`).
5. Criar `ThemeSettingsRepository` (sembast) + `ThemeController` (`@riverpod`).
6. Envolver `MaterialApp.router` com `DynamicColorBuilder` em `app.dart`, observando `themeControllerProvider`.
7. Construir `aparencia_screen.dart` (modo + dynamic toggle + seed picker + preview).
8. Cobrir com testes: (a) `ThemeSettings.fromJson/toJson` (incl. legado hex->argb); (b) `ThemeController` persistindo via `ProviderContainer`/`overrideWith` com sembast in-memory; (c) widget test confirmando que `useDynamic=true` com `dynamic==null` cai no seed manual.

---

## Busca de Acoes, CNPJ & Recomendacoes

Esta secao especifica a feature `acoes` (busca, cotacao, fundamentos e sinais proprios) e o servico transversal de **enriquecimento por CNPJ** usado tambem pela feature `renda_fixa` (emissor de CDB/LCI/LCA/debenture). Tudo escrito para implementacao direta: arvore de arquivos, contratos Dart, parsers, cache, limites e wireframes.

> **Premissas herdadas das decisoes globais (nao re-decidir):** Riverpod 3 com `@riverpod` (codegen), `freezed 3` + `json_serializable`, `dio 5.9` com interceptors (base URL por API, token brapi, User-Agent, logging em debug, normalizacao de erro), `Result<T>` sealed na camada data/domain, `AsyncNotifier` + `AsyncValue.guard` na fronteira Riverpod, persistencia `sembast` (`databaseFactoryIo`), `go_router 17` tipado, `fl_chart` (CandlestickChart no detalhe), `intl` pt_BR. NAO usar `get_it`. NAO adicionar `http` (usar `dio`).

### 1. Escopo e fontes de dados

| Capacidade | Fonte primaria | Fallback | Auth | Limite relevante |
|---|---|---|---|---|
| Busca/autocomplete de ticker | brapi `/api/quote/list?search=` | (lista local cacheada) | Token brapi (opcional p/ lista) | 15k req/mes |
| Cotacao + dados de mercado | brapi `/api/quote/{ticker}` | cache diario | Token brapi (4 tickers sem token) | 1 ticker/req, update ~30min |
| Fundamentos (P/L, P/VP, DY, ROE) | brapi `?modules=defaultKeyStatistics,financialData,summaryProfile` | degrada (campos null) | Token brapi free | maioria dos modulos limitada no free |
| Recomendacoes de analistas | brapi `recommendationKey`/`targetMeanPrice` | **sinal proprio local** | **PRO pago** (null no free) | so PRO popula |
| CNPJ do emissor (renda fixa) | BrasilAPI `/api/cnpj/v1/{cnpj}` | OpenCNPJ -> ReceitaWS | Nenhuma (BrasilAPI/OpenCNPJ); ReceitaWS 3/min | fair use; OpenCNPJ 50 req/s |

**Decisao critica (CONFIRMADA por fetch jun/2026):** os campos de recomendacao de analistas (`recommendationKey`, `recommendationMean`, `targetMeanPrice`, `targetHighPrice`, `targetLowPrice`, `numberOfAnalystOpinions`) existem no schema mas **retornam `null` no plano free com HTTP 200** (so o plano PRO os popula). Portanto:

- O MVP gratuito **NAO promete** "recomendacao de analista".
- Geramos **sinais proprios** ("Sinais Investa BR"), calculados localmente a partir de fundamentos (P/L, P/VP, DY, ROE, divida/EBITDA quando disponivel), com rotulo explicito de que sao heuristicas, nao recomendacao (aspecto CVM).
- Se o usuario configurar um **token PRO**, a UI passa a exibir tambem o bloco de analistas (degradacao graciosa reversa). Detalhe na secao 7.

### 2. Token brapi em runtime config

O token brapi e **obrigatorio na pratica**: sem token so funcionam `PETR4`, `VALE3`, `MGLU3`, `ITUB4`. A busca ampla exige o token free (15k req/mes).

- Token persistido no store `configuracoes` (sembast), nunca hardcoded no codigo versionado.
- Pode vir tambem de `--dart-define=BRAPI_TOKEN=...` para builds de demo; precedencia: **config do usuario > dart-define > vazio**.
- Sem token valido, a feature opera em "modo demo" (4 tickers) e a UI exibe um banner pedindo o token (link para `brapi.dev`).

```dart
// lib/src/features/acoes/data/brapi_token_source.dart
@riverpod
class BrapiToken extends _$BrapiToken {
  @override
  Future<String?> build() async {
    final cfg = ref.watch(configRepoProvider);
    final saved = await cfg.lerString('brapiToken');
    if (saved != null && saved.isNotEmpty) return saved;
    const fromDefine = String.fromEnvironment('BRAPI_TOKEN');
    return fromDefine.isEmpty ? null : fromDefine;
  }

  Future<void> definir(String token) async {
    await ref.read(configRepoProvider).gravarString('brapiToken', token.trim());
    ref.invalidateSelf();
  }
}
```

O interceptor de token (decisao global do `dio`) injeta `Authorization: Bearer <token>` quando presente:

```dart
// lib/src/common/network/brapi_auth_interceptor.dart
class BrapiAuthInterceptor extends Interceptor {
  BrapiAuthInterceptor(this._tokenReader);
  final String? Function() _tokenReader; // le do provider sincronicamente (cache)

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenReader();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

### 3. Arvore de arquivos da feature `acoes` e do servico CNPJ

```
lib/src/
  common/
    network/
      dio_providers.dart            # Dio por API (brapi, brasilapi, opencnpj, receitaws)
      brapi_auth_interceptor.dart
  features/
    acoes/
      presentation/
        busca_acoes_screen.dart     # campo de busca + lista de resultados
        detalhe_acao_screen.dart    # cotacao + candlestick + fundamentos + sinais
        widgets/
          ticker_result_tile.dart
          fundamentos_grid.dart
          sinais_card.dart          # Sinais Investa BR (heuristica local)
          recomendacao_pro_card.dart# so visivel com token PRO (campos != null)
      application/
        sinais_service.dart         # heuristica P/L,P/VP,DY,ROE -> SinalAcao
      domain/
        ticker_resumo.dart          # freezed (resultado de busca)
        cotacao_acao.dart           # freezed (quote)
        fundamentos_acao.dart       # freezed (modules)
        sinal_acao.dart             # freezed sealed (resultado da heuristica)
      data/
        brapi_acoes_datasource.dart # dio -> brapi
        acoes_repository.dart       # Result<T> + cache sob demanda
        dto/
          brapi_quote_dto.dart      # json_serializable do payload bruto
    renda_fixa/
      data/
        cnpj/
          cnpj_repository.dart      # cascata BrasilAPI -> OpenCNPJ -> ReceitaWS
          brasilapi_cnpj_datasource.dart
          opencnpj_datasource.dart
          receitaws_datasource.dart
          dto/
            cnpj_brasilapi_dto.dart
            cnpj_opencnpj_dto.dart
        ...
      domain/
        empresa_cnpj.dart           # freezed (modelo unificado dos 3 provedores)
```

### 4. Modelos de dominio (freezed)

```dart
// domain/ticker_resumo.dart
@freezed
sealed class TickerResumo with _$TickerResumo {
  const factory TickerResumo({
    required String ticker,        // PETR4
    String? nome,                  // Petroleo Brasileiro SA
    String? logoUrl,               // https://icons.brapi.dev/icons/PETR4.svg
    String? tipo,                  // stock | fund | bdr
  }) = _TickerResumo;
  factory TickerResumo.fromJson(Map<String, Object?> j) => _$TickerResumoFromJson(j);
}

// domain/cotacao_acao.dart
@freezed
sealed class CotacaoAcao with _$CotacaoAcao {
  const factory CotacaoAcao({
    required String ticker,
    required String? nome,
    required double precoAtual,            // regularMarketPrice
    required double? variacaoPercent,      // regularMarketChangePercent
    double? maxDia,                        // regularMarketDayHigh
    double? minDia,                        // regularMarketDayLow
    double? max52s,                        // fiftyTwoWeekHigh
    double? min52s,                        // fiftyTwoWeekLow
    int? volume,
    double? valorMercado,                  // marketCap
    String? moeda,                         // BRL
    String? logoUrl,
    required DateTime obtidoEm,            // requestedAt
  }) = _CotacaoAcao;
  factory CotacaoAcao.fromJson(Map<String, Object?> j) => _$CotacaoAcaoFromJson(j);
}

// domain/fundamentos_acao.dart  (todos NULLABLE: free tier omite varios)
@freezed
sealed class FundamentosAcao with _$FundamentosAcao {
  const factory FundamentosAcao({
    double? precoLucro,        // priceEarnings / trailingPE
    double? precoVp,           // priceToBook
    double? dividendYield,     // dividendYield (fracao 0..1)
    double? roe,               // returnOnEquity (fracao)
    double? margemLiquida,     // profitMargins
    double? dividaEbitda,      // se disponivel
    double? lpa,               // earningsPerShare
    String? setor, String? industria, String? site, // summaryProfile
  }) = _FundamentosAcao;
  factory FundamentosAcao.fromJson(Map<String, Object?> j) => _$FundamentosAcaoFromJson(j);
}

// domain/sinal_acao.dart — resultado da heuristica local
enum NivelSinal { positivo, neutro, atencao, indisponivel }

@freezed
sealed class CriterioSinal with _$CriterioSinal {
  const factory CriterioSinal({
    required String rotulo,     // "P/L", "Dividend Yield"...
    required NivelSinal nivel,
    required String explicacao, // texto acessivel (icone+texto, nunca so cor)
    String? valorFormatado,     // "8,2" / "9,4%"
  }) = _CriterioSinal;
}

@freezed
sealed class SinalAcao with _$SinalAcao {
  const factory SinalAcao({
    required int pontuacao,            // 0..100
    required NivelSinal nivelGeral,
    required List<CriterioSinal> criterios,
    required int criteriosDisponiveis, // quantos puderam ser avaliados
  }) = _SinalAcao;
}

// domain/empresa_cnpj.dart — modelo unificado dos 3 provedores
@freezed
sealed class EmpresaCnpj with _$EmpresaCnpj {
  const factory EmpresaCnpj({
    required String cnpj,              // 14 digitos normalizados
    required String razaoSocial,
    String? nomeFantasia,
    String? situacaoCadastral,         // ATIVA / BAIXADA / ...
    String? cnaeFiscal,
    String? cnaeDescricao,
    String? naturezaJuridica,
    String? porte,
    double? capitalSocial,
    String? uf, String? municipio, String? bairro,
    String? logradouro, String? numero, String? cep,
    @Default(<SocioCnpj>[]) List<SocioCnpj> socios,
    required String fonte,             // brasilapi | opencnpj | receitaws
    required DateTime obtidoEm,
  }) = _EmpresaCnpj;
  factory EmpresaCnpj.fromJson(Map<String, Object?> j) => _$EmpresaCnpjFromJson(j);
}

@freezed
sealed class SocioCnpj with _$SocioCnpj {
  const factory SocioCnpj({required String nome, String? qualificacao, String? faixaEtaria}) = _SocioCnpj;
  factory SocioCnpj.fromJson(Map<String, Object?> j) => _$SocioCnpjFromJson(j);
}
```

### 5. Fluxo de busca de acao e exibicao

```
                   +------------------------------------------+
  usuario digita   | BuscaAcoesScreen                          |
  "petr"  -------> |  debounce 350ms                           |
                   |  AcoesNotifier.buscar(termo)              |
                   +---------------------+--------------------+
                                         |
                  acoesRepositoryProvider.buscar(termo)
                                         |
            cache de lista (sembast 'cache_acoes', TTL 24h) ?
              sim -> filtra localmente por prefixo/contains
              nao -> GET brapi /quote/list?search={termo}&token
                                         |
                         List<TickerResumo>  (AsyncValue)
                                         |
       tap em um resultado -> go_router push /acoes/detalhe/:ticker
                                         |
                   +------------------------------------------+
                   | DetalheAcaoScreen(ticker)                 |
                   |  detalheAcaoProvider(ticker)              |
                   |   -> GET /quote/{ticker}                  |
                   |        ?range=3mo&interval=1d             |
                   |        &modules=defaultKeyStatistics,     |
                   |          financialData,summaryProfile     |
                   |   parse -> CotacaoAcao + Fundamentos +    |
                   |            historico p/ CandlestickChart  |
                   |   sinais = SinaisService.avaliar(fund)    |
                   +------------------------------------------+
```

**Regras de UX:**
- **Debounce de 350ms** na busca para nao gastar requisicoes (limite 15k/mes).
- **1 ticker por requisicao** no detalhe (limite do free) — nunca agrupar tickers.
- Historico limitado a `range=3mo` (free entrega ~3 meses); para ranges maiores exibir aviso "Historico limitado no plano gratuito".
- Sem token: lista de busca pode falhar; cair para uma lista local fixa dos 4 tickers de teste + mensagem.

#### Wireframe — Busca

```
+------------------------------------------------------+
| ←  Buscar acoes                                       |
+------------------------------------------------------+
| 🔎 [ petr                                    ✕ ]      |
+------------------------------------------------------+
| Resultados                                            |
|  [logo] PETR4  Petroleo Brasileiro PN     [ + ]       |
|  [logo] PETR3  Petroleo Brasileiro ON     [ + ]       |
|  [logo] PETZ3  Petz                       [ + ]       |
+------------------------------------------------------+
| (sem token)  ⓘ Configure seu token brapi gratuito    |
|              para buscar todas as acoes.  [Ajustes]   |
+------------------------------------------------------+
```

#### Wireframe — Detalhe

```
+------------------------------------------------------+
| ←  PETR4   Petroleo Brasileiro PN          [+ add]    |
+------------------------------------------------------+
|  R$ 38,54   ▼ 1,33%  (icone seta + texto)             |
|  Max 38,78 / Min 38,20   ·   52s: 29,31–50,69         |
|  Atualizado em 17/06/2026 09:21  🔄                   |
+------------------------------------------------------+
|  [ CandlestickChart 3M ▾  — fl_chart ]                |
|  Legenda textual: abertura/fech/max/min por dia       |
+------------------------------------------------------+
|  Fundamentos                                          |
|   P/L 4,62   P/VP —   DY —   ROE —                     |
|   (— = indisponivel no plano gratuito)                |
+------------------------------------------------------+
|  Sinais Investa BR  (heuristica, NAO e recomendacao)  |
|   Pontuacao: 60/100  · NEUTRO                          |
|   ✓ P/L baixo (4,6) — preco atrativo vs lucro         |
|   • DY indisponivel                                   |
|   ⚠ Avaliacao parcial: 1 de 4 criterios disponiveis   |
+------------------------------------------------------+
|  (so com token PRO) Analistas: COMPRA · alvo R$ 45,00 |
+------------------------------------------------------+
```

### 6. Datasource e repositorio brapi (com Result + 429 backoff)

#### Payload de cotacao (confirmado ao vivo)

```json
{
  "results": [{
    "symbol": "PETR4", "longName": "Petroleo Brasileiro SA Pfd", "currency": "BRL",
    "regularMarketPrice": 38.54, "regularMarketChangePercent": -1.33,
    "regularMarketDayHigh": 38.78, "regularMarketDayLow": 38.2,
    "regularMarketVolume": 36250100, "marketCap": 532981244102,
    "fiftyTwoWeekLow": 29.31, "fiftyTwoWeekHigh": 50.69,
    "priceEarnings": 4.617, "earningsPerShare": 8.347,
    "logourl": "https://icons.brapi.dev/icons/PETR4.svg",
    "historicalDataPrice": [{"date": 1781..., "open": 38.1, "high": 38.9, "low": 37.9, "close": 38.5, "volume": 30000000}],
    "financialData": {"recommendationKey": null, "targetMeanPrice": null, "numberOfAnalystOpinions": null}
  }],
  "requestedAt": "2026-06-17T12:21:14.095Z", "took": 2
}
```

> **Atencao ao parsing:** valores numericos podem vir como `int` ou `double` no JSON — sempre converter via `(v as num?)?.toDouble()`. Campos de analista podem estar **ausentes OU presentes com `null`** — tratar ambos como indisponivel.

```dart
// data/acoes_repository.dart
@riverpod
AcoesRepository acoesRepository(Ref ref) =>
    AcoesRepository(ref.watch(brapiAcoesDatasourceProvider), ref.watch(localDbProvider));

class AcoesRepository {
  AcoesRepository(this._ds, this._db);
  final BrapiAcoesDatasource _ds;
  final Database _db;

  static final _cacheAcoes = stringMapStoreFactory.store('cache_acoes');

  Future<Result<List<TickerResumo>>> buscar(String termo) async {
    if (termo.trim().length < 2) return const Success([]);
    try {
      final dtos = await _ds.buscarLista(termo);
      return Success(dtos.map((d) => d.toResumo()).toList());
    } on DioException catch (e) {
      return Failure(mapDioToFailure(e)); // interceptor ja normalizou
    }
  }

  /// Detalhe com cache diario SOB DEMANDA (chave ticker+yyyy-MM-dd).
  Future<Result<DetalheAcao>> detalhe(String ticker, {bool forcar = false}) async {
    final hoje = _hojeSaoPaulo();
    final key = 'detalhe_${ticker}_$hoje';
    final cached = await _cacheAcoes.record(key).get(_db);
    if (!forcar && cached != null) {
      return Success(DetalheAcao.fromJson(cached['payload']! as Map<String, Object?>));
    }
    try {
      final det = await _ds.detalhe(ticker); // 1 ticker/req
      await _cacheAcoes.record(key).put(_db, {
        'payload': det.toJson(),
        'fetchedAt': DateTime.now().toIso8601String(),
      });
      return Success(det);
    } on DioException catch (e) {
      // fallback offline: serve cache de hoje OU mais recente, marcando stale
      final any = await _maisRecente(ticker);
      if (any != null) return Success(any.copyWith(stale: true));
      return Failure(mapDioToFailure(e));
    }
  }

  String _hojeSaoPaulo() => DateTime.now().toUtc()
      .subtract(const Duration(hours: 3)).toIso8601String().substring(0, 10);
}
```

**Tratamento de HTTP 429 (cota estourada):** retry com **backoff exponencial** limitado, depois servir cache stale. Implementado via interceptor dedicado no `dio` do brapi:

```dart
// common/network/retry_429_interceptor.dart
class Retry429Interceptor extends Interceptor {
  Retry429Interceptor(this._dio, {this.maxRetries = 2});
  final Dio _dio; final int maxRetries;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final tentativa = (err.requestOptions.extra['retry'] as int?) ?? 0;
    if (status == 429 && tentativa < maxRetries) {
      final espera = Duration(milliseconds: 500 * (1 << tentativa)); // 0.5s,1s
      await Future<void>.delayed(espera);
      final opts = err.requestOptions..extra['retry'] = tentativa + 1;
      try {
        handler.resolve(await _dio.fetch<dynamic>(opts));
        return;
      } on DioException catch (e) { handler.next(e); return; }
    }
    handler.next(err); // 429 final vira Failure -> repo serve cache stale
  }
}
```

### 7. Recomendacoes: heuristica gratuita ("Sinais Investa BR")

Como recomendacao de analista exige PRO, o MVP calcula sinais **localmente** a partir dos fundamentos. A heuristica e simples, transparente e tolerante a campos ausentes (degrada para "avaliacao parcial").

**Faixas e pontuacao por criterio** (cada criterio vale ate 25 pts; pontuacao final = media dos criterios *disponiveis* re-escalada para 0..100):

| Criterio | Positivo (25) | Neutro (12) | Atencao (0) | Indisponivel |
|---|---|---|---|---|
| **P/L** (`precoLucro`) | `0 < P/L <= 12` | `12 < P/L <= 25` | `P/L > 25` ou `<= 0` | null |
| **P/VP** (`precoVp`) | `0 < P/VP <= 1,5` | `1,5 < P/VP <= 3` | `P/VP > 3` ou `<= 0` | null |
| **DY** (`dividendYield`) | `DY >= 6%` | `3% <= DY < 6%` | `DY < 3%` | null |
| **ROE** (`roe`) | `ROE >= 15%` | `10% <= ROE < 15%` | `ROE < 10%` | null |

> DY e ROE chegam da brapi como **fracao** (0,094 = 9,4%) — converter na exibicao com `NumberFormat.decimalPercentPattern(locale:'pt_BR')`.

```dart
// application/sinais_service.dart
@riverpod
SinaisService sinaisService(Ref ref) => const SinaisService();

class SinaisService {
  const SinaisService();

  SinalAcao avaliar(FundamentosAcao f) {
    final criterios = <CriterioSinal>[
      _faixa('P/L', f.precoLucro, pos: (v) => v > 0 && v <= 12,
          neu: (v) => v > 12 && v <= 25,
          fmt: (v) => v.toStringAsFixed(1),
          okMsg: 'preco atrativo vs lucro', atMsg: 'preco alto vs lucro'),
      _faixa('P/VP', f.precoVp, pos: (v) => v > 0 && v <= 1.5,
          neu: (v) => v > 1.5 && v <= 3,
          fmt: (v) => v.toStringAsFixed(2),
          okMsg: 'abaixo/perto do valor patrimonial', atMsg: 'caro vs patrimonio'),
      _faixa('Dividend Yield', f.dividendYield, pos: (v) => v >= 0.06,
          neu: (v) => v >= 0.03,
          fmt: (v) => '${(v * 100).toStringAsFixed(1)}%',
          okMsg: 'bom retorno em dividendos', atMsg: 'dividendos baixos'),
      _faixa('ROE', f.roe, pos: (v) => v >= 0.15,
          neu: (v) => v >= 0.10,
          fmt: (v) => '${(v * 100).toStringAsFixed(1)}%',
          okMsg: 'alta rentabilidade', atMsg: 'rentabilidade baixa'),
    ];
    final disponiveis = criterios.where((c) => c.nivel != NivelSinal.indisponivel).toList();
    if (disponiveis.isEmpty) {
      return SinalAcao(pontuacao: 0, nivelGeral: NivelSinal.indisponivel,
          criterios: criterios, criteriosDisponiveis: 0);
    }
    final pts = disponiveis.map(_pontos).reduce((a, b) => a + b);
    final score = (pts / (disponiveis.length * 25) * 100).round();
    final nivel = score >= 70 ? NivelSinal.positivo
        : score >= 40 ? NivelSinal.neutro : NivelSinal.atencao;
    return SinalAcao(pontuacao: score, nivelGeral: nivel,
        criterios: criterios, criteriosDisponiveis: disponiveis.length);
  }

  int _pontos(CriterioSinal c) => switch (c.nivel) {
        NivelSinal.positivo => 25, NivelSinal.neutro => 12, _ => 0,
      };

  CriterioSinal _faixa(String rotulo, double? v, {
    required bool Function(double) pos, required bool Function(double) neu,
    required String Function(double) fmt, required String okMsg, required String atMsg,
  }) {
    if (v == null) {
      return CriterioSinal(rotulo: rotulo, nivel: NivelSinal.indisponivel,
          explicacao: 'indisponivel no plano gratuito');
    }
    final nivel = pos(v) ? NivelSinal.positivo : neu(v) ? NivelSinal.neutro : NivelSinal.atencao;
    return CriterioSinal(rotulo: rotulo, nivel: nivel, valorFormatado: fmt(v),
        explicacao: nivel == NivelSinal.atencao ? atMsg : okMsg);
  }
}
```

**Degradacao graciosa (obrigatoria):**
- No free, `precoLucro` e `lpa` costumam vir (vem na cotacao base); P/VP, DY, ROE frequentemente sao `null` -> o card mostra "Avaliacao parcial: N de 4 criterios disponiveis" e a pontuacao re-escala so sobre os disponiveis.
- O card **sempre** carrega o aviso: *"Sinais calculados automaticamente a partir de indicadores publicos. Conteudo informativo, NAO e recomendacao de investimento (CVM)."*
- **Token PRO:** se `recommendationKey != null`, exibir adicionalmente `RecomendacaoProCard` (compra/venda/manter + `targetMeanPrice` + `numberOfAnalystOpinions`). Mapear `recommendationKey`: `strong_buy/buy -> COMPRA`, `hold -> MANTER`, `sell/strong_sell -> VENDA`. Esse card e o unico ponto que consome dados de analista e so aparece quando preenchido.

### 8. CNPJ — enriquecimento do emissor (cascata com fallback)

Usado no cadastro de renda fixa (campo "Emissor", botao "🔎 CNPJ"). Normalizar **sempre** para 14 digitos antes de chamar.

```
normalizarCnpj("19.131.243/0001-97") -> "19131243000197"

  cnpjRepository.consultar(cnpj)
        |
   cache local (store 'cache_cnpj', TTL longo = 30 dias) ?
     sim -> retorna EmpresaCnpj
     nao v
   BrasilAPI  /api/cnpj/v1/{cnpj}  (principal, sem auth)
     ok 200 -> mapeia -> grava cache -> retorna
     erro / 404 / 429 / timeout v
   OpenCNPJ   api.opencnpj.org/{cnpj}  (50 req/s, sem auth)   [ATENCAO schema: QSA, endereco PLANO]
     ok 200 -> mapeia -> grava cache -> retorna
     erro v
   ReceitaWS  receitaws.com.br/v1/cnpj/{cnpj}  (3 req/min!)   [fallback PONTUAL, respeitar rate]
     ok 200 -> mapeia -> grava cache -> retorna
     erro -> Failure
```

```dart
String normalizarCnpj(String entrada) => entrada.replaceAll(RegExp(r'\D'), '');

@riverpod
CnpjRepository cnpjRepository(Ref ref) => CnpjRepository(
      brasilApi: ref.watch(brasilApiCnpjDatasourceProvider),
      openCnpj: ref.watch(openCnpjDatasourceProvider),
      receitaWs: ref.watch(receitaWsDatasourceProvider),
      db: ref.watch(localDbProvider),
    );

class CnpjRepository {
  CnpjRepository({required this.brasilApi, required this.openCnpj,
      required this.receitaWs, required this.db});
  final BrasilApiCnpjDatasource brasilApi;
  final OpenCnpjDatasource openCnpj;
  final ReceitaWsDatasource receitaWs;
  final Database db;

  static final _cache = stringMapStoreFactory.store('cache_cnpj');
  static const _ttl = Duration(days: 30);

  Future<Result<EmpresaCnpj>> consultar(String entrada) async {
    final cnpj = normalizarCnpj(entrada);
    if (cnpj.length != 14) return const Failure(ValidacaoFailure('CNPJ invalido'));

    final cached = await _cache.record(cnpj).get(db);
    if (cached != null) {
      final emp = EmpresaCnpj.fromJson(cached['payload']! as Map<String, Object?>);
      if (DateTime.now().difference(emp.obtidoEm) < _ttl) return Success(emp);
    }

    for (final fetch in <Future<EmpresaCnpj> Function()>[
      () => brasilApi.consultar(cnpj),
      () => openCnpj.consultar(cnpj),
      () => receitaWs.consultar(cnpj), // 3/min: ultimo recurso
    ]) {
      try {
        final emp = await fetch();
        await _cache.record(cnpj).put(db, {'payload': emp.toJson()});
        return Success(emp);
      } on DioException {
        continue; // tenta proximo provedor
      }
    }
    if (cached != null) {
      return Success(EmpresaCnpj.fromJson(cached['payload']! as Map<String, Object?>));
    }
    return const Failure(RedeFailure('Nao foi possivel consultar o CNPJ'));
  }
}
```

#### Diferencas de schema entre provedores (parsers distintos por DTO)

| Campo unificado | BrasilAPI | OpenCNPJ | ReceitaWS |
|---|---|---|---|
| Razao social | `razao_social` | `razao_social` | `nome` |
| Nome fantasia | `nome_fantasia` | `nome_fantasia` | `fantasia` |
| Situacao | `situacao_cadastral` | `situacao_cadastral` | `situacao` |
| CNAE principal | `cnae_fiscal` + `cnae_fiscal_descricao` | `cnaes[]` com `is_principal=true` | `atividade_principal[0]` |
| Socios | `qsa[]` | **`QSA[]`** (maiusculo!) | `qsa[]` |
| Endereco | campos planos | **plano** (`tipo_logradouro`, `logradouro`, `numero`, `bairro`, `cep`, `uf`, `municipio`) | decomposto (`logradouro`, `numero`, `bairro`, `municipio`, `uf`, `cep`) |
| Capital social | `capital_social` (num) | `capital_social` (string) | `capital_social` (string com virgula) |

**Pegadinhas confirmadas (jun/2026):**
- **OpenCNPJ:** array de socios e `QSA` (maiusculo), NAO `socios`; endereco e **plano** (sem objeto aninhado); `cnaes[]` traz `{codigo, descricao, is_principal}`; `cnpj_cpf_socio` vem mascarado.
- **ReceitaWS:** `ultima_atualizacao` vem em **ISO 8601** (`2026-06-15T23:59:59.000Z`), mas `abertura`/`data_situacao` em `dd/MM/yyyy` — parsers diferentes por campo. Limite **3 req/min** (aguardar ~20s entre chamadas) -> manter como ultimo recurso, com cache agressivo.
- **BrasilAPI `/cnpj`** e o endpoint mais throttled da BrasilAPI (depende da Receita downstream) — por isso a cascata + cache de 30 dias e essencial.
- Cada provedor tem seu proprio `Dio` (base URL via interceptor) e seu proprio `User-Agent` padrao.

#### Wireframe — CNPJ no cadastro de renda fixa

```
+------------------------------------------------------+
| Emissor   [ 19.131.243/0001-97          🔎 Buscar ]   |
|           ⟳ consultando...                            |
+------------------------------------------------------+
| ✓ GOOGLE BRASIL INTERNET LTDA.                        |
|   Situacao: ATIVA · Porte: DEMAIS                     |
|   CNAE: 6319-4/00 Portais, provedores...              |
|   Sao Paulo/SP   · fonte: BrasilAPI                   |
|   [ Usar este emissor ]                               |
+------------------------------------------------------+
```

### 9. Limites de requisicao e cache (resumo operacional)

| API | Limite | Estrategia no app |
|---|---|---|
| **brapi (cotacao/detalhe)** | 15k req/mes, **1 ticker/req**, update ~30min, hist ~3 meses | Cache diario por `ticker+data` (sob demanda, NAO no boot); debounce 350ms na busca; `range=3mo`; 429 -> backoff (0,5s/1s) -> cache stale |
| **brapi (busca/lista)** | conta na cota | Cachear lista (`cache_acoes`, TTL 24h) e filtrar localmente; sem token -> 4 tickers de teste |
| **brapi (analistas)** | so PRO popula | Nao consumir no free; heuristica local substitui |
| **BrasilAPI /cnpj** | fair use, throttled | Cache 30 dias por CNPJ; cascata para OpenCNPJ |
| **OpenCNPJ** | 50 req/s por IP | Fallback de alto volume; cache 30 dias |
| **ReceitaWS** | **3 req/min** | Ultimo recurso; cache 30 dias; nao usar em rajada |

**Cache: por que SOB DEMANDA e nao no boot.** Acoes e CNPJ **nao** entram no batch de boot (decisao global: o boot so busca SGS `/ultimos/1`, feriados e cotacoes da carteira). Acoes/CNPJ usam cache proprio acionado quando o usuario abre a tela, para nao pesar o boot nem queimar a cota mensal de 15k. Os dois usam as mesmas regras gerais de cache: chave por dia (acoes) / TTL longo (CNPJ), `stale-while-revalidate`, fallback offline marcando `stale=true`, e botao de refresh manual que forca refetch (`forcar: true`).

**Stores sembast desta secao** (separados dos 4 stores principais do app, pois sao cache derivado e **nao entram no export**):
- `cache_acoes` — detalhe/cotacao por `detalhe_{ticker}_{yyyy-MM-dd}` e lista de busca.
- `cache_cnpj` — `EmpresaCnpj` por CNPJ (14 digitos), TTL 30 dias.

### 10. Testes obrigatorios desta secao

- **Parsing brapi:** cotacao com numeros `int`/`double` mistos; campos de analista ausentes vs `null`; `historicalDataPrice` -> velas do CandlestickChart.
- **SinaisService:** todas as faixas (P/L, P/VP, DY, ROE) nos 3 niveis; caso "todos null" -> `NivelSinal.indisponivel`; re-escala com avaliacao parcial (ex.: so P/L disponivel).
- **Cascata CNPJ:** BrasilAPI falha -> OpenCNPJ assume; mapeamento de `QSA` (maiusculo) e endereco plano do OpenCNPJ; `ultima_atualizacao` ISO do ReceitaWS; `normalizarCnpj` removendo mascara; CNPJ != 14 digitos -> `ValidacaoFailure`.
- **Cache:** servir do cache quando `data==hoje`; 429 -> backoff -> stale; fallback offline retorna ultimo snapshot com `stale=true`.
- Mocks via `mocktail`; injetar datasources fakes com `overrideWith` em `ProviderContainer`.

---

## Tratamento de Erros, Offline & Resiliencia

Esta secao define o contrato de erros do **Investa BR** ponta a ponta: como erros nascem na camada `data` (parse, rede, HTTP), como sao tipados em `Failure` e transportados por `Result<T>`, como sobem ate o Riverpod via `AsyncValue.guard`, como sao traduzidos para mensagens em pt-BR na UI, e como o app se comporta offline / com dados desatualizados (stale). Tudo aqui e **normativo**: o implementador deve seguir os nomes de tipo, assinaturas e tabelas exatamente como descritos, pois sao referenciados por outras secoes (rede, cache diario, calculo financeiro).

### Principios de design

1. **Camadas `data`/`domain` nunca lancam para a UI.** Toda chamada de I/O (dio, sembast, file_picker, CSV) e capturada e convertida em `Result<T>` (`Success`/`FailureResult`). Excecoes so existem dentro da camada `data` e sao imediatamente normalizadas.
2. **Um unico ponto de normalizacao de `DioException`.** Um interceptor (`ErrorNormalizerInterceptor`) converte `DioException` em `NetworkFailure` tipado *antes* de chegar ao datasource. O datasource so monta o `Failure` final de dominio (ex.: `IndicadorIndisponivelFailure`).
3. **Fronteira Riverpod usa `AsyncValue`.** AsyncNotifiers expoem `AsyncValue<T>` (sealed: `data`/`loading`/`error`). A conversao `Result<T> -> AsyncValue<T>` e feita por um helper unico (`ResultX.toAsync` / `guardResult`). A UI faz `switch` em `AsyncValue` + `switch` em `Failure` para escolher a mensagem.
4. **Toda mensagem ao usuario e pt-BR e vem de um unico mapeador** (`FailureMessages.of(failure, l10n)`), alimentado pelo `.arb`. Nunca expor `toString()` de excecao na UI.
5. **Offline e estado de primeira classe, nao erro.** Quando ha cache valido (mesmo vencido), o app serve o cache marcando `stale=true` e exibe banner; so vira erro de tela cheia quando nao ha nenhum dado para mostrar.
6. **Resiliencia configuravel por API.** Timeout, retry e backoff sao definidos por dominio (BCB SGS, brapi, BrasilAPI, OpenCNPJ, AwesomeAPI, Tesouro CKAN) via `RetryPolicy`, porque os limites e o comportamento de cada API diferem (ex.: brapi 429 -> backoff agressivo; CKAN CSV de ~13,5 MiB -> timeout longo).

### Arvore de arquivos

```
lib/src/common/
  errors/
    failure.dart                # sealed class Failure + subclasses (freezed)
    result.dart                 # sealed class Result<T> (Success/FailureResult) + extensions
    async_value_x.dart          # guardResult / Result.toAsync / Failure.toAsyncError
    failure_messages.dart       # Failure -> String pt-BR (usa AppLocalizations)
  network/
    dio_factory.dart            # cria Dio por API com baseUrl/UA/token
    interceptors/
      base_url_interceptor.dart
      brapi_token_interceptor.dart
      logging_interceptor.dart  # so em debug
      error_normalizer_interceptor.dart  # DioException -> NetworkFailure
      retry_interceptor.dart    # retry/backoff por RetryPolicy
    retry_policy.dart           # RetryPolicy + politicas por API
    network_info.dart           # checagem de conectividade (best-effort)
  widgets/
    error_view.dart             # estado de erro de tela cheia (icone+texto+acao)
    stale_banner.dart           # banner "dados de DD/MM as HH:mm"
    empty_view.dart             # estado vazio
```

---

### 1. Tipo `Failure` (sealed) e `Result<T>`

`Failure` e uma **sealed class freezed** (Dart 3), o que da pattern matching exaustivo no `switch`. Cada variante carrega o minimo para a UI e para diagnostico (a `causa` tecnica nunca vai para a tela; serve so para log em debug).

```dart
// lib/src/common/errors/failure.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const Failure._();

  /// Sem conexao / DNS / socket. dataPossivelEmCache indica se ha fallback.
  const factory Failure.semConexao({Object? causa}) = SemConexaoFailure;

  /// Timeout (connect/send/receive) estourado.
  const factory Failure.timeout({
    required TipoTimeout tipo,
    Object? causa,
  }) = TimeoutFailure;

  /// HTTP 4xx (exceto 401/404/429 que tem variantes proprias).
  const factory Failure.respostaInvalida({
    required int statusCode,
    String? corpo,
    Object? causa,
  }) = RespostaInvalidaFailure;

  /// HTTP 401/403 (token brapi ausente/invalido).
  const factory Failure.naoAutorizado({int? statusCode, Object? causa}) =
      NaoAutorizadoFailure;

  /// HTTP 404 (recurso/serie/CNPJ inexistente).
  const factory Failure.naoEncontrado({Object? causa}) = NaoEncontradoFailure;

  /// HTTP 429 — rate limit (brapi, OpenCNPJ, ReceitaWS). retryApos opcional.
  const factory Failure.limiteRequisicoes({
    Duration? retryApos,
    Object? causa,
  }) = LimiteRequisicoesFailure;

  /// HTTP 5xx — falha do servidor.
  const factory Failure.servidor({required int statusCode, Object? causa}) =
      ServidorFailure;

  /// Corpo nao e o JSON/CSV esperado (ex.: SGS retornou HTML de erro;
  /// valor string nao parseavel; CSV com colunas faltando).
  const factory Failure.parse({required String detalhe, Object? causa}) =
      ParseFailure;

  /// Erro de persistencia local (sembast/arquivo).
  const factory Failure.armazenamento({String? detalhe, Object? causa}) =
      ArmazenamentoFailure;

  /// Import/Export: arquivo invalido, checksum, versao incompativel.
  const factory Failure.importExport({
    required ImportExportErro motivo,
    String? detalhe,
    Object? causa,
  }) = ImportExportFailure;

  /// Validacao de entrada do usuario (formularios) — nao e erro de I/O.
  const factory Failure.validacao({required String campo, required String detalhe}) =
      ValidacaoFailure;

  /// Coringa para o que nao foi previsto. Em debug, logar `causa`/`stack`.
  const factory Failure.desconhecido({Object? causa, StackTrace? stack}) =
      DesconhecidoFailure;
}

enum TipoTimeout { conexao, envio, recebimento }

enum ImportExportErro {
  arquivoNaoEhInvestaBr,   // campo app != 'investa_br'
  versaoMaisNova,          // schemaVersion do arquivo > app
  checksumInvalido,        // sha256 nao confere
  jsonMalformado,          // jsonDecode falhou
  semPermissaoArquivo,     // file_picker/IO negou
}
```

`Result<T>` e uma sealed class minima (sem `fpdart` obrigatorio, conforme decisao global). Inclui extensions de uso diario.

```dart
// lib/src/common/errors/result.dart
import 'failure.dart';

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;

  /// Valor ou null (uso pontual; prefira pattern matching).
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        FailureResult() => null,
      };

  /// Mapeia o valor mantendo o Failure intacto.
  Result<R> map<R>(R Function(T) f) => switch (this) {
        Success(:final value) => Success(f(value)),
        FailureResult(:final failure) => FailureResult(failure),
      };

  /// Encadeia outra operacao que tambem retorna Result.
  Result<R> flatMap<R>(Result<R> Function(T) f) => switch (this) {
        Success(:final value) => f(value),
        FailureResult(:final failure) => FailureResult(failure),
      };

  /// Pattern matching ergonomico.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        FailureResult(:final failure) => onFailure(failure),
      };
}
```

**Helper de captura na camada `data`** (envolve qualquer bloco assincrono e ja normaliza para `Failure`):

```dart
// usado pelos datasources/repositories
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Success(await body());
  } on Failure catch (f) {
    // Failure ja normalizado por interceptor (NetworkFailure) ou por parse local.
    return FailureResult(f);
  } on FormatException catch (e, s) {
    return FailureResult(Failure.parse(detalhe: e.message, causa: e));
  } catch (e, s) {
    return FailureResult(Failure.desconhecido(causa: e, stack: s));
  }
}
```

### 2. Fronteira Riverpod: `Result<T>` -> `AsyncValue<T>`

Os repositorios retornam `Result<T>`. Os AsyncNotifiers convertem para `AsyncValue<T>` mantendo o `Failure` como `error`, para a UI fazer pattern match. Helper unico:

```dart
// lib/src/common/errors/async_value_x.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'failure.dart';
import 'result.dart';

extension ResultToAsync<T> on Result<T> {
  AsyncValue<T> toAsync() => switch (this) {
        Success(:final value) => AsyncData(value),
        FailureResult(:final failure) =>
          AsyncError(failure, StackTrace.current),
      };
}

/// Executa um corpo que retorna Result<T> e devolve AsyncValue<T>,
/// preservando o Failure como error (sem virar Exception generica).
Future<AsyncValue<T>> guardResult<T>(
  Future<Result<T>> Function() body,
) async {
  try {
    return (await body()).toAsync();
  } on Failure catch (f) {
    return AsyncError(f, StackTrace.current);
  } catch (e, s) {
    return AsyncError(Failure.desconhecido(causa: e, stack: s), s);
  }
}
```

Exemplo de AsyncNotifier (indicadores da home):

```dart
// features/indicadores/presentation/indicadores_controller.dart
@riverpod
class IndicadoresController extends _$IndicadoresController {
  @override
  Future<SnapshotIndicadores> build() async {
    final repo = ref.watch(indicadoresRepositoryProvider);
    final res = await repo.obterDoDia(); // Result<SnapshotIndicadores>
    // Converte Failure -> AsyncError. AsyncValue.guard alternativo abaixo.
    return res.fold(
      onSuccess: (s) => s,
      onFailure: (f) => throw f, // capturado pelo build do AsyncNotifier
    );
  }

  Future<void> atualizar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(indicadoresRepositoryProvider);
      final res = await repo.atualizarForcado(); // ignora cache
      return res.fold(onSuccess: (s) => s, onFailure: (f) => throw f);
    });
  }
}
```

> Por que `throw f` dentro de `AsyncValue.guard`/`build`: o `Failure` e relancado como objeto de erro e fica em `AsyncError.error` como `Failure`. Como `Failure` e sealed, a UI faz `switch` exaustivo sem casts. **Nunca** lance `Exception(string)` aqui — perderia o tipo.

### 3. Mapeamento de erros de rede/API para mensagens pt-BR

#### 3.1 `DioException` -> `Failure` (interceptor unico)

```dart
// lib/src/common/network/interceptors/error_normalizer_interceptor.dart
class ErrorNormalizerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = _mapear(err);
    // Rejeita com o Failure embrulhado para o datasource extrair via guard().
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: failure, // <- Failure tipado viaja em .error
        type: err.type,
        response: err.response,
      ),
    );
  }

  Failure _mapear(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return const Failure.timeout(tipo: TipoTimeout.conexao);
      case DioExceptionType.sendTimeout:
        return const Failure.timeout(tipo: TipoTimeout.envio);
      case DioExceptionType.receiveTimeout:
        return const Failure.timeout(tipo: TipoTimeout.recebimento);
      case DioExceptionType.connectionError:
        return Failure.semConexao(causa: err.error);
      case DioExceptionType.badCertificate:
        return Failure.respostaInvalida(statusCode: 495, causa: err.error);
      case DioExceptionType.cancel:
        return Failure.desconhecido(causa: err);
      case DioExceptionType.badResponse:
        return _mapearStatus(err);
      case DioExceptionType.unknown:
        // Erros de socket vem aqui com SocketException.
        if (err.error is SocketException) {
          return Failure.semConexao(causa: err.error);
        }
        return Failure.desconhecido(causa: err.error);
    }
  }

  Failure _mapearStatus(DioException err) {
    final code = err.response?.statusCode ?? 0;
    final retryApos = _parseRetryAfter(err.response?.headers);
    return switch (code) {
      401 || 403 => Failure.naoAutorizado(statusCode: code, causa: err.error),
      404 => const Failure.naoEncontrado(),
      429 => Failure.limiteRequisicoes(retryApos: retryApos, causa: err.error),
      >= 500 && <= 599 => Failure.servidor(statusCode: code, causa: err.error),
      _ => Failure.respostaInvalida(
          statusCode: code,
          corpo: err.response?.data?.toString(),
          causa: err.error,
        ),
    };
  }

  Duration? _parseRetryAfter(Headers? h) {
    final raw = h?.value('retry-after');
    if (raw == null) return null;
    final segundos = int.tryParse(raw);
    return segundos != null ? Duration(seconds: segundos) : null;
  }
}
```

No datasource, o `guard` extrai o `Failure` que veio em `DioException.error`:

```dart
Future<Result<T>> guardDio<T>(Future<T> Function() body) async {
  try {
    return Success(await body());
  } on DioException catch (e) {
    final f = e.error;
    if (f is Failure) return FailureResult(f);
    return FailureResult(Failure.desconhecido(causa: e));
  } on Failure catch (f) {
    return FailureResult(f);
  } catch (e, s) {
    return FailureResult(Failure.desconhecido(causa: e, stack: s));
  }
}
```

#### 3.2 Pegadinha critica do BCB SGS: HTML / valor-string / 10 anos

O SGS as vezes responde **HTTP 200 com corpo HTML** ("Requisicao Invalida") quando o User-Agent e rejeitado, e os valores vem como **string com ponto decimal** (ex.: `"14.50"`). Series 226/195 trazem `dataFim`. O parser do datasource deve detectar esses casos e converter em `ParseFailure`:

```dart
List<PontoSerie> parseSgs(dynamic data) {
  // 1) Corpo HTML mascarado de 200: dio entregou String em vez de List.
  if (data is String) {
    throw Failure.parse(detalhe: 'SGS retornou conteudo nao-JSON (HTML?).');
  }
  if (data is! List) {
    throw Failure.parse(detalhe: 'SGS: formato inesperado (${data.runtimeType}).');
  }
  return data.map((e) {
    final m = e as Map<String, dynamic>;
    final valorStr = m['valor'] as String?; // valor SEMPRE vem string
    final valor = double.tryParse(valorStr?.replaceAll(',', '.') ?? '');
    if (valor == null) {
      throw Failure.parse(detalhe: 'SGS: valor nao numerico "$valorStr".');
    }
    return PontoSerie(
      data: _parseDataBr(m['data'] as String),       // dd/MM/yyyy
      dataFim: m['dataFim'] != null
          ? _parseDataBr(m['dataFim'] as String)
          : null,
      valor: valor,
    );
  }).toList(growable: false);
}
```

> Para consultas por periodo, o cliente do SGS deve fragmentar janelas > 10 anos antes de chamar (responsabilidade do `SgsDatasource`, ver secao de Rede). Se o BCB devolver 400/422 por janela invalida, cai em `RespostaInvalidaFailure` e a UI mostra a mensagem padrao de "nao foi possivel carregar".

#### 3.3 Tabela: `Failure` -> mensagem pt-BR -> acao da UI

Toda mensagem vem do `.arb` (chaves abaixo). O mapeador `FailureMessages` e o **unico** lugar que decide o texto. A coluna "Acao UI" define o componente (`ErrorView` de tela cheia, `SnackBar`, `StaleBanner` ou inline no formulario).

| Failure | Chave ARB | Mensagem pt-BR | Acao UI | Botao |
|---|---|---|---|---|
| `SemConexaoFailure` | `erroSemConexao` | "Sem conexao com a internet. Mostrando os ultimos dados salvos." (com cache) / "Sem conexao com a internet." (sem cache) | StaleBanner se ha cache; senao ErrorView | "Tentar novamente" |
| `TimeoutFailure` | `erroTimeout` | "O servico demorou para responder. Tente novamente." | ErrorView / SnackBar | "Tentar novamente" |
| `NaoAutorizadoFailure` (brapi) | `erroBrapiToken` | "Nao foi possivel acessar as acoes. Verifique o token da brapi em Ajustes." | ErrorView + atalho | "Abrir Ajustes" |
| `NaoEncontradoFailure` (CNPJ) | `erroCnpjNaoEncontrado` | "CNPJ nao encontrado." | inline no campo | — |
| `NaoEncontradoFailure` (acao) | `erroTickerNaoEncontrado` | "Ativo nao encontrado." | EmptyView na busca | — |
| `LimiteRequisicoesFailure` | `erroLimiteRequisicoes` | "Muitas consultas em pouco tempo. Aguarde um instante e tente de novo." (+ contador se `retryApos`) | SnackBar | "Tentar de novo" |
| `ServidorFailure` | `erroServidor` | "O servico esta instavel no momento. Tente mais tarde." | ErrorView | "Tentar novamente" |
| `RespostaInvalidaFailure` | `erroRespostaInvalida` | "Nao foi possivel carregar os dados agora." | ErrorView | "Tentar novamente" |
| `ParseFailure` | `erroDadosInesperados` | "Recebemos uma resposta inesperada do servico." | ErrorView; usa cache se houver | "Tentar novamente" |
| `ArmazenamentoFailure` | `erroArmazenamento` | "Falha ao acessar os dados salvos no dispositivo." | SnackBar / ErrorView | "Tentar novamente" |
| `ImportExportFailure(arquivoNaoEhInvestaBr)` | `erroImportArquivo` | "Este arquivo nao e um backup do Investa BR." | Dialog | "Ok" |
| `ImportExportFailure(versaoMaisNova)` | `erroImportVersao` | "Este backup foi gerado por uma versao mais nova. Atualize o app para importar." | Dialog | "Ok" |
| `ImportExportFailure(checksumInvalido)` | `erroImportChecksum` | "O arquivo de backup parece corrompido (verificacao de integridade falhou)." | Dialog | "Ok" |
| `ImportExportFailure(jsonMalformado)` | `erroImportJson` | "Nao foi possivel ler o arquivo de backup." | Dialog | "Ok" |
| `ValidacaoFailure` | (dinamica) | usa `detalhe` ja em pt-BR | inline no formulario | — |
| `DesconhecidoFailure` | `erroDesconhecido` | "Algo deu errado. Tente novamente." | ErrorView / SnackBar | "Tentar novamente" |

```dart
// lib/src/common/errors/failure_messages.dart
String mensagemDeFailure(Failure f, AppLocalizations l10n, {bool temCache = false}) {
  return switch (f) {
    SemConexaoFailure() =>
      temCache ? l10n.erroSemConexaoComCache : l10n.erroSemConexao,
    TimeoutFailure() => l10n.erroTimeout,
    NaoAutorizadoFailure() => l10n.erroBrapiToken,
    NaoEncontradoFailure() => l10n.erroNaoEncontrado, // refinar por contexto na tela
    LimiteRequisicoesFailure(:final retryApos) => retryApos != null
        ? l10n.erroLimiteRequisicoesComTempo(retryApos.inSeconds)
        : l10n.erroLimiteRequisicoes,
    ServidorFailure() => l10n.erroServidor,
    RespostaInvalidaFailure() => l10n.erroRespostaInvalida,
    ParseFailure() => l10n.erroDadosInesperados,
    ArmazenamentoFailure() => l10n.erroArmazenamento,
    ImportExportFailure(:final motivo) => switch (motivo) {
        ImportExportErro.arquivoNaoEhInvestaBr => l10n.erroImportArquivo,
        ImportExportErro.versaoMaisNova => l10n.erroImportVersao,
        ImportExportErro.checksumInvalido => l10n.erroImportChecksum,
        ImportExportErro.jsonMalformado => l10n.erroImportJson,
        ImportExportErro.semPermissaoArquivo => l10n.erroImportPermissao,
      },
    ValidacaoFailure(:final detalhe) => detalhe,
    DesconhecidoFailure() => l10n.erroDesconhecido,
  };
}
```

#### 3.4 Consumo na UI (pattern match em `AsyncValue` + `Failure`)

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final async = ref.watch(indicadoresControllerProvider);
  return switch (async) {
    AsyncData(:final value) => DashboardBody(snapshot: value),
    AsyncLoading() => const _DashboardSkeleton(),
    AsyncError(:final error) => ErrorView(
        mensagem: error is Failure
            ? mensagemDeFailure(error, l10n)
            : l10n.erroDesconhecido,
        onRetry: () => ref.read(indicadoresControllerProvider.notifier).atualizar(),
      ),
    AsyncValue() => const SizedBox.shrink(), // exaustividade
  };
}
```

---

### 4. Comportamento offline e dados desatualizados (stale)

A regra-mestra: **sempre que houver qualquer snapshot persistido, o app mostra dado em vez de erro**, sinalizando "stale" quando o dado nao e do dia ou veio de fallback offline. Isso casa com o `DailyCacheService` (secao de Cache) e com `cache_indicadores` no sembast.

#### 4.1 Maquina de estados do dado servido

```
                +-----------------------------+
   abrir tela   |  ler cache_indicadores      |
  ------------> |  (sembast, key indicadores) |
                +--------------+--------------+
                               |
            cache == null?     |  cache != null
          +--------------------+--------------------+
          v                                         v
   +-------------+                      data == hoje && dentro do TTL?
   |  buscar     |                      +-----------+-----------+
   |  rede       |                  sim |                       | nao
   +------+------+                      v                       v
          |                       SERVE (fresh)          SERVE (cache)  ── exibe imediato
   sucesso| erro                  stale=false            stale=true
          v      \                                        + revalida em background:
   persiste e    \                                          buscar rede
   serve fresh    v                                          |  sucesso -> regrava, stale=false
                ErrorView                                     |  erro    -> mantem cache, stale=true
              (sem dado)                                       v          + banner "offline/desatualizado"
```

Ou seja: **stale-while-revalidate**. O cache aparece na hora; a revalidacao acontece sem bloquear a UI. Se a revalidacao falha (offline), o banner stale permanece.

#### 4.2 Modelo de snapshot com metadados de frescor

O documento `cache_indicadores/indicadores_dia` (sembast) ja carrega os campos de controle:

```json
{
  "dataUltimaAtualizacao": "2026-06-17",
  "fetchedAt": "2026-06-17T08:55:10-03:00",
  "ttlHoras": 12,
  "stale": false,
  "fonte": "bcb_sgs+brapi",
  "indicadores": { "selicMeta": 14.50, "cdiDia": 0.0534, "ipcaMes": 0.58 },
  "cotacoes": { "PETR4": 38.54 }
}
```

Regra de frescor (fuso America/Sao_Paulo, UTC-3 fixo, sem horario de verao desde 2019):

```dart
bool _ehFresh(Map<String, Object?> snap) {
  final hoje = _hojeSaoPaulo(); // "yyyy-MM-dd"
  final mesmaData = snap['dataUltimaAtualizacao'] == hoje;
  final fetchedAt = DateTime.tryParse(snap['fetchedAt'] as String? ?? '');
  final ttl = Duration(hours: (snap['ttlHoras'] as num?)?.toInt() ?? 12);
  final dentroTtl =
      fetchedAt != null && DateTime.now().difference(fetchedAt) < ttl;
  return mesmaData && dentroTtl;
}

String _hojeSaoPaulo() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 3))
        .toIso8601String().substring(0, 10);
```

#### 4.3 Repositorio com stale-while-revalidate

```dart
Future<Result<SnapshotIndicadores>> obterDoDia() async {
  final cacheRaw = await _cacheRepo.lerIndicadores(); // Map? do sembast
  final cache = cacheRaw == null ? null : SnapshotIndicadores.fromJson(cacheRaw);

  // 1) Cache fresh -> serve direto, sem rede.
  if (cache != null && _ehFresh(cacheRaw!)) {
    return Success(cache);
  }

  // 2) Sem cache -> precisa de rede; erro vira ErrorView de tela cheia.
  if (cache == null) {
    return _buscarEPersistir();
  }

  // 3) Cache stale -> serve agora marcado stale e revalida em background.
  _revalidarEmBackground(); // fire-and-forget; atualiza o provider via ref
  return Success(cache.copyWith(stale: true));
}

Future<void> _revalidarEmBackground() async {
  final res = await _buscarEPersistir();
  res.fold(
    onSuccess: (s) => _onRevalidado?.call(Success(s)),
    onFailure: (_) {}, // silencioso: cache stale ja esta na tela
  );
}
```

#### 4.4 Banner de dados desatualizados (wireframe)

```
+------------------------------------------------------+
| ⚠  Sem conexao. Dados de 16/06 as 18:42.   [Atualizar]|   <- StaleBanner (cor warning)
+------------------------------------------------------+
|  Indicadores                                          |
|  +----------+ +----------+ +----------+ +----------+  |
|  | SELIC    | | CDI      | | IPCA mes | | IGP-M    |  |
|  | 14,50%aa | | 0,0534%  | | 0,58%    | | 0,84%    |  |
|  +----------+ +----------+ +----------+ +----------+  |
+------------------------------------------------------+
```

`StaleBanner` so aparece quando `snapshot.stale == true`. Texto formatado com `intl`: `DateFormat("dd/MM 'as' HH:mm", 'pt_BR').format(fetchedAt)`. Botao "Atualizar" chama `controller.atualizar()` (force refresh), igual ao botao de refresh manual da home.

#### 4.5 Politica por dominio offline

| Dominio | Tem cache offline? | Offline sem cache | Stale aceitavel |
|---|---|---|---|
| Indicadores (SGS) | Sim (`cache_indicadores`) | ErrorView | Sim — banner; series mudam 1x/dia (D-1 util) |
| Cotacoes carteira (brapi) | Sim (snapshot diario) | mostra ultimo preco com banner | Sim — free atualiza ~30min |
| Busca de acoes (brapi) | Nao (sob demanda) | EmptyView "sem conexao" | Nao |
| CNPJ emissor (BrasilAPI/OpenCNPJ) | Sim (cache por CNPJ, TTL longo) | usa cache se houver | Sim — dado cadastral muda pouco |
| Tesouro (CKAN CSV) | Sim (cache diario do CSV filtrado) | usa ultimo CSV | Sim |
| Cambio (AwesomeAPI) | Sim (cache curto) | usa ultimo | Sim — secundario |

> `network_info.dart` faz uma checagem best-effort de conectividade so para escolher a mensagem ("Sem conexao" vs "servico instavel"); **nunca** e usado para bloquear a tentativa de request — a fonte de verdade e o resultado do dio. Em desktop a checagem de conectividade e pouco confiavel, entao a decisao final sempre vem do erro real do dio.

---

### 5. Retry, timeout e backoff no dio

#### 5.1 `RetryPolicy` por API

```dart
// lib/src/common/network/retry_policy.dart
class RetryPolicy {
  const RetryPolicy({
    required this.maxTentativas,      // total de tentativas (1 = sem retry)
    required this.baseDelay,          // atraso base do backoff
    required this.maxDelay,           // teto do atraso
    this.fatorMultiplicador = 2.0,    // expoente do backoff
    this.usarJitter = true,           // jitter para evitar thundering herd
    this.respeitaRetryAfter = true,   // honra header Retry-After em 429
  });

  final int maxTentativas;
  final Duration baseDelay;
  final Duration maxDelay;
  final double fatorMultiplicador;
  final bool usarJitter;
  final bool respeitaRetryAfter;

  /// delay = min(maxDelay, baseDelay * fator^(tentativa-1)) [+ jitter]
  Duration delayPara(int tentativa, {Duration? retryAfter}) {
    if (respeitaRetryAfter && retryAfter != null) {
      return retryAfter > maxDelay ? maxDelay : retryAfter;
    }
    final exp = baseDelay.inMilliseconds *
        pow(fatorMultiplicador, tentativa - 1);
    var ms = min(exp.toInt(), maxDelay.inMilliseconds);
    if (usarJitter) {
      // full jitter: aleatorio em [0, ms]
      ms = Random().nextInt(ms + 1);
    }
    return Duration(milliseconds: ms);
  }
}
```

Formula do backoff exponencial com full jitter:

```
delay(n) = random(0, min(maxDelay, baseDelay * fator^(n-1)))
```

Exemplo (`baseDelay=400ms`, `fator=2`, `maxDelay=8s`), antes do jitter: 400ms, 800ms, 1.6s, 3.2s, 6.4s, 8s…

#### 5.2 Tabela de timeouts e politicas por API

| API | connectTimeout | receiveTimeout | maxTentativas | baseDelay | Observacao |
|---|---|---|---|---|---|
| BCB SGS | 8s | 12s | 3 | 500ms | rate limit do servidor; max ~5 req paralelas no boot |
| brapi (cotacao) | 8s | 12s | 4 | 800ms | 429 frequente no free; backoff agressivo + honrar Retry-After |
| BrasilAPI (feriados/taxas) | 8s | 12s | 3 | 500ms | comunitario, sem SLA |
| BrasilAPI (CNPJ) | 10s | 15s | 2 | 1s | mais throttled (depende da Receita) -> fallback OpenCNPJ |
| OpenCNPJ (fallback) | 8s | 12s | 2 | 500ms | 50 req/s; rapido |
| ReceitaWS (fallback 2) | 10s | 15s | 1 | — | 3 req/min: NAO fazer retry automatico |
| AwesomeAPI | 8s | 10s | 2 | 500ms | secundario |
| Tesouro CKAN (CSV ~13,5 MiB) | 12s | 60s | 2 | 2s | receiveTimeout longo pelo tamanho do CSV |

#### 5.3 Quais erros sao "retentaveis"

Retry **apenas** para falhas transitorias. Erros deterministicos (4xx exceto 429, parse, validacao) **nunca** sao retentados — repetir nao muda o resultado.

```dart
bool _ehRetentavel(Failure f) => switch (f) {
      TimeoutFailure() => true,
      SemConexaoFailure() => true,        // pode ser blip momentaneo
      ServidorFailure() => true,          // 5xx
      LimiteRequisicoesFailure() => true, // 429 com backoff/Retry-After
      RespostaInvalidaFailure() => false, // 4xx deterministico
      NaoAutorizadoFailure() => false,    // token errado -> nao adianta
      NaoEncontradoFailure() => false,
      ParseFailure() => false,
      ArmazenamentoFailure() => false,
      ImportExportFailure() => false,
      ValidacaoFailure() => false,
      DesconhecidoFailure() => false,
    };
```

> Importante: so retentar metodos **idempotentes**. No Investa BR todas as chamadas externas sao `GET`, logo seguras para retry. Caso surja `POST` no futuro, marcar explicitamente como nao-retentavel.

#### 5.4 `RetryInterceptor`

```dart
// lib/src/common/network/interceptors/retry_interceptor.dart
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio, required this.policy});
  final Dio dio;
  final RetryPolicy policy;

  static const _kTentativa = 'retry_tentativa';

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    // O ErrorNormalizerInterceptor deve rodar ANTES e por o Failure em err.error.
    final failure = err.error is Failure
        ? err.error as Failure
        : const Failure.desconhecido();

    final tentativa = (err.requestOptions.extra[_kTentativa] as int? ?? 1);

    final podeRepetir = _ehRetentavel(failure) &&
        tentativa < policy.maxTentativas &&
        err.requestOptions.method == 'GET';

    if (!podeRepetir) {
      return handler.next(err); // segue como Failure ja normalizado
    }

    final retryAfter = failure is LimiteRequisicoesFailure
        ? failure.retryApos
        : null;
    final delay = policy.delayPara(tentativa, retryAfter: retryAfter);
    await Future<void>.delayed(delay);

    final novasOpcoes = err.requestOptions
      ..extra[_kTentativa] = tentativa + 1;

    try {
      final resposta = await dio.fetch<dynamic>(novasOpcoes);
      return handler.resolve(resposta);
    } on DioException catch (e) {
      return handler.next(e); // proxima iteracao trata / desiste
    }
  }
}
```

#### 5.5 Ordem dos interceptors (fixa)

A ordem importa: o normalizador precisa transformar `DioException` em `Failure` **antes** do retry, e o retry deve ser o ultimo a decidir.

```dart
// lib/src/common/network/dio_factory.dart
Dio criarDio({required ApiConfig cfg, required RetryPolicy policy}) {
  final dio = Dio(BaseOptions(
    baseUrl: cfg.baseUrl,
    connectTimeout: cfg.connectTimeout,
    receiveTimeout: cfg.receiveTimeout,
    sendTimeout: cfg.sendTimeout,
    headers: {
      // BCB SGS rejeita alguns clientes sem UA -> sempre enviar UA padrao.
      'User-Agent': 'InvestaBR/1.0 (+app)',
      'Accept': 'application/json',
    },
  ));
  dio.interceptors.addAll([
    BaseUrlInterceptor(cfg),            // 1) ajusta baseUrl por API
    if (cfg.usaTokenBrapi) BrapiTokenInterceptor(cfg), // 2) injeta token
    ErrorNormalizerInterceptor(),       // 3) DioException -> Failure
    RetryInterceptor(dio: dio, policy: policy), // 4) retry/backoff
    if (kDebugMode) LoggingInterceptor(),       // 5) log so em debug
  ]);
  return dio;
}
```

#### 5.6 Fallback encadeado de CNPJ (resiliencia entre fontes)

Alem do retry intra-API, CNPJ usa **fallback entre fontes** quando a principal falha de forma nao recuperavel (esgotou retry, 429, 5xx). Last-resort ReceitaWS sem retry por causa do limite de 3 req/min.

```dart
Future<Result<EmpresaCnpj>> consultarCnpj(String cnpjBruto) async {
  final cnpj = somenteDigitos(cnpjBruto); // normaliza antes
  // 0) cache local por CNPJ (TTL longo)
  final cache = await _cnpjCache.ler(cnpj);
  if (cache != null) return Success(cache);

  // 1) BrasilAPI -> 2) OpenCNPJ -> 3) ReceitaWS
  for (final fonte in _fontesCnpjEmOrdem) {
    final res = await fonte.buscar(cnpj);
    switch (res) {
      case Success(:final value):
        await _cnpjCache.gravar(cnpj, value);
        return Success(value);
      case FailureResult(:final failure):
        // 404 e definitivo: CNPJ nao existe, nao adianta tentar outra fonte.
        if (failure is NaoEncontradoFailure) return res;
        // demais (timeout/429/5xx): tenta a proxima fonte.
        continue;
    }
  }
  return const FailureResult(Failure.servidor(statusCode: 503));
}
```

---

### 6. Erros de Import/Export (resiliencia de dados locais)

O import roda em **transacao atomica** no sembast (REPLACE ou MERGE) so apos validar identidade, versao e checksum. Qualquer falha vira `ImportExportFailure` tipado e a transacao nunca e aplicada parcialmente.

```dart
Future<Result<void>> importar(File arquivo, {ModoImport modo = ModoImport.replace}) async {
  // 1) ler + decodificar
  final Map<String, Object?> raiz;
  try {
    raiz = jsonDecode(await arquivo.readAsString()) as Map<String, Object?>;
  } catch (_) {
    return const FailureResult(
        Failure.importExport(motivo: ImportExportErro.jsonMalformado));
  }
  // 2) identidade
  if (raiz['app'] != 'investa_br') {
    return const FailureResult(
        Failure.importExport(motivo: ImportExportErro.arquivoNaoEhInvestaBr));
  }
  // 3) versao (bloqueia backup mais novo que o app)
  final v = (raiz['schemaVersion'] as num?)?.toInt() ?? 0;
  if (v > LocalDb.schemaVersion) {
    return const FailureResult(
        Failure.importExport(motivo: ImportExportErro.versaoMaisNova));
  }
  // 4) checksum sha256 do bloco "data"
  final data = raiz['data'] as Map<String, Object?>;
  final esperado = (raiz['checksum'] as String?)?.split(':').last;
  if (esperado != null && sha256Hex(jsonEncode(data)) != esperado) {
    return const FailureResult(
        Failure.importExport(motivo: ImportExportErro.checksumInvalido));
  }
  // 5) aplicar em transacao (atomico) — falha de IO vira ArmazenamentoFailure
  try {
    final migrado = migratePayload(data, v, LocalDb.schemaVersion);
    await LocalDb.instance.db.transaction((txn) async {
      if (modo == ModoImport.replace) {
        await LocalDb.investimentosRf.delete(txn);
        await LocalDb.posicoesAcoes.delete(txn);
      }
      // ... put por id (MERGE = last-write-wins via updatedAt)
    });
    return const Success(null);
  } catch (e, s) {
    return FailureResult(Failure.armazenamento(causa: e));
  }
}
```

> `cache_indicadores` **nao** entra no export (dado derivado). Por isso uma falha de cache nunca contamina backup/restore.

---

### 7. Testes obrigatorios de erro/resiliencia

| Cenario | Como testar | Resultado esperado |
|---|---|---|
| SGS retorna HTML em 200 | mock dio devolve String | `ParseFailure` -> ErrorView; se cache, serve stale |
| SGS valor "14.50"/"14,50" | parse unitario | `double` correto; nunca lanca |
| brapi 429 com Retry-After | mock 429 + header `retry-after: 2` | retenta apos 2s; ao esgotar -> `LimiteRequisicoesFailure` |
| Timeout receive | dio `receiveTimeout` curto + servidor lento | `TimeoutFailure` + N tentativas conforme policy |
| Offline com cache do dia anterior | cache `data` != hoje, rede falha | serve cache `stale=true` + banner |
| Offline sem cache | sembast vazio, rede falha | `SemConexaoFailure` -> ErrorView |
| CNPJ 404 | mock 404 | `NaoEncontradoFailure` inline; NAO tenta proxima fonte |
| CNPJ BrasilAPI 5xx -> OpenCNPJ ok | mock encadeado | resultado da OpenCNPJ + grava cache |
| Import versao mais nova | arquivo `schemaVersion` > app | `ImportExportFailure(versaoMaisNova)`, banco intacto |
| Import checksum errado | adulterar `data` | `ImportExportFailure(checksumInvalido)`, transacao nao aplicada |
| Retry nao repete 4xx | mock 400 | 1 tentativa apenas (`_ehRetentavel == false`) |

Mocks com `mocktail`; overrides de provider via `ProviderContainer`/`overrideWith` para injetar `Dio` fake e `LocalDb` em memoria. A exaustividade do `switch` sobre `Failure` e garantida em tempo de compilacao (sealed class), entao adicionar uma nova variante quebra o build ate ser tratada no mapeador e na UI — isso e intencional.

---

## Seguranca & Privacidade dos Dados Locais

Esta secao define, de forma acionavel, o modelo de seguranca e privacidade do **Investa BR** (`investa_br`). O principio reitor e simples e nao negociavel: **todos os dados do usuario (carteira de renda fixa, posicoes em acoes, configuracoes e tema) vivem exclusivamente no dispositivo**. O app **nao opera nenhum servidor proprio**, **nao tem conta/login**, **nao faz telemetria** e so se comunica com APIs publicas de terceiros (BCB, brapi, BrasilAPI/OpenCNPJ, AwesomeAPI, Tesouro CKAN) para leitura de dados de mercado. Nenhum dado pessoal ou de carteira sai do dispositivo, exceto quando o proprio usuario, por acao explicita, exporta um arquivo de backup.

### 1. Modelo de ameaca e fronteiras de confianca

| Ativo | Onde fica | Quem ameaca | Mitigacao |
|---|---|---|---|
| Carteira RF + acoes (sembast) | Disco local, dir. de documentos do app | Outro app/usuario com acesso ao FS (desktop), backup em nuvem do SO, despejo de dispositivo | Sandbox da plataforma; opcao de cifrar o banco (SQLCipher-like codec do sembast); exclusao de backup do SO |
| Backup JSON exportado | Onde o usuario salvar/compartilhar | Quem receber o arquivo | Backup opcionalmente cifrado com senha (AES-GCM); checksum SHA-256 |
| Token brapi | sembast (store `configuracoes`) ou secure storage | Quem ler o banco | Tratado como segredo; nunca exportado; nunca logado |
| Trafego HTTP | Rede (BCB/brapi/BrasilAPI/...) | MITM, observador de rede | HTTPS obrigatorio; sem envio de PII; query params sem dados do usuario |
| CNPJ de emissor consultado | Enviado as APIs de CNPJ | Operador da API (BrasilAPI/OpenCNPJ) | CNPJ de empresa nao e dado pessoal do usuario; normalizar e cachear localmente |

**Fronteira de confianca:** tudo dentro do processo do app e do diretorio de documentos e confiavel; tudo que cruza a rede ou o sistema de arquivos compartilhado e nao confiavel e deve ser minimizado.

### 2. Dados 100% locais, sem servidor proprio

#### 2.1 Inventario do que e persistido (e onde)

```
<getApplicationDocumentsDirectory()>/
  investa_br.db                  # banco sembast (databaseFactoryIo) - dados do usuario
  investa_br.db.lock             # lock interno do sembast (efemero)
  exports/                       # area opcional de exportacoes locais (criada sob demanda)
```

As **4 stores** do sembast (decisao global) e sua classificacao de privacidade:

| Store | Conteudo | Classe de dado | Entra no export? | Cifravel? |
|---|---|---|---|---|
| `investimentos_rf` | CDB/LCI/LCA/Tesouro/debentures, valores, datas, CNPJ emissor | Sensivel (financeiro do usuario) | Sim | Sim |
| `posicoes_acoes` | Ticker, quantidade, preco medio, corretora | Sensivel (financeiro do usuario) | Sim | Sim |
| `configuracoes` | Tema, locale, seed, **token brapi**, **opcao de cripto** | Mista (contem segredo) | Parcial (sem o token) | Sim |
| `cache_indicadores` | SELIC/CDI/IPCA, cotacoes, snapshot diario | Derivado/publico (nao pessoal) | **Nao** | Sim (junto do banco) |

Regra de ouro: **`cache_indicadores` e dado derivado de fontes publicas e NAO entra no backup**; e regeneravel a qualquer momento pelo `DailyCacheService`.

#### 2.2 Ausencia de backend (declaracao tecnica)

- Nao existe endpoint proprio, banco remoto, fila, analytics, crash reporter de rede nem push server.
- O app **nao integra `firebase_*`, nem SDK de analytics/ads/attribution**. Lint/CI deve barrar a entrada desses pacotes (ver secao 8).
- Toda chamada de rede e `GET` de leitura a APIs publicas, sem corpo com dados do usuario. Os unicos identificadores enviados sao: tickers (publicos), CNPJ de empresas emissoras (dado publico de PJ) e o **token brapi** (segredo do usuario, enviado apenas ao dominio `brapi.dev`).

#### 2.3 Whitelist de dominios (allowlist de rede)

O `DioFactory` deve recusar qualquer base URL fora desta lista. Centralizar em `lib/src/constants/api_endpoints.dart`:

```dart
/// Unica fonte da verdade dos dominios permitidos. Qualquer requisicao
/// fora desta lista deve falhar em desenvolvimento (assert) e ser
/// normalizada como Failure em producao.
abstract final class ApiHosts {
  static const bcbSgs       = 'api.bcb.gov.br';        // indicadores (sem auth)
  static const bcbOlinda    = 'olinda.bcb.gov.br';     // Focus (sem auth)
  static const brapi        = 'brapi.dev';             // acoes (token do usuario)
  static const brasilApi    = 'brasilapi.com.br';      // CNPJ/feriados/PTAX (sem auth)
  static const openCnpj     = 'api.opencnpj.org';      // fallback CNPJ (sem auth)
  static const awesomeApi   = 'economia.awesomeapi.com.br'; // cambio (chave opcional)
  static const tesouroCkan  = 'www.tesourotransparente.gov.br'; // CSV Tesouro

  static const all = <String>{
    bcbSgs, bcbOlinda, brapi, brasilApi, openCnpj, awesomeApi, tesouroCkan,
  };
}
```

Interceptor de guarda (rejeita host nao listado e forca HTTPS):

```dart
class HostAllowlistInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    final permitido = uri.scheme == 'https' && ApiHosts.all.contains(uri.host);
    assert(permitido, 'Host nao permitido: ${uri.host}');
    if (!permitido) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Host bloqueado pela allowlist: ${uri.host}',
        ),
      );
    }
    handler.next(options);
  }
}
```

### 3. Criptografia opcional do banco e do backup

A criptografia e **opcional e desligada por padrao** (o app deve abrir sem fricao no primeiro uso). O usuario ativa em `Ajustes > Privacidade`. Sao **dois mecanismos independentes**:

```
                +---------------------------------------------+
                |  Ajustes > Privacidade & Seguranca          |
                |                                             |
                |  [ ] Proteger banco local com senha         |  (A) cripto em repouso
                |       (criptografa investa_br.db)           |
                |                                             |
                |  Backup exportado:                          |
                |   (•) Sem senha (JSON legivel)              |  (B) cripto do backup
                |   ( ) Protegido por senha (.investa)        |
                +---------------------------------------------+
```

#### 3.1 (A) Banco local cifrado em repouso (codec do sembast)

O sembast suporta um **codec de banco** (parametro `codec` em `openDatabase`) que cifra/decifra cada registro JSON gravado em disco. Usamos AES-GCM derivando a chave da senha do usuario via **PBKDF2-HMAC-SHA256** (ou Argon2id, se disponivel). O salt fica em arquivo separado `investa_br.salt` (nao secreto).

Derivacao da chave (formula):
```
chave = PBKDF2-HMAC-SHA256(senha, salt, iteracoes = 200_000, dkLen = 32 bytes)
```

Implementacao do codec (esqueleto; cada registro e cifrado individualmente, AES-GCM com nonce de 12 bytes prefixado ao ciphertext, em Base64):

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:sembast/sembast.dart';

/// Codec sembast que cifra cada valor JSON com AES-GCM.
/// A chave (32 bytes) e derivada da senha do usuario via PBKDF2 fora daqui.
SembastCodec investaCodec(SecretKey key) =>
    SembastCodec(signature: 'aes-gcm-v1', codec: _AesGcmJsonCodec(key));

class _AesGcmJsonCodec extends Codec<Object?, String> {
  _AesGcmJsonCodec(this._key) : _algo = AesGcm.with256bits();
  final SecretKey _key;
  final AesGcm _algo;

  @override
  Converter<Object?, String> get encoder => _Enc(_key, _algo);
  @override
  Converter<String, Object?> get decoder => _Dec(_key, _algo);
}

// Enc/Dec: jsonEncode -> bytes -> AES-GCM(nonce|cipher|mac) -> base64.
// Decodificacao reversa; falha de MAC => InvalidSenhaException.
```

Abertura do banco com escolha de modo:

```dart
Future<Database> openInvestaDb({SecretKey? chave}) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'investa_br.db');
  return databaseFactoryIo.openDatabase(
    path,
    version: LocalDb.schemaVersion,
    codec: chave == null ? null : investaCodec(chave), // sem chave = texto-claro
    onVersionChanged: LocalDb.onVersionChanged,
  );
}
```

Fluxo de ativacao/desativacao (migracao de modo) — **deve ser atomico e reversivel**:

```
Ativar cripto:                          Desativar cripto:
  1. pedir senha (2x, confirmar)          1. pedir senha atual
  2. derivar chave (PBKDF2)               2. abrir db cifrado (valida senha)
  3. abrir db atual (texto-claro)         3. ler todos os registros
  4. dump completo -> memoria             4. abrir db novo (sem codec)
  5. abrir db_novo com codec(chave)       5. regravar tudo
  6. regravar tudo em txn                 6. fsync + swap atomico
  7. fsync + swap atomico do arquivo      7. apagar arquivo cifrado (zero-fill)
  8. apagar arquivo antigo
```

Regras de chave:
- A senha **nunca** e persistida. Apenas o **salt** (`investa_br.salt`) fica em disco.
- A chave derivada vive **somente em memoria** durante a sessao. Ao bloquear/fechar o app, descartar a referencia.
- Opcionalmente, oferecer "lembrar nesta sessao" guardando a chave em `flutter_secure_storage` (Keychain/Keystore/DPAPI) — **nunca** em sembast nem shared_preferences. (Adicionar `flutter_secure_storage` apenas se este recurso for implementado.)
- Esquecimento de senha = **perda irrecuperavel** dos dados. Avisar explicitamente na UI ("nao ha recuperacao; guarde sua senha").

#### 3.2 (B) Backup exportado cifrado

O export padrao e o JSON descrito na decisao global (legivel). Quando o usuario escolhe "Protegido por senha", o **mesmo payload** e cifrado e gravado com extensao `.investa` (envelope binario), em vez de `.json`:

```
Arquivo .investa (envelope de backup cifrado)
+--------------------------------------------------------------+
| magic   "INVESTABR1"  (10 bytes ASCII)                       |
| kdf     0x01 = PBKDF2-HMAC-SHA256                            |
| iter    uint32 BE (ex.: 200000)                              |
| saltLen uint8 ; salt (16 bytes)                              |
| nonce   12 bytes (AES-GCM)                                   |
| cipher  AES-256-GCM( gzip( jsonUtf8(payload) ) )            |
| tag     16 bytes (GCM auth tag, embutida no cipher pelo lib) |
+--------------------------------------------------------------+
```

O `payload` interno e exatamente o mesmo objeto do export legivel (com `app`, `schemaVersion`, `exportedAt`, `appVersion`, `checksum` SHA-256 e `data`). Assim, a logica de import/validacao/migracao (`migratePayload`, REPLACE/MERGE) e **identica**; muda apenas a camada de transporte (decifrar antes de `jsonDecode`).

```dart
Future<List<int>> cifrarBackup(Map<String, Object?> payload, String senha) async {
  final salt = _randomBytes(16);
  final key = await _pbkdf2(senha, salt, 200000); // 32 bytes
  final plain = gzip.encode(utf8.encode(jsonEncode(payload)));
  final box = await AesGcm.with256bits()
      .encrypt(plain, secretKey: key, nonce: _randomBytes(12));
  return _montarEnvelope(salt: salt, iter: 200000, nonce: box.nonce, cipher: box.concatenation());
}
```

Selecao de extensao no `file_picker` (import deve aceitar ambos):
```dart
FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json', 'investa'], // .json = legivel, .investa = cifrado
);
```

#### 3.3 O que NUNCA e cifravel/exportavel

- O **token brapi** nunca entra em nenhum arquivo de export (nem cifrado nem legivel): trata-se de segredo do usuario que pode mudar e nao deve transitar em backups. No payload de `configuracoes` exportado, o campo do token e **removido** antes de serializar.

```dart
Map<String, Object?> sanitizarConfigParaExport(Map<String, Object?> cfg) {
  final copia = Map<String, Object?>.from(cfg)
    ..remove('brapiToken')      // segredo: nunca exportar
    ..remove('awesomeApiKey')   // segredo opcional
    ..remove('protecaoBanco');  // estado de cripto local, nao faz sentido portar
  return copia;
}
```

### 4. Permissoes minimas por plataforma

Principio: **nenhuma permissao perigosa**. O app nao usa camera, microfone, localizacao, contatos, biometria (a menos que se opte por desbloqueio biometrico via secure storage), nem armazenamento amplo. Acesso a arquivos e feito via **document picker do SO** (escopo por arquivo selecionado), nunca por leitura ampla do FS.

#### 4.1 Tabela de permissoes por plataforma

| Plataforma | Permissao | Necessaria? | Justificativa |
|---|---|---|---|
| Android | `INTERNET` | Sim | APIs de mercado (somente leitura) |
| Android | `READ/WRITE_EXTERNAL_STORAGE` | **Nao** | Usar Storage Access Framework (file_picker/share) - sem acesso amplo |
| Android | `ACCESS_NETWORK_STATE` | Opcional | Detectar offline para `stale-while-revalidate` |
| iOS/macOS | App Sandbox | Sim (macOS) | Habilitado; sem entitlements extras |
| iOS/macOS | `com.apple.security.network.client` | Sim (macOS) | Saida HTTP cliente |
| iOS/macOS | `com.apple.security.files.user-selected.read-write` | Sim (macOS) | Import/export via painel do usuario |
| iOS | NSAppTransportSecurity | Sim (default ATS) | Forca HTTPS; **nao** adicionar excecoes |
| Windows | (nenhuma especial) | - | Win32, sem capabilities de loja restritas |
| Linux | (nenhuma especial) | - | Acesso a `XDG_DATA_HOME`/docs dir |

#### 4.2 Android — `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- UNICA permissao obrigatoria: leitura de APIs publicas de mercado -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Opcional: detectar conectividade p/ modo offline (cache stale) -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <!-- NAO declarar: READ/WRITE_EXTERNAL_STORAGE, MANAGE_EXTERNAL_STORAGE,
         CAMERA, LOCATION, RECORD_AUDIO, READ_CONTACTS, etc. -->

    <application
        android:label="Investa BR"
        android:allowBackup="false"
        android:fullBackupContent="false"
        android:dataExtractionRules="@xml/data_extraction_rules">
        <!-- cleartext desativado: so HTTPS -->
        <!-- android:usesCleartextTraffic e false por padrao (API 28+) -->
    </application>
</manifest>
```

`android:allowBackup="false"` + `dataExtractionRules` **impede que o banco va para o backup em nuvem do Google** sem consentimento — coerente com "dados 100% locais". `android/app/src/main/res/xml/data_extraction_rules.xml`:

```xml
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="file" path="investa_br.db"/>
    <exclude domain="file" path="investa_br.db.lock"/>
    <exclude domain="file" path="investa_br.salt"/>
  </cloud-backup>
  <device-transfer>
    <exclude domain="file" path="investa_br.db"/>
  </device-transfer>
</data-extraction-rules>
```

#### 4.3 iOS — `ios/Runner/Info.plist`

```xml
<!-- ATS padrao: HTTPS obrigatorio, SEM excecoes -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
</dict>
<!-- Excluir banco do backup do iCloud: feito em runtime via
     NSURLIsExcludedFromBackupKey no arquivo investa_br.db (ver 4.6). -->
```

Nao declarar `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, etc. — se nao usa, **nao pede**.

#### 4.4 macOS — entitlements

`macos/Runner/DebugProfile.entitlements` e `Release.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>            <true/>
<key>com.apple.security.network.client</key>          <true/>
<key>com.apple.security.files.user-selected.read-write</key> <true/>
<!-- NAO incluir: network.server, files.downloads.read-write amplo,
     camera, microphone, location, address-book. -->
```

#### 4.5 Windows / Linux

- **Windows:** app Win32 (nao MSIX de loja por padrao); sem `<Capabilities>` restritas. Banco em `getApplicationDocumentsDirectory()` (perfil do usuario). Sem registro de servico/firewall inbound — o app so faz conexoes de saida.
- **Linux:** dados em `getApplicationDocumentsDirectory()` (mapeado para `~/Documents` ou XDG). Sem `polkit`/D-Bus privilegiado. Se empacotar em Flatpak/Snap, conceder apenas `--share=network` e `--filesystem=home` minimo (ou portais para file picker).

#### 4.6 Excluir o banco de backups automaticos (runtime)

No boot, marcar os arquivos do banco para nao serem copiados a nuvem do SO (especialmente iOS):

```dart
// Apos abrir o banco. Em iOS, seta NSURLIsExcludedFromBackupKey.
Future<void> excluirDoBackupDoSO(String dbPath) async {
  if (Platform.isIOS || Platform.isMacOS) {
    // via canal nativo/plugin: NSURL setResourceValue:forKey:NSURLIsExcludedFromBackupKey
    await BackupExclusion.exclude(dbPath);
  }
  // Android: ja coberto por allowBackup=false + dataExtractionRules.
}
```

### 5. Consideracoes LGPD

A LGPD (Lei 13.709/2018) trata de **dados pessoais de pessoas naturais**. A arquitetura do Investa BR foi desenhada para **minimizar o alcance da LGPD a praticamente zero**, pois o app atua como ferramenta local sob controle exclusivo do titular.

#### 5.1 Posicionamento juridico-tecnico

| Tema LGPD | Como o Investa BR se posiciona |
|---|---|
| Papel do desenvolvedor | **Nao e controlador nem operador** dos dados financeiros: nao coleta, nao recebe, nao tem acesso. Os dados ficam sob controle unico do usuario no dispositivo (analogo a um app de calculadora/planilha local). |
| Dados pessoais coletados pelo app | **Nenhum** enviado a terceiros do desenvolvedor. Nao ha cadastro, e-mail, nome, CPF, device-id ou telemetria. |
| Base legal | Tratamento e feito pelo proprio titular, no proprio dispositivo, para uso particular/domestico — **art. 4, I da LGPD** (tratamento por pessoa natural para fins exclusivamente particulares e nao economicos esta fora do escopo da lei). |
| Dados de mercado (SELIC, cotacoes, CNPJ de PJ) | Dados publicos; **CNPJ de empresa nao e dado pessoal** do usuario. Nenhum dado pessoal do usuario e transmitido as APIs. |
| Token brapi / chave AwesomeAPI | Credencial tecnica do usuario; tratada como segredo local, nunca compartilhada. |

#### 5.2 Direitos do titular — atendidos por design

A LGPD garante acesso, portabilidade, correcao e eliminacao (arts. 18). Como tudo e local, esses direitos sao atendidos **pela propria UI**, sem intervencao de terceiros:

| Direito (LGPD) | Recurso no app |
|---|---|
| Acesso aos dados | Tela Carteira/Dashboard mostra tudo; banco e legivel |
| Portabilidade | **Export JSON** (formato aberto, documentado, com `schemaVersion`) |
| Correcao | Telas de Edicao de RF/acoes |
| Eliminacao | **"Apagar todos os dados"** (limpa stores + arquivos; zero-fill se cifrado) |
| Anonimato/Confidencialidade | Cripto opcional do banco (secao 3.1) |

Funcao de eliminacao total (deve ser irreversivel e completa):

```dart
Future<void> apagarTudo() async {
  await LocalDb.instance.db.close();
  final dir = await getApplicationDocumentsDirectory();
  for (final nome in ['investa_br.db', 'investa_br.db.lock', 'investa_br.salt']) {
    final f = File(p.join(dir.path, nome));
    if (await f.exists()) {
      // Sobrescreve antes de apagar (best-effort em FS com journaling)
      await _zeroFill(f);
      await f.delete();
    }
  }
  // Limpar secure storage (token brapi/chave) se utilizado
  await secureStorage.deleteAll();
}
```

#### 5.3 Aviso de privacidade (Politica) — conteudo minimo

Incluir uma tela `Ajustes > Privacidade > Politica de Privacidade` (texto local, sem rede) declarando, em pt-BR:

1. "O Investa BR **nao coleta, nao armazena em servidores e nao compartilha** seus dados. Tudo fica no seu aparelho."
2. Quais APIs publicas sao consultadas e o que e enviado a elas (tickers, CNPJ de empresas, e — apenas para `brapi.dev` — seu token). Listar os 7 dominios da secao 2.3.
3. Que essas APIs sao operadas por terceiros (BCB, brapi, BrasilAPI, etc.) com politicas proprias; linkar (texto) as fontes.
4. Que o usuario pode exportar, apagar e cifrar seus dados a qualquer momento.
5. Data da ultima atualizacao e versao do app.

#### 5.4 Privacidade nas lojas (App Store / Play)

- **Play Data Safety:** declarar "Nenhum dado coletado/compartilhado". Justificavel pela ausencia de backend/telemetria.
- **Apple Privacy Nutrition Label:** marcar "Data Not Collected". Nao incluir SDKs de tracking; **sem `NSUserTrackingUsageDescription`**.

### 6. Uso e armazenamento de tokens de API

Apenas a **brapi** exige token (obrigatorio na pratica para mais de 4 tickers). A **AwesomeAPI** tem chave **opcional**. Demais APIs (BCB, BrasilAPI, OpenCNPJ, Tesouro) **nao usam credencial**.

#### 6.1 Politica de credenciais

| Credencial | Origem | Onde guardar | Exportada? | Logada? |
|---|---|---|---|---|
| Token brapi | **Inserido pelo usuario** em Ajustes | `flutter_secure_storage` (preferencial) ou store `configuracoes` (cifravel) | **Nunca** | **Nunca** |
| Chave AwesomeAPI (opcional) | Inserida pelo usuario | Idem | Nunca | Nunca |

**Decisao:** o app **nao embute** um token brapi compartilhado no binario. Motivos: (1) a cota e de 15.000 req/mes por token — um token embutido seria exaurido por toda a base de usuarios; (2) tokens em binario sao trivialmente extraiveis (reverse engineering), violando os ToS da brapi. **O usuario fornece o proprio token gratuito.** Sem token, o app degrada graciosamente para os 4 tickers de teste (PETR4, VALE3, MGLU3, ITUB4) com aviso claro na UI.

#### 6.2 Onde e como armazenar

Preferir **`flutter_secure_storage`** (Keychain no iOS/macOS, Keystore/EncryptedSharedPreferences no Android, DPAPI no Windows, libsecret no Linux). Se o desktop Linux nao tiver keyring disponivel, cair para a store `configuracoes` do sembast **com o banco cifrado ativado** (secao 3.1), nunca em texto-claro persistente quando o usuario optou por protecao.

```dart
@riverpod
class BrapiTokenController extends _$BrapiTokenController {
  static const _k = 'brapi_token';
  final _secure = const FlutterSecureStorage();

  @override
  Future<String?> build() => _secure.read(key: _k);

  Future<void> salvar(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    await _secure.write(key: _k, value: t);
    ref.invalidateSelf();
  }

  Future<void> remover() async {
    await _secure.delete(key: _k);
    ref.invalidateSelf();
  }
}
```

#### 6.3 Injecao segura no Dio (sem vazar em logs)

Interceptor injeta o token apenas para o host da brapi e **redige** o token no logging:

```dart
class BrapiTokenInterceptor extends Interceptor {
  BrapiTokenInterceptor(this._tokenLeitor);
  final Future<String?> Function() _tokenLeitor;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.uri.host == ApiHosts.brapi) {
      final token = await _tokenLeitor();
      if (token != null && token.isNotEmpty) {
        // Header (recomendado) - nao aparece na URL/historico
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Logging que NUNCA imprime segredos.
class SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    assert(() {
      final headers = Map<String, Object?>.from(o.headers)
        ..updateAll((k, v) =>
            k.toLowerCase() == 'authorization' ? '***REDACTED***' : v);
      // Redige tambem ?token= caso seja usado em query
      final url = o.uri.toString().replaceAll(
          RegExp(r'token=[^&]+'), 'token=***REDACTED***');
      debugPrint('[DIO] ${o.method} $url headers=$headers');
      return true;
    }());
    h.next(o);
  }
}
```

Regras adicionais:
- **Preferir header `Authorization: Bearer`** ao inves de `?token=` na query (query vai para historico/cache/proxies). Usar query so como fallback se a chamada especifica exigir.
- O logging detalhado (`SafeLogInterceptor`) so e adicionado em **debug** (`assert(() {...})` ou `kDebugMode`); em release nao ha logging de rede.
- Nunca incluir o token em mensagens de erro/`Failure` exibidas ou persistidas no `cache_indicadores`.
- Ao montar um `Failure` a partir de `DioException`, **strip** de `requestOptions.headers['Authorization']` e de `token=` na URL antes de guardar/exibir.

#### 6.4 UI de configuracao do token

```
+------------------------------------------------------+
| Ajustes › Acoes (brapi)                               |
|                                                       |
| Token brapi (gratuito)                                |
|  [ ••••••••••••••••••••••  ]   👁  [ Colar ] [ Salvar]|
|  ↳ Sem token: apenas PETR4, VALE3, MGLU3, ITUB4.      |
|  ↳ Crie um gratis em brapi.dev (15.000 req/mes).      |
|                                                       |
|  Status: ✓ token valido (verificado 17/06/2026)       |
|  [ Remover token ]                                    |
+------------------------------------------------------+
```

- Campo `obscureText: true` com toggle de visibilidade.
- Validacao opcional: 1 chamada de teste a `/api/quote/PETR4` com o token; tratar HTTP 429 (backoff) e 401 (token invalido).
- Botao "Remover token" chama `BrapiTokenController.remover()` e limpa o secure storage.

### 7. Integridade e robustez do import/export (aspecto de seguranca)

Mesmo sendo local, o import e uma **fronteira de entrada nao confiavel** (o arquivo pode estar corrompido ou ser malicioso). Controles obrigatorios:

| Controle | Como |
|---|---|
| Verificacao de identidade | `payload['app'] == 'investa_br'`, senao recusa |
| Bloqueio de versao futura | `schemaVersion <= LocalDb.schemaVersion`, senao "atualize o app" |
| Integridade | `checksum` SHA-256 do bloco `data` confere |
| Autenticidade (backup cifrado) | AES-GCM falha de MAC => senha errada ou adulteracao |
| Atomicidade | Aplicar dentro de `db.transaction` (REPLACE limpa antes; MERGE por `id` com last-write-wins por `updatedAt`) |
| Limite de tamanho | Recusar arquivos absurdamente grandes (DoS) antes de `jsonDecode` (ex.: > 50 MiB) |
| Sanitizacao de tipos | Validar shape de cada registro (ids string, datas ISO) antes de `put` |

```dart
const _maxBytesImport = 50 * 1024 * 1024; // guarda contra arquivo gigante

Future<void> validarTamanho(File f) async {
  final len = await f.length();
  if (len > _maxBytesImport) {
    throw const ImportException('Arquivo grande demais para ser um backup valido.');
  }
}
```

### 8. Garantias automatizadas (CI/lints/testes)

A privacidade e mantida por verificacao automatica, nao por disciplina manual:

| Garantia | Mecanismo |
|---|---|
| Sem `print`/`debugPrint` em release | `very_good_analysis` (`avoid_print`) + revisao |
| Sem SDKs de tracking/analytics/crash de rede | Regra de CI: falhar build se `pubspec.lock` contiver `firebase_analytics`, `sentry`, `amplitude`, etc. |
| Token nunca em log | Teste de unidade do `SafeLogInterceptor` (asserta redacao de `Authorization` e `token=`) |
| Token fora do export | Teste: `exportar()` de um banco com token => JSON resultante nao contem o token |
| Allowlist de host | Teste: requisicao a host fora da lista => `DioException(cancel)` |
| Import defensivo | Testes cobrindo: `app` errado, `schemaVersion` futura, checksum invalido, senha errada (.investa), arquivo corrompido |
| Cripto round-trip | Teste: gravar cifrado -> reabrir com senha certa (ok) e errada (falha de MAC) |
| Eliminacao total | Teste: `apagarTudo()` remove arquivos e limpa secure storage |

```dart
// Exemplo de teste (mocktail) garantindo que o token nao vaza no export.
test('export nao contem token brapi', () async {
  await config.record('app').put(db, {'brapiToken': 'SEGREDO123', 'temaId': 'dark'});
  final json = await ImportExportService(db).exportarComoString();
  expect(json, isNot(contains('SEGREDO123')));
});
```

### 9. Resumo das decisoes (checklist de implementacao)

- [ ] **Sem backend**: apenas `GET` de leitura aos 7 dominios da allowlist; `HostAllowlistInterceptor` ativo.
- [ ] **Dados locais** em `investa_br.db` (sembast) no dir. de documentos; `cache_indicadores` fora do export.
- [ ] **Cripto opcional (A)**: codec AES-GCM do sembast, chave via PBKDF2-200k; salt em `investa_br.salt`; senha so em memoria.
- [ ] **Cripto opcional (B)**: backup `.investa` (envelope AES-256-GCM + gzip); import aceita `.json` e `.investa`.
- [ ] **Permissoes minimas**: Android so `INTERNET` (+`ACCESS_NETWORK_STATE` opcional), `allowBackup=false`; iOS ATS sem excecoes; macOS sandbox + 3 entitlements; Windows/Linux sem capabilities especiais.
- [ ] **Banco excluido de backups do SO** (allowBackup=false + dataExtractionRules; `NSURLIsExcludedFromBackupKey` em iOS/macOS).
- [ ] **LGPD**: sem coleta/telemetria; direitos atendidos por export/edicao/eliminacao; politica local; lojas como "nenhum dado coletado".
- [ ] **Token brapi**: fornecido pelo usuario, em `flutter_secure_storage`; nunca embutido, exportado nem logado; header `Bearer` + redacao em logs.
- [ ] **Import defensivo**: identidade, versao, checksum, MAC, atomicidade, limite de tamanho.
- [ ] **CI/lints/testes** travam regressoes de privacidade (sem analytics, sem vazamento de token, allowlist, cripto round-trip, apagar tudo).

---

## Internacionalizacao Multi-idioma & Formatacao

> Esta secao define COMO o Investa BR (`investa_br`) configura i18n/l10n **multi-idioma** com `flutter_localizations` e centraliza TODA a formatacao de moeda, percentual, datas e numeros. Regra de ouro do projeto: **nenhum widget chama `NumberFormat`/`DateFormat` diretamente** — tudo passa pelos formatadores centralizados em `lib/src/common/utils/`. Strings de UI vivem nos `.arb`; valores numericos/monetarios sao formatados pelos utils, **sempre no idioma ativo**.
>
> **Idiomas suportados no MVP: `pt-BR` (padrao e fallback), `en` (ingles) e `es` (espanhol).** O idioma segue o do dispositivo quando suportado, com **override manual** escolhido pelo usuario em Configuracoes e **persistido** em `configuracoes.locale` (sembast). Importante: o app trata de investimentos do Brasil, entao a **moeda e sempre BRL (R$)** — muda apenas o idioma da interface e os separadores/ordem de numeros e datas conforme o locale ativo.

### 1. Visao geral e principios

| Principio | Decisao |
|---|---|
| Idiomas suportados (MVP) | `pt-BR` (padrao + **fallback**), `en`, `es` — lista em `supportedLocales` |
| Resolucao de locale | Segue o idioma do dispositivo quando suportado; **override manual** do usuario; fallback `pt-BR` |
| Persistencia do idioma | `configuracoes.locale` (sembast); valor `"system"`/ausente = "seguir o sistema" |
| Mecanismo de strings | `flutter_localizations` + `gen-l10n` (arquivos `.arb`), classe gerada `AppLocalizations` |
| Delegates | `AppLocalizations` + `GlobalMaterial/Widgets/CupertinoLocalizations` (traduzem Material/Cupertino nos 3 idiomas) |
| Mecanismo de formatacao numerica/data | `intl ^0.20.0` (`NumberFormat`, `DateFormat`) — **sempre com o locale ativo** |
| Onde inicializar dados de locale | `main()` antes do `runApp`, via `initializeDateFormatting(null, null)` (carrega todos os locales) |
| Controle do idioma | `LocaleController` (Riverpod) le/grava `configuracoes.locale` e dirige `MaterialApp.locale` |
| Onde ficam os formatadores | `lib/src/common/utils/` (`Formatters`, `Parsers`) — providos via Riverpod, **reconstruidos quando o locale muda** |
| Tipo monetario interno | `double` em BRL; arredondamento HALF-EVEN; moeda sempre R$ independente do idioma |
| Acesso a string na UI | `context.l10n.<chave>` (extension) — nunca string literal hardcoded na UI |
| Acesso a formatacao na UI | `ref.watch(formattersProvider).moeda(valor)` |

Diferenca conceitual que o codigo NUNCA deve confundir:
- **Strings de interface** (rotulos, titulos, mensagens, plurais, generos) → `.arb` / `AppLocalizations`.
- **Valores de dominio** (R$ 1.234,56 / 110,5% / 17/06/2026) → `Formatters` baseado em `intl`. ARB so entra aqui via *placeholders* `{}` com `type: double`/`type: DateTime` quando a string precisa interpolar um valor formatado dentro de uma frase.

### 2. Dependencias e configuracao do projeto

#### 2.1 `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:        # delegates Material/Cupertino/Widgets nos idiomas suportados (pt-BR, en, es)
    sdk: flutter
  intl: ^0.20.0                 # NumberFormat / DateFormat — versao casada com gen-l10n do Flutter 3.44

flutter:
  generate: true                # ATIVA o gen-l10n (gera AppLocalizations a partir dos .arb)
```

> Atencao de versao: o `gen-l10n` do Flutter 3.44 exige uma versao compativel de `intl`. Fixar `intl: ^0.20.0` evita o erro classico `the version of intl ... is not compatible`. Nao deixar o pub resolver para uma `intl` mais nova que a esperada pelo SDK.

#### 2.2 `l10n.yaml` (raiz do projeto)

```yaml
arb-dir: lib/src/localization/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/src/localization/gen
synthetic-package: false        # gera no projeto (commitavel), nao em package sintetico
nullable-getters: false         # getters nao-nulaveis: erro de compilacao se faltar chave
use-deferred-loading: false     # desktop/mobile: carregamento direto (sem split web)
```

Comando de geracao (roda no `flutter pub get`, ou manual):

```bash
flutter gen-l10n
```

#### 2.3 Arvore de arquivos da camada de localizacao/formatacao

```
lib/src/
  localization/
    l10n/
      app_pt.arb                 # template + traducoes pt-BR (fonte da verdade)
      app_en.arb                 # ingles (mesmas chaves, traduzidas)
      app_es.arb                 # espanhol (mesmas chaves, traduzidas)
    gen/                         # gerado por gen-l10n — COMMITAR
      app_localizations.dart
      app_localizations_pt.dart
      app_localizations_en.dart
      app_localizations_es.dart
    l10n_extension.dart          # extension BuildContext.l10n
  common/
    utils/
      formatters.dart            # Formatters: moeda, percentual, data, numero, compacto
      parsers.dart               # Parsers: string pt-BR -> double/DateTime (inputs do usuario)
      money.dart                 # arredondamento monetario (HALF-EVEN, centavos)
      formatters_provider.dart   # Provider Riverpod expondo Formatters
```

> Politica de commit: `lib/src/localization/gen/**` e `*.g.dart`/`*.freezed.dart` SAO commitados (consistente com a decisao global de commitar artefatos de code-gen).

### 3. Wiring no `MaterialApp.router`

```dart
// lib/src/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'localization/gen/app_localizations.dart';

class InvestaBrApp extends ConsumerWidget {
  const InvestaBrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider); // Locale? (null = seguir o sistema)

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,

      // ---- i18n / l10n ----
      localizationsDelegates: const [
        AppLocalizations.delegate,                 // strings do app
        GlobalMaterialLocalizations.delegate,      // textos do Material (ok, cancelar, datepicker)
        GlobalWidgetsLocalizations.delegate,       // direcao de texto
        GlobalCupertinoLocalizations.delegate,     // widgets Cupertino (iOS)
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // padrao + fallback
        Locale('en'),       // ingles
        Locale('es'),       // espanhol
      ],
      // null  => Flutter resolve pelo idioma do dispositivo (localeResolutionCallback abaixo).
      // != null => idioma escolhido manualmente pelo usuario em Configuracoes.
      locale: locale,
      localeResolutionCallback: (device, supported) {
        // Casa por idioma+pais e, se nao houver, so por idioma; senao cai em pt-BR.
        if (device != null) {
          for (final s in supported) {
            if (s.languageCode == device.languageCode &&
                (s.countryCode == null || s.countryCode == device.countryCode)) {
              return s;
            }
          }
          for (final s in supported) {
            if (s.languageCode == device.languageCode) return s;
          }
        }
        return const Locale('pt', 'BR'); // fallback
      },

      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.mode,
    );
  }
}
```

#### 3.1 Inicializacao em `main.dart`

`intl` precisa carregar os simbolos de locale antes de qualquer `DateFormat('...','pt_BR')`. Sem isso, lanca `LocaleDataException`.

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega os simbolos de data/numero de TODOS os locales suportados (pt-BR, en, es).
  // Passar `null` inicializa todos os locales conhecidos do intl de uma vez —
  // assim a troca de idioma em runtime nao precisa de init adicional.
  await initializeDateFormatting(null, null);
  // Default global do intl: pt-BR. O LocaleController atualiza Intl.defaultLocale
  // a cada troca de idioma; o Formatters tambem recebe o locale ativo explicitamente.
  Intl.defaultLocale = 'pt_BR';

  // ... abrir sembast, window_manager (desktop), etc.

  runApp(const ProviderScope(child: InvestaBrApp()));
}
```

#### 3.2 Extension de acesso as strings (`l10n_extension.dart`)

```dart
import 'package:flutter/widgets.dart';
import 'gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

Uso na UI: `Text(context.l10n.dashboardTitle)`.

### 3.3 `LocaleController` — idioma do usuario (persistido) + seletor

O idioma e estado de aplicacao: lido/gravado em `configuracoes.locale` (sembast) e exposto por um controller Riverpod que dirige `MaterialApp.locale`. Valor `null` significa **"seguir o idioma do dispositivo"** (a resolucao final fica a cargo do `localeResolutionCallback`).

```dart
// lib/src/features/configuracoes/application/locale_controller.dart
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// Idiomas oferecidos para escolha manual (alem de "seguir o sistema").
const kSupportedLocales = <Locale>[
  Locale('pt', 'BR'),
  Locale('en'),
  Locale('es'),
];

@riverpod
class LocaleController extends _$LocaleController {
  @override
  Locale? build() {
    // configuracoes.locale: 'pt_BR' | 'en' | 'es' | 'system' (ou ausente).
    final code = ref.watch(configRepositoryProvider).locale; // String?
    return _fromCode(code);
  }

  /// Define o idioma. `null` => seguir o sistema.
  Future<void> definir(Locale? locale) async {
    state = locale;
    Intl.defaultLocale = (locale ?? const Locale('pt', 'BR')).toString();
    await ref.read(configRepositoryProvider).gravarLocale(_toCode(locale));
  }

  Locale? _fromCode(String? code) {
    if (code == null || code == 'system') return null;
    final p = code.split('_');
    return p.length == 2 ? Locale(p[0], p[1]) : Locale(p[0]);
  }

  String _toCode(Locale? l) => l == null
      ? 'system'
      : (l.countryCode == null ? l.languageCode : '${l.languageCode}_${l.countryCode}');
}
```

Seletor de idioma em **Configuracoes** (opcoes = "Seguir o sistema" + os 3 idiomas):

```dart
final atual = ref.watch(localeControllerProvider);
return Column(children: [
  RadioListTile<Locale?>(
    title: Text(context.l10n.idiomaSeguirSistema),   // "Seguir o sistema"
    value: null, groupValue: atual,
    onChanged: (v) => ref.read(localeControllerProvider.notifier).definir(v),
  ),
  for (final l in kSupportedLocales)
    RadioListTile<Locale?>(
      title: Text(_nomeIdioma(l)),                   // autonimo: "Portugues (Brasil)", "English", "Espanol"
      value: l, groupValue: atual,
      onChanged: (v) => ref.read(localeControllerProvider.notifier).definir(v),
    ),
]);
```

> O nome de cada idioma e exibido **no proprio idioma** (autonimo), nao traduzido. Trocar o idioma reconstroi `MaterialApp` (novas strings via `AppLocalizations`) **e** o `formattersProvider`/`parsersProvider` (nova formatacao numerica/data), porque todos observam o `LocaleController`. Como `configuracoes.locale` ja existe no schema (secao *Persistencia*), a escolha sobrevive a reinicios e entra no export/import.

### 4. Arquivos `.arb`

#### 4.1 Convencoes

- `app_pt.arb` e o **template** (define chaves + metadados `@chave`).
- Chaves em `lowerCamelCase`, agrupadas por feature por prefixo (`dashboard...`, `rendaFixa...`, `acoes...`, `conversor...`, `config...`, `comum...`).
- Toda chave tem `@chave` com `description` (obrigatorio por lint de qualidade do projeto).
- Placeholders monetarios/percentuais que entram DENTRO de uma frase usam `type: double` + `format`/`optionalParameters` do `intl`; quando o valor ja vem formatado pelo `Formatters`, usar placeholder `type: String` e passar o texto pronto.
- Plurais com `{count, plural, ...}`; genero (se necessario) com `{genero, select, ...}`.

#### 4.2 `lib/src/localization/l10n/app_pt.arb` (extrato representativo)

```json
{
  "@@locale": "pt_BR",

  "appTitle": "Investa BR",
  "@appTitle": { "description": "Nome do aplicativo exibido na barra de titulo e no SO." },

  "dashboardTitle": "Inicio",
  "@dashboardTitle": { "description": "Titulo da aba/tela inicial (dashboard)." },

  "dashboardPatrimonioLabel": "Patrimonio total",
  "@dashboardPatrimonioLabel": { "description": "Rotulo do bloco de patrimonio total no dashboard." },

  "dashboardAtualizadoEm": "Atualizado em {data}",
  "@dashboardAtualizadoEm": {
    "description": "Carimbo de data da ultima atualizacao dos indicadores. Recebe a data JA FORMATADA (dd/MM/yyyy) pelo Formatters.",
    "placeholders": { "data": { "type": "String", "example": "17/06/2026" } }
  },

  "comumValorMonetarioInline": "Valor: {valor}",
  "@comumValorMonetarioInline": {
    "description": "Frase que interpola um valor monetario ja formatado em R$ pelo Formatters.",
    "placeholders": { "valor": { "type": "String", "example": "R$ 10.000,00" } }
  },

  "rendaFixaQtdInvestimentos": "{count, plural, =0{Nenhum investimento} =1{1 investimento} other{{count} investimentos}}",
  "@rendaFixaQtdInvestimentos": {
    "description": "Contagem de investimentos de renda fixa cadastrados (plural pt-BR).",
    "placeholders": { "count": { "type": "int" } }
  },

  "conversorMelhorOpcao": "Melhor opcao: {nome} ({taxaLiquida} a.a. liquido)",
  "@conversorMelhorOpcao": {
    "description": "Resultado do comparador. taxaLiquida vem formatado como percentual pelo Formatters.",
    "placeholders": {
      "nome": { "type": "String", "example": "LCI 95% CDI" },
      "taxaLiquida": { "type": "String", "example": "13,63%" }
    }
  },

  "comumAvisoInformativo": "Valores informativos. Nao constituem recomendacao de investimento.",
  "@comumAvisoInformativo": { "description": "Aviso de conformidade (aspecto CVM) exibido em telas de calculo/comparador." },

  "configIsencaoIrDatada": "Em 2026, LCI/LCA/CRI/CRA, debentures incentivadas e poupanca sao isentas de IR-PF.",
  "@configIsencaoIrDatada": { "description": "Aviso datado sobre a regra de isencao tributaria vigente (versionada)." },

  "configIdiomaTitulo": "Idioma",
  "@configIdiomaTitulo": { "description": "Titulo da secao de escolha de idioma em Configuracoes." },

  "idiomaSeguirSistema": "Seguir o sistema",
  "@idiomaSeguirSistema": { "description": "Opcao do seletor de idioma que usa o idioma do dispositivo." }
}
```

> **Decisao de design importante:** valores monetarios e percentuais que aparecem isolados (cards, celulas de tabela, eixos de grafico) NAO passam por `.arb` — sao formatados direto pelo `Formatters` e exibidos em `Text`. O `.arb` so e usado quando o numero esta **embutido numa frase traduzivel** (ex.: "Atualizado em {data}"), e mesmo assim recebemos o valor **ja formatado** como `String`, para garantir consistencia com o `Formatters` central e evitar dupla configuracao de locale.

#### 4.3 `app_en.arb` e `app_es.arb` (idiomas adicionais)

Os arquivos de traducao contem **exatamente as mesmas chaves** do template `app_pt.arb` (o `gen-l10n` emite warning para chave ausente; com `nullable-getters: false` uma chave faltante vira erro de uso). NAO repetem os metadados `@chave` (esses vivem so no template). Os placeholders (`{data}`, `{count}`, `{nome}`, `{taxaLiquida}`) sao preservados; os plurais sao reescritos conforme a regra de cada idioma.

`lib/src/localization/l10n/app_en.arb`:
```json
{
  "@@locale": "en",
  "appTitle": "Investa BR",
  "dashboardTitle": "Home",
  "dashboardPatrimonioLabel": "Total balance",
  "dashboardAtualizadoEm": "Updated on {data}",
  "comumValorMonetarioInline": "Amount: {valor}",
  "rendaFixaQtdInvestimentos": "{count, plural, =0{No investments} =1{1 investment} other{{count} investments}}",
  "conversorMelhorOpcao": "Best option: {nome} ({taxaLiquida} net p.a.)",
  "comumAvisoInformativo": "Informational figures. Not an investment recommendation.",
  "configIsencaoIrDatada": "In 2026, LCI/LCA/CRI/CRA, incentivized debentures and savings are income-tax exempt for individuals (Brazil).",
  "configIdiomaTitulo": "Language",
  "idiomaSeguirSistema": "Follow system"
}
```

`lib/src/localization/l10n/app_es.arb`:
```json
{
  "@@locale": "es",
  "appTitle": "Investa BR",
  "dashboardTitle": "Inicio",
  "dashboardPatrimonioLabel": "Patrimonio total",
  "dashboardAtualizadoEm": "Actualizado el {data}",
  "comumValorMonetarioInline": "Importe: {valor}",
  "rendaFixaQtdInvestimentos": "{count, plural, =0{Sin inversiones} =1{1 inversion} other{{count} inversiones}}",
  "conversorMelhorOpcao": "Mejor opcion: {nome} ({taxaLiquida} neto anual)",
  "comumAvisoInformativo": "Valores informativos. No constituyen recomendacion de inversion.",
  "configIsencaoIrDatada": "En 2026, LCI/LCA/CRI/CRA, debentures incentivadas y ahorro estan exentos de IR para personas fisicas (Brasil).",
  "configIdiomaTitulo": "Idioma",
  "idiomaSeguirSistema": "Seguir el sistema"
}
```

> Manter os tres `.arb` sincronizados e tarefa de manutencao: ao adicionar uma chave no template, adiciona-la tambem em `en` e `es`. Um teste de CI pode comparar os conjuntos de chaves dos tres arquivos e falhar se divergirem.

### 5. `Formatters` — moeda, percentual, data, numero

Toda a formatacao vive em `lib/src/common/utils/formatters.dart`. Os `NumberFormat`/`DateFormat` sao **criados uma vez** (custosos de instanciar) e reutilizados.

```dart
// lib/src/common/utils/formatters.dart
import 'package:intl/intl.dart';

/// Formatadores centralizados pt-BR. Todas as instancias sao cacheadas.
/// NUNCA instanciar NumberFormat/DateFormat fora desta classe.
class Formatters {
  Formatters({this.locale = 'pt_BR'});

  final String locale;

  // ---------- MOEDA (BRL) ----------
  // R$ 1.234,56  -> simbolo + espaco + milhar '.' + decimal ',' (2 casas)
  late final NumberFormat _moeda =
      NumberFormat.currency(locale: locale, symbol: r'R$', decimalDigits: 2);

  // Sem simbolo (para tabelas/edicao): 1.234,56
  late final NumberFormat _moedaSemSimbolo =
      NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2);

  // Compacto para eixos/grafico: R$ 1,2 mi
  late final NumberFormat _moedaCompacta =
      NumberFormat.compactCurrency(locale: locale, symbol: r'R$');

  /// R$ 1.234,56  (entrada em reais, ja arredondada pelo Money antes de exibir)
  String moeda(num valor) => _moeda.format(valor);

  /// 1.234,56 (sem simbolo)
  String moedaSemSimbolo(num valor) => _moedaSemSimbolo.format(valor).trim();

  /// R$ 1,2 mi / R$ 532,9 bi — para eixos do fl_chart
  String moedaCompacta(num valor) => _moedaCompacta.format(valor);

  // ---------- PERCENTUAL ----------
  // Convencao do projeto: percentuais sao armazenados como NUMERO INTEIRO/DECIMAL
  // ja em "unidade percentual" (ex.: 14.5 = 14,5%; 110 = 110%), NAO como fracao 0..1.
  // Por isso usamos decimalPattern + sufixo manual, e NAO decimalPercentPattern
  // (que multiplicaria por 100).
  late final NumberFormat _pct2 = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;

  late final NumberFormat _pctFlex = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 4;

  /// 14.5  -> "14,50%"  (2 casas fixas — uso padrao em cards/relatorios)
  String percentual(num valorEmUnidadePercentual) =>
      '${_pct2.format(valorEmUnidadePercentual)}%';

  /// 110 -> "110%" ; 13.45 -> "13,45%" (casas variaveis 0..4, sem zeros a esquerda inuteis)
  String percentualFlex(num v) => '${_pctFlex.format(v)}%';

  /// Para taxas expressas como fracao 0..1 (ex.: 0.145 -> "14,50%").
  /// Use quando o valor vier de calculo interno (taxaLiquidaAnualEfetiva retorna 0..1).
  String percentualDeFracao(double fracao) => percentual(fracao * 100);

  // ---------- DATA (ordem/idioma seguem o locale ativo) ----------
  // yMd respeita o locale: pt-BR/es -> dd/MM/yyyy ; en -> M/d/yyyy.
  late final DateFormat _data = DateFormat.yMd(locale);                    // pt:17/06/2026  en:6/17/2026
  late final DateFormat _dataHora = DateFormat.yMd(locale).add_Hm();       // + HH:mm
  late final DateFormat _mesAno = DateFormat('MM/yyyy', locale);           // 06/2026
  late final DateFormat _mesAnoExt = DateFormat('MMMM/yyyy', locale);      // junho/2026 | June/2026 | junio/2026
  late final DateFormat _diaMes = DateFormat('dd MMM', locale);            // 17 jun (nome do mes localizado)

  String data(DateTime d) => _data.format(d);
  String dataHora(DateTime d) => _dataHora.format(d);
  String mesAno(DateTime d) => _mesAno.format(d);
  String mesAnoExtenso(DateTime d) => _mesAnoExt.format(d);
  String diaMes(DateTime d) => _diaMes.format(d);

  // ---------- NUMERO ----------
  late final NumberFormat _inteiro = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = 0; // 1.000

  late final NumberFormat _quantidade = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 8; // quantidade de cotas/acoes (fracionarias)

  String inteiro(num v) => _inteiro.format(v);
  String quantidade(num v) => _quantidade.format(v);
}
```

#### 5.1 Tabela de saidas esperadas (contrato de formatacao)

> As saidas abaixo sao no locale **pt-BR**. Com o idioma ativo em `en`, a MESMA API muda separadores/ordem automaticamente: `moeda(10000)` => `R$ 10,000.00`; `data(17/06/2026)` => `6/17/2026`; `percentual(14.5)` => `14.50%`. A **moeda permanece BRL (R$)** em todos os idiomas — muda apenas a formatacao numerica/de data.

| Metodo | Entrada | Saida pt-BR | Observacao |
|---|---|---|---|
| `moeda` | `10000` | `R$ 10.000,00` | espaco apos `R$`, milhar `.`, decimal `,` |
| `moeda` | `1234.5` | `R$ 1.234,50` | sempre 2 casas |
| `moeda` | `-89.9` | `-R$ 89,90` | negativo: sinal antes do simbolo |
| `moedaSemSimbolo` | `1234.56` | `1.234,56` | para campos de edicao/celulas |
| `moedaCompacta` | `532981244102` | `R$ 533 bi` | eixos de grafico |
| `percentual` | `14.5` | `14,50%` | valor JA em unidade percentual |
| `percentual` | `110` | `110,00%` | % do CDI |
| `percentualFlex` | `110` | `110%` | sem casas desnecessarias |
| `percentualDeFracao` | `0.1363` | `13,63%` | converte fracao 0..1 |
| `data` | `DateTime(2026,6,17)` | `17/06/2026` | |
| `dataHora` | `2026-06-17 08:55` | `17/06/2026 08:55` | carimbo de cache |
| `mesAnoExtenso` | `DateTime(2026,6,1)` | `junho/2026` | IPCA/IGP-M mensal |
| `quantidade` | `100` | `100` | acoes |

> **Pegadinha do percentual (load-bearing):** NAO usar `NumberFormat.decimalPercentPattern` para nossos percentuais, porque ele assume que a entrada e uma **fracao 0..1** e multiplica por 100 — exibiria `14.5` como `1.450%`. Como o dominio do Investa BR guarda taxas em "unidade percentual" (`14.5`, `110`), usamos `decimalPattern` + sufixo `%` manual. A unica via que aceita fracao e `percentualDeFracao`, usada explicitamente quando o calculo retorna 0..1 (ex.: `taxaLiquidaAnualEfetiva`).

#### 5.2 Provider Riverpod (`formatters_provider.dart`)

```dart
// lib/src/common/utils/formatters_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'formatters.dart';

part 'formatters_provider.g.dart';

@riverpod
Formatters formatters(Ref ref) {
  // Observa o idioma: trocar de idioma => Formatters reconstroi com o novo locale.
  final override = ref.watch(localeControllerProvider);
  return Formatters(locale: resolveIntlLocaleTag(override)); // 'pt_BR' | 'en' | 'es'
}

@riverpod
Parsers parsers(Ref ref) {
  final override = ref.watch(localeControllerProvider);
  return Parsers(locale: resolveIntlLocaleTag(override));
}

/// override != null  => tag do idioma escolhido pelo usuario.
/// override == null   => idioma do dispositivo, limitado aos suportados; fallback 'pt_BR'.
String resolveIntlLocaleTag(Locale? override) {
  final l = override ??
      WidgetsBinding.instance.platformDispatcher.locale; // locale do SO
  final tag = l.countryCode == null
      ? l.languageCode
      : '${l.languageCode}_${l.countryCode}';
  const suportados = {'pt_BR', 'en', 'es'};
  if (suportados.contains(tag)) return tag;
  if (suportados.contains(l.languageCode)) return l.languageCode; // ex.: 'en_US' -> 'en'
  return 'pt_BR';
}
```

Uso na UI:

```dart
final f = ref.watch(formattersProvider);
Text(f.moeda(posicao.valorAtual));                 // R$ 11.430,00
Text(f.percentual(indicadores.selicMeta));         // 14,50%
Text(context.l10n.dashboardAtualizadoEm(f.data(snapshot.fetchedAt))); // "Atualizado em 17/06/2026"
```

### 6. `Parsers` — entrada do usuario (string pt-BR -> tipo)

O usuario digita `R$ 10.000,00`, `110,5`, `17/06/2026`. Precisamos do caminho inverso. Centralizado em `parsers.dart`.

```dart
// lib/src/common/utils/parsers.dart
import 'package:intl/intl.dart';

class Parsers {
  Parsers({this.locale = 'pt_BR'});
  final String locale;

  late final NumberFormat _num = NumberFormat.decimalPattern(locale);
  // Separadores do locale ATIVO: pt-BR/es -> decimal ',' grupo '.'; en -> decimal '.' grupo ','.
  String get _dec => _num.symbols.DECIMAL_SEP;
  String get _grp => _num.symbols.GROUP_SEP;
  // Padrao de data do locale (yMd): pt-BR/es dd/MM/yyyy ; en M/d/yyyy.
  late final DateFormat _data = DateFormat.yMd(locale);

  /// "R$ 10.000,00" (pt) / "$10,000.00" (en) -> 10000.0. Robusto a simbolo/espacos.
  /// Estrategia: remove o separador de GRUPO do locale, troca o separador
  /// DECIMAL do locale por '.', e descarta o resto (simbolo de moeda etc.).
  double? moeda(String entrada) {
    final limpo = entrada
        .replaceAll(_grp, '')
        .replaceAll(_dec, '.')
        .replaceAll(RegExp(r'[^\d.\-]'), '');
    if (limpo.isEmpty || limpo == '-') return null;
    return double.tryParse(limpo);
  }

  /// "110,5" (pt) / "110.5" (en) -> 110.5  (taxa em unidade percentual)
  double? percentual(String entrada) {
    final limpo = entrada
        .replaceAll('%', '')
        .replaceAll(_grp, '')
        .replaceAll(_dec, '.')
        .trim();
    return double.tryParse(limpo);
  }

  /// Data no padrao do locale ativo -> DateTime; retorna null se invalido (nao lanca).
  DateTime? data(String entrada) {
    try {
      return _data.parseStrict(entrada);
    } catch (_) {
      return null;
    }
  }
}
```

> **Por que `replaceAll` em vez de `NumberFormat.parse` para moeda?** O input do usuario costuma vir com simbolo de moeda, espacos e separador de milhar. `NumberFormat.parse` falha com simbolo de moeda e e fragil com milhares parciais. A normalizacao manual (remover o separador de GRUPO, trocar o DECIMAL por `.`) e deterministica e testavel — e, como os separadores vem dos `symbols` do **locale ativo**, o mesmo parser funciona em `pt-BR`, `en` e `es`. Os testes unitarios devem cobrir, por locale: `"R$ 1.234,56"` (pt), `"$10,000.00"` (en), `"1234,5"`, `"1.000"`, `""`, `"abc"`, negativos.

#### 6.1 Mascara de input monetario (campos de cadastro)

Para o `TextFormField` de valor (telas de Cadastro RF/Acoes), aplicar formatacao enquanto digita via `TextInputFormatter`, sempre delegando ao `Formatters`:

```dart
// lib/src/common/utils/money_input_formatter.dart
import 'package:flutter/services.dart';
import 'formatters.dart';

class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this._f);
  final Formatters _f;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final digitos = newV.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitos.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final centavos = int.parse(digitos);
    final valor = centavos / 100.0;            // ultimos 2 digitos = centavos
    final texto = _f.moeda(valor);             // R$ 1.234,56
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
```

Uso: `inputFormatters: [MoneyInputFormatter(ref.read(formattersProvider))]` no campo de valor inicial.

### 7. Datas: timezone, parsing das APIs e exibicao

O app cruza tres convencoes de data — todas tratadas e convertidas para `DateTime` na borda da camada `data`, e exibidas exclusivamente pelo `Formatters`.

| Fonte | Formato bruto | Conversao |
|---|---|---|
| BCB SGS (`data`, `dataFim`) | `"17/06/2026"` (DD/MM/YYYY, string) | `DateFormat('dd/MM/yyyy').parseStrict` |
| BrasilAPI feriados | `"2026-01-01"` (ISO date) | `DateTime.parse` |
| Tesouro CKAN CSV | `"17/06/2026"` (dd/mm/aaaa) | `DateFormat('dd/MM/yyyy').parseStrict` |
| AwesomeAPI `create_date` | `"2026-06-17 09:55:36"` | `DateFormat('yyyy-MM-dd HH:mm:ss').parse` |
| Cache/export interno | ISO 8601 (`toIso8601String`) | `DateTime.parse` |

#### 7.1 Fuso horario do cache diario (America/Sao_Paulo, UTC-3)

A chave de cache `yyyy-MM-dd` e o teste "data == hoje" usam o fuso de Brasilia (sem horario de verao desde 2019 → UTC-3 fixo). NAO usar `DateTime.now()` local do device cru, pois um usuario em outro fuso quebraria a logica de "primeira requisicao do dia".

```dart
// lib/src/common/utils/data_brasil.dart
class DataBrasil {
  /// Data corrente em America/Sao_Paulo (UTC-3), formato yyyy-MM-dd.
  static String hojeChave() {
    final spNow = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return '${spNow.year.toString().padLeft(4, '0')}-'
        '${spNow.month.toString().padLeft(2, '0')}-'
        '${spNow.day.toString().padLeft(2, '0')}';
  }
}
```

> Importante: essa chave (`yyyy-MM-dd`) e **interna** (comparacao/persistencia), nunca exibida. A data exibida ao usuario sempre passa por `Formatters.data` → `17/06/2026`.

#### 7.2 Parsing defensivo do SGS (valor como STRING + decimal `.`)

O SGS retorna `valor` como **string** com ponto decimal (`"14.50"`, `"0.053400"`), e datas em `DD/MM/YYYY`. Nao confundir com o input do usuario (que usa virgula). O parse de API e SEMPRE com `double.parse` sobre ponto:

```dart
// dentro do datasource SGS
double parseValorSgs(String raw) =>
    double.parse(raw.trim()); // SGS usa '.' decimal; nunca trocar por ','

DateTime parseDataSgs(String raw) =>
    DateFormat('dd/MM/yyyy', 'pt_BR').parseStrict(raw.trim());
```

### 8. Arredondamento monetario

Regras de arredondamento sao **load-bearing** (afetam projecoes, IR/IOF e patrimonio). Centralizadas em `money.dart`.

#### 8.1 Politica

| Item | Decisao |
|---|---|
| Modo de arredondamento | **HALF-EVEN** (banker's rounding) — reduz vies acumulado em somas de carteira |
| Granularidade de exibicao/persistencia de moeda | 2 casas (centavos) |
| Quando arredondar | Apenas na **fronteira de exibicao e de persistencia de valores monetarios finais** (VF, rendimento, IR, IOF, VF liquido). Calculos intermediarios (fatores diarios, juros compostos base 252) permanecem em `double` de precisao plena |
| Taxas/percentuais | NAO arredondar para 2 casas no calculo; arredondar so na exibicao via `Formatters.percentual` |
| Por que nao `double` arredondado a cada passo | Arredondar fatores diarios propaga erro em prazos longos (252 d.u.); arredonda-se so o resultado |

> Justificativa do HALF-EVEN: o padrao do Dart `double.toStringAsFixed`/`round()` usa half-up (arredonda 0,5 sempre para cima), o que enviesa somas grandes de carteira. HALF-EVEN ("arredonda para o par") e o padrao financeiro/contabil e o que a `intl` NumberFormat usa internamente para exibicao — alinhamos o helper de persistencia ao mesmo criterio para que valor exibido == valor salvo.

#### 8.2 Implementacao (`money.dart`)

```dart
// lib/src/common/utils/money.dart

/// Helpers de arredondamento monetario. Use SEMPRE antes de persistir
/// ou comparar valores monetarios finais. Calculos intermediarios ficam
/// em double de precisao plena.
class Money {
  const Money._();

  /// Arredonda para [casas] decimais usando HALF-EVEN (banker's rounding).
  /// Ex.: arredondar(2.675, 2) == 2.68 ; arredondar(2.665, 2) == 2.66.
  static double arredondar(double valor, [int casas = 2]) {
    if (valor.isNaN || valor.isInfinite) return valor;
    final fator = _pow10(casas);
    final escalado = valor * fator;
    final piso = escalado.floorToDouble();
    final resto = escalado - piso;

    double arredondadoEscalado;
    const eps = 1e-9; // tolerancia para erro de ponto flutuante
    if ((resto - 0.5).abs() < eps) {
      // exatamente .5 -> vai para o PAR mais proximo
      arredondadoEscalado = (piso % 2 == 0) ? piso : piso + 1;
    } else {
      arredondadoEscalado = escalado.roundToDouble();
    }
    return arredondadoEscalado / fator;
  }

  /// Conveniencia: arredonda para centavos (2 casas).
  static double centavos(double valor) => arredondar(valor, 2);

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}
```

#### 8.3 Onde aplicar no motor financeiro

```dart
// Ao finalizar uma projecao (apos juros compostos base 252, IR e IOF):
final vfBruto      = vi * pow(1 + iAnual, du / 252).toDouble(); // precisao plena
final rendBruto    = vfBruto - vi;                              // precisao plena
final iof          = aliquotaIof(dc) * rendBruto;               // precisao plena
final ir           = aliquotaIr(dc, isento) * (rendBruto - iof);// precisao plena

// Arredonda SOMENTE os valores monetarios finais que serao exibidos/persistidos:
final out = Projecao(
  vfBruto:        Money.centavos(vfBruto),
  rendimentoBruto:Money.centavos(rendBruto),
  iof:            Money.centavos(iof),
  ir:             Money.centavos(ir),
  vfLiquido:      Money.centavos(vi + rendBruto - iof - ir),
);
```

> Patrimonio total (dashboard): somar os valores **ja arredondados a centavos** de cada posicao, e arredondar o total uma vez ao final. Isso evita o classico "1 centavo de diferenca" entre a soma exibida e a soma dos itens.

#### 8.4 Verificacao do HALF-EVEN (casos de teste obrigatorios)

| Entrada | Casas | Esperado (HALF-EVEN) | Por que |
|---|---|---|---|
| `2.675` | 2 | `2.68` | digito anterior `7` impar → sobe |
| `2.665` | 2 | `2.66` | digito anterior `6` par → mantem |
| `2.5` | 0 | `2.0` | par mais proximo |
| `3.5` | 0 | `4.0` | par mais proximo |
| `0.125` | 2 | `0.12` | `2` par → mantem |
| `0.135` | 2 | `0.14` | `3` impar → sobe |
| `-2.675` | 2 | `-2.68` | simetrico |

### 9. Integracao com graficos (fl_chart) e acessibilidade

- Eixos monetarios do `LineChart`/`BarChart`/`PieChart`: usar `Formatters.moedaCompacta` para labels de eixo (evita overflow) e `Formatters.moeda` no tooltip/legenda.
- Percentuais em eixos: `Formatters.percentual` / `percentualFlex`.
- **Acessibilidade pt-BR:** toda legenda textual do grafico (exigida pela decisao de acessibilidade — nunca depender so de cor) usa valores formatados: `"Renda Fixa: R$ 79.640,00 (62%)"`. Os rotulos descritivos sao strings do `.arb` quando contem frase; o valor monetario/percentual vem do `Formatters`.
- `Semantics(label: ...)` em cards de indicador deve concatenar nome (do `.arb`) + valor formatado: `Semantics(label: '${context.l10n.selicLabel}: ${f.percentual(v)}')`.
- Variacao (alta/baixa) sempre com icone + texto + valor formatado, nunca so verde/vermelho.

### 10. Testes obrigatorios da camada de formatacao

Cobrir com `flutter_test` (unit, sem necessidade de mocks):

```dart
group('Formatters pt-BR', () {
  final f = Formatters();
  test('moeda', () {
    expect(f.moeda(10000), 'R\$ 10.000,00');
    expect(f.moeda(1234.5), 'R\$ 1.234,50');
    expect(f.moeda(-89.9), '-R\$ 89,90');
  });
  test('percentual (unidade percentual, nao fracao)', () {
    expect(f.percentual(14.5), '14,50%');
    expect(f.percentual(110), '110,00%');
    expect(f.percentualDeFracao(0.1363), '13,63%');
  });
  test('data', () {
    expect(f.data(DateTime(2026, 6, 17)), '17/06/2026');
    expect(f.mesAnoExtenso(DateTime(2026, 6, 1)), 'junho/2026');
  });
});

group('Parsers pt-BR', () {
  final p = Parsers();
  test('moeda suja', () {
    expect(p.moeda('R\$ 1.234,56'), 1234.56);
    expect(p.moeda('1234,5'), 1234.5);
    expect(p.moeda(''), isNull);
    expect(p.moeda('abc'), isNull);
  });
  test('data invalida nao lanca', () {
    expect(p.data('32/13/2026'), isNull);
    expect(p.data('17/06/2026'), DateTime(2026, 6, 17));
  });
});

group('Money HALF-EVEN', () {
  test('arredonda para par', () {
    expect(Money.centavos(2.675), 2.68);
    expect(Money.centavos(2.665), 2.66);
    expect(Money.arredondar(2.5, 0), 2.0);
    expect(Money.arredondar(3.5, 0), 4.0);
  });
});
```

> Nota de setup de teste: como `initializeDateFormatting` so roda no `main`, testes que usam `DateFormat`/`NumberFormat` por locale devem chamar `await initializeDateFormatting(null, null)` em `setUpAll` (carrega pt-BR, en e es de uma vez). Replicar os grupos acima para `en` e `es` — ex.: `Formatters(locale:'en').moeda(10000) == r'R$ 10,000.00'` e `.data(DateTime(2026,6,17)) == '6/17/2026'` — garantindo o contrato em todos os idiomas suportados.

### 11. Checklist de implementacao (acionavel)

1. Adicionar `flutter_localizations`, `intl: ^0.20.0` e `flutter: generate: true` no `pubspec.yaml`.
2. Criar `l10n.yaml` na raiz com `arb-dir`, `template-arb-file: app_pt.arb`, `synthetic-package: false`, `nullable-getters: false`.
3. Criar `app_pt.arb` (`@@locale: pt_BR`, todas as chaves com `@chave`) **e** `app_en.arb` (`@@locale: en`) **e** `app_es.arb` (`@@locale: es`) com as MESMAS chaves traduzidas (sem `@meta`).
4. Rodar `flutter gen-l10n` (ou `flutter pub get`) → gera `app_localizations(_pt/_en/_es).dart`; commitar o gerado.
5. Criar `l10n_extension.dart` com `BuildContext.l10n`.
6. Em `main()`: `await initializeDateFormatting(null, null)` (carrega TODOS os locales) + `Intl.defaultLocale = 'pt_BR'` antes do `runApp`.
7. No `MaterialApp.router`: `localizationsDelegates` (4 delegates), `supportedLocales: [pt-BR, en, es]`, `locale: ref.watch(localeControllerProvider)`, `localeResolutionCallback` (fallback pt-BR) e `onGenerateTitle`.
8. Implementar o `LocaleController` (le/grava `configuracoes.locale`) e o **seletor de idioma** em Configuracoes ("Seguir o sistema" + 3 idiomas).
9. Implementar `Formatters`, `Parsers`, `Money`, `MoneyInputFormatter`, `DataBrasil` em `lib/src/common/utils/` — `Formatters`/`Parsers` recebem o **locale ativo**.
10. Expor `Formatters`/`Parsers` via `formattersProvider`/`parsersProvider` **observando `localeControllerProvider`** (reconstroem ao trocar idioma).
11. Garantir por lint/review que nenhum widget instancia `NumberFormat`/`DateFormat` diretamente — tudo via `Formatters`.
12. Escrever os testes da secao 10 nos 3 locales (moeda, percentual, data, parse, HALF-EVEN), incluindo troca de idioma em runtime.
13. Garantir parse de API com ponto decimal (SGS/CKAN), de formato FIXO, separado do parse de input do usuario (que segue o locale ativo).

---

## Testes & Qualidade de Código

Esta seção define a estratégia de testes e o regime de qualidade estática do **Investa BR** (`investa_br`). Tudo aqui é prescritivo: o implementador deve seguir os caminhos de arquivo, comandos, fixtures e padrões de mock exatamente como descritos. A regra-mãe é: **lógica financeira nunca regride** — qualquer alteração no motor de cálculo, na tabela de IR/IOF, no parsing das APIs ou na lógica de cache diário deve ser coberta por teste unitário antes do merge.

> **Premissa de execução**: o ambiente fixa Flutter 3.44 via FVM (`.fvmrc`). Todo comando de teste/análise neste documento é prefixado por `fvm` (ex.: `fvm flutter test`, `fvm dart run build_runner build`). Em CI o `fvm` garante a mesma versão do SDK que o dev local.

---

### 1. Pirâmide de testes

Distribuição-alvo de esforço e contagem (proporção, não número absoluto):

```
                    ╱╲
                   ╱  ╲        E2E / patrol            ~5%
                  ╱ E2E╲       (integration_test)      ~6-12 cenários
                 ╱──────╲      fluxos críticos ponta a ponta
                ╱ widget  ╲    Widget tests            ~25%
               ╱  tests    ╲   telas + componentes Riverpod
              ╱─────────────╲
             ╱   unit tests   ╲ Unit (puro Dart)       ~70%
            ╱  cálculo + parse ╲ motor financeiro, mappers,
           ╱   + cache + i/o    ╲ cache, import/export, formatters
          ╱──────────────────────╲
```

| Camada | Pacote | Onde roda | O que cobre | Velocidade | Alvo de cobertura |
|---|---|---|---|---|---|
| **Unit** | `flutter_test` + `mocktail` | host (VM Dart) | motor financeiro (252/360/365, IR, IOF, gross-up), parsing SGS/brapi/CNPJ/Tesouro CSV, `DailyCacheService`, import/export (REPLACE/MERGE/checksum), `Result<T>` mapping, formatters intl | ms | **≥ 95% nas funções financeiras** |
| **Widget** | `flutter_test` + `ProviderContainer`/`overrideWith` | host (Flutter test binding) | telas com estados `AsyncValue` (data/loading/error), navegação responsiva (breakpoints), formulários, semântica/acessibilidade, gráficos com legenda textual | dezenas de ms | ≥ 70% nos widgets de `presentation` |
| **Integration / E2E** | `integration_test` + `patrol` | device/emulador/desktop | boot → cache diário → dashboard; cadastro RF → projeção → patrimônio; export → import (file_picker/share_plus nativos) | s | fluxos críticos (não medido por %) |

A base larga (unit) reflete o perfil do app: **o valor de negócio está na matemática financeira e no parsing defensivo das APIs**, que são código puro-Dart sem dependência de UI ou rede e, portanto, baratos e rápidos de testar exaustivamente.

#### 1.1 Árvore de arquivos de teste

Espelha `lib/src/` (feature-first). Convenção: cada arquivo `foo.dart` testável tem `foo_test.dart` no mesmo caminho relativo sob `test/`.

```
test/
  src/
    common/
      utils/
        formatters_test.dart            # NumberFormat R$, %, DateFormat dd/MM/yyyy
        dias_uteis_test.dart            # contagem de dias úteis c/ feriados
      result_test.dart                  # sealed Result<T> Success/Failure
    features/
      renda_fixa/
        domain/
          motor_calculo_test.dart       # CRÍTICO: base 252/360/365, juros compostos
          tributacao_test.dart          # CRÍTICO: IR regressivo + IOF + isenção
          taxa_value_object_test.dart   # value object {tipo,valor,indexador,base,cap}
        data/
          rf_repository_test.dart        # sembast CRUD + Finder (mock db ou memória)
      conversor_taxas/
        domain/
          comparador_test.dart          # rentabilidade líq. anual + gross-up
      indicadores/
        data/
          sgs_mapper_test.dart          # CRÍTICO: parse string/vírgula/dataFim/HTML
          sgs_datasource_test.dart       # mocktail do Dio
        application/
          daily_cache_service_test.dart  # CRÍTICO: chave por dia, stale, refresh
      acoes/
        data/
          brapi_mapper_test.dart         # campos null (free tier), degradação
          brapi_datasource_test.dart     # mocktail Dio + HTTP 429
      patrimonio/
        application/
          patrimonio_service_test.dart   # agregação RF (curva) + ações (cotação)
      configuracoes/
        application/
          import_export_service_test.dart # CRÍTICO: REPLACE/MERGE/checksum/schema
  widget/
    dashboard_screen_test.dart
    cadastro_rf_screen_test.dart
    conversor_screen_test.dart
    root_shell_responsive_test.dart      # 3 breakpoints
  helpers/
    pump_app.dart                        # helper de ProviderScope + MaterialApp
    fakes.dart                           # fakes reutilizáveis (db em memória, etc.)
    fixtures/
      sgs_432_ultimos1.json
      sgs_226_tr_datafim.json
      sgs_12_html_erro.txt               # resposta HTML de erro do SGS
      brapi_petr4_quote.json
      brapi_wege3_financialdata_null.json
      brasilapi_cnpj.json
      opencnpj_cnpj.json
      tesouro_precotaxa_sample.csv       # recorte do CSV do Tesouro
      export_v1.json                     # backup válido p/ import
      export_v2_futuro.json              # backup de versão futura (deve bloquear)
integration_test/
  boot_cache_flow_test.dart
  cadastro_rf_flow_test.dart
  import_export_flow_test.dart           # patrol: file picker nativo
```

Fixtures ficam em `test/helpers/fixtures/` e são carregadas via `File('test/helpers/fixtures/<arquivo>').readAsStringSync()` (ou helper dedicado), **nunca** chamando a rede real em teste.

---

### 2. Unit tests — funções financeiras (o coração)

As funções financeiras são puro-Dart, determinísticas e sem I/O. São o alvo mais importante e devem ter cobertura ≥ 95% (ramos de IR/IOF incluídos). Use **tolerância explícita** com `closeTo` (nunca `equals` em `double`).

#### 2.1 Convenção de tolerância

```dart
// test/helpers/matchers.dart
import 'package:flutter_test/flutter_test.dart';

/// Tolerância padrão para valores monetários (centavo).
Matcher reaisProximo(double esperado) => closeTo(esperado, 0.01);

/// Tolerância para taxas em fração (ex.: 0.1357). 1e-6 ≈ 0,0001%.
Matcher taxaProxima(double esperado) => closeTo(esperado, 1e-6);
```

#### 2.2 Motor de cálculo base 252 / 360 / 365

`test/src/features/renda_fixa/domain/motor_calculo_test.dart`:

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/renda_fixa/domain/motor_calculo.dart';
import '../../../../helpers/matchers.dart';

void main() {
  group('base 252 (juros compostos, padrão de mercado)', () {
    test('VF prefixado 13% a.a. por 252 du = VI*(1+i)^1', () {
      // 252 dias úteis = 1 ano cheio → fator anual exato
      final vf = MotorCalculo.vfBase252(vi: 10000, iAnual: 0.13, diasUteis: 252);
      expect(vf, reaisProximo(11300.00));
    });

    test('VF prefixado 13% a.a. por 126 du = VI*(1.13)^(126/252)', () {
      final esperado = 10000 * pow(1.13, 126 / 252);
      final vf = MotorCalculo.vfBase252(vi: 10000, iAnual: 0.13, diasUteis: 126);
      expect(vf, reaisProximo(esperado.toDouble()));
    });

    test('% do CDI: 110% CDI 14,40% a.a. por 252 du', () {
      // convenção: (1+cdi)^(p*du/252)
      final esperado = 10000 * pow(1.1440, 1.10 * 252 / 252);
      final vf = MotorCalculo.vfPercentualCdi(
        vi: 10000, cdiAnual: 0.1440, percentual: 1.10, diasUteis: 252,
      );
      expect(vf, reaisProximo(esperado.toDouble()));
    });

    test('híbrido IPCA+6%: corrige principal pelo índice e aplica juro real', () {
      // índice acumulado período = 4,72%; taxa real 6% por 252 du
      final esperado = 10000 * (1 + 0.0472) * pow(1.06, 252 / 252);
      final vf = MotorCalculo.vfHibrido(
        vi: 10000, indiceAcumulado: 0.0472, taxaReal: 0.06, diasUteis: 252,
      );
      expect(vf, reaisProximo(esperado.toDouble()));
    });
  });

  group('base 360 / 365 (dias corridos, configurável por produto)', () {
    test('base 365 usa dias corridos', () {
      final esperado = 10000 * pow(1.13, 365 / 365);
      final vf = MotorCalculo.vfBaseAnoCivil(
        vi: 10000, iAnual: 0.13, diasCorridos: 365, base: 365,
      );
      expect(vf, reaisProximo(esperado.toDouble()));
    });

    test('base 360 (comercial) diverge de 365 no mesmo prazo', () {
      final v360 = MotorCalculo.vfBaseAnoCivil(
        vi: 10000, iAnual: 0.13, diasCorridos: 180, base: 360);
      final v365 = MotorCalculo.vfBaseAnoCivil(
        vi: 10000, iAnual: 0.13, diasCorridos: 180, base: 365);
      expect(v360, greaterThan(v365)); // 180/360 > 180/365
    });
  });
}
```

#### 2.3 Tributação — IR regressivo + IOF + isenção (CRÍTICO e datado)

`test/src/features/renda_fixa/domain/tributacao_test.dart`. Cobrir **todas as faixas** da tabela e os **30 dias** do IOF, mais a regra de isenção (LCI/LCA/CRI/CRA/incentivadas/poupança).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/renda_fixa/domain/tributacao.dart';

void main() {
  group('IR regressivo (vigente 2026)', () {
    // tabela: ≤180=22,5% | 181-360=20% | 361-720=17,5% | >720=15%
    final casos = <int, double>{
      1: 0.225, 180: 0.225,
      181: 0.20, 360: 0.20,
      361: 0.175, 720: 0.175,
      721: 0.15, 3650: 0.15,
    };
    casos.forEach((dias, aliquota) {
      test('$dias dias corridos -> ${aliquota * 100}%', () {
        expect(aliquotaIr(dias, isento: false), aliquota);
      });
    });

    test('produto isento sempre 0% independente do prazo', () {
      expect(aliquotaIr(45, isento: true), 0.0);
      expect(aliquotaIr(2000, isento: true), 0.0);
    });
  });

  group('IOF regressivo (Decreto 6.306/2007)', () {
    // fórmula fechada: trunc((30-dias)/30*100)/100 ; >=30 -> 0
    test('tabela dia-a-dia confere nos pontos âncora', () {
      expect(aliquotaIof(1), 0.96);
      expect(aliquotaIof(10), 0.66);
      expect(aliquotaIof(20), 0.33);
      expect(aliquotaIof(29), 0.03);
      expect(aliquotaIof(30), 0.0);
      expect(aliquotaIof(31), 0.0);
    });

    test('IOF incide só sobre o rendimento, antes do IR', () {
      final r = aplicarTributos(rendimentoBruto: 100, diasCorridos: 10, isento: false);
      // IOF = 0,66*100 = 66 ; baseIR = 34 ; IR = 0,225*34 = 7,65
      expect(r.iof, closeTo(66.0, 1e-9));
      expect(r.ir, closeTo(7.65, 1e-9));
    });
  });

  group('isenção encapsulada em TaxRuleSet DATADO', () {
    test('regra de 2026 mantém LCI/LCA/incentivadas isentas (MP 1.303/2025 caducou)', () {
      final regra = TaxRuleSet.vigenteEm(DateTime(2026, 6, 17));
      expect(regra.isentoIrPf(ClasseAtivo.lci), isTrue);
      expect(regra.isentoIrPf(ClasseAtivo.debentureIncentivada), isTrue);
      expect(regra.isentoIrPf(ClasseAtivo.cdb), isFalse);
      expect(regra.vigenteDesde, DateTime(2025, 10, 1)); // documenta a data
    });
  });
}
```

> **Por que datar a regra**: a isenção é o ponto mais sujeito a mudança legislativa. O `TaxRuleSet` é versionado e datado; o teste fixa a regra vigente em 2026 e protege contra alteração acidental. Quando a lei mudar, adiciona-se um novo `TaxRuleSet` com nova data e um teste correspondente — sem quebrar o histórico.

#### 2.4 Comparador / conversor — rentabilidade líquida anual + gross-up

`test/src/features/conversor_taxas/domain/comparador_test.dart`:

```dart
void main() {
  group('rentabilidade líquida anual efetiva (base 252)', () {
    test('LCI isenta não sofre IR; líquido == bruto', () {
      final liq = taxaLiquidaAnualEfetiva(
        vi: 10000, iBrutaAnual: 0.1363, prazoDias: 730, diasUteis: 504, isento: true,
      );
      // sem IR/IOF, a taxa líquida anual ~ a bruta contratada
      expect(liq, closeTo(0.1363, 1e-3));
    });

    test('CDB tributável: líquido < bruto pelo IR de 15% (>720 dias)', () {
      final liq = taxaLiquidaAnualEfetiva(
        vi: 10000, iBrutaAnual: 0.1596, prazoDias: 730, diasUteis: 504, isento: false,
      );
      expect(liq, lessThan(0.1596));
    });

    test('gross-up: taxa bruta equivalente do isento usa IR do prazo', () {
      final bruta = taxaBrutaEquivalenteDeIsento(0.1363, prazoDias: 730);
      // 0,1363 / (1 - 0,15) = 0,16035...
      expect(bruta, closeTo(0.16035, 1e-4));
    });
  });
}
```

#### 2.5 Dias úteis com feriados

`test/src/common/utils/dias_uteis_test.dart` — contagem real (não aproximação `dc*252/365`), usando feriados injetados:

```dart
test('exclui fins de semana e feriados nacionais do intervalo', () {
  final feriados = {DateTime(2026, 4, 21)}; // Tiradentes (terça)
  final du = diasUteisEntre(
    DateTime(2026, 4, 20), DateTime(2026, 4, 24), feriados: feriados,
  );
  // 20(seg),22(qua),23(qui),24(sex) = 4 ; 21 é feriado
  expect(du, 4);
});
```

---

### 3. Parsing das APIs (unit) — defensivo e baseado em fixtures

O parsing é a segunda área mais sensível: o SGS devolve **valor como STRING** (vírgula/ponto), algumas séries têm `dataFim`, e respostas de erro podem vir como **HTML**. brapi no free retorna campos de analista **null**. Cada mapper tem teste com fixture real.

#### 3.1 SGS mapper

`test/src/features/indicadores/data/sgs_mapper_test.dart`:

```dart
void main() {
  group('SgsMapper', () {
    test('série simples (432) faz parse de valor string para double', () {
      final json = jsonDecode(_fixture('sgs_432_ultimos1.json')) as List;
      final p = SgsMapper.parsePonto(json.first as Map<String, dynamic>);
      expect(p.valor, 14.50);
      expect(p.data, DateTime(2026, 6, 17));
      expect(p.dataFim, isNull);
    });

    test('série com período (226 TR) preenche dataFim', () {
      final json = jsonDecode(_fixture('sgs_226_tr_datafim.json')) as List;
      final p = SgsMapper.parsePonto(json.first as Map<String, dynamic>);
      expect(p.dataFim, DateTime(2026, 7, 16));
    });

    test('valor com vírgula decimal é normalizado', () {
      final p = SgsMapper.parsePonto({'data': '16/06/2026', 'valor': '0,053400'});
      expect(p.valor, closeTo(0.053400, 1e-9));
    });

    test('resposta HTML de erro vira Failure, não exceção crua', () {
      final html = _fixture('sgs_12_html_erro.txt'); // "<html>...Requisição Inválida..."
      final r = SgsMapper.tryParseLista(html);
      expect(r, isA<Failure<List<PontoSerie>>>());
    });
  });
}

String _fixture(String nome) =>
    File('test/helpers/fixtures/$nome').readAsStringSync();
```

#### 3.2 brapi mapper — degradação graciosa (free tier)

`test/src/features/acoes/data/brapi_mapper_test.dart`:

```dart
test('financialData com campos de analista null não quebra o parse', () {
  final json = jsonDecode(_fixture('brapi_wege3_financialdata_null.json'));
  final acao = BrapiMapper.parseQuote(json as Map<String, dynamic>);
  expect(acao.precoAtual, isNotNull);
  expect(acao.recommendationKey, isNull);     // free retorna null com HTTP 200
  expect(acao.targetMeanPrice, isNull);
  expect(acao.temRecomendacaoAnalista, isFalse); // UI degrada graciosamente
});
```

#### 3.3 Tesouro CSV parser

`test/src/features/.../tesouro_csv_parser_test.dart` — separador `;`, decimal vírgula, títulos por extenso, filtra Data Base mais recente:

```dart
test('parse CSV ; com decimal vírgula e título por extenso', () {
  final csv = _fixture('tesouro_precotaxa_sample.csv');
  final titulos = TesouroCsvParser.parse(csv);
  final selic = titulos.firstWhere((t) => t.tipo == 'Tesouro Selic');
  expect(selic.taxaCompraManha, closeTo(0.1234, 1e-4));
  // filtro por Data Base mais recente
  final ultimaBase = titulos.map((t) => t.dataBase).reduce((a, b) => a.isAfter(b) ? a : b);
  expect(TesouroCsvParser.maisRecentes(csv).every((t) => t.dataBase == ultimaBase), isTrue);
});
```

---

### 4. Mocks com mocktail das APIs (Dio)

**Não usar code-gen para mocks** (decisão global: mocktail sem `build_runner` para mocks). Mock-se o `Dio` (ou um `DioClient` abstrato por API). A camada `datasource` recebe `Dio` via injeção (Riverpod provider) — em teste, sobrescreve-se com o mock.

#### 4.1 Setup mocktail e `registerFallbackValue`

`mocktail` exige `registerFallbackValue` para tipos não-primitivos usados em `any()` (ex.: `RequestOptions`, `Options`).

```dart
// test/helpers/mocks.dart
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}
class FakeOptions extends Fake implements Options {}

void registerHttpFallbacks() {
  registerFallbackValue(FakeRequestOptions());
  registerFallbackValue(FakeOptions());
}
```

#### 4.2 Stub de sucesso, erro de rede e HTTP 429

`test/src/features/indicadores/data/sgs_datasource_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:investa_br/src/features/indicadores/data/sgs_datasource.dart';
import '../../../../helpers/mocks.dart';

void main() {
  setUpAll(registerHttpFallbacks);

  late MockDio dio;
  late SgsDatasource sut;

  setUp(() {
    dio = MockDio();
    sut = SgsDatasource(dio);
  });

  Response<T> _resp<T>(T data, int status) => Response<T>(
        data: data,
        statusCode: status,
        requestOptions: RequestOptions(path: ''),
      );

  test('GET /ultimos/1 da série 432 retorna Success com o ponto', () async {
    when(() => dio.get<dynamic>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => _resp<dynamic>(
            [{'data': '17/06/2026', 'valor': '14.50'}], 200));

    final r = await sut.ultimoValor(432);

    expect(r, isA<Success<PontoSerie>>());
    expect((r as Success).value.valor, 14.50);
    verify(() => dio.get<dynamic>(
          'bcdata.sgs.432/dados/ultimos/1',
          options: any(named: 'options'),
        )).called(1);
  });

  test('DioException de conexão vira Failure tipado (não propaga exceção)', () async {
    when(() => dio.get<dynamic>(any(), options: any(named: 'options')))
        .thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ));

    final r = await sut.ultimoValor(432);
    expect(r, isA<Failure<PontoSerie>>());
    expect((r as Failure).erro, isA<FalhaRede>());
  });
}
```

`test/src/features/acoes/data/brapi_datasource_test.dart` — backoff em HTTP 429:

```dart
test('HTTP 429 mapeia para FalhaRateLimit e aciona política de backoff', () async {
  when(() => dio.get<dynamic>(any(), options: any(named: 'options')))
      .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          statusCode: 429,
          requestOptions: RequestOptions(path: ''),
        ),
        type: DioExceptionType.badResponse,
      ));

  final r = await sut.cotacao('PETR4');
  expect(r, isA<Failure<Acao>>());
  expect((r as Failure).erro, isA<FalhaRateLimit>());
});
```

#### 4.3 Tabela de cenários de mock obrigatórios por API

| Datasource | Cenários a stubar | Falha esperada |
|---|---|---|
| **SGS** (BCB) | sucesso 200 JSON; valor string vírgula; série com `dataFim`; resposta HTML; timeout | `FalhaRede`, `FalhaParse` |
| **brapi** | 200 com dados; 200 campos analista `null`; 401 sem token (ticker fora dos 4 livres); 429 | `FalhaAuth`, `FalhaRateLimit` |
| **BrasilAPI CNPJ** | 200; 404 CNPJ inexistente; 429/5xx (mais throttled) | `FalhaNaoEncontrado`, `FalhaRede` |
| **OpenCNPJ (fallback)** | 200 (schema QSA + endereço plano); usado quando BrasilAPI falha | encadeamento testado em `application` |
| **Feriados (BrasilAPI)** | 200 lista nacional do ano | `FalhaRede` |
| **AwesomeAPI / Tesouro CSV** | 200 corpo CSV/JSON; corpo malformado | `FalhaParse` |

#### 4.4 Fallback encadeado de CNPJ (teste de application)

O serviço de CNPJ tenta BrasilAPI → OpenCNPJ. Mock-se **dois** datasources e verifica-se a transição:

```dart
test('cai para OpenCNPJ quando BrasilAPI falha', () async {
  when(() => brasilApi.consultar(any()))
      .thenAnswer((_) async => Failure(FalhaRede()));
  when(() => openCnpj.consultar(any()))
      .thenAnswer((_) async => Success(_emissorFake));

  final r = await sut.buscarEmissor('19131243000197');

  expect(r, isA<Success<Emissor>>());
  verify(() => brasilApi.consultar('19131243000197')).called(1);
  verify(() => openCnpj.consultar('19131243000197')).called(1);
});

test('normaliza CNPJ (só dígitos) antes da chamada', () async {
  when(() => brasilApi.consultar(any()))
      .thenAnswer((_) async => Success(_emissorFake));
  await sut.buscarEmissor('19.131.243/0001-97');
  verify(() => brasilApi.consultar('19131243000197')).called(1);
});
```

---

### 5. Cache diário e import/export (unit)

#### 5.1 `DailyCacheService`

Testa a chave por dia (`yyyy-MM-dd`, fuso America/São_Paulo UTC-3), `stale-while-revalidate`, fallback offline e refresh forçado. Injeta-se um **relógio** (`Clock`/`DateTime Function()`) e um **sembast em memória** (`databaseFactoryMemory`) para determinismo.

```dart
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database db;
  late MockSgsDatasource sgs;
  late DailyCacheService sut;
  var agora = DateTime.utc(2026, 6, 17, 12); // 09:00 em SP

  setUp(() async {
    db = await databaseFactoryMemory.openDatabase('t.db');
    sgs = MockSgsDatasource();
    sut = DailyCacheService(db: db, sgs: sgs, clock: () => agora);
  });

  test('primeira chamada do dia faz fetch e persiste com data de hoje', () async {
    when(() => sgs.lote(any())).thenAnswer((_) async => Success(_snapshotFake));
    final r = await sut.obterIndicadores();
    expect(r.stale, isFalse);
    verify(() => sgs.lote(any())).called(1);
  });

  test('segunda chamada no mesmo dia serve do cache (não chama API)', () async {
    when(() => sgs.lote(any())).thenAnswer((_) async => Success(_snapshotFake));
    await sut.obterIndicadores();
    clearInteractions(sgs);
    final r = await sut.obterIndicadores();
    expect(r.stale, isFalse);
    verifyNever(() => sgs.lote(any())); // serviu do cache
  });

  test('vira o dia -> refetch', () async {
    when(() => sgs.lote(any())).thenAnswer((_) async => Success(_snapshotFake));
    await sut.obterIndicadores();
    agora = agora.add(const Duration(days: 1)); // 18/06
    await sut.obterIndicadores();
    verify(() => sgs.lote(any())).called(2);
  });

  test('falha de rede com cache antigo: serve stale=true (offline)', () async {
    when(() => sgs.lote(any())).thenAnswer((_) async => Success(_snapshotFake));
    await sut.obterIndicadores();             // popula cache
    agora = agora.add(const Duration(days: 1));
    when(() => sgs.lote(any())).thenAnswer((_) async => Failure(FalhaRede()));
    final r = await sut.obterIndicadores();
    expect(r.stale, isTrue);                   // marca stale para a UI
  });

  test('refresh manual ignora o cache do dia', () async {
    when(() => sgs.lote(any())).thenAnswer((_) async => Success(_snapshotFake));
    await sut.obterIndicadores();
    clearInteractions(sgs);
    await sut.obterIndicadores(forcarRefresh: true);
    verify(() => sgs.lote(any())).called(1);
  });
}
```

#### 5.2 Import/Export — REPLACE / MERGE / checksum / schemaVersion

`test/src/features/configuracoes/application/import_export_service_test.dart` (sembast em memória + payloads de fixture):

```dart
group('import', () {
  test('REPLACE substitui todo o conteúdo do usuário (estado final == arquivo)', () async {
    await rfRepo.upsert(_docExistente); // dado antigo que não está no backup
    final payload = jsonDecode(_fixture('export_v1.json')) as Map<String, Object?>;
    await sut.importar(payload, modo: ModoImport.replace);
    final todos = await rfRepo.todos();
    expect(todos.map((e) => e['id']), isNot(contains(_docExistente['id'])));
  });

  test('MERGE por id aplica last-write-wins via updatedAt', () async {
    await rfRepo.upsert({..._doc, 'updatedAt': '2026-06-10T00:00:00-03:00'});
    final novo = {..._doc, 'updatedAt': '2026-06-17T00:00:00-03:00', 'apelido': 'novo'};
    await sut.importar(_envelope([novo]), modo: ModoImport.merge);
    final atual = await rfRepo.porId(_doc['id'] as String);
    expect(atual!['apelido'], 'novo'); // mais recente venceu
  });

  test('checksum SHA-256 inválido bloqueia import', () async {
    final payload = jsonDecode(_fixture('export_v1.json')) as Map<String, Object?>;
    payload['checksum'] = 'sha256:deadbeef';
    expect(() => sut.importar(payload), throwsA(isA<BackupCorrompido>()));
  });

  test('schemaVersion maior que o app é rejeitado', () async {
    final payload = jsonDecode(_fixture('export_v2_futuro.json')) as Map<String, Object?>;
    expect(() => sut.importar(payload), throwsA(isA<BackupVersaoNova>()));
  });

  test('app != investa_br é rejeitado', () async {
    expect(() => sut.importar({'app': 'outro', 'schemaVersion': 1}),
        throwsA(isA<BackupInvalido>()));
  });

  test('import é atômico: falha no meio não deixa estado parcial', () async {
    // payload com 1 doc válido + 1 inválido força rollback da transação
    expect(() => sut.importar(_envelopeComDocInvalido()), throwsA(isA<Object>()));
    expect((await rfRepo.todos()), isEmpty); // nada foi gravado
  });
});

group('export', () {
  test('cache_indicadores NÃO entra no export (derivado)', () async {
    await cacheRepo.salvar(_snapshotFake);
    final out = await sut.gerarPayload();
    expect((out['data'] as Map).containsKey('cache_indicadores'), isFalse);
  });

  test('checksum do bloco data confere no round-trip export->import', () async {
    await rfRepo.upsert(_doc);
    final out = await sut.gerarPayload();
    await sut.importar(out, modo: ModoImport.replace); // não deve lançar
  });
});
```

---

### 6. Widget tests — Riverpod via `ProviderContainer` / `overrideWith`

DI é o próprio Riverpod (decisão global: sem get_it). Em teste, sobrescreve-se os providers de datasource/serviço por fakes/mocks via `overrides` no `ProviderScope`. Para AsyncNotifiers, sobrescreve-se com versões que emitem `AsyncData`/`AsyncLoading`/`AsyncError`.

#### 6.1 Helper `pumpApp`

`test/helpers/pump_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/localization/app_localizations.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    Size surface = const Size(400, 800), // compact por padrão
    Locale locale = const Locale('pt', 'BR'), // troque p/ Locale('en')/Locale('es') ao testar i18n
  }) async {
    await binding.setSurfaceSize(surface);
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
    await pumpAndSettle();
  }
}
```

#### 6.2 Dashboard com os 3 estados de `AsyncValue`

`test/widget/dashboard_screen_test.dart`:

```dart
void main() {
  testWidgets('estado loading mostra skeleton/spinner', (tester) async {
    await tester.pumpApp(
      const DashboardScreen(),
      overrides: [
        indicadoresProvider.overrideWith(() => _LoadingNotifier()),
      ],
    );
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('estado data renderiza cards formatados em pt-BR', (tester) async {
    await tester.pumpApp(
      const DashboardScreen(),
      overrides: [
        indicadoresProvider.overrideWith(
          () => _DataNotifier(_snapshotFake), // SELIC 14,50%, CDI 14,40%...
        ),
      ],
    );
    expect(find.text('14,50% a.a.'), findsOneWidget); // NumberFormat pt-BR
    expect(find.text('SELIC'), findsOneWidget);
  });

  testWidgets('estado error mostra mensagem e botão de tentar novamente', (tester) async {
    await tester.pumpApp(
      const DashboardScreen(),
      overrides: [
        indicadoresProvider.overrideWith(() => _ErrorNotifier()),
      ],
    );
    expect(find.textContaining('Não foi possível'), findsOneWidget);
    expect(find.byKey(const Key('btn_tentar_novamente')), findsOneWidget);
  });

  testWidgets('cache stale exibe aviso de dados desatualizados', (tester) async {
    await tester.pumpApp(
      const DashboardScreen(),
      overrides: [
        indicadoresProvider.overrideWith(() => _DataNotifier(_snapshotStale)),
      ],
    );
    expect(find.textContaining('offline'), findsOneWidget);
  });
}
```

#### 6.3 Navegação responsiva — 3 breakpoints

`test/widget/root_shell_responsive_test.dart` usa `binding.setSurfaceSize`:

```dart
void main() {
  testWidgets('compact <600dp -> NavigationBar', (tester) async {
    await tester.pumpApp(const RootShell(), surface: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('medium 600-840dp -> NavigationRail compacto', (tester) async {
    await tester.pumpApp(const RootShell(), surface: const Size(700, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('expanded >=840dp -> NavigationRail extended', (tester) async {
    await tester.pumpApp(const RootShell(), surface: const Size(1100, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('IndexedStack preserva estado das abas', (tester) async {
    await tester.pumpApp(const RootShell(), surface: const Size(400, 800));
    expect(find.byType(IndexedStack), findsOneWidget);
  });
}
```

#### 6.4 Acessibilidade no widget test

Validar semântica e contraste com os matchers nativos do `flutter_test`:

```dart
testWidgets('cards e gráfico têm semântica e atendem guidelines de acessibilidade',
    (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpApp(
    const DashboardScreen(),
    overrides: [indicadoresProvider.overrideWith(() => _DataNotifier(_snapshotFake))],
  );

  // legenda textual do donut (não depender só de cor)
  expect(find.bySemanticsLabel(RegExp(r'Renda Fixa.*%')), findsOneWidget);

  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));   // >=48dp
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
});
```

#### 6.5 Formulário de cadastro RF

Validações de campo, máscara R$, preview de projeção e submissão (repository mockado via override). Confirma que o estado é preservado e que datas usam `DateFormat('dd/MM/yyyy','pt_BR')`.

---

### 7. Integration / E2E com `integration_test` + `patrol`

`patrol` cobre o que o `integration_test` puro não alcança: **interações nativas** (file picker do import/export, permissões, janela desktop). Cenários mínimos:

| Arquivo | Fluxo | Observações |
|---|---|---|
| `boot_cache_flow_test.dart` | abrir app → batch SGS + feriados → dashboard com cards preenchidos | usa servidor HTTP fake local ou overrides de datasource; **não bate na API real** |
| `cadastro_rf_flow_test.dart` | navegar p/ Carteira → FAB → preencher CDB 110% CDI → salvar → patrimônio atualiza | valida persistência sembast ponta a ponta |
| `import_export_flow_test.dart` | exportar JSON (share_plus) → importar de volta (file_picker nativo) → dados conferem | **patrol** para a seleção nativa de arquivo |

Exemplo `patrol` para o file picker nativo:

```dart
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('importar backup via file picker nativo', ($) async {
    await $.pumpWidgetAndSettle(const InvestaBrApp());
    await $.tap($(#abaAjustes));
    await $.tap($(#btnImportar));

    // interação NATIVA fora do canvas Flutter
    await $.native.tap(Selector(text: 'investa_br_backup.json'));

    await $.waitUntilVisible($(#snackImportOk));
    expect($('CDB Banco X 2027'), findsOneWidget);
  });
}
```

> **Regra E2E**: nunca depender de rede externa real (BCB/brapi/BrasilAPI) em CI — fluxos usam overrides de datasource ou um stub HTTP local. APIs reais são frágeis (rate limit, 5xx, HTML de erro) e tornariam o CI não-determinístico.

Execução: `fvm flutter test integration_test/` (integration_test puro) e `patrol test` (cenários patrol, requer device/emulador ou desktop ativo).

---

### 8. Lints e análise estática

Adotar **`very_good_analysis`** (mais rigoroso que `flutter_lints`). Configuração em `analysis_options.yaml` na raiz.

#### 8.1 `analysis_options.yaml`

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    # arquivos gerados não devem poluir a análise
    missing_required_param: error
    missing_return: error
    invalid_annotation_target: ignore   # freezed/json_serializable
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/src/localization/generated/**"   # gen-l10n
    - "build/**"

linter:
  rules:
    # imutabilidade e proibição de prints (decisão global)
    avoid_print: true
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_declarations: true
    prefer_final_locals: true
    prefer_final_fields: true
    # disciplina de qualidade
    avoid_dynamic_calls: true
    only_throw_errors: true
    require_trailing_commas: true
    public_member_api_docs: false   # app, não package: docs públicas opcionais
```

#### 8.2 Regras de domínio reforçadas

- **`avoid_print: true`** — em vez de `print`, usar o interceptor de logging do Dio (só em debug) ou `debugPrint`. CI falha em qualquer `print`.
- **Imutabilidade** — entidades de domínio são `freezed` (`@freezed`, campos `final`); o lint `prefer_const_constructors` e os `final` forçados ajudam. `Result<T>`, `TipoRendimento`, `ClasseAtivo` são `sealed` — o analyzer garante **pattern matching exaustivo** nos `switch` (sem `default`, novo caso quebra compilação — proteção de domínio gratuita).
- **`avoid_dynamic_calls`** — crítico no parsing de JSON: força tipar o acesso (`map['valor'] as String`) em vez de chamadas dinâmicas que mascaram erros de schema.

#### 8.3 Code-gen e arquivos gerados

`build_runner` único gera `*.g.dart` (json/riverpod) e `*.freezed.dart` (freezed) e as rotas tipadas (go_router_builder). Esses arquivos são **commitados** (decisão global) e **excluídos da análise** (acima). Comando:

```bash
fvm dart run build_runner build --delete-conflicting-outputs   # one-shot (CI)
fvm dart run build_runner watch  -d                            # dev
```

Em CI, validar que os arquivos gerados estão **em dia** (sem drift): rodar o build e checar que `git diff` está limpo (ver §10).

---

### 9. Cobertura — alvo e medição

| Escopo | Alvo | Por quê |
|---|---|---|
| **Funções financeiras** (`features/*/domain` de cálculo, tributação, comparador, dias úteis) | **≥ 95% de linhas e ramos** | erro aqui é financeiro e silencioso; exige rigor máximo |
| **Parsing / mappers** (`features/*/data`) | **≥ 90%** | APIs retornam formatos ardilosos (string, HTML, null) |
| **Application / services** (cache, import/export, fallback CNPJ) | **≥ 85%** | lógica de orquestração crítica |
| **Presentation / widgets** | **≥ 70%** | foco em estados AsyncValue e acessibilidade |
| **Projeto global** | **≥ 80%** | gate de CI |

Arquivos **excluídos** da contagem: `*.g.dart`, `*.freezed.dart`, `lib/src/localization/generated/**`, `main.dart` e adaptadores triviais de plataforma (ex.: serviço `window_manager`, que é testado manualmente em desktop).

#### 9.1 Gerar e filtrar cobertura

```bash
fvm flutter test --coverage          # gera coverage/lcov.info
```

Filtrar gerados antes de medir (requer `lcov`/`genhtml` ou um filtro Dart):

```bash
# remove arquivos gerados do relatório
lcov --remove coverage/lcov.info \
  '**/*.g.dart' '**/*.freezed.dart' '**/localization/generated/**' \
  -o coverage/lcov.cleaned.info
genhtml coverage/lcov.cleaned.info -o coverage/html
```

Alternativa puro-Dart (sem lcov nativo, melhor no Windows do dev): pacote dev `test_cov_console` ou `very_good test --coverage --min-coverage 80` (CLI `very_good_cli`), que já aplica o gate e roda em todas as plataformas.

---

### 10. CI local (gate de qualidade)

O projeto não tem servidor de CI assumido; o gate roda **localmente** antes de cada PR/commit relevante, reproduzível via FVM. Materializar como script único e (opcionalmente) como hook de pré-commit.

#### 10.1 Script `tool/ci.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> 1/6 dependências"
fvm flutter pub get

echo "==> 2/6 code-gen (freezed/json/riverpod/go_router)"
fvm dart run build_runner build --delete-conflicting-outputs

echo "==> 3/6 checar drift de arquivos gerados"
if ! git diff --quiet -- '*.g.dart' '*.freezed.dart'; then
  echo "ERRO: arquivos gerados desatualizados. Rode build_runner e commite." >&2
  git --no-pager diff --stat -- '*.g.dart' '*.freezed.dart' >&2
  exit 1
fi

echo "==> 4/6 formatação"
fvm dart format --set-exit-if-changed lib test

echo "==> 5/6 análise estática (very_good_analysis)"
fvm flutter analyze --fatal-infos --fatal-warnings

echo "==> 6/6 testes + cobertura mínima"
fvm flutter test --coverage
lcov --remove coverage/lcov.info \
  '**/*.g.dart' '**/*.freezed.dart' '**/localization/generated/**' \
  -o coverage/lcov.cleaned.info
# gate de 80% global (substitua por very_good test --min-coverage 80 se preferir)
COV=$(lcov --summary coverage/lcov.cleaned.info 2>&1 | grep -oP 'lines\.+: \K[0-9.]+')
echo "Cobertura: ${COV}%"
awk "BEGIN { exit !(${COV} >= 80.0) }" || { echo "Cobertura < 80%" >&2; exit 1; }

echo "OK: pipeline local verde."
```

> No ambiente do dev (Windows / Git Bash), `tool/ci.sh` roda via Bash; alternativamente `very_good test --min-coverage 80` evita a dependência de `lcov`/`awk` e é multiplataforma.

#### 10.2 Etapas do gate (resumo)

| Ordem | Etapa | Comando | Falha se… |
|---|---|---|---|
| 1 | Deps | `fvm flutter pub get` | resolução de versões quebra |
| 2 | Code-gen | `build_runner build --delete-conflicting-outputs` | geração falha |
| 3 | Drift de gerados | `git diff --quiet -- '*.g.dart' '*.freezed.dart'` | gerados desatualizados |
| 4 | Formatação | `dart format --set-exit-if-changed` | há código não formatado |
| 5 | Análise | `flutter analyze --fatal-infos --fatal-warnings` | qualquer info/warning |
| 6 | Testes + cobertura | `flutter test --coverage` + gate 80% | teste falha ou cobertura baixa |

#### 10.3 Hook de pré-commit (opcional, recomendado)

Para tornar automático, configurar um hook que roda o subconjunto rápido (format + analyze + testes unit) — patrol/E2E ficam fora do pré-commit por exigirem device. O hook completo (`tool/ci.sh`) roda antes do PR.

---

### 11. Checklist de "definição de pronto" (DoD) por tipo de mudança

| Mudança | Testes obrigatórios antes do merge |
|---|---|
| Motor de cálculo (252/360/365, % CDI, IPCA+) | unit em `motor_calculo_test.dart` cobrindo o ramo novo, com `closeTo` |
| Tabela IR/IOF ou regra de isenção | unit em `tributacao_test.dart` + novo `TaxRuleSet` datado se a lei mudou |
| Novo campo/endpoint de API | fixture + teste de mapper + cenário mocktail (sucesso + falha) |
| Lógica de cache | cenário em `daily_cache_service_test.dart` (cache hit/miss/stale/refresh) |
| Import/export | round-trip + REPLACE/MERGE + checksum + schemaVersion |
| Nova tela / widget | widget test dos 3 estados AsyncValue + `meetsGuideline` de acessibilidade |
| Fluxo crítico de usuário | cenário `integration_test`/`patrol` (sem rede real) |

Nenhum PR passa no gate (§10) com `print`, com arquivos gerados desatualizados, com cobertura global < 80% ou com cobertura das funções financeiras < 95%.

---

## Build & Release por Plataforma

Esta secao define, de forma acionavel, como gerar artefatos de build do **Investa BR** (`investa_br`) em **android, ios, windows, macos, linux** (web fora de escopo), incluindo assinatura, icones, splash, identificadores de aplicacao e distribuicao. Tudo assume **Flutter 3.44 (stable) + Dart 3.12**, fixados via **FVM** (`.fvmrc`).

> Convencao desta secao: todos os comandos `flutter ...` devem ser executados via FVM em dev/CI para garantir reprodutibilidade da versao do SDK: `fvm flutter ...`. Onde escrevo `flutter`, leia `fvm flutter` (ou configure o PATH do FVM). O comando que materializa as plataformas e: `fvm flutter create --platforms=android,ios,windows,macos,linux .`

---

### 1. Identificadores de aplicacao (canonicos)

Estes valores sao a fonte de verdade e devem ser identicos em todas as plataformas, exceto quando a plataforma tem regra propria (App Store usa reverse-DNS; Linux usa `.desktop`). Definir ANTES de gerar icones/splash/assinaturas, pois mudar depois exige regenerar artefatos nativos.

| Item | Valor canonico | Onde aparece |
|---|---|---|
| Nome de exibicao | `Investa BR` | label/title de cada plataforma |
| Application/Bundle ID | `br.com.fiduciascm.investabr` | Android applicationId, iOS/macOS PRODUCT_BUNDLE_IDENTIFIER, Linux application-id |
| Pacote Dart (pubspec `name`) | `investa_br` | imports `package:investa_br/...` |
| Versao | `version: 1.0.0+1` no pubspec | `versionName/versionCode`, `CFBundleShortVersionString/CFBundleVersion`, FileVersion (Windows) |
| Scheme de deep link (futuro) | `investabr://` | iOS `CFBundleURLSchemes`, Android intent-filter |

> O `applicationId`/`bundleId` deve ser estavel e unico globalmente (reverse-DNS de um dominio que voce controla). Usei `br.com.fiduciascm.investabr` por coerencia com o dominio corporativo. Se for publicar sob outra conta, troque o prefixo de dominio, NUNCA o sufixo `investabr`.

Mapeamento da string `version: X.Y.Z+N` do `pubspec.yaml`:

```
version: 1.0.0+1
         ^^^^^ ^
         |     +-- build number (N)  -> versionCode (Android), CFBundleVersion (iOS/macOS)
         +-------- semver (X.Y.Z)     -> versionName (Android), CFBundleShortVersionString (iOS/macOS)
```

Sobrescrita por linha de comando (util em CI para injetar o numero do pipeline):

```bash
flutter build appbundle --build-name=1.0.0 --build-number=$CI_BUILD_ID
```

---

### 2. Comandos de build por plataforma

Pre-requisito comum (sempre antes de qualquer build de release, especialmente em CI):

```bash
flutter --version                 # confirmar 3.44.x / Dart 3.12.x (via FVM)
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed/json/riverpod/go_router_builder
flutter analyze                   # very_good_analysis deve passar limpo
flutter test                      # unit/widget
```

> Embora `*.g.dart` e `*.freezed.dart` sejam commitados, rode `build_runner build` em CI antes do build de release para garantir que os gerados estao em sincronia com o codigo-fonte (falha se houver drift).

#### 2.1 Android

```bash
# Debug (emulador/dispositivo)
flutter run -d <android_device>

# Release: App Bundle (.aab) — formato OBRIGATORIO para Google Play
flutter build appbundle --release
#   saida: build/app/outputs/bundle/release/app-release.aab

# Release: APK universal (sideload / distribuicao fora da Play Store)
flutter build apk --release
#   saida: build/app/outputs/flutter-apk/app-release.apk

# Release: APKs por ABI (menor tamanho por dispositivo)
flutter build apk --release --split-per-abi
#   saidas: app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk
```

Notas Android:
- `minSdkVersion`: definir `21` (cobre ~99% dos aparelhos e e exigido por varios plugins). `targetSdkVersion`/`compileSdkVersion`: usar `flutter.targetSdkVersion`/`flutter.compileSdkVersion` (o template do Flutter 3.44 ja aponta para SDK recente exigido pela Play Store).
- Para Material You (dynamic_color) funcionar com a paleta do wallpaper, e necessario rodar em Android 12+ (API 31+); abaixo disso o app cai no seed manual — nao requer config de build especial, apenas o fallback ja decidido no `ThemeController`.

#### 2.2 iOS (exige macOS + Xcode)

```bash
# Debug em simulador/dispositivo
flutter run -d <ios_device>

# Build de release sem assinatura (para CI que assina depois via Xcode/fastlane)
flutter build ios --release --no-codesign

# Build + arquivamento para distribuicao (gera .xcarchive e permite exportar .ipa)
flutter build ipa --release
#   saida: build/ios/ipa/investa_br.ipa  (depende de ExportOptions.plist / assinatura)
```

Notas iOS:
- O `.ipa` so e gerado com assinatura valida (certificado + provisioning profile). Em maquina de dev com conta Apple Developer configurada no Xcode, `flutter build ipa --release` resolve automaticamente; em CI use `--export-options-plist=ios/ExportOptions.plist`.
- Deployment target minimo: definir `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (ou superior) no `ios/Podfile` e no projeto Runner. Conferir compatibilidade dos plugins (`file_picker`, `share_plus`).

#### 2.3 Windows (exige Windows + Visual Studio com "Desktop development with C++")

```bash
flutter config --enable-windows-desktop   # uma vez por maquina
flutter build windows --release
#   saida: build/windows/x64/runner/Release/   (investa_br.exe + DLLs + data/)
```

Notas Windows:
- O artefato e a **pasta** `Release/` inteira (exe + `flutter_windows.dll` + `data/flutter_assets/`). Distribua a pasta completa, nao apenas o `.exe`.
- `window_manager` configura titulo/tamanho minimo/centralizacao em runtime (isolado atras de servico). Tamanho minimo e icone da janela tambem sao definidos via `windows/runner/main.cpp`/`Runner.rc`.

#### 2.4 macOS (exige macOS + Xcode)

```bash
flutter config --enable-macos-desktop      # uma vez por maquina
flutter build macos --release
#   saida: build/macos/Build/Products/Release/Investa BR.app
```

Notas macOS:
- Para que `path_provider` (sembast + export) e `file_picker` (importar/exportar JSON) funcionem, e necessario configurar os **entitlements** (sandbox + acesso a arquivos selecionados pelo usuario) — ver secao 4.4.
- O artefato e um bundle `.app`. Para distribuicao fora da Mac App Store, e necessario assinatura Developer ID + notarizacao (ver secao 6).

#### 2.5 Linux (exige Linux + toolchain: clang, cmake, ninja, pkg-config, libgtk-3-dev)

```bash
flutter config --enable-linux-desktop      # uma vez por maquina
flutter build linux --release
#   saida: build/linux/x64/release/bundle/   (investa_br + lib/ + data/)
```

Notas Linux:
- O artefato e a **pasta** `bundle/` (executavel `investa_br` + `lib/*.so` + `data/`). Empacotar como `.tar.gz`, **AppImage**, **Snap** ou **Flatpak** para distribuicao (ver secao 6.5).
- Dependencias de runtime na maquina-alvo: `libgtk-3-0` e libs basicas. `file_picker` no Linux usa GTK; testar o dialogo de importar/exportar em pelo menos uma distro Ubuntu LTS.

#### 2.6 Resumo (saidas e ambiente)

| Plataforma | Comando release | Artefato | Ambiente de build |
|---|---|---|---|
| Android (Play) | `flutter build appbundle --release` | `app-release.aab` | qualquer (Win/macOS/Linux) |
| Android (sideload) | `flutter build apk --release [--split-per-abi]` | `.apk` | qualquer |
| iOS | `flutter build ipa --release` | `.ipa` / `.xcarchive` | macOS + Xcode |
| Windows | `flutter build windows --release` | pasta `Release/` | Windows + VS C++ |
| macOS | `flutter build macos --release` | `Investa BR.app` | macOS + Xcode |
| Linux | `flutter build linux --release` | pasta `bundle/` | Linux + GTK toolchain |

---

### 3. Icones e Splash (flutter_launcher_icons + flutter_native_splash)

Adicionar como **dev_dependencies** (sao ferramentas de geracao, nao dependencias de runtime):

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0
  flutter_native_splash: ^2.4.0
```

Arvore de assets de marca (criar antes de gerar):

```
assets/
  branding/
    icon.png            # 1024x1024, PNG, sem transparencia nas bordas (base do icone)
    icon_foreground.png # 1024x1024, arte centralizada com padding (camada adaptive Android)
    splash.png          # logo centralizado (~1152x1152 area segura), fundo transparente
    splash_dark.png     # variante para tema escuro (opcional)
```

#### 3.1 flutter_launcher_icons

Criar `flutter_launcher_icons.yaml` na raiz (ou bloco `flutter_launcher_icons:` no pubspec). Cobrir TODAS as plataformas geradas:

```yaml
# flutter_launcher_icons.yaml
flutter_launcher_icons:
  image_path: "assets/branding/icon.png"

  android: true
  # Adaptive icon (Android 8+): camada de fundo solida + foreground com padding
  adaptive_icon_background: "#0D47A1"
  adaptive_icon_foreground: "assets/branding/icon_foreground.png"
  min_sdk_android: 21

  ios: true
  remove_alpha_ios: true        # App Store rejeita icone iOS com canal alpha

  windows:
    generate: true
    image_path: "assets/branding/icon.png"
    icon_size: 256              # 48..256

  macos:
    generate: true
    image_path: "assets/branding/icon.png"

  # Linux: flutter_launcher_icons NAO gera icone de janela Linux automaticamente.
  # Definir manualmente (ver 3.3).
```

Geracao:

```bash
dart run flutter_launcher_icons
```

Isso reescreve os assets nativos: `android/app/src/main/res/mipmap-*/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `windows/runner/resources/app_icon.ico`, `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.

#### 3.2 flutter_native_splash

Criar `flutter_native_splash.yaml`:

```yaml
# flutter_native_splash.yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: "assets/branding/splash.png"

  color_dark: "#121212"
  image_dark: "assets/branding/splash_dark.png"

  # Android 12+ tem API de splash dedicada (icone central + fundo)
  android_12:
    image: "assets/branding/splash.png"
    color: "#FFFFFF"
    image_dark: "assets/branding/splash_dark.png"
    color_dark: "#121212"

  android: true
  ios: true
  web: false            # web fora de escopo

  # Desktop: flutter_native_splash NAO gera splash para windows/macos/linux.
  # No desktop, o "splash" e a propria janela; gerenciar via window_manager
  # (esconder a janela ate o primeiro frame estar pronto).
```

Geracao / remocao:

```bash
dart run flutter_native_splash:create      # gera
dart run flutter_native_splash:remove      # reverte (se precisar refazer)
```

> Importante (desktop): nem `flutter_launcher_icons` (Linux) nem `flutter_native_splash` (Windows/macOS/Linux) cobrem 100% desktop. Para o splash de desktop, use `window_manager` para abrir a janela ja oculta e exibi-la apenas apos `runApp` + primeira renderizacao:

```dart
// main.dart (trecho desktop, isolado atras do servico de janela)
Future<void> _bootstrapDesktopWindow() async {
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    title: 'Investa BR',
    minimumSize: Size(420, 640),
    center: true,
    skipTaskbar: false,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();   // mostra so quando pronto -> evita flash de janela vazia
    await windowManager.focus();
  });
}
```

#### 3.3 Icone de janela no Linux (manual)

O `flutter_launcher_icons` nao cobre Linux. Definir o icone via arquivo `.desktop` no empacotamento (ver 6.5) e, para a janela em runtime, registrar o icone no GTK editando `linux/runner/my_application.cc`:

```cpp
// linux/runner/my_application.cc — ao criar a GtkWindow
gtk_window_set_title(window, "Investa BR");
gtk_window_set_default_icon_name("investabr"); // casa com Icon= do .desktop
gtk_window_set_default_size(window, 1024, 720);
```

#### 3.4 Ordem de regeneracao (sempre que a marca mudar)

```bash
dart run flutter_launcher_icons \
  && dart run flutter_native_splash:create \
  && flutter clean && flutter pub get
```

---

### 4. Configuracao de Bundle ID / App ID por plataforma

Definir o ID canonico (`br.com.fiduciascm.investabr`) e o nome (`Investa BR`) em CADA plataforma. Localizacoes exatas:

#### 4.1 Android

`android/app/build.gradle` (ou `build.gradle.kts`):

```gradle
android {
    namespace = "br.com.fiduciascm.investabr"
    defaultConfig {
        applicationId = "br.com.fiduciascm.investabr"
        minSdkVersion = 21
        targetSdkVersion = flutter.targetSdkVersion
        versionCode = flutter.versionCode      // vem de pubspec version +N
        versionName = flutter.versionName      // vem de pubspec X.Y.Z
    }
}
```

Nome de exibicao em `android/app/src/main/AndroidManifest.xml`:

```xml
<application android:label="Investa BR" ...>
```

#### 4.2 iOS

Em `ios/Runner.xcodeproj` (Build Settings) ou via Xcode:
- `PRODUCT_BUNDLE_IDENTIFIER = br.com.fiduciascm.investabr`

Em `ios/Runner/Info.plist`:

```xml
<key>CFBundleDisplayName</key>
<string>Investa BR</string>
<key>CFBundleName</key>
<string>investa_br</string>
```

#### 4.3 Windows

Nao ha "bundle id" no sentido mobile. A identidade vem do `Runner.rc` e do `CMakeLists.txt`:

`windows/runner/Runner.rc` (metadados do executavel):

```rc
VALUE "CompanyName", "Fiducia SCM"
VALUE "FileDescription", "Investa BR"
VALUE "ProductName", "Investa BR"
VALUE "InternalName", "investa_br"
VALUE "OriginalFilename", "investa_br.exe"
```

`windows/CMakeLists.txt`: `set(BINARY_NAME "investa_br")`.

> Se for distribuir via Microsoft Store (MSIX), o `Package.Identity.Name` (formato `Publisher.AppName`) e definido no empacotamento MSIX (ver 6.4), nao aqui.

#### 4.4 macOS

`macos/Runner/Configs/AppInfo.xcconfig`:

```
PRODUCT_NAME = Investa BR
PRODUCT_BUNDLE_IDENTIFIER = br.com.fiduciascm.investabr
PRODUCT_COPYRIGHT = Copyright © 2026 Fiducia SCM. All rights reserved.
```

Entitlements (necessarios para sembast/export e file_picker funcionarem sob sandbox). Editar `macos/Runner/Release.entitlements` e `DebugProfile.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>   <!-- chamadas HTTP as APIs -->
<true/>
```

> Sem `network.client` em release, as chamadas a BCB SGS/brapi/BrasilAPI falham silenciosamente no macOS. Sem `files.user-selected.read-write`, importar/exportar JSON nao abre o dialogo. Testar explicitamente import/export em macOS (decisao de desktop ja prevista nos testes).

#### 4.5 Linux

Application ID em `linux/CMakeLists.txt`:

```cmake
set(BINARY_NAME "investa_br")
set(APPLICATION_ID "br.com.fiduciascm.investabr")
```

E no arquivo `.desktop` de distribuicao (ver 6.5), o campo `Icon=` e o nome do arquivo devem casar com o application-id.

---

### 5. Assinatura por plataforma

#### 5.1 Android (keystore + Gradle)

Gerar keystore de upload (uma vez; guardar com seguranca, fora do git):

```bash
keytool -genkey -v -keystore ~/investa-br-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Criar `android/key.properties` (NAO commitar — adicionar ao `.gitignore`):

```properties
storeFile=/caminho/seguro/investa-br-upload.jks
storePassword=********
keyAlias=upload
keyPassword=********
```

Em `android/app/build.gradle`, carregar e aplicar:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            storeFile file(keystoreProperties["storeFile"])
            storePassword keystoreProperties["storePassword"]
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

> Recomendado ativar o **Play App Signing**: voce assina com a chave de upload e o Google re-assina com a chave de distribuicao. Guarde o keystore de upload e suas senhas em cofre (perda = impossibilidade de atualizar o app sob o mesmo `applicationId`).

#### 5.2 iOS / macOS (certificados Apple)

- Conta no Apple Developer Program (US$99/ano) — obrigatoria para publicar.
- iOS: certificado de distribuicao + provisioning profile do bundle id `br.com.fiduciascm.investabr`. Em dev, "Automatically manage signing" no Xcode resolve; em CI, use **fastlane match** ou App Store Connect API key + `ExportOptions.plist`.
- macOS: dois caminhos de assinatura:
  - **Mac App Store**: certificado "Apple Distribution" + entitlements de sandbox.
  - **Distribuicao direta (fora da loja)**: certificado **Developer ID Application** + **notarizacao** (ver 6.3).

#### 5.3 Windows

- O `.exe` Flutter nao precisa ser assinado para rodar, mas o SmartScreen exibira aviso. Para evitar, use um **certificado de Code Signing** (OV ou EV) e assine:

```bash
signtool sign /fd SHA256 /a /tr http://timestamp.digicert.com /td SHA256 \
  "build/windows/x64/runner/Release/investa_br.exe"
```

- Para Microsoft Store, o pacote MSIX e assinado no fluxo de empacotamento (ver 6.4).

#### 5.4 Linux

- Nao ha assinatura de codigo obrigatoria. Para Snap/Flatpak, a confianca vem da loja (Snap Store/Flathub). AppImage pode ser acompanhado de assinatura GPG opcional.

---

### 6. Consideracoes de distribuicao

#### 6.1 Aviso regulatorio (CVM) — pre-requisito de loja

Antes de submeter as lojas, garantir que o app exibe claramente que **valores e calculos sao informativos e nao constituem recomendacao de investimento**. Isso e relevante para a revisao da App Store (categoria Financas) e protege legalmente. A UI ja deve trazer esse aviso no comparador/conversor (decisao de dominio); replicar na descricao da loja.

#### 6.2 Android — Google Play
- Subir o **`.aab`** (App Bundle) no Play Console; o Play gera os APKs otimizados por dispositivo.
- Categoria sugerida: Financas. Preencher o questionario de **Data Safety** (o app armazena dados financeiros localmente via sembast; o token brapi e config de runtime; nenhuma coleta enviada a servidor proprio — declarar transparente).
- Para sideload/distribuicao corporativa interna, usar `.apk` (universal ou split por ABI).

#### 6.3 iOS — App Store
- Distribuicao **exclusiva** via App Store / TestFlight (nao ha sideload pratico). Subir o `.ipa` via Xcode Organizer, `xcrun altool`/`notarytool` ou fastlane.
- Preencher **App Privacy** (mesma logica do Data Safety). Como o app consome APIs publicas (BCB/brapi/BrasilAPI) e nao tem backend proprio, declarar apenas o uso de rede.
- Token brapi: NAO embutir token pessoal hardcoded num app publicado amplamente (15.000 req/mes e compartilhado por toda a base de usuarios -> estoura rapido e viola limites). Estrategia: ou pedir ao usuario seu proprio token nas Configuracoes (runtime config), ou degradar para os 4 tickers de teste (PETR4, VALE3, MGLU3, ITUB4) quando sem token.

#### 6.4 Windows — distribuicao
Tres caminhos, em ordem de atrito crescente de empacotamento:

| Canal | Empacotamento | Assinatura | Observacao |
|---|---|---|---|
| ZIP da pasta `Release/` | `flutter build windows` + zipar | opcional (recomendada) | mais simples; instalacao manual |
| Instalador (Inno Setup / MSI) | script Inno Setup sobre a pasta | recomendada | UX de instalacao/atalho/uninstall |
| Microsoft Store (MSIX) | pacote `msix` (`msix_config` no pubspec) | obrigatoria (cert ou pela Store) | maior alcance, sandbox |

Para MSIX, adicionar `msix` como dev_dependency e configurar:

```yaml
dev_dependencies:
  msix: ^3.16.0
```
```yaml
msix_config:
  display_name: Investa BR
  identity_name: FiduciaSCM.InvestaBR
  publisher_display_name: Fiducia SCM
  logo_path: assets/branding/icon.png
  capabilities: internetClient
```
```bash
dart run msix:create
```

#### 6.5 Linux — distribuicao
Empacotar a pasta `bundle/`. Incluir um arquivo `.desktop` para integracao com o menu:

```
[Desktop Entry]
Name=Investa BR
Exec=investa_br
Icon=investabr
Type=Application
Categories=Office;Finance;
```

| Formato | Quando usar | Notas |
|---|---|---|
| `.tar.gz` | distribuicao manual / scripts | mais simples; usuario extrai e roda `investa_br` |
| AppImage | binario portatil unico | empacotar `bundle/` + `.desktop` + icone com `appimagetool` |
| Snap | Snap Store | confinamento; declarar plugs `home`/`network` para file_picker/HTTP |
| Flatpak | Flathub | runtime GNOME; permissoes `--filesystem=home` e `--share=network` |

> Testar import/export JSON (`file_picker` + `share_plus` + `path_provider`) em pelo menos um formato confinado (Snap/Flatpak), pois o sandbox pode bloquear acesso ao home — adicionar as permissoes de filesystem e rede no manifesto.

#### 6.6 macOS — distribuicao
- **Direta (DMG/zip)**: assinar com Developer ID + **notarizar** e fazer **staple**:

```bash
xcrun notarytool submit "Investa BR.zip" \
  --apple-id "<apple-id>" --team-id "<TEAMID>" --password "<app-specific-pwd>" --wait
xcrun stapler staple "Investa BR.app"
```
- **Mac App Store**: certificado Apple Distribution + sandbox + entitlements (secao 4.4).

#### 6.7 Matriz consolidada de distribuicao

| Plataforma | Canal primario | Artefato | Assinatura | Conta paga |
|---|---|---|---|---|
| Android | Google Play | `.aab` | keystore upload + Play App Signing | Play Console (taxa unica) |
| iOS | App Store / TestFlight | `.ipa` | cert distribuicao + provisioning | Apple Dev (anual) |
| Windows | MSIX (Store) ou Inno/MSI | `.msix` / instalador | code signing (recomendada) | opcional |
| macOS | Mac App Store ou DMG notarizado | `.app` / `.dmg` | Developer ID + notarizacao | Apple Dev (anual) |
| Linux | Flathub / Snap / AppImage | flatpak/snap/AppImage/`.tar.gz` | nao obrigatoria | nao |

---

### 7. CI/CD (esqueleto reprodutivel)

Etapas recomendadas no pipeline (GitHub Actions ou similar), com FVM para fixar o SDK:

```yaml
# .github/workflows/release.yml (esqueleto)
jobs:
  build:
    strategy:
      matrix:
        target: [android, windows, linux]   # ios/macos exigem runner macOS
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.0', channel: 'stable' }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
      # passo de build especifico por matrix.target (ver secao 2)
```

Recomendacoes de CI:
- Segredos (keystore Android, senhas, certificados Apple) em **secrets** do CI, nunca no repo. `android/key.properties` e gerado em tempo de build a partir de secrets.
- iOS/macOS exigem runner macOS; Windows exige runner Windows (com VS C++); Linux exige instalar `clang cmake ninja-build pkg-config libgtk-3-dev`.
- Injetar `--build-number=$RUN_NUMBER` para versionamento automatico do build.
- Gerar e arquivar os artefatos por plataforma como artifacts do pipeline antes da etapa de publicacao.

---

### 8. Checklist de release (rapido)

```
[ ] pubspec version X.Y.Z+N atualizado (semver + build number)
[ ] flutter analyze limpo (very_good_analysis) e flutter test verde
[ ] build_runner regenerado e *.g.dart / *.freezed.dart commitados
[ ] icones (flutter_launcher_icons) e splash (flutter_native_splash) regenerados se a marca mudou
[ ] bundle/app id == br.com.fiduciascm.investabr em todas as plataformas
[ ] aviso CVM (informativo, nao recomendacao) presente na UI e na descricao da loja
[ ] Android: .aab assinado (Play App Signing)
[ ] iOS: .ipa assinado e App Privacy preenchido
[ ] Windows: MSIX/instalador assinado (ou aviso SmartScreen aceito)
[ ] macOS: .app assinado (Developer ID) + notarizado + stapled, entitlements de sandbox/rede/arquivos
[ ] Linux: .desktop + icone + permissoes (home/network) no formato confinado; import/export testado
[ ] import/export JSON testado em Windows, macOS e Linux (decisao de desktop)
```

---

## Roadmap de Implementacao em Fases

Esta secao define a **ordem de execucao** para o Claude Opus 4.8 construir o **Investa BR** do zero, em fases incrementais. Cada fase produz um app que **compila e roda nas 5 plataformas** (Android, iOS, Windows, macOS, Linux) e tem criterios de pronto (DoD) verificaveis. As decisoes tecnicas (Flutter 3.44/Dart 3.12, Riverpod 3 com code-gen, sembast, Dio, go_router, freezed) ja estao fechadas nas secoes anteriores — aqui o foco e **sequencia, dependencias e o que entregar em cada marco**.

---

### Regras transversais (valem para TODAS as fases)

Antes de considerar qualquer fase concluida, o implementador deve garantir:

1. **`fvm flutter analyze` com zero warnings/errors** (lints `very_good_analysis`).
2. **`fvm dart run build_runner build --delete-conflicting-outputs` sem erros** (freezed/json_serializable/riverpod_generator).
3. **Testes da fase passando** (`fvm flutter test`) — a piramide de testes da secao *Testes & Qualidade* cresce junto com o codigo, nunca depois.
4. **App compila e abre nas 5 plataformas** (no minimo smoke manual em 1 mobile + 1 desktop por fase; release completo so na fase final).
5. **Nenhum dado de mercado hardcoded em runtime** — valores fixos so em testes/mocks.
6. **`domain/` permanece puro** (sem `import 'package:flutter/...'`, sem Dio, sem sembast).
7. **Sem chamadas de rede reais em testes** — sempre `mocktail` + `overrideWith`.

> **Controle de versao:** por instrucao do usuario, **nao realizar commits** durante a implementacao. Versionar manualmente fica a cargo do usuario.

---

### Visao geral das fases

| Fase | Marco | Entrega principal | Depende de | UI? |
|------|-------|-------------------|-----------|-----|
| **F0** | Fundacao | Projeto criado, FVM, deps, lints, build_runner, esqueleto de pastas, tema minimo | — | esqueleto |
| **F1** | Dominio & Motor Financeiro | Entidades (freezed), enums, value objects, **funcoes financeiras puras** (juros 252du, IPCA+, %CDI, prefixado, IR/IOF, conversor, projecao) 100% testadas | F0 | nao |
| **F2** | Persistencia Local | sembast aberto, 4 stores, repositorios CRUD, `schemaVersion`/migracao, **export/import JSON** com validacao+checksum | F1 | nao |
| **F3** | Camada de Dados & Cache Diario | `dio_factory` + interceptors, datasources remotos (BCB SGS, brapi, BrasilAPI/OpenCNPJ/ReceitaWS, AwesomeAPI, Tesouro CSV), `Result/Failure`, **`DailyCacheService`** + fallback offline | F0, F1 | nao |
| **F4** | Navegacao & Home | go_router, navegacao responsiva (NavigationBar/Rail), **Tela Inicial** (cards de indicadores + patrimonio + grafico), estados loading/erro/vazio | F2, F3 | sim |
| **F5** | Carteira & Cadastro | Telas de cadastro/edicao de RF e posicoes de acoes; calculo de **patrimonio** e rentabilidade; lista e distribuicao da carteira | F2, F4 | sim |
| **F6** | Conversor/Comparador | Tela do **conversor de renda** usando o motor financeiro + indices do dia (bruto x liquido, taxa bruta equivalente de isentos) | F1, F3, F4 | sim |
| **F7** | Acoes & CNPJ | Busca de acao (brapi), exibicao de cotacao/fundamentos, enriquecimento via CNPJ; **recomendacoes (desejavel)** por heuristica de fundamentos com degradacao graciosa | F3, F4 | sim |
| **F8** | Tema & i18n & Polimento | Tema customizavel (seed color, claro/escuro/sistema, `dynamic_color`), persistencia do tema, l10n pt-BR completo, acessibilidade, icones/splash | F4 | sim |
| **F9** | Testes, Hardening & Release | Cobertura alvo, testes de integracao (patrol), builds **release** assinadas por plataforma, smoke final nos 5 SO | todas | — |

---

### Grafo de dependencias

```
            F0 (fundacao)
           /     |       \
          F1     F3       (tema base em F0)
         /  \   /  \
        F2   \ /    \
        |     X      \
        |    / \      \
        F4 <-   ->     F7 (precisa F3,F4)
       / | \
      F5 F6 F8         F9 = depois de TODAS
```

- **Caminho critico:** F0 -> F1 -> F2 -> F4 -> F5. As demais (F3, F6, F7, F8) penduram a partir de F1/F4.
- **Paralelizavel:** F1 (dominio puro) e F3 (camada de rede) podem avancar em paralelo apos F0, pois F3 so consome as *interfaces*/entidades de F1, nao a UI.

---

### Detalhamento por fase

#### F0 — Fundacao
**Objetivo:** projeto esqueleto compilavel, tooling fechado.
- `flutter create --platforms=android,ios,windows,macos,linux --org br.com.fiduciascm --project-name investa_br investa_br`.
- `.fvmrc` (Flutter 3.44.0); `pubspec.yaml` com TODAS as deps das secoes (riverpod, freezed, json_serializable, go_router, dio, sembast, path_provider, file_picker, share_plus, intl, fl_chart, dynamic_color, uuid, crypto, + dev: build_runner, riverpod_generator, mocktail, very_good_analysis).
- `analysis_options.yaml`, `build.yaml`, `l10n.yaml`.
- Esqueleto de pastas `lib/src/...` (secao *Estrutura de Pastas*), `main.dart` + `bootstrap.dart` chamando `LocalDb.instance.open()` (stub), `ProviderScope`, `window_manager` no desktop.
- `MaterialApp.router` com `ColorScheme.fromSeed` minimo (tema definitivo so na F8) e uma rota Home placeholder.

**DoD:** app abre tela vazia nas 5 plataformas; `build_runner` e `analyze` limpos.

#### F1 — Dominio & Motor Financeiro
**Objetivo:** coracao do app, sem nenhuma dependencia de Flutter.
- Entidades freezed: `InvestimentoRendaFixa`, `PosicaoAcao`, `Indicador`, `Carteira`, `ConfiguracaoTema`; value objects `Dinheiro`/`Money`, `Percentual`.
- Enums/unions: `TipoRendimento` (`PREFIXADO | PERCENTUAL_CDI | PERCENTUAL_SELIC | IPCA_MAIS | IGPM_MAIS | PERCENTUAL_PURO`), `Indexador`, `ClasseAtivo`, `Tributacao`.
- **Funcoes puras** (testaveis sem mocks): juros compostos base **252 dias uteis**, fator diario do CDI, IPCA+/IGPM+, prefixado a.a., **IR regressivo** (tabela), **IOF** (tabela 30 dias), **conversor/comparador** (taxa bruta equivalente de isento; rentabilidade liquida anual efetiva), **projecao de valor futuro**.
- Interfaces de repositorio (sem implementacao ainda).

**DoD:** cobertura de testes **alta nas funcoes financeiras** (casos da secao *Matematica Financeira* reproduzidos como testes-tabela); `domain/` sem import externo.

#### F2 — Persistencia Local & Import/Export
**Objetivo:** dados do usuario persistem e fazem round-trip por JSON.
- `LocalDb.open()` (sembast `databaseFactoryIo`), 4 stores, `schemaVersion=1`, `_onVersionChanged`.
- Repositorios CRUD: `renda_fixa`, `posicoes_acoes`, `configuracoes`, `cache_indicadores`.
- `import_export/`: `backup_payload` (freezed), `backup_codec` (encode/decode + **checksum SHA-256 canonico**), `payload_migrator`, `import_export_service` (file_picker + share_plus), `ModoImport { replace, merge }`, validacoes tipadas (rejeicao por `app` errado, `schemaVersion` futura, checksum divergente).

**DoD:** CRUD persistente; **export gera JSON valido** (formato da secao *Persistencia*); **import valida, migra e faz merge/replace**; round-trip export->import->export idempotente; testes com `databaseFactoryMemory`.

#### F3 — Camada de Dados & Cache Diario
**Objetivo:** dados de mercado entram no app, com cache e resiliencia.
- `dio_factory` (um Dio por API) + interceptors: `user_agent` (obrigatorio p/ SGS), `brapi_token`, `error_normalizer` (mapeia HTML/429/5xx -> `Failure`), `logging` (so `kDebugMode`).
- Datasources remotos: `sgs_remote` (batch de boot das 7 series), `brapi_remote`, CNPJ (`brasilapi` principal + `opencnpj`/`receitaws` fallback), `awesomeapi`, Tesouro CSV (sob demanda).
- `Result<T>`/`Failure` sealed; mappers DTO->entidade (parse `String`->`double`, datas `dd/MM/yyyy`).
- **`DailyCacheService`**: ao abrir o app, se `dataUltimaAtualizacao != hoje` -> refaz requisicoes e grava; senao usa cache. TTL, `stale`, **refresh manual**, fallback offline (ultimo snapshot).

**DoD:** snapshot de indicadores do dia cacheado e exibivel; refresh manual funciona; **nenhum teste bate na rede real** (mocktail); 429/5xx e offline tratados sem crash.

#### F4 — Navegacao & Tela Inicial
**Objetivo:** primeira tela util com dados reais.
- `go_router` + `ShellRoute` com navegacao responsiva (`NavigationBar` mobile / `NavigationRail` desktop).
- **Tela Inicial:** cards SELIC/CDI/IPCA/IGP-M (do cache), **patrimonio total** (RF + acoes), distribuicao da carteira (fl_chart), estados loading/erro/vazio, pull-to-refresh.
- Formatacao pt-BR (`NumberFormat` R$, percentuais, datas).

**DoD:** Home renderiza indicadores e patrimonio a partir de dados cacheados reais; estados de erro/vazio cobertos.

#### F5 — Carteira & Cadastro
**Objetivo:** usuario registra e ve seu patrimonio evoluir.
- Formularios de cadastro/edicao de **investimento RF** (tipo de rendimento, indexador, taxa, valor inicial, datas, quantidade de cotas) e de **posicao de acao**; validacao de formulario.
- Lista da carteira, calculo de valor atual/rentabilidade por item (usa motor da F1 + indices da F3), totalizacao.

**DoD:** registrar um CDB/LCI e uma acao atualiza o patrimonio e a distribuicao na Home; edicao/exclusao funcionam e persistem.

#### F6 — Conversor / Comparador de Renda
**Objetivo:** comparar investimentos por tipo de taxa.
- Tela do conversor: entrada de uma taxa por tipo (prefixado, %CDI/%SELIC, IPCA+/IGPM+, percentual puro) + flag isento; saida em **rentabilidade liquida anual efetiva** e **taxa bruta equivalente**, usando indices do dia.
- Comparacao lado a lado de 2+ cenarios.

**DoD:** comparar 110% CDI x IPCA+6% x 13% prefixado x LCI 95% CDI (isenta) bate com os casos de teste da secao *Matematica Financeira*.

#### F7 — Acoes & CNPJ
**Objetivo:** busca de acoes com dados (recomendacoes desejavel).
- Busca por ticker (brapi, com token), exibicao de cotacao + fundamentos; enriquecimento da empresa via **CNPJ** (BrasilAPI principal, fallback OpenCNPJ/ReceitaWS).
- **Recomendacoes (desejavel):** como `recommendationKey`/`targetMeanPrice` so vem no plano PRO da brapi, derivar **sinais proprios** por heuristica de fundamentos (P/L, P/VP, DY, ROE) e **degradar graciosamente** quando ausentes.

**DoD:** buscar PETR4 mostra cotacao+fundamentos; CNPJ resolve com fallback; ausencia de recomendacao paga nao quebra a UI.

#### F8 — Tema, i18n & Polimento
**Objetivo:** identidade visual e acabamento.
- Tema customizavel: `ColorScheme.fromSeed` com **seed editavel**, modo claro/escuro/sistema, `dynamic_color` (Material You quando disponivel), persistencia em `configuracoes`.
- l10n pt-BR completo (`.arb`), acessibilidade (contraste, semantics, fontes escalaveis), `flutter_launcher_icons` + `flutter_native_splash`.

**DoD:** trocar tema/seed persiste entre sessoes; auditoria basica de a11y; icones/splash em todas as plataformas.

#### F9 — Testes, Hardening & Release
**Objetivo:** qualidade e distribuicao.
- Atingir a cobertura alvo (secao *Testes*); testes de integracao (`patrol`/`integration_test`) dos fluxos criticos (cadastro -> patrimonio, conversor, busca de acao, export/import).
- Builds **release** por plataforma (secao *Build & Release*): assinatura, bundle id `br.com.fiduciascm.investa_br`, icones/splash; smoke manual nos 5 SO.

**DoD:** artefatos release gerados e abrindo em Android, iOS, Windows, macOS e Linux; checklist de release concluido.

---

## Riscos & Mitigacoes

Esta secao cataloga os riscos tecnicos e de produto do **Investa BR** (`investa_br`) e prescreve mitigacoes acionaveis, com codigo Dart, contratos de teste e formulas. O leitor (implementador) deve tratar cada mitigacao como requisito de implementacao, nao como sugestao. A regra de ouro do app: **nenhuma fonte externa e ponto unico de falha — todo dado externo tem cache local persistido e degradacao graciosa (`stale=true`)**.

---

### 1. Risco: APIs gratuitas mudarem schema, mudarem URL ou cairem

Todas as fontes externas sao gratuitas/comunitarias e **sem SLA contratual**. Em ordem de criticidade para o app:

| Fonte | Criticidade | Modo de falha provavel | Sintoma observavel |
|---|---|---|---|
| BCB SGS | Critica (indicadores) | Rejeicao por User-Agent (retorna HTML "Requisicao Invalida"); filtro obrigatorio desde 26/03/2025; rate limit de servidor | HTTP 200 com `text/html` em vez de JSON; HTTP 400 |
| brapi.dev | Alta (acoes) | Mudanca de plano free; token revogado; 429 | HTTP 401/429; campos nulos |
| BrasilAPI | Media (CNPJ, feriados, PTAX) | Throttle downstream (Receita) no `/cnpj`; projeto comunitario beta | HTTP 429/5xx, latencia alta |
| OpenCNPJ | Media (fallback CNPJ) | Confusao com homonimo `.com`; mudanca de schema (`QSA`, endereco plano) | HTTP 4xx; parse falha |
| Tesouro CKAN (CSV) | Media (Tesouro Direto) | DataStore desabilitado (nao usar `datastore_search`); CSV grande muda colunas; endpoint legado 410 Gone | HTTP 400 no datastore; parse CSV falha |
| AwesomeAPI | Baixa (cambio, opcional) | Cache de 1min sem chave; teto de resultados | dados defasados |

#### Mitigacao 1.1 — Camada de fonte isolada atras de interface + Result tipado

Nenhuma feature chama `dio` diretamente. Toda chamada passa por um `DataSource` que retorna `Result<T>`, mapeando `DioException` para `Failure` tipado. Isso isola mudancas de API a um unico arquivo por fonte.

Arvore de arquivos da camada de rede:

```
lib/src/
  common/
    network/
      dio_client.dart            # Dio + interceptors (base url, UA, token, log, erro)
      api_failure.dart           # sealed Failure: Network, Http, Parse, RateLimit, Auth, Offline
      result.dart                # sealed Result<T>: Success<T> / FailureResult<T>
      endpoints.dart             # constantes de TODAS as base URLs e paths (ponto unico de troca)
  features/
    indicadores/data/
      bcb_sgs_datasource.dart     # parser defensivo SGS (string, dataFim, HTML)
    acoes/data/
      brapi_datasource.dart       # token, 429, campos nulos
    renda_fixa/data/
      cnpj_datasource.dart        # BrasilAPI -> OpenCNPJ -> ReceitaWS (fallback encadeado)
      tesouro_csv_datasource.dart # download CSV + parse ; / virgula decimal
```

`endpoints.dart` centraliza URLs — se o BCB mudar o dominio, muda-se **um** arquivo:

```dart
abstract final class Endpoints {
  // Cada base e uma constante; trocar aqui propaga a todo o app.
  static const bcbSgs = 'https://api.bcb.gov.br/dados/serie';
  static const brapi = 'https://brapi.dev/api';
  static const brasilApi = 'https://brasilapi.com.br/api';
  static const openCnpj = 'https://api.opencnpj.org';
  static const receitaWs = 'https://receitaws.com.br/v1';
  static const awesomeApi = 'https://economia.awesomeapi.com.br';
  static const tesouroCsv =
      'https://www.tesourotransparente.gov.br/ckan/dataset/'
      'df56aa42-484a-4a59-8184-7676580c81e3/resource/'
      '796d2059-14e9-44e3-80c9-2d9e30b405c1/download/precotaxatesourodireto.csv';
}
```

`Failure` como sealed class (Dart 3), permitindo pattern matching exaustivo na UI:

```dart
sealed class ApiFailure {
  const ApiFailure(this.message);
  final String message;
}

final class NetworkFailure extends ApiFailure {
  const NetworkFailure([super.message = 'Sem conexao']);
}
final class OfflineCacheFailure extends ApiFailure {
  const OfflineCacheFailure([super.message = 'Sem cache disponivel']);
}
final class HttpFailure extends ApiFailure {
  const HttpFailure(this.statusCode, [super.message = 'Erro HTTP']);
  final int statusCode;
}
final class RateLimitFailure extends ApiFailure {
  const RateLimitFailure([super.message = 'Limite de requisicoes atingido']);
}
final class AuthFailure extends ApiFailure {
  const AuthFailure([super.message = 'Token ausente ou invalido']);
}
final class ParseFailure extends ApiFailure {
  // Critico: SGS pode devolver HTML em vez de JSON.
  const ParseFailure([super.message = 'Resposta em formato inesperado']);
}
```

`Result<T>` como sealed class (decisao global: **nao** usar fpdart/dartz como dependencia obrigatoria):

```dart
sealed class Result<T> {
  const Result();
}
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}
final class Err<T> extends Result<T> {
  const Err(this.failure);
  final ApiFailure failure;
}
```

#### Mitigacao 1.2 — Interceptor de normalizacao de erro + deteccao de HTML

O BCB SGS, sob falha ou User-Agent ausente, retorna **HTML** com HTTP 200. Trate isso explicitamente:

```dart
class ErrorNormalizingInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final contentType = response.headers.value('content-type') ?? '';
    // SGS pode devolver "Requisicao Invalida" em HTML com status 200.
    if (contentType.contains('text/html') &&
        response.requestOptions.responseType == ResponseType.json) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: const ParseFailure('SGS retornou HTML (provavel rejeicao de UA)'),
        ),
      );
      return;
    }
    handler.next(response);
  }
}
```

Mapeamento `DioException -> ApiFailure` (executado uma vez, na fronteira do datasource):

```dart
ApiFailure mapDioError(DioException e) => switch (e.response?.statusCode) {
      401 || 403 => const AuthFailure(),
      429 => const RateLimitFailure(),
      final int s when s >= 500 => HttpFailure(s, 'Servidor indisponivel'),
      final int s when s >= 400 => HttpFailure(s),
      _ => switch (e.type) {
          DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout =>
            const NetworkFailure(),
          _ => e.error is ApiFailure
              ? e.error! as ApiFailure
              : const ParseFailure(),
        },
    };
```

#### Mitigacao 1.3 — Fallback encadeado por dominio

CNPJ tem 3 fontes. O datasource tenta em ordem e so propaga `Err` se **todas** falharem:

```dart
Future<Result<EmissorCnpj>> consultarCnpj(String cnpjRaw) async {
  final cnpj = cnpjRaw.replaceAll(RegExp(r'\D'), ''); // normaliza: so digitos
  for (final fonte in [_brasilApi, _openCnpj, _receitaWs]) {
    final r = await fonte(cnpj);
    if (r is Ok<EmissorCnpj>) return r;
  }
  return const Err(NetworkFailure('Nenhuma fonte de CNPJ respondeu'));
}
```

#### Mitigacao 1.4 — Snapshot persistido sempre serve de paraquedas

Toda fonte critica grava `cache_indicadores` no sembast. Se a API mudar/cair, o app serve o ultimo snapshot bom marcado `stale=true` (ver risco 6). **Nunca** crashar por falha de rede no boot.

#### Mitigacao 1.5 — Versionar a base URL legada e detectar 410 Gone

O endpoint legado do Tesouro (`tesourodireto.com.br/json/...`) retorna **410 Gone**. O datastore CKAN retorna **400**. Ambos sao tratados como `HttpFailure` que dispara o caminho do CSV. Documentar no codigo:

```dart
// NAO usar datastore_search (HTTP 400, DataStore desabilitado no portal).
// NAO usar tesourodireto.com.br/json (HTTP 410 Gone).
// Unico caminho valido: download do CSV + parse local.
```

---

### 2. Risco: limites de requisicao (rate limits, cotas, janelas)

Cada API tem limites distintos. Estourar = 429, bloqueio temporario ou dados truncados.

| Fonte | Limite real | Consequencia de estourar |
|---|---|---|
| BCB SGS | Janela max **10 anos** por consulta de periodo; `/ultimos` max **20** registros; filtros obrigatorios desde 26/03/2025; ~**5 req paralelas** como cortesia | HTTP 400 / bloqueio temporario do IP |
| brapi.dev (free) | **15.000 req/mes**, **1 ticker/req**, update ~30min, historico ~3 meses; sem token so 4 tickers | HTTP 429 |
| BrasilAPI | Fair use, sem numero oficial; `/cnpj` e o mais throttled (Receita downstream) | HTTP 429/5xx |
| OpenCNPJ | **50 req/s** por IP | HTTP 429 |
| ReceitaWS / CNPJ.ws | **3 req/min** (free) | bloqueio por 60s |
| AwesomeAPI | sem chave: cache 1min, 100 resultados/serie; com chave: 100k req/mes, 1500 resultados; `daily` max 360 dias | dados defasados / truncados |

#### Mitigacao 2.1 — Cache diario absorve a maior parte do volume

O `DailyCacheService` garante **no maximo 1 batch de requisicoes por dia** para os indicadores. As series SGS atualizam ~1x/dia (D-1 util), entao um refetch por dia e suficiente. Isso reduz o consumo de SGS a ~7 req/dia (uma por serie) e de brapi a `N tickers da carteira`/dia.

#### Mitigacao 2.2 — Pool de concorrencia limitado (max 5 paralelas no SGS)

No boot, as 7 series SGS sao buscadas em paralelo, mas com **teto de 5 simultaneas** (cortesia recomendada):

```dart
/// Executa [tasks] com no maximo [maxConcurrent] em voo simultaneamente.
Future<List<Result<T>>> runPooled<T>(
  List<Future<Result<T>> Function()> tasks, {
  int maxConcurrent = 5,
}) async {
  final results = List<Result<T>?>.filled(tasks.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= tasks.length) return;
      results[i] = await tasks[i]();
    }
  }
  await Future.wait(
    List.generate(maxConcurrent.clamp(1, tasks.length), (_) => worker()),
  );
  return results.cast<Result<T>>();
}
```

#### Mitigacao 2.3 — Fragmentacao de series longas (janela de 10 anos do SGS)

Os cards da home usam `/ultimos/1` (nao sofre a regra de 10 anos). Mas o **historico** do conversor/grafico pode pedir periodos longos. Fragmentar em janelas de ate 10 anos e concatenar:

```dart
/// Gera janelas [inicio, fim] de no maximo 10 anos (limite do SGS por consulta).
List<(DateTime, DateTime)> janelas10Anos(DateTime inicio, DateTime fim) {
  final out = <(DateTime, DateTime)>[];
  var cursor = inicio;
  while (cursor.isBefore(fim)) {
    // 10 anos - 1 dia para nao exceder a diferenca maxima permitida.
    final limite = DateTime(cursor.year + 10, cursor.month, cursor.day)
        .subtract(const Duration(days: 1));
    final janelaFim = limite.isBefore(fim) ? limite : fim;
    out.add((cursor, janelaFim));
    cursor = janelaFim.add(const Duration(days: 1));
  }
  return out;
}
```

#### Mitigacao 2.4 — Backoff exponencial com jitter em 429/5xx

Interceptor de retry para `RateLimitFailure` e `5xx` (nunca em 4xx de cliente):

```dart
class BackoffRetryInterceptor extends Interceptor {
  BackoffRetryInterceptor(this._dio, {this.maxRetries = 3});
  final Dio _dio;
  final int maxRetries;
  static const _base = Duration(milliseconds: 400);

  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler handler) async {
    final status = e.response?.statusCode ?? 0;
    final retryable = status == 429 || status >= 500;
    final attempt = (e.requestOptions.extra['retry'] as int?) ?? 0;
    if (!retryable || attempt >= maxRetries) return handler.next(e);

    // Respeita Retry-After se presente; senao exponencial + jitter.
    final retryAfter = int.tryParse(
      e.response?.headers.value('retry-after') ?? '',
    );
    final delay = retryAfter != null
        ? Duration(seconds: retryAfter)
        : _base * (1 << attempt) +
            Duration(milliseconds: Random().nextInt(250));
    await Future<void>.delayed(delay);

    final opts = e.requestOptions..extra['retry'] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(opts));
    } on DioException catch (err) {
      handler.next(err);
    }
  }
}
```

#### Mitigacao 2.5 — CNPJ: cache local com TTL longo + respeitar 3 req/min do fallback

CNPJ muda raramente. Cache por CNPJ com TTL de dias/semanas elimina quase toda repeticao. O fallback ReceitaWS (3 req/min) so e acionado apos BrasilAPI e OpenCNPJ falharem, entao seu limite raramente e tocado. Quando tocado, o backoff (Retry-After) espera os ~20s recomendados.

#### Mitigacao 2.6 — Tesouro/acoes sob demanda, fora do boot

Para nao pesar o boot e nao gastar cota brapi, **acoes e Tesouro nao entram no batch de abertura**. Cotacoes da carteira sao buscadas no boot (sao poucos tickers), mas a busca de acoes e os precos do Tesouro sao carregados sob demanda com cache proprio.

---

### 3. Risco: precisao dos calculos financeiros

Calculo errado de rentabilidade/imposto e o pior bug possivel num app financeiro — engana o usuario. Fontes de erro: aproximacao de dias uteis, base de dias incorreta, parse de string SGS, arredondamento de `double`, regra tributaria desatualizada.

#### Mitigacao 3.1 — Taxa como Value Object, nunca um `double` solto

Decisao global: modelar a taxa como `{tipoRendimento, valorContratado, indexador, baseDias, capitalizacao}`. Usar freezed + sealed unions com pattern matching:

```dart
enum BaseDias { d252, d360, d365 }
enum Capitalizacao { composta, simples }

@freezed
sealed class TipoRendimento with _$TipoRendimento {
  const factory TipoRendimento.prefixado(double taxaAnual) = Prefixado;
  const factory TipoRendimento.percentualCdi(double percentual) = PercentualCdi;
  const factory TipoRendimento.percentualSelic(double percentual) = PercentualSelic;
  const factory TipoRendimento.ipcaMais(double taxaRealAnual) = IpcaMais;
  const factory TipoRendimento.igpmMais(double taxaRealAnual) = IgpmMais;
  const factory TipoRendimento.percentualPuro(double taxaPeriodo) = PercentualPuro;
}
```

A entidade **persiste a taxa contratada**, nunca a taxa efetiva derivada (esta e recalculada sempre).

#### Mitigacao 3.2 — Base 252 dias uteis com contagem real de feriados

Decisao global: base 252 + juros compostos como **padrao**. **Proibido** aproximar `dias_uteis = dias_corridos * (252/365)` — acumula erro em prazos longos. Usar contagem real com feriados nacionais da BrasilAPI (`/feriados/v1/{ano}`), validada contra calendario ANBIMA/B3.

```dart
/// Conta dias uteis no intervalo [inicio, fim], excluindo fins de semana
/// e feriados. [feriados] = datas normalizadas (sem hora) do calendario.
int diasUteisEntre(DateTime inicio, DateTime fim, Set<DateTime> feriados) {
  var count = 0;
  var d = DateTime(inicio.year, inicio.month, inicio.day);
  final ate = DateTime(fim.year, fim.month, fim.day);
  while (d.isBefore(ate)) {
    final ehFimDeSemana =
        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    if (!ehFimDeSemana && !feriados.contains(d)) count++;
    d = d.add(const Duration(days: 1));
  }
  return count;
}
```

> **Atencao (ANBIMA):** BrasilAPI retorna apenas feriados **nacionais** (`type=national`). O mercado segue o calendario ANBIMA/B3, que pode divergir. Embarcar um JSON de feriados ANBIMA como fallback/complemento e validar contra ele para precificacao.

#### Mitigacao 3.3 — Formulas de referencia (centralizadas e testadas)

Notacao: `VI` = valor inicial, `VF` = valor futuro bruto, `du` = dias uteis, `dc` = dias corridos, `i` = taxa anual (ex. 0,1440).

| Cenario | Formula |
|---|---|
| Base 252 (CDI/Selic/prefixado) | `VF = VI * (1 + i)^(du/252)` |
| % do CDI (projecao, p ex. 1.10) | `VF ≈ VI * (1 + cdi)^(p * du/252)` |
| % do CDI (historico exato) | `VF = VI * Π_t [ ((1+CDI_t)^(1/252) - 1) * p + 1 ]` |
| Base 360 / 365 | `VF = VI * (1 + i)^(dc/360)` ou `^(dc/365)` |
| Hibrido IPCA+ | `VF = VI * fatorIndice * (1 + taxaReal)^(du/252)` |
| Percentual puro composto | `VF = VI * (1 + taxaPeriodo)^nPeriodos` |
| Percentual puro simples | `VF = VI * (1 + taxaPeriodo * nPeriodos)` |

```dart
import 'dart:math';

double vfBase252(double vi, double iAnual, int du) =>
    vi * pow(1 + iAnual, du / 252).toDouble();

double vfPercentualCdi(double vi, double cdiAnual, double pct, int du) =>
    vi * pow(1 + cdiAnual, pct * du / 252).toDouble(); // pct=1.10 => 110%

double vfHibrido(double vi, double indiceAcum, double taxaReal, int du) =>
    vi * (1 + indiceAcum) * pow(1 + taxaReal, du / 252).toDouble();
```

#### Mitigacao 3.4 — Tributacao encapsulada em config versionada e DATADA

Decisao global (tributacao vigente 2026): IR regressivo, IOF regressivo, isencoes de LCI/LCA/CRI/CRA/incentivadas/poupanca (MP 1.303/2025 **caducou** em out/2025). A regra de isencao e o ponto mais sujeito a mudanca legislativa — encapsular num `TaxRuleSet` **datado**:

Tabela IR regressivo (sobre o rendimento):

| Prazo (dias corridos) | Aliquota |
|---|---|
| ate 180 | 22,5% |
| 181 a 360 | 20,0% |
| 361 a 720 | 17,5% |
| acima de 720 | 15,0% |

IOF regressivo (so resgate < 30 dias, sobre o rendimento), formula fechada do Decreto 6.306/2007:

`aliquotaIOF = trunc((30 - dias) / 30 * 100) / 100`, e `0` para `dias >= 30`.

```dart
/// Conjunto de regras tributarias com vigencia datada.
/// Trocar de regra = adicionar novo TaxRuleSet, nao editar o antigo.
class TaxRuleSet {
  const TaxRuleSet({
    required this.vigenteDesde,
    required this.classesIsentasIr,
  });
  final DateTime vigenteDesde;
  final Set<ClasseAtivo> classesIsentasIr;

  double aliquotaIr(int diasCorridos, ClasseAtivo classe) {
    if (classesIsentasIr.contains(classe)) return 0;
    if (diasCorridos <= 180) return 0.225;
    if (diasCorridos <= 360) return 0.20;
    if (diasCorridos <= 720) return 0.175;
    return 0.15;
  }

  double aliquotaIof(int diasCorridos) =>
      diasCorridos >= 30 ? 0 : ((30 - diasCorridos) / 30 * 100).truncate() / 100;
}

// Regra vigente em 2026 (MP 1.303/2025 caducou; isentos permanecem isentos).
const taxRule2026 = TaxRuleSet(
  vigenteDesde: /* DateTime(2025,10,12) */ null as DateTime,
  classesIsentasIr: {
    ClasseAtivo.lci, ClasseAtivo.lca, ClasseAtivo.cri, ClasseAtivo.cra,
    ClasseAtivo.debentureIncentivada, ClasseAtivo.poupanca,
  },
);
```

Ordem de aplicacao (load-bearing — IOF antes do IR, ambos sobre o rendimento):

```dart
final rendimentoBruto = vf - vi;
final iof = rule.aliquotaIof(dc) * rendimentoBruto;
final ir = rule.aliquotaIr(dc, classe) * (rendimentoBruto - iof);
final vfLiquido = vi + rendimentoBruto - iof - ir;
```

#### Mitigacao 3.5 — Gross-up de isentos usa a aliquota IR do prazo planejado

Para comparar isento vs tributavel, o comparador converte tudo para **rentabilidade liquida anual efetiva (% a.a., base 252)** e calcula a taxa bruta equivalente do isento **com a aliquota do prazo** (nao fixar 15%):

`taxaBrutaEquivalente = taxaLiquidaIsento / (1 - aliquotaIr(prazoDias))`

```dart
double taxaLiquidaAnualEfetiva({
  required double vi,
  required double iBrutaAnual,
  required int prazoDias,
  required int diasUteis,
  required ClasseAtivo classe,
  required TaxRuleSet rule,
}) {
  final vf = vi * pow(1 + iBrutaAnual, diasUteis / 252).toDouble();
  final rend = vf - vi;
  final iof = rule.aliquotaIof(prazoDias) * rend;
  final ir = rule.aliquotaIr(prazoDias, classe) * (rend - iof);
  final vfLiq = vi + rend - iof - ir;
  return pow(vfLiq / vi, 252 / diasUteis).toDouble() - 1;
}
```

A UI deve exibir o **prazo assumido** e o aviso CVM: *"Valores informativos, nao constituem recomendacao de investimento."*

#### Mitigacao 3.6 — Parse defensivo do SGS (string, ponto/virgula, dataFim)

O SGS retorna `valor` como **string** (`"14.50"`, `"0.053400"`) e algumas series (TR=226, poupanca=195) trazem `dataFim`. Parser tolerante a virgula/ponto:

```dart
double parseSgsValor(String raw) =>
    double.parse(raw.trim().replaceAll(',', '.'));

DateTime parseSgsData(String raw) {
  final p = raw.split('/'); // dd/MM/yyyy
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}
```

#### Mitigacao 3.7 — Suite de testes de regressao com casos conhecidos

Decisao global manda cobrir calculo por tipo de taxa. Contrato minimo de testes (`flutter_test` + `mocktail`):

```dart
group('motor de calculo - base 252', () {
  test('prefixado 13% a.a., 252 du, ~12 meses', () {
    final vf = vfBase252(10000, 0.13, 252);
    expect(vf, closeTo(11300, 0.01)); // (1.13)^1 = 1.13
  });

  test('110% CDI com CDI 14,40%, 252 du', () {
    final vf = vfPercentualCdi(10000, 0.1440, 1.10, 252);
    expect(vf, closeTo(10000 * pow(1.1440, 1.10), 0.01));
  });

  test('IOF dia 1 = 96%, dia 30 = 0%', () {
    expect(taxRule2026.aliquotaIof(1), 0.96);
    expect(taxRule2026.aliquotaIof(30), 0.0);
  });

  test('IR 22,5% ate 180 dias para CDB', () {
    expect(taxRule2026.aliquotaIr(180, ClasseAtivo.cdb), 0.225);
  });

  test('LCI isenta de IR independentemente do prazo', () {
    expect(taxRule2026.aliquotaIr(90, ClasseAtivo.lci), 0.0);
  });
});

group('parsing SGS', () {
  test('valor string com ponto', () => expect(parseSgsValor('14.50'), 14.5));
  test('valor string com virgula', () => expect(parseSgsValor('0,0534'), 0.0534));
  test('data dd/MM/yyyy', () =>
      expect(parseSgsData('17/06/2026'), DateTime(2026, 6, 17)));
});
```

#### Mitigacao 3.8 — Tolerancia a arredondamento

`double` IEEE-754 introduz ruido. Comparacoes em teste usam `closeTo`. A apresentacao usa `intl` (`NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')`) que arredonda **so na exibicao** — calculos internos mantem precisao total. Nunca arredondar valores intermediarios antes do resultado final.

---

### 4. Risco: manutencao de pacotes (storage, window_manager, freezed, patrol)

#### Mitigacao 4.1 — Storage: Isar descartado, sembast escolhido (decisao resolvida)

O risco de manutencao do storage foi a divergencia central da pesquisa. **Isar/isar_community foi descartado**: o autor abandonou o projeto original, o fork comunitario depende de **binarios nativos por plataforma** (atrito de build em desktop) e e mantido pela comunidade, nao pelo autor. **Hive CE** seria 2a opcao, mas exige TypeAdapters binarios + `toJson/fromJson` paralelos so para o export.

A decisao e **sembast** (`^3.8.9`): 100% Dart (sem plugin nativo, sem atrito de build em Windows/macOS/Linux), NoSQL de documentos onde cada registro **e** JSON nativo (export = dump trivial, import = `put`). Isso casa exatamente com o requisito "NoSQL em JSON" + "importar/exportar tudo como JSON".

| Criterio | sembast (escolhido) | Hive CE | isar_community |
|---|---|---|---|
| 100% Dart, sem binario nativo | Sim | Sim | Nao (atrito desktop) |
| Armazena como JSON nativo | Sim | Nao (binario) | Nao |
| Export/import JSON | Trivial | Manual | Manual |
| Mantido pelo autor | Sim (tekartik) | Sim (fork ativo) | Nao (fork comunitario) |

#### Mitigacao 4.2 — Repositorios isolam o sembast (troca futura barata)

Decisao global: `LocalDb` singleton + repositorios (`RendaFixaRepo`, `AcoesRepo`, `CacheRepo`, `ConfigRepo`) + `ImportExportService`. O resto do app **nunca** importa `sembast` diretamente. Se o volume crescer (series historicas massivas), migra-se **so** essas series para Drift/SQLite, mantendo sembast para documentos do usuario — alteracao restrita aos repositorios.

```dart
/// Contrato que isola o app do sembast. Qualquer backend (sembast hoje,
/// Drift amanha para series massivas) implementa esta interface.
abstract interface class RendaFixaRepo {
  Future<String> upsert(Map<String, Object?> doc);
  Future<List<Map<String, Object?>>> listar();
  Future<void> remover(String id);
}
```

#### Mitigacao 4.3 — window_manager (0.x) atras de servico

`window_manager ^0.5.0` esta em **0.x** — API pode mudar (breaking changes sem aviso semver forte). Decisao global: isolar atras de um `DesktopWindowService` com no-op em mobile. Trocar o pacote = mexer em um arquivo.

```dart
abstract interface class DesktopWindowService {
  Future<void> init();
}

/// Implementacao desktop; em mobile usar uma NoopWindowService.
class WindowManagerService implements DesktopWindowService {
  @override
  Future<void> init() async {
    // Toda API instavel de window_manager confinada aqui.
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(420, 640));
    await windowManager.setTitle('Investa BR');
    await windowManager.center();
  }
}
```

Selecao da implementacao via Riverpod (DI): `Platform.isAndroid || Platform.isIOS ? NoopWindowService() : WindowManagerService()`.

#### Mitigacao 4.4 — Fixar versoes e commitar artefatos gerados

- **FVM** (`.fvmrc`) fixa Flutter 3.44 / Dart 3.12 para reprodutibilidade dev/CI.
- Versoes fixadas com `^` controlado no `pubspec.yaml`; commitar `pubspec.lock`.
- **freezed evolui rapido** (3.x atual; 4.0-dev ja existe). Revisar breaking changes antes de qualquer upgrade major. `patrol` idem.
- Code-gen unico via `build_runner` (freezed, json_serializable, riverpod_generator, go_router_builder). Decisao global: **commitar `*.g.dart` e `*.freezed.dart`** — evita falha de CI por divergencia de versao do gerador.

#### Mitigacao 4.5 — Testar import/export nas 3 plataformas desktop

`file_picker`, `share_plus` e `path_provider` cobrem todas as plataformas, mas comportamento de file picker/permissoes diverge. Decisao global manda E2E com `patrol` cobrindo import/export em **Windows/macOS/Linux** alem de mobile.

---

### 5. Risco: recomendacoes de analistas (brapi) e degradacao graciosa

Campos `recommendationKey`, `recommendationMean`, `targetMeanPrice`, `numberOfAnalystOpinions` so vem populados no plano **PRO pago**. No free, o endpoint responde **HTTP 200 com os campos `null`** (nao da 401 — pegadinha que engana teste rapido).

#### Mitigacao 5.1 — Nao prometer recomendacao de analista como feature core

Decisao global: no MVP gratuito, **derivar sinais proprios** calculados localmente a partir de fundamentos disponiveis (P/L, P/VP, DY, ROE). A UI degrada graciosamente quando campos vem nulos:

```dart
@freezed
sealed class SinalAcao with _$SinalAcao {
  const factory SinalAcao.analista({
    required String recommendationKey, // so se token PRO popular
    required double targetMeanPrice,
  }) = SinalAnalista;
  const factory SinalAcao.derivado({
    required double score,              // calculado de P/L, DY, ROE
    required String racional,
  }) = SinalDerivado;
  const factory SinalAcao.indisponivel() = SinalIndisponivel;
}

SinalAcao montarSinal(BrapiQuote q) {
  if (q.recommendationKey != null && q.targetMeanPrice != null) {
    return SinalAcao.analista(
      recommendationKey: q.recommendationKey!,
      targetMeanPrice: q.targetMeanPrice!,
    );
  }
  if (q.priceEarnings != null || q.dividendYield != null) {
    return SinalAcao.derivado(score: _scoreLocal(q), racional: _racional(q));
  }
  return const SinalAcao.indisponivel();
}
```

UI faz pattern match exaustivo e **nunca** assume que o campo de analista existe.

---

### 6. Risco: dados defasados / offline / divergencia entre fontes

#### Mitigacao 6.1 — stale-while-revalidate com marcacao visivel

O `cache_indicadores` guarda `dataUltimaAtualizacao` (yyyy-MM-dd, fuso America/Sao_Paulo UTC-3), `fetchedAt` e `stale`. Em falha de rede, serve o ultimo snapshot bom com `stale=true`, e a UI exibe *"Atualizado em DD/MM/YYYY (dados podem estar defasados)"* + botao de refresh manual que forca refetch.

```dart
String hojeSaoPaulo() {
  // America/Sao_Paulo = UTC-3, sem horario de verao desde 2019.
  final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  return now.toIso8601String().substring(0, 10);
}
```

#### Mitigacao 6.2 — Fonte canonica por dado (nunca hardcodar indicador)

Agregadores divergem (ex. CDI 14,40% vs 14,75% no mesmo periodo). Regra: buscar **sempre** o valor oficial do BCB SGS em runtime. BrasilAPI `/taxas/v1` (valores anualizados) e usado **apenas** como atalho headline na home, **nunca** para calculo exato. A Selic pode mudar na proxima reuniao do Copom — reforca a necessidade do fetch dinamico + cache datado.

#### Mitigacao 6.3 — Base de dias configuravel por produto

Assumir 252 para tudo gera erro em titulos que usam ano civil (360/365). `BaseDias` e campo do produto (ver 3.1), com 252 como default.

---

### 7. Risco: integridade e privacidade do import/export

#### Mitigacao 7.1 — Checksum SHA-256 + validacao de schema/app

O arquivo de export inclui `{app, schemaVersion, exportedAt, appVersion, checksum, data}`. No import: valida `app == 'investa_br'`, **bloqueia versao mais nova** que o app, e confere o checksum do bloco `data`. `cache_indicadores` **nao** entra no export (e derivado).

```dart
Future<void> importar({ModoImport modo = ModoImport.replace}) async {
  final map = jsonDecode(content) as Map<String, Object?>;
  if (map['app'] != 'investa_br') throw 'Arquivo nao e backup do Investa BR';
  final fileVersion = (map['schemaVersion'] as num).toInt();
  if (fileVersion > LocalDb.schemaVersion) {
    throw 'Backup de versao mais nova ($fileVersion). Atualize o app.';
  }
  final data = map['data'] as Map<String, Object?>;
  if (map['checksum'] is String) {
    final esperado = (map['checksum'] as String).split(':').last;
    if (sha256Of(jsonEncode(data)) != esperado) throw 'Backup corrompido';
  }
  // Aplica em transacao atomica (REPLACE default; MERGE por id last-write-wins).
}
```

#### Mitigacao 7.2 — REPLACE como default, MERGE por UUID

REPLACE (mais seguro) limpa as stores e regrava. MERGE faz `put` por `id` (UUID estavel) com last-write-wins via `updatedAt`. O default e REPLACE para evitar duplicatas entre dispositivos. `migratePayload` (migracao do arquivo) e **independente** do `onVersionChanged` (migracao do banco em disco), ambos sincronizados pela constante `LocalDb.schemaVersion`.

#### Mitigacao 7.3 — Export em texto claro (privacidade)

Dados financeiros ficam legiveis no JSON exportado. Se surgir requisito de privacidade, oferecer export criptografado por senha (sembast suporta codec/criptografia do banco em disco). Documentado como item futuro.

---

### Tabela consolidada: Risco / Impacto / Mitigacao

| # | Risco | Probabilidade | Impacto | Mitigacao principal |
|---|---|---|---|---|
| 1 | BCB SGS retorna HTML por User-Agent ausente | Media | Alto (indicadores quebram) | UA padrao no interceptor + deteccao de `content-type: text/html` (Mit. 1.2) |
| 2 | API gratuita muda URL/schema/cai | Media | Alto (1) / Medio | DataSource isolado + `endpoints.dart` unico + fallback encadeado + snapshot persistido (Mit. 1.1, 1.3, 1.4) |
| 3 | brapi free estoura 15k req/mes ou 429 | Media | Medio (acoes indisponiveis) | Cache diario + 1 batch/dia + backoff (Mit. 2.1, 2.4) |
| 4 | SGS janela 10 anos / `/ultimos` max 20 | Alta (em historico) | Medio (consulta vazia/400) | Fragmentacao em janelas de 10 anos; `/ultimos/1` nos cards (Mit. 2.3) |
| 5 | ReceitaWS 3 req/min bloqueia | Baixa (so 3o fallback) | Baixo | Cache CNPJ com TTL longo + backoff Retry-After (Mit. 2.5) |
| 6 | Calculo de rentabilidade errado | Media | Critico (engana usuario) | Value object de taxa + base 252 com feriados reais + suite de testes (Mit. 3.1, 3.2, 3.7) |
| 7 | Aproximacao de dias uteis acumula erro | Alta se aproximar | Alto | Contagem real com feriados; proibir `dc * 252/365` (Mit. 3.2) |
| 8 | Regra tributaria muda (lei/MP) | Media | Alto (gross-up errado) | `TaxRuleSet` versionado e datado; aviso CVM datado na UI (Mit. 3.4, 3.5) |
| 9 | Parse SGS (string, virgula, dataFim) | Alta | Alto | Parser defensivo + testes de parsing (Mit. 3.6, 3.7) |
| 10 | Storage abandonado (Isar) / build desktop | — (mitigado por decisao) | Alto | sembast 100% Dart escolhido; repositorios isolam (Mit. 4.1, 4.2) |
| 11 | window_manager 0.x quebra API | Media | Baixo (so desktop) | `DesktopWindowService` isola o pacote (Mit. 4.3) |
| 12 | freezed/patrol breaking change em upgrade | Media | Medio (build CI) | FVM + pubspec.lock + commitar gerados + revisar changelog (Mit. 4.4) |
| 13 | Recomendacao de analista null no free | Alta (certo no free) | Baixo (feature opcional) | Sinais derivados locais + UI degrada graciosamente (Mit. 5.1) |
| 14 | Dados defasados / offline | Alta (esperado) | Medio | stale-while-revalidate + marcacao + refresh manual (Mit. 6.1) |
| 15 | Divergencia entre agregadores | Media | Medio | BCB SGS como fonte canonica; nunca hardcodar (Mit. 6.2) |
| 16 | Import corrompido / versao incompativel | Baixa | Alto (corrompe dados) | Checksum SHA-256 + validacao schema/app + transacao atomica (Mit. 7.1, 7.2) |
| 17 | Tesouro: datastore 400 / endpoint legado 410 | Alta (se usar errado) | Medio | So CSV + cache diario; documentar no codigo (Mit. 1.5) |
| 18 | Export em texto claro (privacidade) | Baixa | Medio | Export criptografado por senha (item futuro) (Mit. 7.3) |

---

### Principios transversais de mitigacao (resumo para o implementador)

1. **Toda fonte externa tem cache local persistido** — falha de rede nunca crasha o boot.
2. **Toda chamada externa retorna `Result<T>`** com `Failure` tipado (sealed) — pattern matching exaustivo na UI.
3. **Dependencia instavel = um arquivo de isolamento** (`endpoints.dart`, `DesktopWindowService`, repositorios) — troca futura barata.
4. **Calculo financeiro = value object + base 252 com feriados reais + suite de regressao** — nunca `double` solto, nunca aproximacao de dias uteis.
5. **Regra tributaria = config datada e versionada** — ponto mais sujeito a mudanca legislativa.
6. **Degradacao graciosa sempre** — campos opcionais (recomendacao de analista) nunca assumidos presentes; dados defasados marcados `stale=true`.
7. **Versoes fixadas (FVM + lock) e artefatos gerados commitados** — reprodutibilidade dev/CI.

---

## Apendices

Material de referencia para a implementacao. Os payloads abaixo foram **verificados por fetch real em 17/06/2026**; os valores numericos servem apenas para validar o parsing — em runtime, **sempre buscar da fonte**.

---

### Apendice A — Codigos de serie do BCB SGS (referencia)

Endpoint: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados?formato=json`. Cards da Home usam `/ultimos/1` (nao sofre o limite de 10 anos). Series **226** (TR) e **195** (poupanca) trazem o campo extra `dataFim`.

| Codigo | Serie | Unidade | Boot? | Observacao |
|--------|-------|---------|:----:|------------|
| 432 | SELIC meta (Copom) | % a.a. | sim | gross-up / card "Selic" |
| 11 | SELIC diaria (efetiva) | % ao dia (252) | sim | motor financeiro |
| 12 | CDI / taxa DI diaria | % ao dia (252) | sim | pos-fixados %CDI |
| 433 | IPCA — variacao mensal | % no mes | sim | hibridos IPCA+ |
| 189 | IGP-M — variacao mensal | % no mes | sim | indexador / card |
| 226 | TR — Taxa Referencial | % no periodo | sim | traz `dataFim` |
| 195 | Poupanca — rendimento | % no periodo | sim | traz `dataFim` |
| 1178 | SELIC anualizada base 252 | % a.a. | nao | Selic diaria anualizada |
| 4389 | CDI anualizado base 252 | % a.a. | nao | headline CDI a.a. |
| 4390 | SELIC acumulada no mes | % | nao | auxiliar |
| 13522 | IPCA acumulado 12 meses | % | nao | card "IPCA 12m" |
| 188 | IGP-DI (alternativa) | % no mes | nao | opcional |

> **Pegadinhas confirmadas:** `valor` vem como **string** (`"14.50"`); datas em `dd/MM/yyyy`; erro pode chegar como **HTML** (`Content-Type: text/html`) — detectar e mapear para `Failure.parse`; **User-Agent obrigatorio** (sem ele a serie 12 retornou HTML); janela de periodo limitada a **10 anos** por requisicao (desde 26/03/2025) — fragmentar series longas; manter **<=5 requisicoes paralelas**.

---

### Apendice B — Exemplos de payload das APIs (verificados em 17/06/2026)

**B.1 — BCB SGS (SELIC meta, CDI diario, TR):**
```jsonc
// GET .../bcdata.sgs.432/dados/ultimos/1?formato=json   (SELIC meta)
[{ "data": "17/06/2026", "valor": "14.50" }]

// GET .../bcdata.sgs.12/dados/ultimos/1?formato=json     (CDI diario, % a.d.)
[{ "data": "16/06/2026", "valor": "0.053400" }]

// GET .../bcdata.sgs.226/dados/ultimos/1?formato=json    (TR — inclui dataFim)
[{ "data": "16/06/2026", "dataFim": "16/07/2026", "valor": "0.1720" }]

// GET .../bcdata.sgs.195/dados/ultimos/1?formato=json    (Poupanca — inclui dataFim)
[{ "data": "16/06/2026", "dataFim": "16/07/2026", "valor": "0.6729" }]
```

**B.2 — brapi.dev (cotacao):**
```jsonc
// GET https://brapi.dev/api/quote/PETR4   (Authorization: Bearer <token gratuito>)
{
  "results": [{
    "symbol": "PETR4",
    "shortName": "PETROBRAS PN",
    "regularMarketPrice": 38.54,
    "regularMarketChangePercent": -0.41,
    "regularMarketTime": "2026-06-17T...",
    "marketCap": 5.0e11,
    "priceEarnings": 7.1,
    "logourl": "https://.../petr4.png"
  }],
  "requestedAt": "2026-06-17T...",
  "took": "..."
}
// Sem token: somente PETR4, MGLU3, VALE3, ITUB4. Outros tickers -> HTTP 401.
// Modulos financialData (recommendationKey/targetMeanPrice) so vem populados no plano PRO.
```

**B.3 — BrasilAPI (CNPJ / taxas / feriados / PTAX):**
```jsonc
// GET https://brasilapi.com.br/api/cnpj/v1/00000000000191
{ "cnpj": "00000000000191", "razao_social": "BANCO DO BRASIL SA",
  "nome_fantasia": "...", "situacao_cadastral": "ATIVA", "uf": "DF",
  "cnae_fiscal": 6422100, "cnae_fiscal_descricao": "...",
  "capital_social": 90000000000, "qsa": [ /* socios */ ] }

// GET https://brasilapi.com.br/api/taxas/v1
[ { "nome": "Selic", "valor": 14.5 }, { "nome": "CDI", "valor": 14.4 },
  { "nome": "IPCA", "valor": 4.72 } ]

// GET https://brasilapi.com.br/api/feriados/v1/2026   (apenas feriados NACIONAIS)
[ { "date": "2026-01-01", "name": "Confraternizacao mundial", "type": "national" }, ... ]
```
> Para **dias uteis de renda fixa**, validar contra o calendario **ANBIMA/B3** (pode divergir dos feriados nacionais). O endpoint `/cnpj` e o mais sujeito a throttling.

**B.4 — OpenCNPJ (fallback de alto volume):**
```jsonc
// GET https://api.opencnpj.org/{cnpj}   (sem auth; 50 req/s por IP; cache Cloudflare)
{ "razao_social": "...", "situacao_cadastral": "...",
  "logradouro": "...", "numero": "...", "bairro": "...", "cep": "...", "uf": "...", "municipio": "...",
  "cnaes": [ { "codigo": "...", "descricao": "...", "is_principal": true } ],
  "QSA": [ { "nome_socio": "...", "cnpj_cpf_socio": "***354400**", "qualificacao_socio": "..." } ],
  "capital_social": "...", "porte_empresa": "...", "telefones": [ { "ddd": "...", "numero": "..." } ] }
```
> Endereco e **plano** (sem objeto aninhado); array de socios chama-se **`QSA`** (nao `socios`).

**B.5 — ReceitaWS (fallback pontual, 3 req/min):**
```jsonc
// GET https://receitaws.com.br/v1/cnpj/{cnpj}
{ "nome": "...", "fantasia": "...", "situacao": "ATIVA",
  "abertura": "01/09/2004",                       // dd/MM/yyyy
  "ultima_atualizacao": "2026-06-15T23:59:59.000Z", // ISO 8601 (atencao: difere do resto!)
  "atividade_principal": [ {"code":"...","text":"..."} ],
  "qsa": [ ... ], "billing": { "free": true, "database": true } }
```

**B.6 — AwesomeAPI Economia (cambio, secundario):**
```jsonc
// GET https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL
{ "USDBRL": { "code":"USD","codein":"BRL","bid":"5.0774","ask":"5.0780",
              "pctChange":"...","create_date":"2026-06-17 09:55:00" }, "EURBRL": { ... } }
```

**B.7 — BCB Olinda / Focus (projecoes, opcional):**
```jsonc
// GET https://olinda.bcb.gov.br/olinda/servico/Expectativas/versao/v1/odata/
//     ExpectativasMercadoAnuais?$filter=Indicador eq 'IPCA' and DataReferencia eq '2026'&$top=1&$format=json
{ "value": [ { "Indicador":"IPCA","DataReferencia":"2026","Data":"2026-06-12",
               "Media":4.5,"Mediana":4.48,"numeroRespondentes":120 } ] }
```
> Inconsistencia oficial de plural: mensal = `ExpectativaMercadoMensais` (SINGULAR), anual = `ExpectativasMercadoAnuais`, Selic = `ExpectativasMercadoSelic` (usa campo `Reuniao`, ex. `R3/2028`). OData pagina com `$top`/`$skip` (max 1000/chamada).

**B.8 — Tesouro Transparente (CSV, sob demanda):**
```
URL: https://www.tesourotransparente.gov.br/ckan/dataset/df56aa42-484a-4a59-8184-7676580c81e3/
     resource/796d2059-14e9-44e3-80c9-2d9e30b405c1/download/precotaxatesourodireto.csv
Formato CSV (delimitador ';', decimais com virgula, datas dd/mm/aaaa, ~13,5 MiB):
Tipo Titulo;Data Vencimento;Data Base;Taxa Compra Manha;Taxa Venda Manha;PU Compra Manha;PU Venda Manha;PU Base Manha
Tesouro IPCA+;15/05/2035;16/06/2026;7,12;7,18;...;...;...
```
> **Nao** existe `datastore_search` neste portal (HTTP 400) — apenas o CSV. Nomes vem por extenso (`Tesouro Prefixado`, `Tesouro Selic`, `Tesouro IPCA+`), nao siglas (LTN/LFT/NTN-B). Baixar 1x/dia e filtrar localmente.

---

### Apendice C — Arquivo de export/import (referencia rapida)

O **schema normativo** do backup esta na secao *Persistencia Local NoSQL/JSON & Import/Export* (cabecalho `app`/`schemaVersion`/`exportedAt`/`appVersion`/`checksum` + bloco `data` com `investimentos_rf[]`, `posicoes_acoes[]`, `configuracoes`). Pontos-chave para revisao:

- Arquivo **JSON unico**; `cache_indicadores` **nao** entra (derivado).
- `checksum` = `sha256:<hex>` do bloco `data` serializado de forma **canonica** (chaves ordenadas), reproduzivel no import.
- `schemaVersion > atual` -> **import recusado**; `<= atual` -> migrado por `migratePayload`.
- `app` diferente de `"investa_br"` -> rejeita.
- `ModoImport`: `replace` (substitui tudo) ou `merge` (last-write-wins por `updatedAt`).

---

### Apendice D — Glossario de renda fixa

| Termo | Significado |
|-------|-------------|
| **SELIC** | Taxa basica de juros da economia (meta definida pelo Copom). Referencia dos pos-fixados em SELIC. |
| **CDI** | Taxa media dos depositos interbancarios; anda colado a SELIC. Indexador mais comum (`% do CDI`). |
| **IPCA** | Indice oficial de inflacao (IBGE). Base dos hibridos `IPCA+`. |
| **IGP-M** | Indice Geral de Precos do Mercado (FGV); usado em alguns titulos e alugueis. |
| **TR** | Taxa Referencial; compoe o rendimento da poupanca e de alguns titulos. |
| **Prefixado** | Taxa fixa conhecida na contratacao (ex.: 13% a.a.). |
| **Pos-fixado** | Rende um % de um indexador (ex.: 110% do CDI, 100% da SELIC). |
| **Hibrido (IPCA+ / IGPM+)** | Parte fixa + indexador (ex.: IPCA + 6% a.a.). Protege da inflacao. |
| **Base 252** | Capitalizacao por **dias uteis** (padrao do CDI/SELIC), vs base 360/365 (dias corridos). |
| **CDB** | Certificado de Deposito Bancario; tributado por IR; coberto pelo FGC. |
| **LCI / LCA** | Letras de Credito Imobiliario/Agronegocio; **isentas de IR** para PF; cobertas pelo FGC. |
| **LC / LF** | Letra de Cambio / Letra Financeira. |
| **CRI / CRA** | Certificados de Recebiveis Imobiliarios/Agro; isentos de IR para PF; **sem FGC**. |
| **Debenture** | Divida de empresa; tributada. **Incentivada** = isenta de IR para PF. |
| **Tesouro Selic / Prefixado / IPCA+** | Titulos publicos (Tesouro Direto); tributados; com liquidez diaria. |
| **IR regressivo** | Aliquota cai com o prazo: 22,5% (ate 180d), 20% (181-360d), 17,5% (361-720d), 15% (>720d). |
| **IOF** | Cobrado so nos primeiros 30 dias (tabela regressiva), sobre o rendimento. |
| **FGC** | Fundo Garantidor de Creditos: garante ate R$ 250 mil por CPF/instituicao (limite global R$ 1 mi/4 anos). |
| **Marcacao a mercado** | Variacao do preco do titulo prefixado/IPCA+ antes do vencimento conforme os juros. |
| **Taxa bruta equivalente** | Taxa que um produto **tributado** precisaria render para igualar um **isento** apos IR. |
| **Liquidez / Carencia** | Quando e possivel resgatar (diaria, no vencimento) / prazo minimo sem resgate. |

---

### Apendice E — Fontes e referencias

**APIs de dados (verificadas):**
- BCB SGS — `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados` (docs: dadosabertos.bcb.gov.br)
- BCB Olinda / Expectativas (Focus) — `https://olinda.bcb.gov.br/olinda/servico/Expectativas/versao/v1/odata`
- Tesouro Transparente (CKAN) — `https://www.tesourotransparente.gov.br/ckan`
- brapi.dev — `https://brapi.dev/api` (docs e pricing em brapi.dev/docs, brapi.dev/pricing)
- BrasilAPI — `https://brasilapi.com.br/docs`
- OpenCNPJ — `https://api.opencnpj.org` (repo: github.com/Hitmasu/opencnpj)
- ReceitaWS — `https://receitaws.com.br`
- AwesomeAPI Economia — `https://docs.awesomeapi.com.br`

**Stack e bibliotecas:**
- Flutter — `https://docs.flutter.dev` · Dart — `https://dart.dev`
- Riverpod — `https://riverpod.dev` · go_router — `pub.dev/packages/go_router`
- freezed — `pub.dev/packages/freezed` · sembast — `pub.dev/packages/sembast`
- dio — `pub.dev/packages/dio` · fl_chart — `pub.dev/packages/fl_chart`
- dynamic_color — `pub.dev/packages/dynamic_color` · Material 3 — `https://m3.material.io`

**Regras de renda fixa / tributacao:**
- Tesouro Direto — `https://www.tesourodireto.com.br`
- FGC — `https://www.fgc.org.br`
- Receita Federal (IR sobre aplicacoes) — `https://www.gov.br/receitafederal`
- ANBIMA (calendario/feriados de mercado) — `https://www.anbima.com.br`

> Datas de verificacao das APIs: **17/06/2026**. Revalidar endpoints e limites periodicamente — APIs gratuitas/comunitarias podem mudar sem aviso (ver secao *Riscos & Mitigacoes*).

