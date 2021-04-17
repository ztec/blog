#!/bin/bash
#!/bin/bash

git add content/quick
NB_CHANGES=$(git status --short | grep "A " | grep "content/quick"|wc -l)

if [ ${NB_CHANGES} -gt 0 ]; then

	git commit -m "Auto-publish Quick"
	git push origin main

else
	echo "No changes worth committing"
fi

