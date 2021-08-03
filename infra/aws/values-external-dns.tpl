#@ load("@ytt:data", "data")
aws:
  credentials:
    accessKey: ${aws_access_key}
    secretKey: ${aws_secret_key}
  region: ${aws_region}
  zoneType: public
policy: sync
sources:
- service
- ingress
#@ if/end data.values.ENABLE_EXTERNAL_DNS_WITH_CONTOUR:
- contour-httpproxy
