---
title: "🐙 un moteur de recherche d'émojis"
date: 2023-04-02T15:00:00+02:00
slug: "moteur-de-recherche-emojis"
tags: ["tech", "go", "emoji", "IA-helped"]
promotions:
    mastodon: https://mamot.fr/@ztec/110130206712339632
    twitter: https://twitter.com/Ztec6/status/1642570030654304259
---

Pour l'un de mes projets, j'ai dû gérer des emojis. Le but était de créer un moteur de recherche d'emojis.
Je ne pars pas de rien, car je dois inclure le tout dans l'un de mes programmes qui tourne déjà, et c'est en Go.
Regardons ensemble comment construire un petit moteur de recherche en Go.

Pour les plus impatients, l'ensemble des exemples de code de cet article se trouve ici : [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go)

Vous pouvez aussi tester et voir le résulta final. Tous les détails son ici: [poulpe.ztec.fr - Le moteur de recherche d'emoji open-sourcé]({{< ref "poulpe-emoji-search-engine" >}})
## :boar: Émojis! Attrapez-les tous!

En premier lieu, il m'a fallu trouver la liste de tous les emojis qui existent. Le site de l'Unicode
en met une à disposition :

https://unicode.org/Public/emoji/15.0/emoji-test.txt

Le fichier ressemble à ceci :

```
[…]
# group: Smileys & Emotion

# subgroup: face-smiling
1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face
1F603                                                  ; fully-qualified     # 😃 E0.6 grinning face with big eyes
1F604                                                  ; fully-qualified     # 😄 E0.6 grinning face with smiling eyes
1F601                                                  ; fully-qualified     # 😁 E0.6 beaming face with smiling eyes
1F606                                                  ; fully-qualified     # 😆 E0.6 grinning squinting face
1F605                                                  ; fully-qualified     # 😅 E0.6 grinning face with sweat
[…]
```

On y trouve le code Unicode, l'émoji lui-même et une description. Le fichier est prévu pour les machines, il devrait donc être facile à parser.

Avant de se lancer tête baissée dans cette direction, regardons ce que la communauté a déjà fait sur le sujet. J'ai trouvé :
- [github.com/enescakir/emoji](https://github.com/enescakir/emoji), mis à jour en 2020.
- [AkinAD/emoji](https://github.com/AkinAD/emoji), mis à jour en 2022 (un fork du premier).
- [github.com/kenshaw/emoji](https://github.com/kenshaw/emoji), mis à jour en 2021.

En regardant dans le code de ces projets j'ai trouver un truc très intéressant :
https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json

Le fichier, qui est mis à jour régulièrement, est parfait et peut être encore plus facilement parsé. C'est du JSON.
En plus de ça, il contient quelques informations supplémentaires comme les alias.

This is the way, on va parser ce fichier directement !

```go
package pouet

import (
	"encoding/json"
	"github.com/go-zoox/fetch"
)

type EmojiDescription struct {
	Emoji          string   `json:"emoji"`
	Description    string   `json:"description"`
	Category       string   `json:"category"`
	Aliases        []string `json:"aliases"`
	Tags           []string `json:"tags"`
	HasSkinTones   bool     `json:"skin_tones,omitempty"`
	UnicodeVersion string   `json:"unicode_version"`
}

type GithubDescriptionResponse []EmojiDescription

func fetchEmojiFromGithub() (results []EmojiDescription, err error) {
	response, err := fetch.Get("https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json")
	if err != nil {
		return
	}
	err = json.Unmarshal(response.Body, &results)
	return
}
```

J'ai utilisé `github.com/go-zoox/fetch` pour récupérer le fichier, car je suis paresseux.

## :zebra: Émoji, Scannez-les tous!

Dans mon programme, j'utilise déjà [Bleve](https://blevesearch.com/) pour indexer d'autres trucs. Je vais donc l'utiliser ici aussi.
L'opération est plutôt simple, car je n'ai pas à conserver de copie de l'index, juste une version en mémoire suffit.

```go
package pouet

import (
	"fmt"
	"github.com/blevesearch/bleve/v2"
	"github.com/sirupsen/logrus"
	"strconv"
	"strings"
)

var (
	index  bleve.Index
	emojis []EmojiDescription
)

func indexEmojis() error {
	// we create a new indexMapping. I used the default one that will index all fields of my EmojiDescription
	mapping := bleve.NewIndexMapping()
	// we create the index instance
	bleveIndex, err := bleve.NewMemOnly(mapping)
	if err != nil {
		return err
	}
	// we fetch the emoji from the internet. This can fail, and may be embedded for better performance
	e, err := fetchEmojiFromGithub()
	if err != nil {
		logrus.WithError(err).Error("Could fetch emoji list")
		return err
	}
	emojis = e
	for eNumber, eDescription := range emojis {
		// this will index each item one by one. No need to be quick here for me, I can wait few ms for the program to start
		err = bleveIndex.Index(fmt.Sprintf("%d", eNumber), eDescription)
		if err != nil {
			logrus.WithError(err).Error("Could not index an emoji")
		}
	}
	index = bleveIndex // we make the index available
}
```
Une fois que la fonction `indexEmojis` est appelée, j'ai un `index` prêt à l'emploi pour chercher des émojis. Testons-le.

```go
package pouet

import (
	"fmt"
	"github.com/AkinAD/emoji"
	"github.com/blevesearch/bleve/v2"
	"github.com/sirupsen/logrus"
	"strconv"
	"strings"
)

var (
	index  bleve.Index
	emojis []EmojiDescription
)

func Search(q string) (results []EmojiDescription) {
	if index == nil {
		// no Index mean indexEmojies was not called yet or did not finished. No results (boot process)
		return
	}
	// we create a query as bleve expect.
	query := bleve.NewQueryStringQuery(q)
	// we define the search options and limit to 200 results. This should be enough.
	searchrequest := bleve.NewSearchRequestOptions(query, 200, 0, false)
	// we do the search itself. This is the longest. Approximately few hundreds of us 
	searchresults, err := index.Search(searchrequest)
	if err != nil {
		logrus.WithError(err).Error("Could not search for an emoji")
		return
	}
	
	// we return the results. I use the index to find my original object stored in `emojis` because it's simpler. Optimisation possible.
	for _, result := range searchresults.Hits {
		numIndex, _ := strconv.ParseInt(result.ID, 10, 64)
		results = append(results, emojis[numIndex])
	}
	return
}
```

J'ai choisi d'utiliser `NewQueryStringQuery` car il permet [pas mal d'options](https://blevesearch.com/docs/Query-String-Query/) lors de la recherche, directement via la chaîne.
Comme ça je pourrais ajouter des modificateurs pour affiner mes recherches. J'utilise beaucoup ces options pour les autres trucs que j'indexe, ça ne sera peut-être pas si utile que ça sur des émojis,
mais ça ne coûte pas grand-chose alors je le garde quand même.

> Détendez-vous et imaginez un clip musical de moi qui ajoute le code que vous avez vu dans mon programme et créant une superbe interface pour envoyer les recherches et voir les résultats.


{{<flex 2>}}
![Résultat de la recherche `grin` affichant l'émoji `grin` comme prévu](img/search-ok-grin.png "Résultat de la recherche grin")
![Résultat de la recherche `smile` affichant plusieurs émojis souriants](img/search-ok-smile.png "Résultat de la recherche smile")
{{</flex>}}

## :bubble_tea: Recherche approximative (Fuzzy)

C'est cool, les résultats sont bons, mais il semblerait qu'il y ait des ratés.

![Résultat de la recherche `hug` qui n'affiche pas de résultats](img/search-ko-hug.png "Résultat de la recherche hug")

Ici, je devrais avoir un émoji en résultat, c'est :hugs:!. Si j'ajoute le `s` à la requête, le moteur le trouve, mais pas sans.
Essayons d'améliorer ça en acceptant des résultats approximatifs.

L'idée est de chercher les résultats proches de la recherche souhaitée, même s'ils ont un ou deux caractères de différent.
Pour faire ça, on va utiliser un truc qui s'appelle la [Distance de Levenshtein](https://fr.wikipedia.org/wiki/Distance_de_Levenshtein).
C'est cool, car Bleve intègre déjà ce mécanisme. Malheureusement, je n'ai pas trouvé comment l'utiliser avec les `QueryStringQuery`, notamment pour ajouter
un niveau d'approximation par défaut. Je peux toujours ajouter un `~` après un mot pour l'activer sur celui-ci, mais ce n'est pas pratique.

C'est un petit projet perso, alors on va y aller en suivant la méthode [RACHE](https://www.la-rache.com/).
Si je n'ai pas de résultats avec la première méthode, je tente avec une recherche dédiée.

```go
func Search(q string) (results []EmojiDescription) {
	if index == nil {
		// no Index mean indexEmojies was not called yet or did not finished. No results (boot process)
		return
	}
	// we create a query as bleve expect.
	query := bleve.NewQueryStringQuery(q)
	// we define the search options and limit to 200 results. This should be enough.
	searchrequest := bleve.NewSearchRequestOptions(query, 200, 0, false)
	// we do the search itself. This is the longest. Approximately few hundreds of us 
	searchresults, err := index.Search(searchrequest)
	if err != nil {
		logrus.WithError(err).Error("Could not search for an emoji")
		return
	}
	
	// If we have no results we try to do a basic fuzzy search
	if len(searchresults.Hits) == 0 {
		// this time, we create a fuzzy query. The rest is the same as before. CopyPasta style. 
		fuzzyQuery := bleve.NewFuzzyQuery(q)
		searchrequest := bleve.NewSearchRequestOptions(fuzzyQuery, 200, 0, false)
		searchresults, err = index.Search(searchrequest)
		if err != nil {
			logrus.WithError(err).Error("Could not search for emoji")
			return
		}
	}
	// we return the results. I use the index to find my original object stored in `emojis` because it's simpler. Optimisation possible.
	for _, result := range searchresults.Hits {
		numIndex, _ := strconv.ParseInt(result.ID, 10, 64)
		results = append(results, emojis[numIndex])
	}
	return
}
```
![Résultat de la recherche `hug` qui affiche maintenant plusieurs résultats dont l'emoji `hug`](img/search-ok-hug.png "Résultat de la recherche hug")

Cette fois, c'est bon, j'ai bien mon émoji câlin. J'ai également quelques autres résultats, mais ça va. Je ne m'attends pas à avoir mon résultat en premier, du moment qu'il est visible sans descendre dans la page, ça me convient.

> note: j'aurais pu aussi utiliser une recherche par préfixe, mais je ne cherche pas toujours en utilisant le début du nom des émojis, donc je préfère la recherche fuzzy

## :purple_square: Les couleurs de peau

Si je cherche pour l'émoji `ok hand`, je le trouve. Cependant, il n'y a que la version de base, la jaune. J'aimerais bien aussi voir les variations quand il y en a.

![Résultat de la recherche `ok hand` n'affichant que des émoji jaune](img/search-ok-hand-no-black.png "Résultat de la recherche ok hand")

> Détendez-vous une seconde encore, et imaginez qu'un narrateur fait irruption dans votre tête avec une voix profonde et raconte :
> "Zed ne le sait pas encore, mais inclure ces jolis émojis avec toutes les couleurs de peau sera une tâche difficile. Des heures passeront avant qu'il ne réussisse le challenge et qu'il comprenne enfin".

Avant de continuer, quelques explications sur la façon dont les émojis fonctionnent. Ce sont des caractères UTF-8. Ces caractères peuvent être combinés ensemble pour former ce qu'on appelle des [ligatures](https://fr.wikipedia.org/wiki/Ligature_(%C3%A9criture)).
Vous prenez deux codes UTF-8 caractères et vous les collez ensemble en un seul caractère. Sur votre écran, vous verrez alors un autre caractère qui n'est aucun des deux premiers. Dans les textes, c'est utilisé pour les liaisons graphiques et pour rendre le texte lisible quand deux lettres simplement coller l'une à côté de l'autre le sont moins.
La beauté du concept, c'est que si votre police ou votre écran ne supporte pas ces ligatures, vous verrez toujours les deux premiers caractères. Cool, non ?

La couleur de peau d'un émoji est gérée avec des ligatures. Vous prenez un émoji, et vous y collez le caractère de la couleur de peau que vous voulez. Le résultat sera un nouvel émoji avec le jaune remplacé par la couleur choisie. Bien sûr, il faut que la police de caractères le supporte, donc toutes les combinaisons ne sont pas possibles.

```
1F44C                                                  ; fully-qualified     # 👌 E0.6 OK hand
1F44C 1F3FB                                            ; fully-qualified     # 👌🏻 E1.0 OK hand: light skin tone
1F44C 1F3FC                                            ; fully-qualified     # 👌🏼 E1.0 OK hand: medium-light skin tone
1F44C 1F3FD                                            ; fully-qualified     # 👌🏽 E1.0 OK hand: medium skin tone
1F44C 1F3FE                                            ; fully-qualified     # 👌🏾 E1.0 OK hand: medium-dark skin tone
1F44C 1F3FF                                            ; fully-qualified     # 👌🏿 E1.0 OK hand: dark skin tone
```

La première colonne contient le code UTF-8 de chaque émoji. On voit bien que la première partie ne change pas. C'est le code de :ok_hand:.
Le second code est la couleur de peau. Nous avons donc la liste des couleurs de peau disponibles.


```go
	tones := map[string][]rune{
      "light skin tone" : []rune("\U0001F3FB"),
      "medium-light skin tone" : []rune("\U0001F3FC"),
      "medium skin tone" : []rune("\U0001F3FD"),
      "medium-dark skin tone" : []rune("\U0001F3FE"),
      "dark skin tone" : []rune("\U0001F3FF"),
	}
```

Dans les librairies dont j'ai parlé en début d'article, les émojis et leurs codes sont gérés via des `string` et utilisent la syntaxe spécifique de l'UTF-8 en Go (`\Uxxxxxxxx`).
Golang possède cependant un type dédié à la manipulation de caractères UTF-8, la `rune`. J'ai décidé de l'utiliser.
Malheureusement, il y a vraiment peu d'exemples en ligne qui utilisent les runes, surtout avec des ligatures.
J'ai utilisé la représentation en `string` ici pour que l'on voie bien le code et le lien entre les runes et le caractère.

Maintenant, on a besoin de créer un nouvel émoji pour chaque variation de couleur. Tous les émojis ne supportent pas ces variations.
Je pourrais parser le fichier original d'Unicode, mais je suis paresseux, vous savez. En plus, si vous avez fait attention avant,
le fichier qu'on parse déjà possède un champ qui donne cette information sous forme d'un `bool`, il n'y a donc rien à faire. :tada:

```go
func enhanceEmojiListWithVariations(list []EmojiDescription) []EmojiDescription {
	tones := map[string][]rune{
        "light skin tone" : []rune("\U0001F3FB"),
        "medium-light skin tone" : []rune("\U0001F3FC"),
        "medium skin tone" : []rune("\U0001F3FD"),
        "medium-dark skin tone" : []rune("\U0001F3FE"),
        "dark skin tone" : []rune("\U0001F3FF"),
    }
	for _, originalEmoji := range list {
		// we only add variations for emoji that supports it
		if originalEmoji.HasSkinTones {
			// we do it for every skin tone
			for skinToneName, tone := range tones {
				// we make a copy of the emojiDescription
				currentEmojiWithSkinTone := originalEmoji
				
				// This is the important bit that took me hours to figure out
				// we convert the emoji in rune (string -> []rune). An emoji can already be composed of multiple sub UTF8 characters, therefore multiple runes.
				// we append to the list of runes the one for the skin tone.
				// finally, we convert that in string using the type conversion. Using fmt would result in printing all runes independently
				currentEmojiWithSkinTone.Emoji = string(append([]rune(currentEmojiWithSkinTone.Emoji), tone...))
				
				// we adapt the description and metadata to match the skin tone
				currentEmojiWithSkinTone.Description = fmt.Sprintf("%s %s", currentEmojiWithSkinTone.Description, skinToneName)
				aliases := []string{}
				for _, alias := range currentEmojiWithSkinTone.Aliases {
					// we update all aliases to include the skin tone
					aliases = append(aliases, fmt.Sprintf("%s_%s",alias,strings.ReplaceAll(strings.ReplaceAll(skinToneName,"-", "_")," ", "_")))
				}
				currentEmojiWithSkinTone.Aliases = aliases
                // I cleared the unicode version because some emoji with skin tone were added way after their original. I could parse the unicode list,
				// but I'm a loafer, so I did not.
				currentEmojiWithSkinTone.UnicodeVersion = "" 
				// we add the new emoji to the list
                list = append(list, currentEmojiWithSkinTone)
			}
		}
	}
	return list
}
```

La clé :key: ici, c'est cette ligne :
```go
currentEmojiWithSkinTone.Emoji = string(append([]rune(currentEmojiWithSkinTone.Emoji), tone...))
```
Je ne suis pas un expert en Go, encore moins en UTF-8. J'ai donc sûrement raté un ou plusieurs trucs, mais après des heures à essayer d'afficher mes emojis ligaturés avec `fmt` sans succès (il y avait toujours deux caractères d'affichés), j'ai fait une conversion de type par inadvertance et ça a fonctionné ! Je n'ai aucune idée de pourquoi j'ai eu besoin de deux heures pour cela.

Nous avons maintenant nos emojis de toutes les couleurs ! :tada:

![Résultat de la recherche `ok hand` affichant toutes les variations de couleur de l'émoji de base](img/search-ok-hand-black.png "Résultat de la recherche ok hand")

## :no_entry_sign: emojis incompatibles

Mon ordinateur et mon téléphone ne supportent pas bien les emojis publiés après la version 14. Mais comme je l'ai dit plus tôt, la beauté des ligatures de l'UTF-8, 
c'est que malgré cela, je vois quand même les différents composants. De cette façon, je ne perds pas le sens original.

![Plusieurs emojis `couple with heart man man` qui affichent la couleur de peau dans un second caractère, un carré de la couleur](img/search-ok-no-ligature.png "Résultat de la recherche pour des emojis ne supportant pas les variations")

Si vous voulez tester par vous-même et bidouiller le code, vous pouvez trouver le code complet et fonctionnel sur ce repository : [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go).

Vous pouvez aussi tester et voir le résulta final. Tous les détails son ici: [poulpe.ztec.fr]({{< ref "poulpe-emoji-search-engine" >}})
## :interrobang: Pourquoi j'ai fait tout ça ?

Déjà, pourquoi pas ? Juste jouer avec des émojis, c'est fun. Mais surtout, mon but était d'avoir un moteur de recherche d'émojis sous la main pour pouvoir copier les émojis ailleurs. 
Tous les systèmes que j'ai trouvés en ligne me semblaient inadaptés et pénibles à utiliser.

- Beaucoup trop lent à charger et à chercher.
- Beaucoup trop inutile. Je ne souhaite pas chercher mon émojis dans une liste interminable d'icônes jaunes.

La meilleure solution que j'avais trouvée, c'était un raccourci vers le fichier du site Unicode. Mais comme les noms d'usage ne sont pas tous inclus, j'ai dû apprendre les versions officielles.
Puis un jour, le site d'Unicode est tombé et n'était plus disponible pendant quelques heures.

Ouais, je dois être le seul au monde qui sait quand le site d'Unicode tombe, et surtout qui est impacté par ça ! :rofl:

## :next_track_button: Et la suite ?

Ce moteur est vraiment simple, basique. Il y a plein de façons de l'améliorer. J'ai d'ailleurs déjà inclus une recherche inverse même si je n'en ai pas parlé ici.
Bleve est puissant malgré tout, mais rate certains cas évidents. Je vais voir ce qui me dérange le plus et l'améliorer en fonction de cela. Peut-être que le résultat sera open-source un jour, mais pour cela je dois encore faire du ménage dans mon projet.
Les émojis ne sont pas les seuls trucs que je "cherche" dans mon moteur de recherche. :wink:

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:
