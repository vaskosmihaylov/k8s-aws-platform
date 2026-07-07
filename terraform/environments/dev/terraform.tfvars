# Set db_password via TF_VAR_db_password environment variable.
# Run: curl -s https://checkip.amazonaws.com to get your IP for CIDR whitelisting.

region       = "eu-west-1"
environment  = "dev"
cluster_name = "k8s-platform-dev"

cluster_endpoint_public_access_cidrs = ["90.154.173.129/32"]

db_username = "dbadmin"
db_name     = "appdb"

github_org      = "vaskosmihaylov"
github_repo     = "k8s-aws-platform"
github_app_repo = "k8s-demo-api"

route53_zone_name = "gaiaderma.com"
