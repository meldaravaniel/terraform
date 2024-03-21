## Summary

This constructs an entire GCP app ecosystem, which includes a base folder and one project corresponding to each environment (dev, qa, prod, etc), within that folder.  
In the projects, it enables required APIs, makes the VPC network, and a few subnet things before the other infrastructure is added.

## PreRequisites

In the earlier stages of this effort, I had a terraform job/service-account/etc for each individual project, but I decided that was overkill and it was a pain in the a$$ to manage at the build job level.  
Yes, you *can* control what that specific account has access to and make it so it can't touch others of the environment projects but...then there's a TON of overhead and it gets complicated and nasty.  
Besides, you have to make those accounts SOMEHOW, meaning you either have to do it manually, every time you want to make a new environment, 
OR you have to have a super account that can make them automatically...in which case you have a super account already........so. Flatten all of that.  Pick your battles.

Because Terraform resources can't create themselves, you need to manually created a GCP project.  It doesn't require a ton, since its primary role is to create other GCP infrastructure, but it does have:

* Google Cloud Storage (GCS) for the terraform state buckets
* Cloud Resource Manager (so that it can make the other resources)
* Cloud SQL Admin API (so that it can make CloudSQL instances)
* Secret Manager API (cuz some secrets get created? this may be obsolete)
* Cloud Billing API (so that it can make folders and projects)
* Identity and Access Management (IAM) API (so that it can manage downstream GSAs and their roles/permissions)

Those are the important ones, and it also has some others enabled.  Some are default for a project. If I missed anything, the errors in the process of running terraform will let you know what they are.

The other important piece is a Google Service Account.  This is what Terraform uses.  It has the credentials and IAM permissions to make all the stuff (a folder, new environment project, 
and all of the resources that go within).  To do its job, it has the `Organization Policy Administrator` role that includes:

```
# definitely needed, so this is included in the custom role below
orgpolicy.policy.get
# the following may not be needed, but that may just be because I haven't created a folder with the GSA in a while. TBD, but at the very least, I KNOW it requires the above permission
orgpolicy.constraints.list
orgpolicy.customConstraints.create
orgpolicy.customConstraints.delete
orgpolicy.customConstraints.get
orgpolicy.customConstraints.list
orgpolicy.customConstraints.update
orgpolicy.policies.create
orgpolicy.policies.delete
orgpolicy.policies.list
orgpolicy.policies.update
orgpolicy.policy.set
policysimulator.orgPolicyViolations.list
policysimulator.orgPolicyViolationsPreviews.create
policysimulator.orgPolicyViolationsPreviews.get
policysimulator.orgPolicyViolationsPreviews.list
```

and a custom role, `Terraform Infra`, at the organization level that has the following permissions:

```
# required to make folders and projects (the policy review may list these as excess if the account hasn't made a project in a while, but that's why it has them)
billing.accounts.getIamPolicy
billing.accounts.setIamPolicy
billing.resourceAssociations.create
compute.projects.get
resourcemanager.folders.create
resourcemanager.projects.create
# required to make buckets
storage.buckets.create
storage.buckets.get 
# other stuff it needed
orgpolicy.policy.get
resourcemanager.organizations.get
```

It grants itself owner permission at the folder level, which then grants it owner on all the projects within.

## High Level Overview

### Folder Creation

Ideally, each environment should have its OWN project and similar projects should be grouped in a folder so that you can easily control things like IAM 
and folder defaults there, instead of individually at the project level.  That simplifies management and separates concerns (and makes looking at billing breakdowns easier).  

When the jobs herein run for the first time, it will create a new folder and add the Uber TF Google Service Account (GSA) as the owner of that folder.  At the folder level, it:

* disables default network creation (we're making our own VPCs in the projects)
* prevents the default project GSAs from getting any IAM permissions (we're making our own, very limited permissions GSAs isntead)

### Environment Project Creation

For each environment module in [main.tf](main.tf), it will create a corresponding project.  In GCP, project IDs are claimed FOREVER, even if you delete the project, 
so I have chosen to randomly generate project IDs that have nothing to do with my apps.  I just go get a random word generator to spit out three words until I like them.  
This way we don't make a project ID we're emotionally attached to, delete it, and then cry because we want to reuse the ID.  The actually useful monicker is the project name.  
That can change whenever you want and is what you see in the GCP console anyways.  

I have it set to `DEPRIVILEGE` the default google-created service accounts, as opposed to `DELETE` because they ARE required for the GCP services to function and if you delete them, 
you can't get them back after 30days, meaning your project is effectively broken.  Learned that the hard way. Heh.

This also enables GoogleAPIs needed to run the app systems.  Each environment should require the same ones, so those are defaulted in the [module variables](modules/cargo-signal-project/variables.tf), 
but they *can* be overridden in a given environment's module definition in [main.tf](main.tf) if necessary.

### Project VPC Network

This gives each project its own virtual private cloud network, allocates a subnet for the cluster's pods+services, for serverless (this is what applies the setup sql to the database), 
and sets up VPC peering so that GPC services can talk to the database (explained more in the database project).  

## Google Artifact Registry

This isn't strictly necessary, but I started this before adding a firewall in the cluster I was using, so the pods only had access to GCP resources.  
To avoid having to use GAR, just be sure to add a tcp allowance in the firewall.

That being said, I like the idea of keeping copies of docker images in GAR...but I don't really have a good reasoning for it.  
GAR runs its own security scans on them and you can see that in GAR itself, but it doesn't really protect you from anything...  
I suppose it does prevent folks from attempting to use more recent versions of the images willy nilly, because if they're not downloaded to GAR first, 
you flat out can't use them, but...again, that's probably not really saving you from anything.  
It saves a TINY amount of time for containers since they don't have to go to the internet for their images but that's probably so negligible as to be silly to consider.  
Maybe I did it because it was fun. :P

That said, I have automated the process of grabbing the images from Dockerhub because I had been downloading them to my computer and doing it manually and that was obvi 
not going to be a good long term solution.  That all happens in [gar-job.yml](jobs/gar-job.yml) and images/versions/etc can be added to the [gar.sh](jobs/gar.sh) script 
the job runs.  That downloads both docker images and helm charts and then stores them in GAR.  

For consistency's sake, only keeping one copy of the images, in one project, seems best.

### Version Variables

Because most of the versions are used downstream, by subsequent projects, they are stored at a parent level using the `TF_VAR_` prefix.  This makes them available to all child projects.

Modifying the version will not change anything automatically, so you'll need to:

1) change the version
2) run the GAR job
3) run terraform for whatever projects use that version in each successive environment
  * note: this step should go through the normal deployment/qa testing/regression process

### Ingress, Specifically

Ingress has three other images it needs: `ingress-nginx/kube-webhook-certgen`, `ingress-nginx/controller`, and `defaultbackend-amd64`.  
These have versions that do not necessarily correspond to the main Ingress version.  When changing the main version, you'll need to go look at that 
[version's chart values](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml) to find the versions it's asking for 
and copy them into the [artifact-registry.yml](.gitlab/artifact-registry.yml) file.  Not great...but so it goes.
