import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../common/providers/core_providers.dart';
import '../../../common/utils/formatters.dart';
import '../../acoes/application/acoes_list_provider.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../../renda_fixa/application/renda_fixa_list_provider.dart';
import '../application/config_providers.dart';
import '../data/import_export/backup_validation.dart';
import '../data/import_export/import_export_service.dart';
import '../data/import_export/import_modo.dart';
import '../domain/configuracao_tema.dart';

/// Cores-semente predefinidas (ARGB).
const _seeds = <int>[
  0xFF1565C0, // azul (padrão)
  0xFF2E7D32, // verde
  0xFF6A1B9A, // roxo
  0xFFEF6C00, // laranja
  0xFF00838F, // teal
  0xFFC62828, // vermelho
];

/// Ajustes: Aparência (tema), Dados (token brapi, import/export, cache) e Sobre.
class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() =>
      _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  final _tokenController = TextEditingController();
  ModoImport _modo = ModoImport.replace;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(configProvider).valueOrNull ??
        ConfiguracaoTema(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));
    final notifier = ref.read(configProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Aparência', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
            ],
            selected: {cfg.themeMode},
            onSelectionChanged: (s) => notifier.setThemeMode(s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar cor do sistema (Material You)'),
            subtitle: const Text('Quando disponível no aparelho.'),
            value: cfg.useDynamic,
            onChanged: (v) => notifier.setUseDynamic(usar: v),
          ),
          const SizedBox(height: 8),
          Text('Cor-semente', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final argb in _seeds)
                _Swatch(
                  cor: Color(argb),
                  selecionada: cfg.seedArgb == argb && !cfg.useDynamic,
                  onTap: () => notifier.setSeed(argb),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Dados', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            cfg.brapiToken == null
                ? 'Token brapi não configurado. Sem token, só estes tickers: '
                    'PETR4/VALE3/MGLU3/ITUB4.'
                : 'Token brapi configurado.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Token brapi',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  notifier.setBrapiToken(_tokenController.text);
                  _tokenController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token salvo.')),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<ModoImport>(
            segments: const [
              ButtonSegment(value: ModoImport.replace, label: Text('Substituir')),
              ButtonSegment(value: ModoImport.merge, label: Text('Mesclar')),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportar,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Exportar'),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importar,
                  icon: const Icon(Icons.download),
                  label: const Text('Importar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatusCache(),
          const Divider(height: 32),
          Text('Sobre', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Investa BR v1.0.0 · Dados informativos, não constituem '
            'recomendação de investimento (CVM).',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _exportar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      final dir = await getApplicationDocumentsDirectory();
      final file = await ImportExportService(db).escreverBackup(dir.path);
      await Share.shareXFiles([XFile(file.path)], subject: 'Backup Investa BR');
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao exportar: $e')),
      );
    }
  }

  Future<void> _importar() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    try {
      final res =
          await ImportExportService(ref.read(databaseProvider)).importarDeArquivo(path, modo: _modo);
      ref
        ..invalidate(rendaFixaListProvider)
        ..invalidate(acoesListProvider)
        ..invalidate(configProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Importado: ${res.inseridos} novos, ${res.atualizados} '
            'atualizados, ${res.ignorados} ignorados.',
          ),
        ),
      );
    } on BackupError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.cor,
    required this.selecionada,
    required this.onTap,
  });

  final Color cor;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionada,
      label: 'Cor-semente',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: selecionada ? 3 : 1,
            ),
          ),
          child: selecionada
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _StatusCache extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(indicadoresProvider).valueOrNull;
    final texto = snap == null
        ? 'Indicadores ainda não carregados.'
        : 'Última atualização: ${Formatters.dataHora(snap.fetchedAt)}';
    return Row(
      children: [
        Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
        IconButton(
          tooltip: 'Atualizar indicadores',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(indicadoresProvider.notifier).atualizar(),
        ),
      ],
    );
  }
}
