---
title: "Webcam on = Lumière allumé (Philips Hue)"
date: 2023-03-31T03:00:00+02:00
slug: "lumiere-webcam-automatic-a-l-usage"
tags: ["linux", "philips-hue", "tech", "bash"]
---


Sur mon bureau, chez moi, quand je télétravaille et que je fais une visio, j'allume ma webcam. 
Je trouve que c'est plus sympa pour les autres de pouvoir me voir. 
J'apprécie également lorsque les autres font de même, mais chacun a ses préférences à ce sujet.

Afin que mon image soit nette et propre, j'ai installé une lampe qui m'envoie beaucoup de lumens à la figure. 
De cette façon, je suis sûr que l'on me voit bien ! 
J'oubliais souvent d'allumer ou pire, de l'éteindre. J'ai donc automatisé le processus.

{{< photo-gallery >}}
{{< photo src="img/light.jpg" name="Lumière et webcam" alt="Une webcam poser au dessus d'une lampe entre deux écrants" >}}
{{</photo-gallery>}}

La lampe que j'utilise est une Philips Hue Play, qui peut être contrôlée via l'ensemble de l'écosystème Philips Hue.

J'ai également une tablette sur mon bureau avec des gros boutons pour allumer et éteindre la lampe. 
C'est pratique, mais cela nécessite tout de même un geste de trop.


{{< photo-gallery >}}
{{< photo src="img/tablet.jpg" name="Tablette de contrôle" alt="Tablette posé sur le bureau avec des gros carré dessus pour allumer ou éteindre les lumières, donc celle de la webcam" >}}
{{</photo-gallery>}}

## API pour allumer la lampe
Les lampes Philips Hue peuvent être contrôlées via le bridge qui dispose d'une API REST assez simple.

Après quelques recherches sur internet, j'ai construit un bout de script pour allumer ou éteindre la lampe :

```bash
#!/bin/bash
HUE_BRIDGE_IP="10.20.0.4"
HUE_USER_NAME="secretCodeYouGetByPressingTheBridgeButton"

echo "Turning off the light"
curl --insecure -X PUT -d '{"on": false}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"


echo "Turning on the light"
curl --insecure -X PUT -d '{"on": true}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"
```

Pour accéder a l'API qui est sur le Bridge lui-même, cette page décris les étapes à suivre.
https://developers.meethue.com/develop/get-started-2/

Il ya notamment la procédure pour obtenir le "username" qui sert de code secret.  
Pour la faire courte, il faut envoyer la requette suivante :
```bash
curl -X POST -d '{"devicetype":"nom_de_votre_script"}'
```
Vite courir pour appuyer sur le bouton du bridge et recommencer à nouveau.
Le code est alors donné, je le note, notamment dans la variable `HUE_USER_NAME`.
Ce code doit ensuite être inséré dans l'URL entre `/api/` et le chemin des "resources".

Ensuite, il m'a fallu comprendre comment fonctionne l'API. En résumé :
- Il y a des "resources" qui représentent les scènes que l'on a configurées (via une application, par exemple). Les scènes définissent l'état souhaité pour chaque lampe de la scène.
- Il y a des "resources" pour chaque lampe afin de les modifier.
- Il y a bien évidemment la possibilité de récupérer la liste des scènes et des lampes.
- Appliquer une scène revient à obtenir la liste des états souhaités pour chaque lampe et à faire un appel pour chacune avec les valeurs de la scène.

Je ne suis pas allé plus loin. Il y a sûrement des subtilités pour les scènes dynamiques ou certaines fonctionnalités. Après tâtonnement, j'ai découvert que le numéro de ma lampe est `4`.

## Detection de l'utilisation de la Webcam
J'ai fait quelques recherches sur Internet, je ne sais plus trop où j'ai trouvé la réponse.
Pour détecter si ma webcam est utilisée, il suffit de faire un `lsmod` et de "regarder" le statut devant `uvcvideo`. Ça donne ça :

```bash
IS_CAM_IN_USE=$(lsmod | grep uvcvideo|head -n 1|awk '{print $3}')
```
Sort un `0` ou un `1`.
Il est fort probable que s'il y a plus d'une webcam, il faille adapter un peu la méthode.

