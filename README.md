## Dependencies

`npm install @actions/core`
`npm install @actions/github`
`ncc build index.js --license licenses.txt`

## Reference

`https://medium.com/google-cloud/how-does-the-gcp-workload-identity-federation-work-with-github-provider-a9397efd7158`

`https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines#gcloud_1`

## Gcloud steps

## Create WIF

`gcloud iam workload-identity-pools create lc-wif-pool --location="global" --project off-net-dev`

## Add provider

`gcloud iam workload-identity-pools providers create-oidc dora-provider \
--location="global" --workload-identity-pool="dora-pool"  \
--issuer-uri="https://token.actions.githubusercontent.com" \
--attribute-mapping="attribute.actor=assertion.actor,google.subject=assertion.sub,attribute.repository=assertion.repository" \
--project off-net-dev`

## Create SA

`gcloud iam service-accounts create dora-wif \
--display-name="service account used by dora-poc" \
--project off-net-dev`

## Add Role

`gcloud projects add-iam-policy-binding off-net-dev \
--member='serviceAccount:lendly-wif@off-net-dev.iam.gserviceaccount.com' \
--role="roles/compute.viewer"`

`gcloud projects add-iam-policy-binding off-net-dev \
--member='serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com' \
--role="roles/iam.workloadIdentityUser"`

## Bind Sa

`gcloud iam service-accounts add-iam-policy-binding dora-wif@off-net-dev.iam.gserviceaccount.com \
--project=off-net-dev \
--role="roles/iam.workloadIdentityUser" \
--member="principalSet://iam.googleapis.com/projects/541105984323/locations/global/workloadIdentityPools/dora-pool/attribute.repository/lendly-telus-com/github-action-wif-sa"`

`gcloud iam service-accounts add-iam-policy-binding dora-wif@off-net-dev.iam.gserviceaccount.com \
    --role=roles/iam.workloadIdentityUser \
    --member="principal://iam.googleapis.com/projects/541105984323/locations/global/workloadIdentityPools/dora-pool/subject/google.subject"`

## add to workflow yaml

` - id: 'auth'
        name: 'Authenticate to Google Cloud'
        uses: 'google-github-actions/auth@v1'
        with:
          create_credentials_file: true
          workload_identity_provider: 'projects/541105984323/locations/global/workloadIdentityPools/lc-wif-pool/providers/lc-wif-provider'
          service_account: ${{ secrets.SERVICE_ACCOUNT }}`
