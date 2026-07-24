import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/catalogue_service.dart';
import '../../services/facture_pdf_service.dart';
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
  final _catalogue = <CatalogueItem>[];
  bool _catalogueCharge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCatalogue());
  }

  Future<void> _chargerCatalogue() async {
    final pressingId = context.read<AuthProvider>().profil?.pressingId;
    if (pressingId == null) return;
    try {
      final items = await CatalogueService(Supabase.instance.client)
          .lister(pressingId, actifsSeulement: true);
      if (mounted) setState(() {
        _catalogue..clear()..addAll(items);
        _catalogueCharge = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Catalogue : $e')));
    }
  }

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
    if (_catalogue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le catalogue est vide. Demandez au patron d’ajouter des travaux.')),
      );
      return;
    }

    final habitCtrl = TextEditingController(text: 'Chemise');
    final autreTravailCtrl = TextEditingController();
    CatalogueItem? travailChoisi = _catalogue.first;
    var modeAutre = false;
    final prixCtrl = TextEditingController(text: _catalogue.first.prixDefaut.toString());
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
                      'Article & travail',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: habitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Article / habit',
                        hintText: 'Ex. Chemise, Pantalon, Robe…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: modeAutre ? '__autre__' : travailChoisi?.id,
                      decoration: const InputDecoration(
                        labelText: 'Travail effectué',
                      ),
                      items: [
                        ..._catalogue.map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              '${d.libelle} (${CatalogueService.libelleCategorie(d.categorie)})',
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '__autre__',
                          child: Text('Autre travail (saisie libre)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        if (v == '__autre__') {
                          modeAutre = true;
                          travailChoisi = null;
                        } else {
                          modeAutre = false;
                          travailChoisi = _catalogue.firstWhere((d) => d.id == v);
                          prixCtrl.text = travailChoisi!.prixDefaut.toString();
                        }
                        setModal(() {});
                      },
                    ),
                    if (modeAutre) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: autreTravailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Précisez le travail',
                          hintText: 'Ex. Retouche, détachage…',
                        ),
                      ),
                    ],
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
      final travail = modeAutre
          ? (autreTravailCtrl.text.trim().isEmpty ? 'Autre travail' : autreTravailCtrl.text.trim())
          : (travailChoisi?.libelle ?? 'Travail');
      final categorie = modeAutre ? 'autre' : travailChoisi?.categorie;
      setState(() {
        _articles.add(
          ArticleDraft(
            typeHabit: habitCtrl.text.trim().isEmpty ? 'Article' : habitCtrl.text.trim(),
            travail: travail,
            categorie: categorie,
            catalogueId: modeAutre ? null : travailChoisi?.id,
            prixUnitaire: double.tryParse(prixCtrl.text) ?? 0,
            quantite: int.tryParse(qteCtrl.text) ?? 1,
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            defauts: defautsCtrl.text.trim().isEmpty ? null : defautsCtrl.text.trim(),
            photos: List.from(photos),
          ),
        );
      });
    }

    habitCtrl.dispose();
    autreTravailCtrl.dispose();
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
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prestation créée'),
          content: const Text('Souhaitez-vous partager le ticket PDF ou consulter les opérations ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'operations'), child: const Text('Opérations')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'pdf'), child: const Text('Partager PDF')),
          ],
        ),
      );
      if (action == 'pdf' && auth.pressing != null) {
        final pdf = await FacturePdfService().buildPdf(
          pressing: auth.pressing!, prestation: prestation, articles: articles,
        );
        await FacturePdfService().sharePdf(pdf, prestation.numeroTicket);
      } else if (action == 'operations' && mounted) {
        context.go('/employe/operations');
      }
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
            tooltip: 'Opérations',
            onPressed: () => context.go('/employe/operations'),
            icon: const Icon(Icons.list_alt),
          ),
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
              onPressed: _catalogueCharge ? _ajouterArticle : null,
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
                  title: Text('${a.typeHabit} — ${a.travail} × ${a.quantite}'),
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
