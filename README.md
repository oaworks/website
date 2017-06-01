# Open Access Button Website Content

This is the content of Open Access Button site.

## Contributing

Our [main repository](https:www.github.org/oabutton/backend) contains far more information on the project, how to contribute etc.

Quick guide:

* If you have an issue (e.g bug, suggestion, question), make it [here](https://github.com/OAButton/backend/issues/new)
* If you want to contribute code to the plugin do it in this repository. Pull requests are always welcome. Some useful information is below.

# Development Notes

## How to edit our site

### Branches, master vs develop.

This repo will automatically deploy changes committed to the site.

* master is our stable, released code.
* develop is what we're currently working on now.

Changes should be committed to the develop branch first and viewed on the test site. Once confirmed as being acceptable, they should be committed to the master branch and they will appear on the live site. The email system & data displayed on the site can be used without causing real database changes or emailing authors. 

Actual editing of the files themselves can be done in any text editor or code editing tool, as you prefer.

### How to edit & release via Github Web UI (good for small changes)

Your steps should be:

1. Change to the develop branch
2. Make some changes as you wish
3. commit them when you're ready
4. View on the test site: oab.test.cottagelabs.com

#### to release

If you're happy with the above changes & everything has been tested

5. Go to: https://github.com/OAButton/oab_static/tree/master. You'll be invited to make a pull request from the develop branch. Do this. 
6. On the new screen, check that the commits you made are lised & others have been tested. If there are commits that haven't been tested either test them or ask Mark to make a pull request for just your changes.  
8. Hit a the "Create a pull request" button.
9. If all checks pass & you have no conflits, keep clicking until it's successfully merged. DON'T delete "develop".
10. Wait for your changes to appear on the live site (this may take a few minutes). If you're changes dont appear, you may need to bug Mark. 

Although before point 5 you probably could do other pushes to develop and view them too. Most of the time it should work
These occasional conflicts are slightly annoying when they occur, but it is still far better than versions of docs flying all over the place anyway!

### How to Edit via GitHub command line

1. git clone git@github.com:OAButton/odb_static.git
2. git checkout develop
3. # edit the files as you see fit, create new files as necessary
4. # you can use the status command to check what branch you are on, and what changes you have ready to commit
5. git status
6. git add .
7. git commit -am 'I edited these files, yay me - or some more useful message'
8. git pull origin develop
9. # if others have mad changes there may be some merge fixes to make after the git pull - if so, fix them.
10. git push origin develop
11. # check the test site to see that things look how you want (there may be a couple of minutes delay)
12. git checkout master
13. git merge develop
14. # again check for any merge conflict warnings and fix them
15. git pull origin master
16. # quick check for any more changes made by others, fix any conflicts, then push the merge
17. git push origin master
18. # now your changes are on the live site too!
19. # so switch back to develop branch ready to do more editing
20. git checkout develop

## Repo Structure and URLs

The usual index.html file naming paradigm can be used inside any folder in the usual way, as the default file to be served if the URL entered matches only the folder name.

For example if the content of this repo is served at mysite.com then a request to mysite.com/my/file will serve the content found in the file at content/my/file.

If mysite.com/content/my is requested, then the content of the file at content/my/index will be served, or else content/my/index.html, or content/my/index.md.

If a file with the given name in the URL cannot be found in the specified folder, and cannot be found with .html (or .md) appended, and also an index or index.html file cannot be found,
then the 404 file found in the top level directory will be served instead. If that does not exist, then a standard nginx 404 will occur.

All the content files are requested and served as javascript dynamic requests, to populate a section of the page from which the request is issued.

To edit the paraphernalia of the page, see the index.html file in the top level directory of this repository. Ignore the header.html and footer.html files but DO NOT delete them.

The structure of content is just the top-level index.html file, for example in oab_static:

https://github.com/OAButton/oab_static/blob/master/index.html

Which does the usual html links to js/css files etc, such as the main css file:

https://github.com/OAButton/oab_static/blob/master/static/oabutton.css

So, for neatness, static content like js and css files, and images, should go in the /static folder.

And then the content of individual pages just goes in the /content folder.

## The Bookmarklet

* The bookmarklet is generated from code that runs the [Open Access Button Plugin](https://github.com/oabutton/unified-extension).
* The bookmarklet can be instantly updated for users similar to how we update the website. 
* You can view the bookmarklet in development at oabb.test.cottagelabs.com

## Approval Process

This keeps branches aligned and ensures content on the sight is properly vetted.

* Anyone can commit to develop branch to test changes
* Joe to approve change
* Joe merges on to master

## Keeping Branches aligned

If branches get out of alignment, Mark needs to review.
