These are a bit of a WIP.  The autopilot cluster works wonderfully, but still ironing out the kinks wrt the memory/cpu allocation of the main runner workload and the pods its spawns upon new jobs.

Also doesn't work for an `npm ci` job...not sure why yet.

V. similar to the other runner in this repo, but without having to manage the GKE resources by self (even if they *are* managed by TF).
