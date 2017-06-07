# Open Access Button Website Content

Static content of OAButton site like the homepage, blogs and the about page, and the email templates.


## How to edit our site

This repo will automatically deploy changes committed to the site. There is a develop branch and a master branch.
Changes should be committed to the develop branch first and viewed on the test site. Once confirmed as being acceptable, 
they should be committed to the master branch and they will appear on the live site.

Actual editing of the files themselves can be done in any text editor or code editing tool, as you prefer.


### How to Edit via GitHub Web UI (needs work)
Your steps should be:

1. Change to the `develop` branch
2. Make some changes in `develop`
2. Commit them in `develop`
3. Pull from `develop` to check in case someone else made changes
4. If all OK, push to `develop`
5. View on the test site: [oab.test.cottagelabs.com](http://oab.test.cottagelabs.com/)
6. Checkout `master`
7. Pull from `master`
8. Merge `develop`
9. Push to `master`

Although before point 7 you probably could do other pushes to Develop and view them too. Most of the time it should work
These occasional conflicts are slightly annoying when they occur, but it is still far better than versions of docs flying all over the place anyway!



### How to Edit via GitHub command line

- Clone the repository and switch to `develop` branch.

  ```sh
  git clone git@github.com:OAButton/odb_static.git
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


---

## Repo Structure and URLs

The usual index.html file naming paradigm can be used inside any folder in the usual way, as the default file to be served if the URL entered matches only the folder name.

For example if the content of this repo is served at `mysite.com` then a request to `mysite.com/my/file` will serve the content found in the file at `content/my/file`.

If `mysite.com/content/my` is requested, then the content of the file at `content/my/index` will be served, or else `content/my/index.html`, or `content/my/index.md`.

If a file with the given name in the URL cannot be found in the specified folder, and cannot be found with `.html` (or `.md`) appended, and also an `index` or `index.html` file cannot be found, 
then the 404 file found in the top level directory will be served instead. If that does not exist, then a standard nginx 404 will occur.

All the content files are requested and served as JavaScript dynamic requests, to populate a section of the page from which the request is issued.

To edit the paraphernalia of the page, see the `index.html` file in the top level directory of this repository. Ignore the `header.html` and `footer.html` files but DO NOT delete them.

The structure of content is just the top-level `index.html` file, for example in oab_static: [website/content/index.html](https://github.com/OAButton/website/blob/master/content/index.html)

Which does the usual HTML links to JS/CSS files etc, such as the main CSS file: [website/static/oabutton.css](https://github.com/OAButton/oab_static/blob/master/static/oabutton.css)

So, for neatness, static content like JS and CSS files, and images, should go in the `/static` folder.

And then the content of individual pages just goes in the `/content` folder.


---

## Approval Process

This keeps branches aligned and ensures content on the sight is properly vetted.

* Anyone can commit to `develop` branch to test changes
* Joe to approve change
* Joe merges on to `master`


---

## Keeping Branches aligned

If branches get out of alignment, Mark needs to review.