## Réglage de la webcam
Avec la lumière allumée, plus besoin de laisser la webcam se régler automatiquement. 
Je peux définir les valeurs d'exposition et de balance des blancs comme je le souhaite.  
Je n'aurai plus l'impression d'être malade une fois sur deux.


```bash
v4l2-ctl --set-ctrl exposure_auto=1
v4l2-ctl --set-ctrl exposure_auto_priority=0
v4l2-ctl --set-ctrl exposure_absolute=120
v4l2-ctl --set-ctrl white_balance_temperature_auto=0
v4l2-ctl --set-ctrl white_balance_temperature=3500
v4l2-ctl --set-ctrl brightness=200
v4l2-ctl --set-ctrl contrast=110
v4l2-ctl --set-ctrl gain=170
v4l2-ctl --set-ctrl power_line_frequency=1
v4l2-ctl --set-ctrl zoom_absolute=100
```
Ces réglages sont les miens, ils s'adaptent en fonction de votre matériel ou de vos préférences.


## Assemblage final

Plus qu'à regrouper tout ça dans un script.

```bash
~/bin/auto-cam.sh
#!/bin/bash
HUE_BRIDGE_IP="10.20.0.4"
HUE_DEVICE_TYPE="linuxauto"
HUE_USER_NAME="AH1gq0t6MlKDi4cVYQuxaD-35vgq-ves2W57Tz4G"

IS_CAM_IN_USE=$(lsmod | grep uvcvideo|head -n 1|awk '{print $3}')
STATE_FILE="/tmp/hue_state"
HUE_STATE=$(cat ${STATE_FILE})

if [ "${IS_CAM_IN_USE}" == "0" ]; then
	echo CAM NOT IN USE;
	if [ "${HUE_STATE}" != "0" ]; then 
		echo "Turning off the light"
 		curl --insecure -X PUT -d '{"on": false}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"
		echo "0" > ${STATE_FILE}
	fi

else
	echo CAM IN USE;
	if [ "${HUE_STATE}" != "1" ]; then
		echo "Turning on the light"
		curl --insecure -X PUT -d '{"on": true}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"
		echo "1" > ${STATE_FILE}
		v4l2-ctl --set-ctrl exposure_auto=1
		v4l2-ctl --set-ctrl exposure_auto_priority=0
		v4l2-ctl --set-ctrl exposure_absolute=120
		v4l2-ctl --set-ctrl white_balance_temperature_auto=0
		v4l2-ctl --set-ctrl white_balance_temperature=3500
		v4l2-ctl --set-ctrl brightness=200
		v4l2-ctl --set-ctrl contrast=110
		v4l2-ctl --set-ctrl gain=170
		v4l2-ctl --set-ctrl power_line_frequency=1
		v4l2-ctl --set-ctrl zoom_absolute=100
	fi
fi
echo "END" 
```

J'ai ajouté un fichier d'état pour mémoriser si la lampe est allumée ou pas. 
Ce n'est pas obligatoire, mais ça m'évite de faire un appel à l'API toutes les secondes. 
En effet, au démarrage de mon ordinateur, je lance le script suivant, qui va simplement lancer le précédent toutes les secondes.


```bash
~/bin/cam-watcher.sh
#!/bin/bash
while true; do
	~/bin/auto-cam.sh
	sleep 1
done
```
Et voilà ! Quand j'utilise ma webcam, la lumière s'allume toute seule. 
Elle reprend le dernier réglage que j'ai mis. 
Je peux donc toujours modifier sa puissance avec la tablette (car parfois c'est trop violent pour mes petits yeux du matin).

## À propos de Philips Hue

Je suis tombé dans le piège Philips Hue il y a quelques années, mais j'en suis satisfait - syndrome de Stockholm sans doute. 
Je n'ai pas testé d'autres marques, notamment Elgato pour mon éclairage de webcam. 
Je ne sais donc pas s'il est facile de les piloter sans installer de mouchard sur son téléphone. 
Concernant Philips Hue, tout se fait en local et les API sont relativement simples d'accès. 
Il est ainsi facile pour la communauté de construire autour d'elle. 
J'ai été agréablement surpris du peu de temps qu'il m'a fallu pour faire ce script. 
Écrire cet article a sûrement été plus long.



Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:



