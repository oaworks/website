# bookmarklet

This bookmarklet just wraps core functionality from the plugin. 

The index.html demonstrates how it looks, and shows a button that 
demonstrates how to write a link that can be saved to a bookmarks 
bar and would call the bookmarklet when clicked from the bookmarks bar.

That click would call the bookmarklet.js file, which will then call for 
the bookmarklet.css file. Also, the ui.js and oab.js files are required 
from the OAB plugin, and should be copied into the top level folder here. 
If new copies of these are retrieved and there were also changes to the 
plugin UI as laid out in its main.html file, then they will need manual 
replication in the bookmarklet.js file here (but they should be pretty 
simple manual changes.) Lastly, the img folder here should be populated 
with the necessary images from the plugin, namely error.png, oa128.png, 
oab_article.png, oab_data.png, and spin_orange.svg

The bookmarklet requires an api key, the value of which should be set 
in the link used to call the code, as the example in index.html shows.

The bookmarklet calls the includer.js script, which needs to know the 
URL to where the necessary files can be found, and a list of the css 
and js file names that are required.

The version number of this bookmarklet must be set in bookmarklet.js. 
It would probably be useful if it equates to the version of the plugin 
that things were last copied from. It can also be useful to use the 
version in includer.js and in the link used to create the bookmarklet, 
so that the links to files are refreshed with version increments.