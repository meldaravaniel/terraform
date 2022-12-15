[[runners]]
  [runners.kubernetes]
    namespace = "${namespace}"
    image = "ubuntu:20.04"
    privileged = false
    cpu_request = "300m"
    cpu_limit = "500m"
    memory_request = "256Mi"
    memory_limit = "512Mi"
    [[runners.kubernetes.volumes.empty_dir]]
      name = "docker-certs"
      mount_path = "/certs/client"
      medium = "Memory"
  [runners.cache]
    Type = "gcs"
    Shared = true
    [runners.cache.gcs]
      BucketName = "${bucket_name}"
