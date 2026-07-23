import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../utils/format.dart';

String normaliserTelephoneWhatsApp(
  String telephone, {
  String indicatifDefaut = indicatifTelephoneDefaut,
}) {
  final chiffres = telephone.replaceAll(RegExp(r'\D'), '');
  if (chiffres.startsWith(indicatifDefaut)) return chiffres;
  if (chiffres.length == 10 && chiffres.startsWith('0')) {
    return '$indicatifDefaut${chiffres.substring(1)}';
  }
  return chiffres;
}

String formaterMessageFacture({
  required String nomPressing,
  required Prestation prestation,
  required List<ArticlePrestation> articles,
}) {
  final lignes = articles
      .map(
        (a) =>
            '• ${a.typeHabit} x${a.quantite} — ${a.sousTotal.round()} FCFA',
      )
      .join('\n');

  final date = formaterDateCourt(prestation.dateDepot);

  return '🧾 *$nomPressing*\n'
      'Ticket : ${prestation.numeroTicket}\n'
      'Client : ${prestation.clientNom}\n'
      'Date : $date\n\n'
      '*Articles*\n$lignes\n\n'
      '*Total : ${prestation.montantTotal.round()} FCFA*\n'
      'Merci pour votre confiance !';
}

Future<void> ouvrirConversationWhatsApp(String telephone, String message) async {
  final numero = normaliserTelephoneWhatsApp(telephone);
  final texte = Uri.encodeComponent(message);
  final deepLink = Uri.parse('whatsapp://send?phone=$numero&text=$texte');
  final fallback = Uri.parse('https://wa.me/$numero?text=$texte');

  if (await canLaunchUrl(deepLink)) {
    await launchUrl(deepLink, mode: LaunchMode.externalApplication);
  } else {
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}
