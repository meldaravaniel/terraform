## Janky Gitlab MR - Terraform - Cloud Build trigger

I haven't gotten enough time to actually connect my repo to CloudBuild the proper way, so instead I just used a Webhook.  Still a WIP, but check out the [cloudbuild.yml](cloudbuild.yml) file to see the process I'm using.

### What this does:

* Git cloudbuilder
  * registers the gitlab ssh key
  * checks out the repo based on the Webhook request
  * checks out the latest MR commit
* Hashicorp terraform image
  * runs tf init
  * runs tf validate
  * runs tf plan, saving the plan to a file in the /workspace folder for later use
  * converts the tf plan file to json
* JQ image
  * massages the tf plan to be a little nicer to read
* Infracost
  * runs a diff (that needs to be fixed, is not using previous plan...)
  * comments (update) to the MR about the Infracost
* saves the tfPlan json and cache, and the infracost plan to a storage bucket
* optional: updates the cloud_builds pubsub topic (not doing anything with that yet, though)

### What it should do next:

* Infracost
  * this isn't using a past plan file to do the before/after comparison...which kind of defeats the purpose of Infracosting.
* comment to the MR the build status (this may also be better done via the pub/sub topic and a consumer...?)
* comment to the MR with the JSON summary of the plan (make that an open thread, not just a comment).

### But why?

1) Gitlab runners are hekkin slow, and if you're managing them on GCP or GKE anyways, you're probably spending more money, time, effort to do that than to just use CloudBuild and let GCP manage the resources required
2) CloudBuild does nice caching of builders/images used in triggers, is smarter about keeping stuff around
3) for the fish. wanted to learn how.
4) get closer to GitOps, want fewer human interactions involved
5) past decisions of tf organization made gitlab-ci a bit...nasty...
6) at some point, will actually connect the repo and not have to use webhooks.  will be even more better.
7) easier to trigger other stuff downstream (CloudRun, GKE, plain old Terraform, etc)

### Minor annoyances

* CloudBuild's logging output is not as nice to look at as Gitlab runners, so the plan output from tf plan is a bit icky
* don't get the in-gitlab "BUILD PASSED!" feedback (yet), so have to do some manual work to get that back
* not having the repo connected means the cloudbuild.yml file is not in the repo, so updating and testing it is annoying

### Useful Documentation

* [Gitlab's Webhook Events](https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#merge-request-events) (specifically the MR event)
  * useful if you need/want to use more substitutions based on what comes in from the request
* [Google's how-to set up Cloud Build](https://cloud.google.com/build/docs/set-up)
  * goes into more depth about what APIs and roles you'll need to do the things
* [Community-created cloud builders](https://github.com/GoogleCloudPlatform/cloud-builders-community)
* [Infracost CLI docs](https://www.infracost.io/docs/features/cli_commands/)
* [How to JQ]()

### Required Pieces

* A GCP project
  * cloudBuild API enabled, etc.  I followed Google's docs, for the most part
* a svc account within that project
* a Gitlab ssh token associated with a Gitlab user (I'm using a build bot user)
* a repo in gitlab with Terraform things in it
* an Infracost API key
* the Webhook URL the trigger you create will use
* Secrets:
  * GL_SSH_KEY (may or may not be same as GL_API_KEY)
  * GL_API_KEY (only needed if you're using different keys for pulling and commenting)
  * INFRACOST_API_KEY
* Trigger Settings
  * Event
    * Webhook Event
  * Webhook URL
    * secret = {your}_gitlab-ssh-key
    * secret version = {version}
    * grab the URL from Show URL Preview and add it to the appropriate Webhook section in Gitlab (pro-tip: mask the key and secret in Gitlab's UI)
  * Source
    * 1st Gen
  * Configuration
    * Type = Cloud build configuration file (yaml or json)
    * Location = inline
  * Substitutions:
    * _GL_ACTION = $(body.object_attributes.action)
    * _GL_OBJECT_KIND = $(body.object_kind)
    * _GL_PROJECT = $(body.project.path_with_namespace)
    * _GL_TARGET_BRANCH = $(body.object_attributes.target_branch)
    * _GL_HOST = 
      * eg. gitlab.mydomain.rock; can hard code this, or get from webhook)
    * _GL_REPO = $(body.project.git_ssh_url)
      * eg. `git@gitlab.mydomain.rock:mygroup/myproject.git`
    * _GL_LAST_COMMIT = $(body.object_attributes.last_commit.id)
    * _TFDIR
      * you may not need this if your repo's main directory is where the terraform files are
      * if your project is quirky, you could get this from the target branch, or the branch name, or hard code it...
    * _GL_MERGE_REQUEST_IID = $(body.object_attributes.iid)
    * _GL_SERVER_URL = 
      * eg. https://gitlab.mydomain.rock
  * Filters:
    ```
    _GL_OBJECT_KIND.matches("merge_request") &&
    _GL_TARGET_BRANCH.matches("main") && (
      _GL_ACTION.matches("open") ||
      _GL_ACTION.matches("reopen") ||
      _GL_ACTION.matches("update")
    )
    ```
    * The above filters make sure the trigger runs only on MRs, and won't run every time someone touches the MR, only when new code is added
    * You can customize the _GL_TARGET_BRANCH to whatever you want, if you're not using `main`
    * Obviously, you can further customize
  * Approval (up to you)
  * Service Account
    * This is up to you, but if you let it use the default cloud-build service account, you will need to grant that access to the secret
    * if you use a different service account, you will need that one to have access to the secrets, as well as cloud logging permissions