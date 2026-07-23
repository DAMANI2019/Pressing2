import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/prestations_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/format.dart';

class NouvellePrestationScreen extends StatefulWidget {
  const NouvellePrestationScreen({super.key});

  @override
  State<NouvellePrestationScreen> createState() => _NouvellePrestationScreenState();
}

class _NouvellePrestationScreenState extends State<NouvellePrestationScreen> {
  final _clientNom = TextEditingController();
  final _clientTel = TextEditingController();
  final _notes = TextEditingController();
  final _articles = <ArticleDraft>[];
  bool _envoi = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _clientNom.dispose();
    _clientTel.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _total => _articles.fold(
        0,
        (s, a) => s + a.prixUnitaire * a.quantite,
      );

  Future<void> _ajouterArticle() async {
    String type = designationsHabits.first.libelle;
    final prixCtrl = TextEditingController(
      text: designationsHabits.first.prixDefaut.toString(),
    );
    final qteCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    final defautsCtrl = TextEditingController();
    final photos = <Uint8List>[];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nouvel article',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items: designationsHabits
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.libelle,
                              child: Text(d.libelle),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        type = v;
                        final def = designationsHabits.firstWhere((d) => d.libelle == v);
                        prixCtrl.text = def.prixDefaut.toString();
                        setModal(() {});
                      },
                      decoration: const InputDecoration(labelText: 'Type d’habit'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prix unitaire (FCFA)'),
                    ),
                    TextField(
                      controller: qteCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantité'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    TextField(
                      controller: defautsCtrl,
                      decoration: const InputDecoration(labelText: 'Défauts'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final p in photos)
                          Image.memory(p, width: 64, height: 64, fit: BoxFit.cover),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final x = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 70,
                              maxWidth: 1280,
                            );
                            if (x == null) return;
                            photos.add(await x.readAsBytes());
                            setModal(() {});
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Photo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      setState(() {
        _articles.add(
          ArticleDraft(
            typeHabit: type,
            prixUnitaire: double.tryParse(prixCtrl.text) ?? 0,
            quantite: int.tryParse(qteCtrl.text) ?? 1,
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            defauts: defautsCtrl.text.trim().isEmpty ? null : defautsCtrl.text.trim(),
            photos: List.from(photos),
          ),
        );
      });
    }

    prixCtrl.dispose();
    qteCtrl.dispose();
    descCtrl.dispose();
    defautsCtrl.dispose();
  }

  Future<void> _enregistrer() async {
    final auth = context.read<AuthProvider>();
    final pressingId = auth.profil?.pressingId;
    final employeId = auth.profil?.id;
    if (pressingId == null || employeId == null) return;

    if (_clientNom.text.trim().isEmpty || _clientTel.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et téléphone client requis.')),
      );
      return;
    }
    if (_articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article.')),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      final service = PrestationsService(Supabase.instance.client);
      final prestation = await service.creerPrestationAvecPhotos(
        pressingId: pressingId,
        employeId: employeId,
        clientNom: _clientNom.text.trim(),
        clientTelephone: _clientTel.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        articles: _articles,
      );

      final articles = await service.listerArticles(prestation.id);
      final message = formaterMessageFacture(
        nomPressing: auth.pressing?.nom ?? 'Pressing',
        prestation: prestation,
        articles: articles,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prestation ${prestation.numeroTicket} créée.')),
      );

      await ouvrirConversationWhatsApp(prestation.clientTelephone, message);

      setState(() {
        _clientNom.clear();
        _clientTel.clear();
        _notes.clear();
        _articles.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle prestation'),
        actions: [
          IconButton(
            onPressed: () => auth.seDeconnecter(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            auth.pressing?.nom ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientNom,
            decoration: const InputDecoration(labelText: 'Nom du client'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientTel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone WhatsApp'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _ajouterArticle,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (_articles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Aucun article pour le moment.', textAlign: TextAlign.center),
            )
          else
            ..._articles.asMap().entries.map((e) {
              final a = e.value;
              return Card(
                child: ListTile(
                  title: Text('${a.typeHabit} × ${a.quantite}'),
                  subtitle: Text(
                    '${formaterMontant(a.prixUnitaire * a.quantite)}'
                    '${a.photos.isEmpty ? '' : ' · ${a.photos.length} photo(s)'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _articles.removeAt(e.key)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(
            'Total : ${formaterMontant(_total)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _envoi ? null : _enregistrer,
            icon: _envoi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text(_envoi ? 'Enregistrement…' : 'Enregistrer et WhatsApp'),
          ),
        ],
      ),
    );
  }
}
