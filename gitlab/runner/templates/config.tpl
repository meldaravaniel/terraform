[[runners]]
  [runners.kubernetes]
    namespace = "${namespace}"
    image = "ubuntu:20.04"
    privileged = true
    [[runners.kubernetes.volumes.empty_dir]]
      name = "docker-certs"
      mount_path = "/certs/client"
      medium = "Memory"
  [runners.cache]
    Type = "gcs"
    Shared = true
    [runners.cache.gcs]
      BucketName = "${bucket_name}"
