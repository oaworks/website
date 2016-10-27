# bookmarklet

TODO this should be in the /static/bookmarklet folder but it is 
causing an error in the build, so moving it out here for now.

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
version in includer.js so that the links to files are refreshed with 
version increments. The actual link used in a page to allow a user to 
drag the bookmark to their bookmark bar should be used as the example 
in index.html, with Math.random() variable added to it, so that every 
use of the bookmarklet will get a fresh version of includer.js - so, 
if includer.js has a new version number set, then it will retrieve 
the latest version of the bookmarklet code, automatically keeping 
users up to date.

