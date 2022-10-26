---
title: "Recevoir et analyser les données des compteurs EDF numérique (linky inclus)"
date: 2022-10-26T19:09:19+02:00
slug: recevoir_analyser_edf_teleinfo_linky
tags: [ "tech", "go", "Raspberry pi", "Thésaurisation compulsive des données"]
---

## Trop long, j'ai pas le temps. 

J'ai sorti une lib go pour lire les données Téléinfo des compteurs EDF électroniques. Les blancs et les moches de type [linky](https://fr.wikipedia.org/wiki/Linky). 

[https://git2.riper.fr/ztec/go_edf_teleinfo](https://git2.riper.fr/ztec/go_edf_teleinfo) aussi sur [github](https://github.com/ztec/go_edf_teleinfo)

## Il était une fois
Depuis 2018, j'ai un raspbery-pi accrocher à coter de mon compteur [EDF](https://fr.wikipedia.org/wiki/%C3%89lectricit%C3%A9_de_France). 
En suivant quelques tutoriels sur le net, je les ai connectés de façon à pouvoir suivre en temps réel ma consommation électrique.

Pour la faire courte, les compteurs électroniques d'EDF (même avant le linky), on trois bornes en bas à droite. Sur les 3, il y en 
a deux qu'on peut utiliser pour recevoir un flux série constant de donnée en provenance du compteur. 
Je ne vais pas detailer la procédure  car il y a pleins d'autre gens qui l'on fait bien mieux que je ne le ferais. Une petite recherche
DuckDucGo sur "EDF téléinfo raspbery-pi" donnera de bons résultats.

{{< photo-gallery >}}
{{< photo src="linky.jpg"       name="Le linky tout moche avec le raspbery-pi a coté (tout moche aussi)" >}}
{{< photo src="connection.jpg"  name="Les connections sur le Linky" >}}
{{</photo-gallery>}}


En realité, j'ai pété toute la partie réception des données fin 2019, donc j'ai plus d'historique (sadFace), mais 
je n'ai jamais enlevé le raspbery-pi pour autant. La flem quoi!

Entre temps, ENEDIS est passer changer mon compteur. Le technicien était un peu surpis de voir deux fils sortir du compteur,
mais apres explications, il a vite compris et a meme pris le temps de remettre soigneusement les fils sur les bonnes 
bornes sur le nouveau compteur de couleur verte affreuse ! Ensuite, le raspbery-pi est resté là, sans que je fasse quoi que ce soit. 
La flem quoi!

Avec les récentes evolutions des tarifs électriques, m'est revenu l'envie de voir ma consommation électrique. (innocent face)
A ce stade, je ne sais meme pas si la Téléinfo est activé sur mon compteur et si mon code marche toujours. D'ailleurs, il est ou mon code ? (thinking face)

Je fouine dans de vieux backups (merci les backup (happy face), hesitez pas à lire [comment je gère mes backups]({{< ref "/post/tech/borg-backup" >}} "Borg backup"))
et je retrouve mon code de l'époque. Je le remets dans un dépot, rajoute quelques lignes de debug, compile et je test sur le raspbery-pi.

Miracle, ça marche du premier coup. J'ai rien eu à changer.

```
Oct 26 19:27:31 compteur plumbus[3960]: time="2022-10-26T19:27:31+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906199 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=750 PTEC=HP..
Oct 26 19:27:32 compteur plumbus[3960]: time="2022-10-26T19:27:32+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906199 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=760 PTEC=HP..
Oct 26 19:27:34 compteur plumbus[3960]: time="2022-10-26T19:27:34+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=770 PTEC=HP..
Oct 26 19:27:35 compteur plumbus[3960]: time="2022-10-26T19:27:35+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=800 PTEC=HP..
Oct 26 19:27:36 compteur plumbus[3960]: time="2022-10-26T19:27:36+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=790 PTEC=HP..
```

Je met ça dans mon nouveau système de stockage de data, et me revoilà avec de joli graph

{{< illustration src="Graph.png"  name="Dashboard EDF"   alt="Dashboard de suivis de consommation électrique" resize="no" >}}

Vous pouvez maintenant vous moquer de moi et de ma consommation électrique, car ce n'est pas du joli joli. J'en reparlerais surement un jour.

## Librarie Go

Bon, pourquoi je vous raconte ma vie comme ça là-dessus ? Car j'ai décidé de publier le bout de code
que j'utilise que j'ai ~volé je ne sais plus où~ fait il y a quelques années sur internet. 
Si jamais vous faites, vous aussi, votre domotique maison en GO vous aurez un peu de code en mois à écrire.

[https://git2.riper.fr/ztec/go_edf_teleinfo](https://git2.riper.fr/ztec/go_edf_teleinfo) aussi sur [github](https://github.com/ztec/go_edf_teleinfo)

Bon, je ne vais pas vous mentir. Ce n'est pas le plus beau code de ma vie. Déjà, car à la base, il date de 2018. Mes débuts avec GO.
Ensuite, parce que je ne l'ai pas amélioré du tout. Je le pose en ligne comme ça, sans garantie. Sans test même.

Si le moi futur à une absence de Flem, il pourra toujours ajouter des tests et complété le support de la Spec d'ENEDIS.
Bonne chance!

### Ça fé quoi ?

La lib propose 3 chose en gros
 - Un moyen d'identifier le début et la fin des trames Téléinfo
 - Un moyen de parser le contenu des trames, et de les validées grace au checksum inclus
 - Une structure toute simple qui permet autocompletion dans vos éditeurs favoris

Si vous voulez plus d'info, le Readme est là pour ça.

### Ça a besoin de quoi ?

Basiquement, vous devez obtenir les trames teleinfo qui sont envoyé par le compteur EDF.
Le plus simple, c'est d'utiliser l'[UART](https://fr.wikipedia.org/wiki/UART) du raspbery-pi, de le configurer avec les bons paramètres,
et de l'ouvrir en lecture dans votre programe. 

```
/!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ 

Ne connectez pas le raspbery-pi directement aux bornes du compteur ! 
Referez vous aux montage disponnible sur internet a base d'Optocoupleur, ou plus simplement 
des equipement pret a l'emploi qui se trouvent pour 15euros

/!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ 
```

en go, ça donne un truc comme ça :

Extrait du [Readme.md](https://git2.riper.fr/ztec/go_edf_teleinfo/src/branch/main/README.md)
```go
fi, err := os.Open("/dev/ttyAMA0") // Open the interface. It must be already configured with correct parameters
scanner := bufio.NewScanner(fi) // Creating a scanner reading incoming data from interface
scanner.Split(go_edf_teleinfo.ScannerSplitter) // Adding a "content splitter" to identify each teleinfo messages
for {
    for scanner.Scan() {
        teleinfo, err := go_edf_teleinfo.PayloadToTeleinfo(scanner.Bytes()) // Reading the latest packet  
        if err != nil {
            fmt.Printf("ERROR %s. %#v\n", err, teleinfo)
            continue
        }
        fmt.Printf("EDF TELEINFO PAYLOAD %#v\n", teleinfo) // You can now use this data as you wish
    }
}
```

Pour ma part, les données finissent dans un collecteur prometheus, et j'ai configuré
mon prometheus pour récupérer les metrics toutes les 5 secondes.

Ça donne un truc de ce genre

```go
teleinfo, err := go_edf_teleinfo.PayloadToTeleinfo(scanner.Bytes())
if err != nil {
    services.GetLogger().WithError(err).Error(err)
    continue
}
edfPAPP.Set(float64(teleinfo.PAPP))
edfPAPPHistogram.Observe(float64(teleinfo.PAPP))
edfIINST.Set(float64(teleinfo.IINST))
edfIINSTHistogram.Observe(float64(teleinfo.IINST))
edfHCHC.Set(float64(teleinfo.HCHC))
edfHCHP.Set(float64(teleinfo.HCHP))
```

### Contribution ?

Si vous voulez contribuer et ~corriger mes erreurs~ améliorer le truc, c'est avec grand plaisir. Ouvrez une PR
sur Github et vous recevrez plein de câlins virtuels.


---

Voilà voilà. Si quelqu'un sur terre a besoin de ça un jour, alors cool. Sinon, il y aura
toujours le moi future qui va surement tous pété à nouveau dans 6 mois et qui recommencera dans 5 ans tout pareil 
(je crois qu'il n'apprend pas de ses erreurs)


Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) 😗