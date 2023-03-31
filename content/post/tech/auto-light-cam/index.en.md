---
title: "Webcam on = Lights on (Philips Hue)"
date: 2023-03-31T11:00:00+02:00
slug: "auto-light-when-using-webcam"
tags: ["linux", "philips-hue", "tech", "bash", "IA-helped"]
promotions:
    mastodon: https://mamot.fr/@ztec/110118599202415170
    twitter: https://twitter.com/Ztec6/status/1641827403587518466
---


On my desk at home, while working remotely and doing a video call, I turn on my webcam.
I find it more pleasant for others to be able to see me.
I also appreciate it when others do the same, but everyone has their preferences on this subject.

To ensure that my image is clear and clean, I installed a lamp that shines a lot of lumens on my face.
This way, I'm sure I'm visible!
I used to forget to turn it on or worse, turn it off. So, I automated the process.


{{< photo-gallery >}}
{{< photo src="img/light.jpg" name="Light and webcam" alt="A webcam on top of a light between two screens" >}}
{{</photo-gallery>}}

The lamp I use is a [Philips Hue Play](https://www.philips-hue.com/en-us/p/hue-white-and-color-ambiance-play-light-bar-single-pack/7820130U7), which can be controlled through the entire Philips Hue ecosystem.

I also have a tablet on my desk with big buttons to turn the lamp on and off.
It's convenient, but it still requires an extra gesture.


{{< photo-gallery >}}
{{< photo src="img/tablet.jpg" name="Control tablet" alt="Tablet on the desk with big square buttons to turn on or off lights including the webcam light" >}}
{{</photo-gallery>}}

##API to turn on the lamp

Philips Hue lamps can be controlled through the bridge, which has a fairly simple REST API.

After some research on the internet, I built a script snippet to turn the lamp on or off:

```bash
#!/bin/bash
HUE_BRIDGE_IP="10.20.0.4"
HUE_USER_NAME="secretCodeYouGetByPressingTheBridgeButton"

echo "Turning off the light"
curl --insecure -X PUT -d '{"on": false}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"


echo "Turning on the light"
curl --insecure -X PUT -d '{"on": true}'  "https://${HUE_BRIDGE_IP}/api/${HUE_USER_NAME}/lights/4/state"
```

To access the API on the bridge itself, this page describes the steps to follow: https://developers.meethue.com/develop/get-started-2/

There is a process to obtain the "username" which serves as a secret code.
To put it briefly, you need to send the following request:
```bash
curl -X POST -d '{"devicetype":"nom_de_votre_script"}'
```
Quickly press the button on the bridge and start again.
The code is then returned, and I write it down, notably in the HUE_USER_NAME variable.
This code must then be inserted in the URL between /api/ and the "resources" path.

Next, I had to understand how the API works. In summary:

 - There are "resources" that represent the scenes that we have configured (via an application, for example). The scenes define the desired state for each lamp in the scene.
 - There are "resources" for each lamp to modify them.
 - There is, of course, the possibility to retrieve the list of scenes and lamps. 
 - Applying a scene involves obtaining the list of desired states for each lamp and making a call for each with the scene values.

I didn't go further. There are probably subtleties for dynamic scenes or certain features. After some trial and error, I discovered that the number of my lamp is 4.

## Webcam usage detection
I did some research on the internet, and I don't quite remember where I found the answer.
To detect if my webcam is being used, I just need to run `lsmod` and "look" at the status in front of `uvcvideo`. It looks like this:

```bash
IS_CAM_IN_USE=$(lsmod | grep uvcvideo|head -n 1|awk '{print $3}')
```
This command outputs a 0 or 1. If there's more than one webcam, it's likely that the method needs to be adapted a bit.

## Webcam settings
With the light on, no need to let the webcam adjust it setting itself. I can set it how I want with fixed exposition time, sensibility and white balance. 
This way, I won't look sick because the white balance is wrong.


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
Those are my settings. Play with them to find your best on your hardware. 


## Final assembly

To build the final script, we just need to put everything together

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

I added a state file to remember whether the lamp is on or off. This is not mandatory, but it saves me from making an API call every second. 
In fact, when I start my computer, I run the following script, which simply runs the previous script every second.


```bash
~/bin/cam-watcher.sh
#!/bin/bash
while true; do
	~/bin/auto-cam.sh
	sleep 1
done
```
And voilà! When I use my webcam, the light turns on automatically. 
It resumes the last setting I used. 
Therefore, I can still adjust its brightness with the tablet (because sometimes it's too intense for my sleepy morning eyes).

## About de Philips Hue

I fell into the Philips Hue trap a few years ago, but I am satisfied with it - probably a Stockholm syndrome.
I haven't tested other brands, including Elgato for my webcam lighting. 
So, I don't know if it's easy to control them without installing a spy app on your phone. 
Regarding Philips Hue, everything is done locally, and the APIs are relatively easy to access. 
This makes it easy for the community to build around it. 
I was pleasantly surprised by how little time it took me to create this script. 
Writing this article was probably longer.

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:



