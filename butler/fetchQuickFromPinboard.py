#!/usr/bin/env python3
import feedparser
import os
import subprocess
import json
import re


def parseFeedAndCreateQuick(lang, feedUrl):
    feed = feedparser.parse(feedUrl)
    for entry in feed.entries:
        if lang == "fr":
            file="quick/2021/"+ re.sub('\-+','-',re.sub('[^a-zA-Z0-9\.\-_]','-',entry.title)) +".md"
        else:
            file="quick/2021/"+ re.sub('\-+','-',re.sub('[^a-zA-Z0-9\.\-_]','-',entry.title)) +"."+lang+".md"
        if os.path.isfile('content/'+file):
           print("Skipping \""+entry.title+'"')
        else:
            print("Creating new quick in "+lang+" for "+entry.title)
            res = subprocess.call("hugo --cacheDir /tmp/butler-fetch-pinboard/ new \""+file+"\"", shell="true")
            if res != 0 :
                print("Unable to create file")
                break
            file1 = open('content/'+file,"r")
            source = file1.read()
            file1.close()
    
            print("Fixing title")
            source = re.sub('title: .*','title: "'+entry.title+'"',source)
    
            print("Defining link")
            source = source.replace('##URL##',entry.link)
          
            if len(entry.tags) > 0:
                print("adding tags "+ entry.tags[0].term.replace('pub-en',''))
                tags = entry.tags[0].term.replace('pub-'+lang,'').strip().split(" ")
                tagsString = json.dumps(tags)
                source = source.replace('tags: []','tags: '+tagsString)
           
            print("Adding description as content")
            source = source + "\n" + entry.description
        
            file1 = open('content/'+file,"w")
            file1.write(source)
            file1.close()

print("Parsing english feed")
parseFeedAndCreateQuick('en', 'https://feeds.pinboard.in/rss/u:ztec/t:pub-en/')     
print("Parsing french feed")
parseFeedAndCreateQuick('fr', 'https://feeds.pinboard.in/rss/u:ztec/t:pub-fr/')     

