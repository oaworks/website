[![DOI](https://zenodo.org/badge/58967079.svg)](https://zenodo.org/badge/latestdoi/58967079)

# Open Access Button Website Content

Static content of OAButton site like the homepage, blogs and the about page, and the email templates.

## How to edit our site

This repo will automatically deploy changes committed to the site. There is a develop branch and a master branch.
Changes should be committed to the develop branch first and viewed on the test site. Once confirmed as being acceptable, 
they should be committed to the master branch and they will appear on the live site. Deployment is handled by Codeship.

develop branch deployment status: 
[ ![Codeship Status for OAButton/website](https://app.codeship.com/projects/4f79d560-ab44-0134-07f6-7e28a7337ed8/status?branch=develop)](https://app.codeship.com/projects/192217)

master branch deployment status:
[ ![Codeship Status for OAButton/website](https://app.codeship.com/projects/4f79d560-ab44-0134-07f6-7e28a7337ed8/status?branch=master)](https://app.codeship.com/projects/192217)

Actual editing of the files themselves can be done in any text editor or code editing tool, as you prefer.

### How to Edit via GitHub Web UI (needs work)
Your steps should be:

1. Change to the `develop` branch
2. Make some changes in `develop`
2. Commit them in `develop`
3. Pull from `develop` to check in case someone else made changes
4. If all OK, push to `develop`
5. View on the test site: [dev.openaccessbutton.org](http://dev.openaccessbutton.org/)
6. Checkout `master`
7. Pull from `master`
8. Merge `develop`
9. Push to `master`

Although before point 7 you probably could do other pushes to Develop and view them too. Most of the time it should work

This is the content of Open Access Button site.

## Contributing

There are three repositories.  [This one](https://github.com/oaworks/website), an [issues/discussion area](https://github.com/oaworks/discussion), and  [plugin code](https://github.com/oaworks/plugin).

Quick guide:

* If you have an issue (e.g bug, suggestion, question), make it [here](https://github.com/oaworks/discussion)
* If you want to contribute code to the plugin [see this repository](https://github.com/oaworks/plugin). Pull requests are always welcome. Some useful information is below.

# Development Notes

## How to edit our site

### Branches, master vs develop.

* develop is what we're currently working on now.
* master is our stable, released code.

These repos will generates our website, in test and production, respectively.  Note that changes (commits) to a repo will automatically be deployed to the live site.

Changes should be committed to the develop branch first and viewed on the test site. The email system & data displayed on the test site can be used without causing real database changes or emailing authors. Once confirmed as being acceptable, they will be committed to the master branch and appear on the live site. 

Actual editing of the files themselves can be done in any text editor or code editing tool, as you prefer.

### How to edit & release via Github Web UI (good for small changes)

Your steps to update the website should be:

1. Make sure you are working in the develop branch
2. Make your changes to files in the develop branch
3. Commit them when you're ready
4. View on the test site: http://dev.openaccessbutton.org

#### to release

If you're happy with the above changes & everything has been tested

5. Go to: https://github.com/oaworks/oab_static/tree/master. You'll be invited to make a pull request from the develop branch. Do this. 
6. On the new screen, check that the commits you made are lised & others have been tested. If there are commits that haven't been tested either test them or ask Mark to make a pull request for just your changes.  
8. Hit a the "Create a pull request" button.
9. If all checks pass & you have no conflicts, keep clicking until it's successfully merged. DON'T delete "develop".
10. Wait for your changes to appear on the live site (this may take a few minutes). If you're changes dont appear, you may need to bug Mark. 

Although before point 5 you probably could do other pushes to develop and view them too. Most of the time it should work

### How to Edit via GitHub command line

- Clone the repository and switch to `develop` branch.

  ```sh
  git clone git@github.com:OAButton/oab_static.git
  git checkout develop
  ```

- Edit the files as you see fit, create new files as necessary.
- You can use the status command to check what branch you are on, and what changes you have ready to commit.

  ```sh
  git status
  git add .
  git commit -am 'I edited these files, yay me - or some more useful message'
  git pull origin develop
  ```

- If others have mad changes there may be some merge fixes to make after the `git pull` - if so, fix them.

  ```sh
  git push origin develop
  ```

- Check the test site to see that things look how you want (there may be a couple of minutes delay).

  ```sh
  git checkout master
  git merge develop
  ```

- Again, check for any merge conflict warnings and fix them.

  ```sh
  git pull origin master
  ```

- Quick check for any more changes made by others, fix any conflicts, then push the merge.

  ```sh
  git push origin master
  ```

- Now your changes are on the live site too!
- Switch back to `develop` branch ready to do more editing

  ```sh
  git checkout develop
  ```
  
## Repo Structure and URLs

The usual index.html file naming paradigm can be used inside any folder in the usual way, as the default file to be served if the URL entered matches only the folder name.

For example if the content of this repo is served at `mysite.com` then a request to `mysite.com/my/file` will serve the content found in the file at `content/my/file`.

If `mysite.com/content/my` is requested, then the content of the file at `content/my/index` will be served, or else `content/my/index.html`, or `content/my/index.md`.

If a file with the given name in the URL cannot be found in the specified folder, and cannot be found with `.html` (or `.md`) appended, and also an `index` or `index.html` file cannot be found, 
then the 404 file found in the top level directory will be served instead. If that does not exist, then a standard nginx 404 will occur.

All the content files are requested and served as JavaScript dynamic requests, to populate a section of the page from which the request is issued.

To edit the paraphernalia of the page, see the `index.html` file in the top level directory of this repository. Ignore the `header.html` and `footer.html` files but DO NOT delete them.

The structure of content is just the top-level `index.html` file, for example in oab_static: [website/content/index.html](https://github.com/oaworks/website/blob/master/content/index.html)

Which does the usual HTML links to JS/CSS files etc, such as the main CSS file: [website/static/oabutton.css](https://github.com/oaworks/oab_static/blob/master/static/oabutton.css)

So, for neatness, static content like JS and CSS files, and images, should go in the `/static` folder.

And then the content of individual pages just goes in the `/content` folder.


---

## The Bookmarklet

* The bookmarklet is generated from code that runs the [Open Access Button Plugin](https://github.com/oaworks/unified-extension).
* The bookmarklet can be instantly updated for users similar to how we update the website. 
* You can view the bookmarklet in development at oabb.test.cottagelabs.com

## Approval Process

This keeps branches aligned and ensures content on the sight is properly vetted.

* Anyone with at least "contributor access" (_i.e._ permission to push) can commit to `develop` branch to test changes
* Joe to approve change
* Joe merges on to `master`


---

## Keeping Branches aligned

If branches get out of alignment, Mark needs to review.
