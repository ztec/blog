---
title: "Go Library to Parse EDF Teleinfo Data"
date: 2022-10-26T19:09:19+02:00
slug: go_edf_teleinfo_release
tags: [ "tech", "go", "raspberry-pi", "data-hoarding"]
---

## TL;DR:

I just released a library to read and parse data from french electronic energy meters (linky or older models).

[https://git2.riper.fr/ztec/go_edf_teleinfo](https://git2.riper.fr/ztec/go_edf_teleinfo) also on [github](https://github.com/ztec/go_edf_teleinfo)

## Once upon a time
Since 2018, I have a raspbery-pi hanging near my [EDF](https://en.wikipedia.org/wiki/%C3%89lectricit%C3%A9_de_France) energy meter. 
Following some tutorials back then, I have connected them to follow my energy consumption in real time.

Without going into the details, EDF electronic meter (even before the ugly linky was imposed) have 3 connector on the right lower hand side.
Two of them allow to receive constant data about the meter and the instantaneous state such as power consumption.
I won't detail how I did it because there is a lot of better content that go in details online. Just do some 
duckduckgo search with "EDF, teleinfo, raspbery-pi" for example.

{{< photo-gallery >}}
{{< photo src="linky.jpg"       name="Linky with raspbery-pi on the side" >}}
{{< photo src="connection.jpg"  name="Linky connection" >}}
{{</photo-gallery>}}

Unfortunately, I broke all my data platform end of 2019. No mor history (visage triste). However, I never removed the
raspbery-pi. So, it is still there, hanging and connected to the meter, powered down. 

Meanwhilem [ENEDIS](https://fr.wikipedia.org/wiki/Enedis) the French electrical grid operator, changed my meter by one of the
new Linky. The technician that installed was a bit surprised at first to see two wire connected to the meter like that.
After some explanation he understood, and even re-installed them carefully on the new meter.
After that, the raspbery-pi stayed there, connected, but off. 

With recent european electricity price "changes", I was curious again to see my electrical trend (Visage innocent)
At this point, I don't even know if the new meter have a working Téléinfo. I don't know either if my code still works.
Speaking of code… (tête en pleine réflexion)

I search in my old backups (thanks backups (visage heureux). You can read more about them on [Borg backup]({{< ref "/post/tech/borg-backup" >}}))
I'm lucky and find my old code. I put it in a repository, add some debug lines, compile and test int on the raspbery-pi I switch on again for the ocasion.

It works! Nothing to update, re-write. It worked on the first try. I now have logs like this:

```
Oct 26 19:27:31 compteur plumbus[3960]: time="2022-10-26T19:27:31+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906199 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=750 PTEC=HP..
Oct 26 19:27:32 compteur plumbus[3960]: time="2022-10-26T19:27:32+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906199 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=760 PTEC=HP..
Oct 26 19:27:34 compteur plumbus[3960]: time="2022-10-26T19:27:34+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=770 PTEC=HP..
Oct 26 19:27:35 compteur plumbus[3960]: time="2022-10-26T19:27:35+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=800 PTEC=HP..
Oct 26 19:27:36 compteur plumbus[3960]: time="2022-10-26T19:27:36+02:00" level=info msg="EDF PAYLOAD" HCHC=5605491 HCHP=12906200 HHPHC=A IINST=3 IMAX=90 ISOUSC=30 OPTARIF=HC.. PAPP=790 PTEC=HP..
```

I put all of that in my new data hoarding platform, and here me again with nerdy graphs.

{{< illustration src="Graph.png"  name="EDF dasbhoard"   alt="Dashboard following consumption of electricity" resize="no" >}}

You can now make fun of me and my outrageous energy consumption. It's not pretty I know. I will talk about that maybe one day.

## Go library 

So, why do I invite you in my life like that ? I decided to publish the code that works and that 
I {{< strike >}}stole I don't remember where{{< /strike >}} did years ago.
Maybe you to build a personal home automation "platform" using go as your main language. With this
library, you will have less to write I hope.

[https://git2.riper.fr/ztec/go_edf_teleinfo](https://git2.riper.fr/ztec/go_edf_teleinfo) also on [github](https://github.com/ztec/go_edf_teleinfo)

I won't lie to you. It is not my best code of art. First because it's from 2018, when I started with go. Then, because I 
did nothing to improve it. I just publish it as is, with no guaranties. Not even Tests !!!

If future me's [Panic monster](https://waitbutwhy.com/2013/10/why-procrastinators-procrastinate.html) wake up some day, 
maybe some tests will appear, and the ENEDIS specification coverage could be increased.
Good luck!

### Ça fé quoi ? (what does it do ?)

The library has 3 things:
 - A mean to identify the beginning and end of teleinfo data
 - A mean to parse teleinfo data and validate it thanks to checksums included
 - A simple struct to hold all the resulting data, that is auto-completion friendly for you loved IDE

More information on the [readme.md](https://git2.riper.fr/ztec/go_edf_teleinfo/src/branch/main/README.md).


### What does it need ?

Basically, you need to get the teleinfo data sent by the EDF meter.
The simplest way, is ti use the raspbery-pi [UART](https://fr.wikipedia.org/wiki/UART), configure it with the proper
parameters then open and read the interface in you program.

```
/!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ 

Do not connect the raspbery-pi to the metter directly!
Please check onlines tutorials based on optocoupler, 
or use secial purpose equipment such as the one you can find for 15e

/!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ /!\ WARNING /!\ 
```

Finally, speaking go, it looks like this:

Extracted from [Readme.md](https://git2.riper.fr/ztec/go_edf_teleinfo/src/branch/main/README.md)
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

On my side, data are sent in a prometheus collector. I configured the prometheus server to scrap metrics every 5 seconds

That look like this

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

### Contributions ?

If you want to participate and {{< strike >}}fix my ugly code{{< /strike >}} improve the library, please do. Open a PR on github and 
you will receive tons of virtual hugs as thanks. 

---

If anyone on earth use this code one day, coool. If not, future me will anyway. 
he will probably break everything again, and start from scratch again like today, in 5 years.
(I suspecte he does not learn from mistakes)

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:
