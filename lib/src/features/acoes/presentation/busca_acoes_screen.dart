import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/result/failure.dart';
import '../../../common/widgets/empty_state.dart';
import '../application/cotacao_providers.dart';

/// Busca de ações por ticker (brapi `/available`). Tap em um resultado abre o
/// detalhe. Sem token, a busca pode falhar/limitar — a mensagem orienta o
/// usuário a configurar o token em Ajustes (F8).
class BuscaAcoesScreen extends ConsumerStatefulWidget {
  const BuscaAcoesScreen({super.key});

  @override
  ConsumerState<BuscaAcoesScreen> createState() => _BuscaAcoesScreenState();
}

class _BuscaAcoesScreenState extends ConsumerState<BuscaAcoesScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _termo = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _termo = valor.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ações')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Buscar ticker (ex.: PETR4)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _resultados(context)),
        ],
      ),
    );
  }

  Widget _resultados(BuildContext context) {
    if (_termo.length < 2) {
      return const EmptyState(
        icone: Icons.search,
        titulo: 'Buscar ações da B3',
        descricao: 'Digite ao menos 2 letras do ticker.',
      );
    }
    final busca = ref.watch(buscaAcoesProvider(_termo));
    return busca.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icone: Icons.error_outline,
        titulo: 'Não foi possível buscar',
        descricao: e is Failure ? e.message : 'Tente novamente.',
      ),
      data: (tickers) {
        if (tickers.isEmpty) {
          return const EmptyState(
            icone: Icons.search_off,
            titulo: 'Nada encontrado',
            descricao: 'Nenhum ticker corresponde à busca.',
          );
        }
        return ListView.builder(
          itemCount: tickers.length,
          itemBuilder: (context, i) => ListTile(
            leading: const Icon(Icons.show_chart),
            title: Text(tickers[i]),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/acoes/${tickers[i]}'),
          ),
        );
      },
    );
  }
}
