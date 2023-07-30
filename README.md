## Dependencies

`npm install @actions/core`
`npm install @actions/github`
`ncc build index.js --license licenses.txt`
`gcloud iam workload-identity-pools create lendly-wif-pool --location="global" --project off-net-dev`

```gcloud iam workload-identity-pools providers create-oidc githubwif \
--location="global" --workload-identity-pool="lendly-wif-pool"  \
--issuer-uri="https://token.actions.githubusercontent.com" \
--attribute-mapping="attribute.actor=assertion.actor,google.subject=assertion.sub,attribute.repository=assertion.repository" \
--project off-net-dev
