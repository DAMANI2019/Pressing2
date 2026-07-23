import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/format.dart';

class FacturePdfService {
  Future<Uint8List> buildPdf({
    required Pressing pressing,
    required Prestation prestation,
    required List<ArticlePrestation> articles,
  }) async {
    final document = pw.Document();
    final raison = _ou(pressing.factureRaisonSociale, pressing.nom);
    final adresse = _ou(pressing.factureAdresse, pressing.adresse);
    final telephone = _ou(pressing.factureTelephone, pressing.telephone);
    final email = _ou(pressing.factureEmail, pressing.email);
    final logo = await _chargerLogo(pressing.factureLogoUrl ?? pressing.logoUrl);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Row(children: [
            if (logo != null) pw.Container(width: 52, height: 52, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.Expanded(child: pw.Text(raison, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          ]),
          if (adresse.isNotEmpty) pw.Text(adresse),
          if (telephone.isNotEmpty) pw.Text('Tél. : $telephone'),
          if (email.isNotEmpty) pw.Text(email),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('FACTURE / TICKET', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('N° ${prestation.numeroTicket}'),
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Client : ${prestation.clientNom}'),
          pw.Text('Téléphone : ${prestation.clientTelephone}'),
          pw.Text('Date de dépôt : ${_date(prestation.dateDepot)}'),
          if (prestation.dateLivraison != null) pw.Text('Date de livraison : ${_date(prestation.dateLivraison!)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
            headers: const ['Article', 'Qté', 'Prix', 'Total'],
            data: articles.map((a) => [
              a.typeHabit,
              '${a.quantite}',
              formaterMontant(a.prixUnitaire),
              formaterMontant(a.sousTotal),
            ]).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total : ${formaterMontant(prestation.montantTotal)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          if (prestation.notes?.isNotEmpty ?? false) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notes : ${prestation.notes}'),
          ],
          pw.SizedBox(height: 28),
          pw.Divider(),
          pw.Text(_ou(pressing.facturePiedPage, 'Merci de votre confiance.'),
              textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
    return document.save();
  }

  Future<void> sharePdf(Uint8List bytes, String numeroTicket) =>
      SharePlus.instance.share(ShareParams(
        text: 'Ticket de pressing $numeroTicket',
        files: [XFile.fromData(bytes, name: 'ticket_$numeroTicket.pdf', mimeType: 'application/pdf')],
      ));

  Future<void> printPdf(Uint8List bytes) => Printing.layoutPdf(onLayout: (_) async => bytes);

  String _ou(String? valeur, String? secours) =>
      valeur?.trim().isNotEmpty == true ? valeur!.trim() : (secours?.trim() ?? '');

  String _date(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(date);
  }

  Future<pw.MemoryImage?> _chargerLogo(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url.trim()));
      return response.statusCode >= 200 && response.statusCode < 300
          ? pw.MemoryImage(response.bodyBytes)
          : null;
    } catch (_) {
      return null;
    }
  }
}
