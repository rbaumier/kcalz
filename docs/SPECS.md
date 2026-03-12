Application iOS permettant de tracker ses calories et son poids.
Ultra performante, ultra légère, ultra facile à utiliser.
UI Ludique : animations, couleurs. French only
Local : 
  - stockage des données dans iCloud
  - stockage des résultats de recherche localement
  - utilisation de bdd openfoodfacts (french only) 
    -> recherche full text search voa SQLite
    -> à voir si on peut réduire leurs données (10Go) bdd pour les stocker en local, ou utiliser leur api uniquement pour les données complètes d'un aliment.

Features :
- Goals journaliers (kcal, protéines, carbs, lipides, sucre, sel (tous optionnels)) qu'on peut modifier facilement
- Dashboard qui affiche nutriments utilisés + restants pour la journée.
- Changer de jour
- Renseigner son poids et surveiller l'évolution
- Renseigner ses aliments :
  - 4 repas : Petit déjeuner, Déjeuner, Goûter, Dîner
  - à droite de chaque repas "[+]" pour ajouter un aliment
    -> input de recherche avec search as you type ET scanner code barre
    -> on affiche par défaut les aliments les plus utilisés par nous, mais on peut toggle et afficher les plus récents
    -> quand on cherche on affiche d'abord les résultats déjà utilisés par nous, puis ceux qui matchent
- Copier les ingrédients d'un repas à un autre : on met un "[ ]" à gauche de chaque aliment, si on sélectionne ça affiche une barre en bas avec "Copier/Supprimer"
- Créer des ensembles d'aliments
