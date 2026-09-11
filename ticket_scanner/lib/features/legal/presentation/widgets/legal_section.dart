import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Textes légaux par défaut (embarqués — remplacés par le dashboard si
/// l'admin personnalise le contenu).
abstract final class DefaultLegalContent {
  static const privacy = '''
PharmaScan — Politique de confidentialité

1. Données collectées
L'application collecte uniquement : un identifiant anonyme d'utilisateur, les informations extraites de vos reçus de pharmacie (pharmacie, date, médicaments, montants), et le nombre de points que vous avez gagnés.

2. Traitement des images
Les images de vos reçus sont traitées SUR VOTRE APPAREIL (reconnaissance de caractères locale). L'image ne quitte jamais votre téléphone : seule la liste des informations extraites est enregistrée.

3. Utilisation
Les prix collectés alimentent la base de comparaison de prix des médicaments au service de tous les utilisateurs. Votre identité n'est jamais associée aux prix publiés.

4. Conservation et suppression
Vous pouvez demander la suppression de votre compte et de toutes vos données à tout moment depuis la page « Suppression du compte » (Réglages), conformément à la réglementation ivoirienne (Loi n° 2013-450 relative à la protection des données à caractère personnel, ARTCI/CERTINUM).

5. Contact
Pour toute question : contact@pharmascan.app''';

  static const consent = '''
Consentement — scan de reçus de pharmacie

En scannant un reçu, vous acceptez ce qui suit :

1. Votre reçu contient des informations de santé (médicaments achetés). Ces informations sont considérées comme sensibles.

2. L'image du reçu est traitée localement sur votre appareil et ne quitte pas votre téléphone.

3. Seules les données extraites (nom de la pharmacie, date, médicaments, prix, montant) sont enregistrées, sans lien avec votre identité réelle.

4. Ces données servent à construire la base publique de comparaison des prix de médicaments.

5. Vous pouvez retirer votre consentement en demandant la suppression de votre compte et de vos données (page « Suppression du compte » dans les Réglages).''';

  static const medical = '''
Avertissement médical — lisez attentivement

PharmaScan est un outil d'INFORMATION et de comparaison de prix. Il ne remplace en aucun cas l'avis d'un médecin ou d'un pharmacien.

- Ne modifiez jamais votre traitement sur la base des informations de cette application.
- Consultez toujours un professionnel de santé pour un diagnostic ou un conseil médical.
- Les prix affichés proviennent des tickets scannés par les utilisateurs et peuvent varier.

EN CAS D'URGENCE :
- SAMU (Côte d'Ivoire) : 185
- Police secours : 112
- Pompiers : 180
- Rendez-vous immédiatement dans l'établissement de santé le plus proche.''';

  static const terms = '''
Conditions d'utilisation — PharmaScan

1. Objet
PharmaScan permet de comparer les prix des médicaments vendus dans les pharmacies de Côte d'Ivoire grâce aux tickets scannés par la communauté.

2. Compte
L'application crée un compte anonyme. Vous gagnez des points pour chaque reçu scanné (gamification). Les points n'ont pas de valeur monétaire et ne peuvent être échangés contre de l'argent.

3. Contenu généré
En scannant un reçu, vous garantissez qu'il s'agit de votre propre reçu et que les informations fournies sont exactes.

4. Usage loyal
Il est interdit de falsifier des reçus, de scanner le même reçu plusieurs fois pour gagner des points, ou d'utiliser l'application à des fins illégales.

5. Disponibilité
L'application est fournie « en l'état ». Les prix indiqués sont indicatifs et peuvent différer des prix pratiqués en officine.

6. Modification
Nous pouvons modifier ces conditions à tout moment. La version en vigueur est disponible dans cette page.''';

  static const legal = '''
Mentions légales — PharmaScan

Éditeur :
PharmaScan — application de comparaison de prix de médicaments.
Côte d'Ivoire — Abidjan.

Contact :
contact@pharmascan.app

Hébergement :
Données hébergées par Firebase (Google Cloud), dans le respect de la réglementation en vigueur.

Propriété intellectuelle :
Le nom et le logo PharmaScan sont protégés. Toute reproduction est interdite sans autorisation.

Responsabilité :
Les informations publiées (prix, pharmacies de garde) sont fournies à titre indicatif par la communauté. L'éditeur ne peut être tenu responsable d'une inexactitude.

Conformité :
Conformément à la réglementation ivoirienne, la vente de médicaments en ligne est interdite en Côte d'Ivoire. PharmaScan ne vend aucun médicament : l'application informe uniquement sur les prix pratiqués en officine.''';
}

/// Section « Informations légales » des Réglages.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations légales',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded),
                title: const Text('Politique de confidentialité'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_rounded),
                title: const Text('Consentement scan reçus'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/consent'),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_rounded),
                title: const Text('Avertissement médical / urgence'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/medical'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Conditions d\'utilisation'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/terms'),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Mentions légales + contact'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/legal'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
