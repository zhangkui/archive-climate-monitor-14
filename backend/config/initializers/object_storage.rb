require "aws-sdk-s3"

# MinIO 以 S3 兼容协议访问；force_path_style 必须开启
OBJECT_STORAGE = Aws::S3::Client.new(
  endpoint: ENV.fetch("MINIO_ENDPOINT", "http://localhost:9000"),
  access_key_id: ENV.fetch("MINIO_ACCESS_KEY_ID", "archive-minio"),
  secret_access_key: ENV.fetch("MINIO_SECRET_ACCESS_KEY", "archive-minio-secret"),
  region: "us-east-1",
  force_path_style: ENV.fetch("MINIO_FORCE_PATH_STYLE", "true") == "true"
)

# 预签名 URL 由浏览器访问，必须使用宿主机可达的外部端点（容器内 minio:9000 不可达）
OBJECT_STORAGE_PUBLIC = Aws::S3::Client.new(
  endpoint: ENV.fetch("MINIO_PUBLIC_ENDPOINT", "http://localhost:9000"),
  access_key_id: ENV.fetch("MINIO_ACCESS_KEY_ID", "archive-minio"),
  secret_access_key: ENV.fetch("MINIO_SECRET_ACCESS_KEY", "archive-minio-secret"),
  region: "us-east-1",
  force_path_style: true
)

REPORT_BUCKET = ENV.fetch("MINIO_BUCKET", "archive-reports")
