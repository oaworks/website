This is the Open Access Button API code.

The OAB API is a service of the Noddy API. As such, it does NOT run on its own.
If you want to run it yourself, you need to download and install Noddy, then 
symlink this folder into the untracked service folder.

However, that is probably not necessary. You can edit the API code here, then 
pushing changes to develop branch will result in the dev API running the changes. 
Then you can test your changes on the dev API.

(A skeleton API may soon be written to make it easier to run this API locally 
without Noddy if desired... but it is not a priority.)

Note there is a test file in here too - be sure to update the tests with new ones if 
necessary for the changes you make to the code. Whenever code is pushed to develop 
the tests are run, and if they fail a warning email will be sent to the admin.
You can also run and view the results of the tests on the API itself at 
<API_URL>/service/oab/test

Once API changes are tested and running well on the dev API, a merge to master 
will make the changes available for the live API, but it will not automatically 
be updated. Ask a project admin if you want to push an update onto the live API 
once it is on the master branch.
