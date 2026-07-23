import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/dashboard_service.dart';
import '../../services/facture_pdf_service.dart';
import '../../utils/format.dart';

class PatronDashboardScreen extends StatefulWidget {
  const PatronDashboardScreen({super.key});

  @override
  State<PatronDashboardScreen> createState() => _PatronDashboardScreenState();
}

class _PatronDashboardScreenState extends State<PatronDashboardScreen> {
  FiltrePeriode _filtre = FiltrePeriode.aujourdhui;
  DonneesDashboard? _donnees;
  String? _erreur;
  bool _chargement = true;
  late final DashboardService _service;

  @override
  void initState() {
    super.initState();
    _service = DashboardService(Supabase.instance.client);
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final pressingId = context.read<AuthProvider>().profil?.pressingId;
    if (pressingId == null) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final data = await _service.charger(
        pressingId: pressingId,
        intervalle: calculerIntervalle(_filtre),
      );
      if (!mounted) return;
      setState(() {
        _donnees = data;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  Future<void> _avancerStatut(String id, statut) async {
    final suivant = _service.prochainStatut(statut);
    if (suivant == null) return;
    try {
      await _service.mettreAJourStatut(prestationId: id, nouveauStatut: suivant);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _partagerPdf(p) async {
    final pressing = context.read<AuthProvider>().pressing;
    if (pressing == null) return;
    final bytes = await FacturePdfService().buildPdf(
      pressing: pressing, prestation: p, articles: p.articles,
    );
    await FacturePdfService().sharePdf(bytes, p.numeroTicket);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ind = _donnees?.indicateurs;

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.pressing?.nom ?? 'Tableau de bord'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (route) => context.go(route),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '/patron/utilisateurs', child: Text('Utilisateurs')),
              PopupMenuItem(value: '/patron/catalogue', child: Text('Catalogue')),
              PopupMenuItem(value: '/patron/facture', child: Text('Factures')),
              PopupMenuItem(value: '/patron/operations', child: Text('Opérations')),
            ],
          ),
          IconButton(onPressed: _charger, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => auth.seDeconnecter(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<FiltrePeriode>(
              segments: const [
                ButtonSegment(value: FiltrePeriode.aujourdhui, label: Text('Aujourd’hui')),
                ButtonSegment(value: FiltrePeriode.semaine, label: Text('Semaine')),
                ButtonSegment(value: FiltrePeriode.mois, label: Text('Mois')),
              ],
              selected: {_filtre},
              onSelectionChanged: (s) {
                setState(() => _filtre = s.first);
                _charger();
              },
            ),
          ),
          if (ind != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Kpi(label: 'CA', value: formaterMontant(ind.chiffreAffaires)),
                  _Kpi(label: 'Prestations', value: '${ind.nombrePrestations}'),
                  _Kpi(label: 'Articles', value: '${ind.nombreArticles}'),
                  _Kpi(label: 'Panier moyen', value: formaterMontant(ind.panierMoyen)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (_chargement)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_erreur != null)
            Expanded(child: Center(child: Text(_erreur!)))
          else if ((_donnees?.prestations.isEmpty ?? true))
            const Expanded(child: Center(child: Text('Aucune prestation sur cette période.')))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _donnees!.prestations.length,
                itemBuilder: (context, i) {
                  final p = _donnees!.prestations[i];
                  final suivant = _service.prochainStatut(p.statut);
                  return Card(
                    child: ListTile(
                      title: Text('${p.numeroTicket} — ${p.clientNom}'),
                      subtitle: Text(
                        '${_service.libelleStatut(p.statut)} · ${formaterMontant(p.montantTotal)}\n'
                        '${formaterDateCourt(p.dateDepot)}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            onPressed: () => _partagerPdf(p),
                          ),
                          if (suivant != null)
                            TextButton(
                              onPressed: () => _avancerStatut(p.id, p.statut),
                              child: Text('→ ${_service.libelleStatut(suivant)}'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
