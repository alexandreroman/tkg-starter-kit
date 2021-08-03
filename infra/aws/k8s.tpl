apiVersion: v1
kind: Secret
metadata:
  name: route53
  namespace: cert-manager
stringData:
  secret-access-key: ${aws_dns_challenge_secret}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${letsencrypt_issuer_email}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - selector:
          dnsZones:
          - "${domain}"
        dns01:
          route53:
            region: ${aws_region}
            accessKeyID: ${aws_dns_challenge_access}
            secretAccessKeySecretRef:
              name: route53
              key: secret-access-key
            hostedZoneID: ${aws_zone_id}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${letsencrypt_issuer_email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - selector:
          dnsZones:
          - "${domain}"
        dns01:
          route53:
            region: ${aws_region}
            accessKeyID: ${aws_dns_challenge_access}
            secretAccessKeySecretRef:
              name: route53
              key: secret-access-key
            hostedZoneID: ${aws_zone_id}
