---
title: "One command to win 1.2To of free space"
date: 2022-11-25T00:00:00+02:00
slug: "tune2fs-reserved-space"
tags: ["linux", "ext4", "tech"]
---

### TL;DR:
Ext4 partitions [reserve 5%](https://listman.redhat.com/archives/ext3-users/2009-January/msg00026.html) of the volume to ensure enough free space is always available. 
I have tuned my ext4 filesystem to reduce reserved space from 5% to 0.05% to maximise usage on a multi Terabytes volume.
For that I use the following command

```bash
sudo tune2fs -m 0.05 /dev/vda
```

## I have NAS

I have a personal NAS that I manage myself. No TrueNAS or anything pre-made. 
I manage it myself on a computer. It's a Debian based distribution (proxmox to be exact) 
with hardware RAID drives attached.

I have a big LVM volume with an ext4 partition where I put all my files inside. I have this exact volume for 3-4 years now. 
It grew whenever I add drives to it. From few TeraBytes it is 24To large now. 

I have a monitoring in place to follow its usage. And you guessed it, empty drive space does stay empty very long. 

{{< illustration src="img/fullCargoGraph.png"  name="Cargo is full"   alt="A gauge showing that the cargo volume is full red at 97.2%" resize="no" >}}

As I'm not able to grow any [Simoleon Tree](https://sims.fandom.com/wiki/Money_tree) at my place. I cannot add drive endlessly.

{{< illustration src="img/MoneyTree.png"  name="Sims 2 money tree"   alt="A Sims2 money tree" resize="no" >}}

I perform some cleaning on a regular basis to try to keep the used space under control. I mostly delete anything not relevant anymore.
From Movies files to project dataset I abandoned I can sometimes free multiple Terabytes of data.

## Cleaning day
Today was cleaning day. After doing the usual stuff, I go on the recycle bin to permanently delete some dangling files.
I do a `df` on the server to check free space after that and find odd values.

{{< illustration src="img/dfBefore.png"  name="df before"   alt="Results of the `df` command showing size=24T, used=20T, Available=2.4T use=90%" resize="no" >}}

### Who did steal my 1.2To ?

I check with a reliable calculator (my brain isn't) and yes: 24-20=4 not 2.4. 
I know there is always some loss in filesystem to hold for maps, journals, or whatnot.
But 1.6To seems excessive.

After some search on the great library of Internet, I found that ext4 filesystem, by default, reserve a small portion of 
any partition made to ensure there is always free space on a volume. 

This seems at the utmost importance for system partitions because no space mean no shell. 
Believe me, I'm old enough to have worked on ancient system that did not have any protection in this regard, 
and it was a real challenge to get a shell on those computers. (considering you do not have physical access to it, of course)

Another usage of this reserved space is to fight against [fragmentation](https://en.wikipedia.org/wiki/Fragmentation_(computing)). 
As I'm running on HardDrive and not SSD, Fragmentation is still a thing I need to consider. 
My volume is for cold storage mostly. I have some hot files that change a lot, 
but they represent a minimal amount of the total data on the drives. Fragmentation should be low.

### Get my terabyte back

As I don't have a real usage of this reserved space, It is safe for me to remove it or at least reduce it a lot. 
So let's go.  Simply run the following command and done

```bash
sudo tune2fs -m 0.05 /dev/vda
```

And voilà !
{{< illustration src="img/dfAfter.png"  name="df after"   alt="command `sudo tune2fs -m 0.05 /dev/vda` and results of the `df` command showing size=24T, used=20T, Available=3.6T use=86%" resize="no" >}}
{{< illustration src="img/notSoFullCargo.png"  name="Cargo is not full anymore"   alt="A gauge showing that the cargo volume is full red at 85.a%" resize="no" >}}

## So what ?

I manage my NAS by hand, and learn with it. Today I learned. Goal achieved. 
 - Now there is safety to avoid being locked away from a servers (when you have credentials)
 - Ext4 reserve 5% of a volume and this is not really useful if the volume is not used as root, or fragmentation is not a concern.
 - `e4defrag` exist and can be used to report on fragmentation and de-fragment a volume, but is really really really long.

Thanks reading me,\
[Bisoux](/page/bisoux) :kissing:

---

References
 - [Reserved block count for Large Filesystem](https://listman.redhat.com/archives/ext3-users/2009-January/msg00026.html)
 - [Reserved space on ext4 database file system](https://www.linuxquestions.org/questions/linux-general-1/reserved-space-on-ext4-database-file-system-4175564363/)
 - [man e4defrag](https://manpages.ubuntu.com/manpages/bionic/man8/e4defrag.8.html)