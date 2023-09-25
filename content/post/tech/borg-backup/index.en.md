---
title: "Backup with Borg"
date: 2021-04-18T17:59:00+02:00
tags: ["linux", "raspberry-pi", "tech"]
aliases:
  - /en/post/tech/borg-backup/
---

You probably already heard of the [OVH's recent fire](https://twitter.com/olesovhcom/status/1369478732247932929).
It was a hard reminder for many people and companies. Many websites and services had big outage consequently and some 
[lost everything in the fire](https://twitter.com/playrust/status/1369611688539009025)

{{< illustration src="OVH-Datacenter-On-Fire.jpg"        name="OVH is on fire"            alt="Picture of OVH's strasbourg datacenter burning" >}}

Most website went down for few hours. Avoiding service interruption when a whole datacenter disappear is not something easy. Some already had everything in place
for this kind of scenario. I won't talk about that today.

Today, I will explain how I do my personal backup.

## The basics
When talking backup, we often point out 3 rules to follow:

 - Having at least 3 copies of you data
 - At least two copies on different media type
 - The third copy must be somewhere else (not in the same geographic space as the other two)

The most important and often forgotten  bullet point is the last one. If your backups are stolen or destroyed all together, 
they are not really useful anymore.

The cloud is a good third place to store backup, but I decided to avoid it for cost's reasons, principle, and learning interest.

## Borg

[Borg](https://www.borgbackup.org/) is a command line tool, meaning there is no interface to click on, meant to back up data incrementally. 
This mean it can reduce backup time by only focusing on changed files instead of doing a full swipe every times. Borg also use a powerfull
deduplication mechanism to reduce backup archive size. If two identical files are found, they will not be store twice, but only once.

Borg works mostly on linux, but I successfully used it on Windows thanks to the [Windows Subsystem Linux](https://docs.microsoft.com/en-us/windows/wsl/install-manual)

Borg works by scanning a folder, and copying it's content to a borg archive via a ssh connection. 

A basic example:

```bash
borg create -s locutus@host:/path/borg/backup/repo/$REPO_NAME::$ARCHIVE_NAME-$CURRENT_DATE  /path/to/backup
```

Will give you this output 

```bash
------------------------------------------------------------------------------
Archive name: mirror-2021-04-13-13h57
Archive fingerprint: c2f6ffa259f358636371439767dd9edc571ec01d84aa474c052c555b70b5c76f
Time (start): Tue, 2021-04-13 13:59:22
Time (end):   Tue, 2021-04-13 13:59:27
Duration: 4.67 seconds
Number of files: 0
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                  712 B                640 B                640 B
All archives:                2.77 TB              2.79 TB            137.29 GB

                       Unique chunks         Total chunks
Chunk index:                   53243              1224153
------------------------------------------------------------------------------
```

I invite you to follow the [official documentation](https://borgbackup.readthedocs.io/en/stable/) to find out how to create repository.
There is a lot of ways to do it, I won't go in details.

### Overview

Basically, here is how I built my backup system:

{{< illustration src="schema.png"        name="Global schematics"            alt="Global schematics"  resize="no" dark-protection="yes" >}}

##### Borg server 

I have a server dedicated to receive borg backup. It's a Virtual Machine in my case, but it could easily be a raspberry pi. 
The disk size is the most important aspect of it. It must be big enough to received all my backups.

I reserved 1TB on a [RAID 5](https://en.wikipedia.org/wiki/Standard_RAID_levels#RAID_5) disk array. If I need more one day
I'll have to buy new hard drives, or do some cleaning.  

Remember that I do  incremental backups. This ensures I keep a history of my files though their life. If I delete a file
it will not be deleted from backups for a long time (configurable)

I created one borg repository for each server and computer I wish to backup.

```bash
root@borg:/backup# ls -la
total 40
drwxrwx--- 10 locutus locutus 4096 Nov  8 01:57 .
drwxr-xr-x  4 root    root    4096 Jun 19  2020 ..
drwxrwx---  3 locutus locutus 4096 Jul 24  2020 windows
drwxrwx---  3 locutus locutus 4096 Nov 19 00:44 home
drwxrwx---  3 locutus locutus 4096 Apr 14 06:18 knode01
drwxrwx---  3 locutus locutus 4096 Apr 14 06:18 knode02
drwxrwx---  3 locutus locutus 4096 Jun 20  2020 martine
drwxrwx---  3 locutus locutus 4096 Nov  8 01:52 pouet
drwxrwx---  3 locutus locutus 4096 Apr 13 00:58 pouet-home
drwxrwx---  3 locutus locutus 4096 Nov  8 01:53 pouet-home-old
```

All my backup are accessible to one user `locutus`. This use is used to connect to the borg server via ssh. All my backup 
computer and servers will have credentials to connect to it (one public ssh key per server)

All repository are encrypted and use a different key. Only the corresponding server and my self know the key.

##### Linux server

On each of my VM I will to backup things, a script goes thought all my important folders and backups them.

```bash
#!/bin/bash
source /root/.bashrc
ARCHIVE_NAME="kube"
CURRENT_DATE=$(date +"%Y-%m-%d-%Hh%M")
echo "Creating a backup archive of /riper/kube named '$ARCHIVE_NAME-$CURRENT_DATE'"
borg create \
 --checkpoint-interval 600 \
 --exclude-caches\
 --verbose \
 -p \
 -s ::$ARCHIVE_NAME-$CURRENT_DATE \
 /riper/kube && \
borg prune -v --list --keep-within=10d --keep-weekly=4 --keep-monthly=12 --keep-yearly=-1
```

I scheduled it using a [CRON](https://fr.wikipedia.org/wiki/Cron)
```bash
18 6 * * * /root/borg-backup-volumes >> /var/log/backup-kube 2>&1
```

In the root `.bashrc`, there is environment variables containing all details and secrets required by borg.
Do not forget to read protect it, otherwise the security key will not be secret.

```bash
BORG_OPTS=""
BORG_SERVER="ssh://locutus@norghost"
BORG_REPO_PATH="/backup/knode01"
export BORG_REPO="$BORG_SERVER$BORG_REPO_PATH"
export BORG_PASSPHRASE="redacted"
```

The last line of the script is here to do some cleanup of borg archives. I've decided to keep files for a certain amount of times
in my backup.

```bash
borg prune -v --list --keep-within=10d --keep-weekly=4 --keep-monthly=12 --keep-yearly=-1
```
 - All archives are kept as is for 10 days (one per days via CRON)
 - After 10 days, only 4 archive per week are kept for 1 month
 - After one month, 12 archives are kept per month
 - After a year, everything is kept as is. (This will blow up some day)

As you can read, there is an issue. After few years I might miss some space if I do not alter the last parameter. I'm waiting 
to have to do it before setting it, `-1` meaning `keep everything`.

##### Windows

On Windows, I did not setup CRON and only do manual trigger.

[Once debian installed as WSL](https://docs.microsoft.com/en-us/windows/wsl/install-manual) , 
I did exactly the same thins as my linux servers. Windows mounting points allow to access
all drives, and we can backup them like any other folder.

As an example, I backup my pictures with this script

```bash
ARCHIVE_NAME="Photos"
CURRENT_DATE=$(date +"%Y-%m-%d-%Hh%M")
echo "Creating a backup archive of /mnt/s/photos named '$ARCHIVE_NAME-$CURRENT_DATE'"
borg create \
 --checkpoint-interval 600 \
 --exclude-caches\
 --verbose \
 -p \
 -s ::$ARCHIVE_NAME-$CURRENT_DATE \
 /mnt/s/photos && \
borg prune -v --list --keep-within=10d --keep-weekly=4 --keep-monthly=12 --keep-yearly=-1
```

##### raspberry PIs

I stated it at the beginning of this article, 3 copies are needed with one elsewhere. For now, I only have

 - The original copy
 - One copy on the borg server

Both are physically located on the same place, at my apartment. I decided to use Raspberry pi to do the other copies.
I configured two of them (Raspberry pi 3)

On them, I installed the classical raspbian, and configured OpenVPN to access my backup network. 
This VPN ensure once they are connected to it, they can only access to what's needed, meaning the Borg server.
I will probably write something about how I use OpenVpn (I use PfSense).

Each Raspberry pi has an usb hard drive attached. Each drives at least have as the same capacity as the Borg server.

Thanks to the VPN, I can use Raspberry Pi anywhere on the world as long as an internet access is available. Via Wifi or best, ethernet. 


###### borg archive in borg archive

My first idea was to simply do an `rsync` of all borg's repository on each Raspberry pi. 
To avoid losing my copy if I delete (willingly or not),the original source, I decided to avoid simple copy (with or without rsync).

Instead, I simply reused borg. For each borg repository, I create a corresponding repository on each Raspberry pi.
I simply create archive of my borg repository inside those. 
I end up with a borg repository inside another borg repository.

I do it this way because I have the benefice of the history. If I do something wrong on my main server, I sil have old 
copies available on each Raspberry pi.
As objects in borg archive are almost immutable, the deduplication process make those copies really space efficient.

To sum up:

 - All my servers and computer create borg archive on the main Borg server.
 - The Borg server create archive copy on each Raspberry pi via ssh though the VPN
 - Borg repository on Raspberry pi are not encrypted as the original ones already are.

I've setup those cron to do copies automatically: 

```bash
57 13 * * * /home/locutus/borg/mirror-borg.sh IP-RASPBERRY-PI-1 >> /var/log/borg/IP-RASPBERRY-PI-1 2>&1
57 13 * * * /home/locutus/borg/mirror-borg.sh IP-RASPBERRY-PI-2 >> /var/log/borg/IP-RASPBERRY-PI-2 2>&1
```

```bash
#!/bin/bash
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK="yes"
if [ $# -eq 0 ]
  then
    echo "No arguments supplied, please specify hostname to mirror to"
fi

TARGET=$1
echo "Create repository if they does not exist"
ls -l /backup/ | awk '{print $9}'|tail -n +2  | xargs -I {} -n 1 /usr/local/bin/borg init --encryption=none locutus@$TARGET:/backup/{}

LIST=$(ls -l /backup/ | awk '{print $9}'|tail -n +2)

ARCHIVE_NAME="mirror"
CURRENT_DATE=$(date +"%Y-%m-%d-%Hh%M")
declare -a arrayList
while read -r line
do
    arrayList+=("$line")
done <<< "$LIST"

for REPO_NAME in "${arrayList[@]}"
do
  echo "Creating a backup archive of $REPO_NAME named '$ARCHIVE_NAME-$CURRENT_DATE'"
  /usr/local/bin/borg create \
   --checkpoint-interval 600 \
   --exclude-caches\
   --verbose \
   -p -x \
   -s locutus@$TARGET:/backup/$REPO_NAME::$ARCHIVE_NAME-$CURRENT_DATE \
   /backup/$REPO_NAME
done <<< "$LIST"
```

I end up with two Raspberry pi containing a copy of my central Borg server, only one day behind.

I keep one at my place (this is my second storage type), and I keep the other one at a family member's place (where Optical fiber connection is available). I have my "elsewhere" copy this way.

A Raspberry pi has a really low power consumption, and you can lower it more by hacking it to only power it once a day for the required time only.
It's also cheap, and the big budget are the usb drives.

## Monitoring

It's really cool to have automatic backup and stuff, except when you need it and discover all automatic stuffs did not worked for some days.
The best is to be warned when something is a bit off. 

When a cron end up with an error, an alert email is enough.

I follow backup disk space using [prometheus](https://prometheus.io/). In fact, I have an ongoing alert I must resolve!

![Disk space alert](alert-grafana.png "Grafana representation of alerts, with one red indicating disk space is low for a month")

My backup disk space do not evolve a lot, here 14 days on borg, and the two Raspberry pi. (Raspberry pi drivers are 1.7T and 2.6TB against only 1TB for the borg server)

![Disk space](disk-space-used.png "Graphical representation of disk space, pretty flat over 14 days for all 3")

Recently, I moved the Raspberry pi synchronisation cron on [GoCD](https://www.gocd.org/) for testing purpose. It works well, I will have a beautiful web interface to trigger synchronisation and see quickly if jobs are working well. 
GoCd is in my ToolBox anyway, using it has no real cost.

![GoCD dashboard](gocd-borg-raspberry-sync.png "GoCD Dashboard with a green sycnrhonisation job")

## Summary

I use this setup for less than a year, and a lots of details are not perfect, however:

 - It's cheap if you compare it to cloud solutions with 1TB or more
 - Free and Open source based
 - Borg allow to mount any archive and go through it like any folder allowing to recover files easily.
 - Security wise, it's good enough for my personal use cases.
 - Everything is automatic and no human intervention required once it's setup
 - A good monitoring is required, mostly on disk space, to know quickly when to do some cleaning or buy new drives.

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:



