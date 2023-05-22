# titre 
Modélisation des embouteillages

# motivation

Avec les avancées technologiques le nombre de personnes recourant à la voiture augmente. Une des premières conséquence de cette croissance sont les embouteillages (car les moyens (routes) n'évoluent pas en même temps), synonymes de pollution et perte de temps pour les usagers.

# thème
Les embouteillages sont un points encore plus sensible en ville, par la densité de population et le peu de distance de manoeuvre pour faire de nouvelles routes et répondre à la demande. De plus, dans un contexte d'hyper-métropolisation cet axe d'échange est un point très critique.

# bibliographie commentée 


Pour la première partie, nous avons pris conscience de l'étendue du problème à l'aide de l'article "Comment se forment les embouteillages ?", de Waleed Mouhali  dans theconversation.com qui met en lumière le phénomène "d'effet chenille". La page Wikipédia sur les embouteillages a aussi été très utile, décrivant une dynamique fréquente où, après un premier état d'instabilité, la file de voitures le reste pour un certain temps, avec un risque accru de nouveaux ralentissements. 
Ensuite on modélise le problème sur un exemple de trafic routier grâce à OpenStreetMap qui permet d'acquérir la donnée de toutes les routes mais aussi des obstacles dans une zone choisie. Avec mygeodata.cloud on pourra convertir ces données en un fichier csv 
directement exploitable depuis un programme caml grâce à la bibliothèque "OCaml csv".


En second lieu, nous aurons recours à des publications scientifiques telles que "Algorithms" de Jeff Erickson dans lequel nous trouverons de nombreuses informations à propos du chemin augmentant de Ford-Fulkerson, basé sur le minimum cut problem, aussi décrit dans algorithms, on pourra ensuite optimiser suivant les règles d'Edmonds et Karps. Toutes les complexités des variantes sont détaillées dans le livre. Finalement cela nous permettra d'opérer sur des voitures assimilées à un flot continu pour une vue d'ensemble uniforme. 

Une autre ressource majeure est "Algorithms Designer Manual" de Steven Skiena, en plus de donner d'autres algorithmes sur les graphes, il fournit des algorithmes de programmation dynamique tels que subsetsum qui va nous permettre de travailler sur la donnée d'un flot discrétisé, pour par exemple considérer des véhicules comportant des spécificités particulières.

En outre, dans le cas où l'on veut opérer sur une situation en temps réel, on étudiera des algorithmes rapides, dis d'approximation ou encore des algorithmes gloutons dont on donnera la preuve de correction.

Pour considérer le problème d'un point de vue plus distant, on utilisera des ressources moins scientifiques telles que "théorie du trafic et régularisation dynamique", Cerema.

Il introduit la notion de diagramme fondamental (relation entre le débit et la vitesse) permettant de rendre compte des phénomènes de trafic routier, puis étudie plus précisémment l'insertion des véhicules d'une voie vers une autre, souvent le principal facteur de ralentissement. 

Ce document fourni différentes solutions pour limiter les embouteillages, soit en prévenant, soit en limitant les impacts d'un ralentissement : avec une régularisation des vitesses des véhicules ou la régularisation de l'accès à l'aide de feux tricolores.
Une dernière solution envisagée serait l'interdiction de dépassement pour les poids lourds, en effet c'est aux effets papillon de cette catégorie de véhicules que le trafic est le plus sensible.
