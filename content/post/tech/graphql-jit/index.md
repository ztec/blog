---
title: "GraphQL JIT, qu'est-ce que c'est qu'ce binz ?"
date: 2025-01-29T00:00:00+02:00
slug: "graphql-jit-est-t-il-vraiment-plus-performant"
images: [2025/post/graphql-jit-est-t-il-vraiment-plus-performant/img/cover-fr.jpg]
description: "Revisiter le choix d'utiliser GraphQL JIT après quelques années d'utilisation réelle sur une API GraphQL"
tags: ["tech", "node.js", "graphql", "performance", "IA-helped"]
promotions:
  twitter: https://x.com/Ztec6/status/1884565919386456395
  mastodon: https://mamot.fr/deck/@ztec/113911431397975652
  bluesky: https://bsky.app/profile/ztec.fr/post/3lguutoxkax2q
---

## Historique

Dans le cadre de mon travail (à Deezer), j'ai conçu un serveur GraphQL il y a quelques années. Parmi les défis que j'ai dû relever, celui de la performance arrive bien en tête. Construire une API GraphQL qui soit à la fois facile à utiliser, à construire et performante n'est pas une tâche facile, surtout en Node.js.


Avec [Jimmy Thomas](https://fr.linkedin.com/in/jimmythomasinfo), une des optimisations que nous avions configurées était l'usage de [GraphQL JIT](https://github.com/zalando-incubator/graphql-jit) en lieu et place du moteur d'exécution original de GraphQL. Le [README](https://github.com/zalando-incubator/graphql-jit?tab=readme-ov-file#why) revendique des gains de temps de réponse et aussi une augmentation du nombre de requêtes qui peuvent être exécutées simultanément en réduisant l'impact CPU du moteur d'exécution.


## GraphQL JIT, c'est quoi ?
Son nom fait référence au concept de compilateur "Just-In-Time" (ou Juste à temps en français). Il est conçu pour tirer parti des optimisations de [V8](https://en.wikipedia.org/wiki/V8_(JavaScript_engine)) afin d'en augmenter les performances. C'est un remplacement direct du moteur d'exécution par défaut de GraphQL, avec quelques restrictions.

L'une des plus importantes est indiquée dans le README du projet :

> Toutes les propriétés calculées doivent avoir un résolveur et seuls ceux-ci peuvent renvoyer une promesse.

Cette limitation n'est pas nécessairement un problème, selon la façon dont vous concevez votre serveur.  
Dans mon cas, j'ai pu m'en accommoder aisément.

Le gain de performance annoncé est assez impressionnant : jusqu'à 10 fois plus rapide que le moteur par défaut.

## Pourquoi a-t-on fait ce choix ?

À l'époque, nous avions fait des tests poussés sur le projet, notamment avec [Gatling](https://en.wikipedia.org/wiki/Gatling_(software)) pour les tests de charge.  
J'ai construit un référentiel de requêtes GraphQL que j'ai utilisées pour comparer les performances de chaque changement.  
Chaque PR avait donc droit à son test de performance, et on vérifiait si des améliorations étaient apportées ou non. Toute dégradation était un motif de travail sur la PR.  
De cette façon, nous avons nettement amélioré les temps de réponse et la charge admissible petit à petit.

Un des changements ayant eu le plus d'impact fut l'adoption de GraphQL JIT. Les gains étaient tels que le choix  
était évident et justifié à l'époque. Malheureusement, les purges automatiques de Jenkins ont fait disparaître tous les rapports et graphiques de cette période, et je n'ai pas eu la présence d'esprit de les  
sauvegarder ailleurs.

## Pourquoi reconsidérer ce choix ?

Quand nous avons fait la bascule, les tests étaient clairs. Cependant, le projet était loin d'être utilisé de manière significative en production. Peu de requêtes, peu de clients, c'était le début.  
Nos choix étaient donc entièrement basés sur les tests que nous faisions et les benchmarks que nous avions. Afin de rendre nos tests les plus réalistes possible, j'ai construit le référentiel de requêtes dont je parlais tout à l'heure.  
Celui-ci a été élaboré sur des bases théoriques de ce que nous pensions être le comportement des futurs clients (les applications qui feraient les appels API). Notamment, l'état actuel de ces applications suggérait certaines directions techniques. Comme toute migration, il n'est pas question de tout refaire, des compromis sont faits. Ces compromis donnaient des directions sur lesquelles nous avons basé nos tests.

Depuis un moment maintenant, l'API est en production et fortement utilisée. De plus en plus même. À la fois grâce à l'augmentation du nombre d'utilisateurs mais aussi parce que  
les applications ont migré vers cette API de plus en plus, délaissant les anciennes (...les API Legacy **Brrrr bruit d'effroi**).

Dans ces conditions, il était temps de reconsidérer quelques choix faits au début et de les confronter à la réalité du monde réel véridique.


## Méthodologie  

Il y a deux tests à faire :  
- Un en production avec de vraies requêtes de clients  
- Un en utilisant l'ancienne méthode avec Gatling, comme avant (test de laboratoire)  

### Tests de production  
Afin de tester les deux moteurs simultanément, j'ai modifié le code du serveur pour choisir aléatoirement l'un ou l'autre. De cette façon, une fois déployé sur le cluster Kubernetes, nous avions environ 50 % des requêtes qui passaient par l'un ou l'autre moteur. Nous avons assez d'instances pour obtenir des statistiques significatives.  

Le code est assez barbare mais fonctionne merveilleusement bien :  

```typescript  
expressApp.use(  
    [...],  
    Math.random() > 0.5  
        ? createJitGraphqlMiddleware({schema})  
        : createJsGraphqlMiddleware(schema),  
);  
```  

Une fois déployé, je vais analyser quelques métriques pour évaluer l'impact de chaque moteur. Je me concentrerai principalement sur :
- Les métriques système telles que l'utilisation du CPU et de la mémoire
- Les métriques de Node.js telles que l'[ELU](https://nodesource.com/blog/event-loop-utilization-nodejs/), la taille de la HEAP et le garbage collector
- Les objectifs de temps de réponse (de combien nous nous écartons de la cible)
- Le temps de réponse moyen et le 95ᵉ percentile

### Test de laboratoire
Pour les tests à l'ancienne, j'ai simplement repris ce que nous avions déjà construit quelques années auparavant. J'ai de nouveau configuré Gatling avec quelques requêtes typiques.  
Les scénarios ne sont pas tout à fait les mêmes qu'à l'époque, car ils ont été un peu améliorés au fur et à mesure. En effet, avec de plus en plus d'utilisation, nous avons ajusté les scénarios pour qu'ils soient plus représentatifs et notamment ajusté les volumes lors des tests. Quand je dis qu'ils sont plus représentatifs, gardez à l'esprit que c'est un jeu perdu d'avance et que mes biais restent présents, comme aux origines. J'ai simplement eu l'occasion de faire des observations plus fines et répétées depuis.
C'est loin d'être digne de la rigueur scientifique ici. Le changement le plus notable est la façon dont les scénarios sont regroupés.

Avant, chaque requête avait son propre scénario. Maintenant, j'ai regroupé les scénarios en deux catégories, représentant deux profils d'utilisateurs principaux :
- Les **utilisateurs légers** envoient de petites requêtes. C'est l'utilisation standard de l'API, similaire à celle de n'importe quel client interagissant avec nos applications/front-end.
- Les **utilisateurs lourds** font de grandes et complexes requêtes, avec beaucoup de champs et de champs imbriqués. C'est typique d'un client utilisant certaines fonctionnalités coûteuses de nos applications ou de tout client malveillant essayant d'abuser de l'API.

Ce qui est important à retenir, c'est que ces deux profils ne sont pas lancés avec la même fréquence de requêtes. L'un en fait beaucoup plus que l'autre.

Le scénario Gatling ressemble à ceci :
```scala  
val heavyUser_ConcurentUser = max_reqps / 20  
val heavyUser_ConcurentRequest = max_reqps / 20  
val lightUser_ConcurentUser = max_reqps - heavyUser_ConcurentUser  
val lightUser_ConcurentRequest = max_reqps - heavyUser_ConcurentRequest  

setUp(  
  lightUser.inject(  
    rampConcurrentUsers(1) to (lightUser_ConcurentUser) during (2 minutes),  
    constantConcurrentUsers(lightUser_ConcurentUser) during (duration - 2 minutes)  
  ).throttle(reachRps(lightUser_ConcurentRequest) in (duration minutes)),  

  heavyUser.inject(  
    rampConcurrentUsers(1) to (heavyUser_ConcurentUser) during (2 minutes),  
    constantConcurrentUsers(heavyUser_ConcurentUser) during (duration - 2 minutes)  
  ).throttle(reachRps(heavyUser_ConcurentRequest) in (duration minutes))  
).protocols(httpProtocol)  
```  

Les tests Gatling s'exécuteront sur mon ordinateur et enverront les requêtes sur des instances de l'API déployées sur un cluster Kubernetes. Ce cluster est très similaire à celui de la production, il est juste plus petit. Je ne vais pas pousser les tests à des valeurs extrêmes, donc je ne suis pas inquiet que les résultats soient faussés par l'environnement.

Je vais regarder les mêmes indicateurs que les tests de production. Cette fois, je ne vais pas regarder les données que me donne Gatling lui-même, car je lance les tests depuis mon ordinateur portable et je ne peux pas faire confiance aux temps de réponse collectés par Gatling. De plus, je n'en ai pas vraiment besoin.

## Résultats

### Productions

#### Temps de réponse

Une des métriques que j'ai est le temps que met le moteur à calculer une requête et produire une réponse.  
Cela n'inclut pas le temps qu'il faut pour envoyer la réponse au client ou le temps de transit sur le réseau.

{{< illustration src="img/prod-avg-all.png"  
name="Temps de réponse moyen par moteur"  
alt="Graphique du temps de réponse moyen par moteur"  
resize="no" >}}

Le temps de réponse moyen montre que le moteur JS est légèrement plus rapide, mais avec seulement 1 ms de différence, ce n'est pas vraiment significatif.

{{< illustration src="img/prod-95p-all.png"  
name="Temps de réponse au 95ᵉ percentile par moteur"  
alt="Graphique du temps de réponse au 95ᵉ percentile par moteur"  
resize="no" >}}

Le 95ᵉ percentile montre une différence un peu plus grande. Ce n'est pas énorme, mais 5 ms semblent significatifs.

Concernant le temps de réponse, nous pouvons dire, sans aucun doute, que le moteur `JIT` n'en vaut pas la peine mathématiquement parlant.  
Cependant, nous parlons d'une différence de 5 ms, pas de quoi révolutionner le projet.

#### Indicateurs système (CPU & RAM)

Le service est déployé sur un cluster Kubernetes. J'ai accès aux métriques du cluster et je peux voir l'utilisation du CPU et de la RAM spécifiquement pour ce service.

> Dans Kubernetes, nous définissons des réservations CPU et RAM. C'est une bonne pratique de préciser au cluster combien de ressources  
> les pods auront besoin. Par exemple, nous pouvons dire qu'un processus Node.js peut utiliser jusqu'à 2 CPUs.  
> Le graphique montre ensuite combien de ces 2 CPUs sont utilisés par rapport à la réservation.  
> La même chose s'applique à la RAM.  
> Bien sûr, le graphique montre les valeurs pour l'ensemble du cluster, pas seulement un pod.
>
> ```yaml
> limits:
>   memory: 512Mi
> requests:
>   memory: 512Mi
>   cpu: 2
> ```
> Un exemple de configuration pour un pod. Cela signifie que le pod aura 2 CPUs et 512 Mi de RAM à sa disposition.

{{< illustration src="img/prod-system-cpu.png"  
name="Pourcentage de l'utilisation de la réservation CPU"  
alt="Pourcentage de l'utilisation de la réservation CPU"  
resize="no" >}}

Le moteur `js` utilise 2 % de CPU en moins que le moteur `JIT`. C'est une différence constante, mais comme pour le temps de réponse, ce n'est pas très impressionnant.  
Ne vous méprenez pas cependant, lorsque vous déployez des centaines ou des milliers de pods, 2 % peuvent devenir beaucoup. Considérons le CPU comme pas cher pour le moment.

{{< illustration src="img/prod-system-RAM.png"  
name="Pourcentage de l'utilisation de la réservation RAM"  
alt="Pourcentage de l'utilisation de la réservation RAM"  
resize="no" >}}

Les indicateurs de RAM sont un peu plus intéressants. Le moteur `js` utilise environ 20 % de RAM en moins que le moteur `JIT`.  
Une différence de 20 % semble substantielle.

#### Indicateurs Node.js

{{< illustration src="img/prod-nodejs-elu.png"  
name="Event Loop Utilization min, max et moyenne au niveau du cluster"  
alt="Event Loop Utilization min, max et moyenne au niveau du cluster"  
resize="no" >}}

Je vous mets au défi d'identifier le moment où le déploiement du 50/50 par moteur a été fait. L'ELU n'a pas bougé d'un iota.  
Je n'ai qu'un indicateur global contrairement au CPU/RAM, je ne peux pas observer les différences de manière aussi précise.  
Cependant, je pars du postulat qu'un changement significatif serait observable avec 50 % des requêtes traitées par le `js-engine`.  
Je considère donc que l'utilisation de l'un ou l'autre moteur n'a pas d'impact sur l'ELU.

{{< illustration src="img/prod-nodejs-heap-old.png"  
name="Heap old space usage at cluster level, min, max, and average"  
alt="Heap old space usage at cluster level, min, max, and average"  
resize="no" >}}

En surveillant la HEAP, on voit que l'espace `old` semble avoir légèrement diminué. Ce n'est pas très évident sur le graphique, mais c'est visible dans la moyenne.  
Le maximum n'a pas changé, mais le minimum oui. Cela confirme ce que nous avons observé plus tôt avec l'utilisation de la RAM.

Les autres espaces de la HEAP n'ont pas été impactés du tout, et il en va de même pour la Garbage Collection.  
Ils racontent tous la même histoire que les métriques ELU. Ils sont restés inchangés par rapport à avant, donc je n'ai pas pris la peine de prendre des captures d'écran des graphiques.

### Résultats des tests de laboratoire

J'ai exécuté le test Gatling pour chaque moteur dans deux déploiements distincts. Les tests ont été exécutés simultanément. Strictement parlant, ils auraient pu s'impacter mutuellement, mais je ne pense pas que cet effet soit significatif, car le cluster que j'utilisais avait suffisamment (vraiment) de ressources pour gérer la charge. De plus, la charge n'était pas si élevée, j'ai maintenu le taux de requêtes bien en dessous des limites.

#### Temps de réponse

{{< illustration src="img/lab-all.png"  
name="Temps de réponse moyen et 95ᵉ percentile par moteur"  
alt="Temps de réponse moyen et 95ᵉ percentile par moteur"  
resize="no" >}}

Les résultats ne sont pas très favorables au moteur `js`. La différence semble vraiment importante en faveur du moteur `JIT`.  
Gardez en tête que les résultats absolus ne sont pas comparables à ceux de la production, mais des comparatifs avec uniquement des données de ces tests restent pertinents.  
Nous perdons environ 50 ms sur le 95ᵉ percentile et 20 ms en moyenne. Cela représente des ralentissements d'approximativement 50 % et 70 % respectivement par rapport au moteur `JIT`.

#### Indicateurs système (CPU & RAM)

{{< illustration src="img/lab-system-all-js.png"  
name="Tableau de bord des métriques système montrant l'utilisation du CPU et de la RAM pour le moteur js"  
alt="Tableau de bord des métriques système montrant l'utilisation du CPU et de la RAM pour le moteur js"  
resize="no" >}}

{{< illustration src="img/lab-system-all-jit.png"  
name="Tableau de bord des métriques système montrant l'utilisation du CPU et de la RAM pour le moteur JIT"  
alt="Tableau de bord des métriques système montrant l'utilisation du CPU et de la RAM pour le moteur JIT"  
resize="no" >}}

La première différence notable, c'est l'utilisation du CPU. Le moteur `js` utilise 20 % de CPU en plus que le moteur `JIT`, pas négligeable.

En ce qui concerne la RAM, la différence est plus faible mais toujours présente, avec seulement quelques pourcentages d'utilisation en plus pour le `js-engine`.

Dans l'ensemble, nos tests synthétiques indiquent que le moteur `JIT` est plus efficace que le moteur `js`.

#### Indicateurs Node.js

{{< illustration src="img/lab-nodejs-all-js.png"  
name="Tableau de bord des métriques Node.js telles que ELU, HEAP et Garbage Collector pour le moteur js"  
alt="Tableau de bord des métriques Node.js telles que ELU, HEAP et Garbage Collector pour le moteur js"  
resize="no" >}}

{{< illustration src="img/lab-nodejs-all-jit.png"  
name="Tableau de bord des métriques Node.js telles que ELU, HEAP et Garbage Collector pour le moteur JIT"  
alt="Tableau de bord des métriques Node.js telles que ELU, HEAP et Garbage Collector pour le moteur JIT"  
resize="no" >}}

L'histoire est la même avec les indicateurs Node.js. Le moteur `js` utilise plus de HEAP, requiert davantage de garbage collection et a un taux d'utilisation de l'ELU plus élevé.  
Spécifiquement, l'ELU est passé de 30 % à 50 %.

## Mais qu'est-ce que c'est qu'ce binz ?

Bon, les choses deviennent intéressantes.  
Les résultats de production montrent clairement un léger avantage pour le moteur `js`. Cette victoire est petite et pourrait, dans certains cas, être considérée comme négligeable.  
Cependant, c'est toujours une victoire, pas une défaite.

En revanche, lorsque nous examinons les résultats de laboratoire, l'histoire est tout autre.  
Le moteur `JIT` est un gagnant clair et net ! De plus, basé uniquement sur les résultats de laboratoire, il est évident qu'utiliser le moteur `JIT` représente un gain important.

Les tests de laboratoire sont grossomodo les mêmes que ceux que j'avais obtenus quelques années auparavant. Le moteur `JIT` montre sa supériorité sur presque tous les aspects, et de manière significative.  
À l'époque, je n'avais que ces informations à ma disposition pour baser mon choix, et j'avais naturellement choisi le moteur `JIT`.

Aujourd'hui, cependant, les résultats de production compliquent la décision :
- Le moteur `js` est meilleur ou au moins aussi bon que le moteur `JIT` en termes de temps de réponse, d'utilisation des ressources et de performances globales.
- La complexité introduite par le moteur `JIT` a un coût.
- Le moteur `JIT` a certaines limitations. Nous ne les avons pas rencontrées, elles ne sont donc pas très pertinentes dans mon contexte.
- Le moteur `js` est le "standard" sur lequel se basent beaucoup d'outils et de librairies.

La question a donc été soulevée en interne, et il y a consensus pour considérer la standardisation suffisamment importante pour justifier un retour au moteur `js`.  
Je suis plutôt d'accord avec cette perspective.

## Mais où sont passés les gains du moteur `JIT` en prod ?

Le monde réel et le laboratoire montrent des comportements opposés qui semblent contre-intuitifs.  
Je crois que la raison principale réside dans la manière dont nous utilisons l'API GraphQL.

Quand nous avons commencé notre aventure GraphQL, nous avons eu une courbe d'apprentissage assez raide.  
L'un des plus grands défis était de concevoir le schéma et d'envisager les requêtes qui seraient faites.  
Nous avons dû tout repenser, en nous éloignant de nos API REST utilisées alors.

Cependant, comme toute personne ayant travaillé sur un système existant le sait (ai-je entendu "legacy" ?),  
nous avons dû considérer de nombreux scénarios existants et limitations techniques.

Par exemple, les résultats paginés n'étaient pas aussi courants à l'époque qu'ils ne le sont aujourd'hui.  
En concevant le schéma, nous avons cherché à suivre "l'état de l'art" dans ce domaine, mais ce n'était pas toujours simple ni même faisable.  
Des compromis ont été faits, et nous avons dû accepter des utilisations pas très optimales de l'API.

Après des années d'apprentissage et d'efforts pour tenter malgré tout de suivre les meilleures pratiques en matière de GraphQL, nous nous retrouvons dans une situation bien meilleure que prévu.  
En effet, nous craignions initialement de traiter des requêtes massives avec de nombreux champs imbriqués. En réalité, en regardant ce que les développeurs front et mobile ont construit, ce scénario n'est pas aussi fréquent que nous l'imaginions.  
Ces inquiétudes n'ont pas totalement disparu, mais semblent moins pertinentes.

Les équipes se sont adaptées à la nouvelle manière de penser, en embrassant les limitations et les concepts d'une API GraphQL.  
La qualité de nos requêtes GraphQL semble suffisante, indiquant que nous n'avons plus autant besoin des optimisations `JIT`.  
En effet, l'un des gros gains du moteur `JIT` est de réduire le temps de réponse des requêtes complexes avec beaucoup de champs imbriqués. Or, nous n'avons pas tant de requêtes de ce type.

À l'avenir, nous pourrions avoir besoin de reconsidérer de nouveau cette décision en fonction de l'évolution de nos futures applications.  
Mais pour l'instant, le moteur `js` semble plus que suffisant tout en nous permettant une maintenance simplifiée.

## Conclusions

Il y a quelques années, j'ai conçu un serveur GraphQL et pris plusieurs décisions architecturales. Nous avons mis en œuvre certaines optimisations évidentes et mené des tests pour vérifier leur efficacité au-delà des affirmations marketing, confirmant nos choix.

Toutes les décisions n'étaient pas parfaites, et il y a beaucoup à dire et critiquer sur le projet. Cependant, le choix du moteur `JIT` était bon à l'époque.

Aujourd'hui, le contexte a évolué.  
Nous avons (assez) de clients réels. Node.js et V8 ont été améliorés. Les implémentations standard de GraphQL ont bénéficié de plusieurs années d'améliorations communautaires.

Revisiter d'anciennes décisions s'est avéré instructif, sinon bénéfique.  
La possibilité de tester une théorie en production, facilement et sans craindre de tout casser, est un luxe. Je suis reconnaissant pour cette opportunité.

Le monde réel, véridique, dépasse toujours le laboratoire et ses benchmarks, une bonne surprise (non) on est d'accord !  
Si vous avez les ressources et le temps, testez vos hypothèses, en utilisant des données réelles ou des clients réels chaque fois que possible.  
Ne négligez pas vos tests en laboratoire, qu'ils soient automatisés (c'est le mieux) ou non.  
Pour cela, il est crucial de maintenir des pratiques de développement saines qui facilitent les tests et le déploiement.

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:


