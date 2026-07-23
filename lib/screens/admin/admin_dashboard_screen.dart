import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_pressings_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/format.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminPressingsService _service;
  List<Pressing> _pressings = [];
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _service = AdminPressingsService(Supabase.instance.client);
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final list = await _service.lister();
      if (!mounted) return;
      setState(() {
        _pressings = list;
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

  Future<void> _creerPressing() async {
    final nom = TextEditingController();
    final gerant = TextEditingController();
    final tel = TextEditingController();
    var duree = 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Nouveau pressing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: gerant, decoration: const InputDecoration(labelText: 'Gérant')),
                TextField(
                  controller: tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: duree,
                  items: dureesAbonnement
                      .map((d) => DropdownMenuItem(value: d.mois, child: Text(d.libelle)))
                      .toList(),
                  onChanged: (v) => setDialog(() => duree = v ?? 1),
                  decoration: const InputDecoration(labelText: 'Durée'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      final result = await _service.creer(
        nom: nom.text,
        gerantNom: gerant.text,
        gerantTelephone: tel.text,
        dureeMois: duree,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pressing créé'),
          content: Text('PIN : ${result.codePin}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (tel.text.trim().isNotEmpty) {
                  ouvrirConversationWhatsApp(
                    tel.text,
                    'Bienvenue chez Pressing ! Votre établissement ${result.pressing.nom} '
                    'est actif jusqu’au ${result.pressing.dateExpiration}. PIN : ${result.codePin}',
                  );
                }
              },
              child: const Text('WhatsApp + OK'),
            ),
          ],
        ),
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      nom.dispose();
      gerant.dispose();
      tel.dispose();
    }
  }

  Future<void> _supprimerPressing(Pressing pressing) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce pressing ?'),
        content: Text('« ${pressing.nom} » et ses données associées seront supprimés si les contraintes de la base le permettent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _service.supprimer(pressing.id);
      await _charger();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ind = _service.calculerIndicateurs(_pressings, prixAbonnementMensuelFcfa);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(onPressed: _charger, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => auth.seDeconnecter(), icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creerPressing,
        icon: const Icon(Icons.add),
        label: const Text('Pressing'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(child: Text(_erreur!))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AdminKpi('Total', '${ind.totalPressings}'),
                        _AdminKpi('Actifs', '${ind.actifs}'),
                        _AdminKpi('Expirés / suspendus', '${ind.expiresOuSuspendus}'),
                        _AdminKpi('CA récurrent', formaterMontant(ind.caRecurrentEstime)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._pressings.map((p) {
                      final statut = _service.statutAffiche(p);
                      return Card(
                        child: ListTile(
                          title: Text(p.nom),
                          subtitle: Text(
                            '${statutAbonnementToDb(statut)} · expire ${p.dateExpiration}\n'
                            '${p.telephone ?? ''} · ${joursRestants(p.dateExpiration)} j',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              try {
                                if (v == '1' || v == '3' || v == '6' || v == '12') {
                                  await _service.prolonger(
                                    pressingId: p.id,
                                    dateExpirationActuelle: p.dateExpiration,
                                    mois: int.parse(v),
                                  );
                                } else if (v == 'suspendre') {
                                  await _service.changerStatut(
                                    pressingId: p.id,
                                    statut: StatutAbonnement.suspendu,
                                  );
                                } else if (v == 'activer') {
                                  await _service.changerStatut(
                                    pressingId: p.id,
                                    statut: StatutAbonnement.actif,
                                  );
                                } else if (v == 'whatsapp' && p.telephone != null) {
                                  await ouvrirConversationWhatsApp(
                                    p.telephone!,
                                    'Bonjour, message concernant votre pressing ${p.nom}.',
                                  );
                                  return;
                                } else if (v == 'supprimer') {
                                  await _supprimerPressing(p);
                                  return;
                                }
                                await _charger();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('$e')));
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: '1', child: Text('Prolonger 1 mois')),
                              PopupMenuItem(value: '3', child: Text('Prolonger 3 mois')),
                              PopupMenuItem(value: '6', child: Text('Prolonger 6 mois')),
                              PopupMenuItem(value: '12', child: Text('Prolonger 1 an')),
                              PopupMenuItem(value: 'suspendre', child: Text('Suspendre')),
                              PopupMenuItem(value: 'activer', child: Text('Réactiver')),
                              PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                              PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

class _AdminKpi extends StatelessWidget {
  const _AdminKpi(this.label, this.value);
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
