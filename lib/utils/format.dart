import 'package:intl/intl.dart';

final _montantFmt = NumberFormat('#,###', 'fr_FR');

String formaterMontant(num montant, {String devise = 'FCFA'}) {
  return '${_montantFmt.format(montant.round())} $devise';
}

String genererNumeroTicket({String prefixe = 'TK'}) {
  final maintenant = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  final aleatoire = (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  return '$prefixe-$maintenant-$aleatoire';
}

enum FiltrePeriode { aujourdhui, semaine, mois }

class IntervalleDates {
  IntervalleDates({required this.debut, required this.fin});
  final DateTime debut;
  final DateTime fin;
}

DateTime _debutDuJour(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _finDuJour(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

DateTime _debutSemaine(DateTime d) {
  final debut = _debutDuJour(d);
  final decalage = debut.weekday - DateTime.monday;
  return debut.subtract(Duration(days: decalage));
}

IntervalleDates calculerIntervalle(FiltrePeriode filtre) {
  final maintenant = DateTime.now();
  switch (filtre) {
    case FiltrePeriode.aujourdhui:
      return IntervalleDates(debut: _debutDuJour(maintenant), fin: _finDuJour(maintenant));
    case FiltrePeriode.semaine:
      return IntervalleDates(debut: _debutSemaine(maintenant), fin: _finDuJour(maintenant));
    case FiltrePeriode.mois:
      final debut = DateTime(maintenant.year, maintenant.month, 1);
      return IntervalleDates(debut: debut, fin: _finDuJour(maintenant));
  }
}

String formaterDateCourt(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat("dd MMM HH:mm", 'fr_FR').format(d);
  } catch (_) {
    return iso;
  }
}

String aujourdhuiIsoDate() => DateTime.now().toIso8601String().substring(0, 10);

String ajouterMois(String dateIso, int mois) {
  final date = DateTime.parse('${dateIso.substring(0, 10)}T12:00:00');
  final cible = DateTime(date.year, date.month + mois, date.day);
  return cible.toIso8601String().substring(0, 10);
}

int joursRestants(String dateExpiration) {
  final aujourdhui = _debutDuJour(DateTime.now());
  final expiration = DateTime.parse('${dateExpiration.substring(0, 10)}T00:00:00');
  return expiration.difference(aujourdhui).inDays;
}

String genererCodePin({int longueur = 6}) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final buffer = StringBuffer();
  var n = now;
  for (var i = 0; i < longueur; i++) {
    buffer.write(n % 10);
    n ~/= 7;
    if (n == 0) n = DateTime.now().millisecondsSinceEpoch;
  }
  return buffer.toString();
}
