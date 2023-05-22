* Sujet actuel : Modélisation des bouchons de voiture en ville - optimisation de la durée des feux de circulation et décalage les uns par rapport aux autres
* Ce que vous avez fait jusqu'à présent : identification du problème : les embouteillages font parti des enjeux majeurs de la ville, causant une forte pollution, perte de temps et perte de patience de certains usagers parisiens. En effet, les applications permettant "d'éviter les bouchons" en proposant un itinéraire alternatif ne permettent que de lisser cette forte densité de voitures, ne résolvant pas tellement le problème.

En fait je viens de trouver ce sujet je sais pas s'il est pertinent ; avant j'ai fait quelques recherches peu concluantes sur par exemple le pb du voyageur de commerce.

J'ai l'impression qu'on est un peu contraint d'étudier un problème appliqué à quelque-chose, une modélisation, et faire un peu comme un exposé..

* vous demander si mon sujet est convenable
* dans un premier temps il faudrait préciser ce qui cause les bouchons
* puis comment les limiter/résoudre exemples : timing des feux tricolores, attitude à adopter en conduite ? (différentes stratégie, laisser une certaine distance (car temps de réaction mais si c'est trop long ça réduit le nombre de voitures qui peuvent passer à un feu)).
* autres points que je pourrais étudier : système de route idéal, permettant une optimalité suivant certains paramètres, comme le gain de temps pour le plus grand nombre de personnes, la garantie d'un temps pas trop long en pire cas pour tout le monde, et quelques exceptions pour les pompiers par exemple
* circulation des fourmis


* SOMMAIRE
  * etayage de la pbatique ; precision du pb. (avantages a la resoudre)
  * ce qui existe déjà, ce que l'ont sait du pb. (waze)
  * représentation et mise en évidence du problème, exemples les plus critiques
  * propositions de résolutions
    * 1
    * 2
    * ...
  * mise en place pratique des systèmes, choix des propositions
* Le problème
  * indice de congestion (TomTom), temps perdu *TomTom mesure "des segments de route individuels ainsi que des réseaux routiers entiers" et pondère ensuite les "routes les plus fréquentées et les plus importantes pour calculer un niveau de congestion global précis."*
  * urbanisme
  * les embouteillages coûtent 5,9 milliards d'euros à l'économie française, tous les ans
* résolution avec les feux tricolores : meilleurs timings à adopter pour maximiser le débit de voiture et minimiser le temps d'attente dans la file avant de pouvoir traverser. on va simuler le passage de voitures à un carrefour, alterné entre les deux sens.

=> pas exploitable car inutile (réfléchir)

* VOIES DE DELESTAGE
  * extraire les coordonnées des routes d'un csv
  * représenter les routes d'une ville sur graphics

(\* TODO trouver un site permettant d'extraire en csv le graphe d'une ville, avec les arêtes et sommets.

* utilisation d'osmium : osmium cat map.osm -o truc.osm.pbf osm4routing truc.osm.pbf )
* RECAP :

---

meilleurs intersections avec un rapport prix / qualité en débit presentations des propositions avec leurs spécificités puis graphique des rapports

propositions de voies de delaistage. pbs : le prix / impossibilités du a des monuments ect. ce qu'on peut imaginer faire : reperer des zones critiques dans les grandes villes, et proposer mon algorithme qui affiche des voies de delaistage

le "meilleur comportement" en tant que conducteur : meme distance devant derriere, mais cause un pb :

* essayer différents points de vu et comparer avec des SOURCES :


* livre d'algorithmie pour
  * flot (on regarde le flux), ford fulkerson ! ou on
  * discretise (prog dynamique, où on génére un nouveau plateau a chaque fois et on a accès à chacunes des voitures) : on pourra avoir une vue précise sur chacune des voitures
  * algo d'approx ?
* autre ressource (peut-être + commune, pas scientifique) qui traitent du même problème