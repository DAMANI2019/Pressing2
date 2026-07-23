import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/facture_pdf_service.dart';
import '../../services/prestations_service.dart';
import '../../utils/format.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}
class _OperationsScreenState extends State<OperationsScreen> {
  late final PrestationsService _service;
  final _pdf = FacturePdfService();
  FiltrePeriode _filtre = FiltrePeriode.aujourdhui;
  List<Prestation> _items = [];
  bool _chargement = true;
  @override
  void initState() { super.initState(); _service = PrestationsService(Supabase.instance.client); WidgetsBinding.instance.addPostFrameCallback((_) => _charger()); }
  Future<void> _charger() async {
    final id = context.read<AuthProvider>().profil?.pressingId; if (id == null) return;
    setState(() => _chargement = true);
    try { final items = await _service.lister(pressingId: id, intervalle: calculerIntervalle(_filtre)); if (mounted) setState(() { _items = items; _chargement = false; }); }
    catch (e) { if (mounted) setState(() => _chargement = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _pdfPrestation(Prestation p, {bool imprimer = false}) async {
    final pressing = context.read<AuthProvider>().pressing; if (pressing == null) return;
    try { final data = await _pdf.buildPdf(pressing: pressing, prestation: p, articles: p.articles); if (imprimer) await _pdf.printPdf(data); else await _pdf.sharePdf(data, p.numeroTicket); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF : $e'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Opérations'), actions: [
    if (context.watch<AuthProvider>().profil?.role == RoleUtilisateur.employe)
      IconButton(onPressed: () => context.go('/employe'), icon: const Icon(Icons.add)),
    IconButton(onPressed: _charger, icon: const Icon(Icons.refresh)),
  ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<FiltrePeriode>(segments: const [
        ButtonSegment(value: FiltrePeriode.aujourdhui, label: Text('Jour')), ButtonSegment(value: FiltrePeriode.semaine, label: Text('Semaine')), ButtonSegment(value: FiltrePeriode.mois, label: Text('Mois')),
      ], selected: {_filtre}, onSelectionChanged: (v) { setState(() => _filtre = v.first); _charger(); })),
      Expanded(child: _chargement ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? const Center(child: Text('Aucune prestation.')) : ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: _items.length, itemBuilder: (_, i) { final p = _items[i]; return Card(child: ListTile(
          title: Text('${p.numeroTicket} — ${p.clientNom}'), subtitle: Text('${formaterMontant(p.montantTotal)} · ${p.statut.name}'),
          isThreeLine: true, trailing: Wrap(spacing: 0, children: [
            IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => _pdfPrestation(p)),
            if (p.statut != StatutPrestation.livre) IconButton(icon: const Icon(Icons.local_shipping_outlined), tooltip: 'Marquer livré', onPressed: () async { await _service.marquerLivre(p.id); _charger(); }),
          ]),
        )); },
      )),
    ]),
  );
}
