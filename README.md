# Todo App on Google Cloud: Cloud Run + Cloud SQL + Cloud Build + Terraform

A full-stack TypeScript todo app (Express 5 API + React 19 SPA + PostgreSQL). It is based on
[kristiyan-velkov/docker-nodejs-sample](https://github.com/kristiyan-velkov/docker-nodejs-sample),
containerized and deployed to a **private** Cloud Run service backed by **Cloud SQL for
PostgreSQL**, with CI/CD in **Cloud Build** and infrastructure in **Terraform**.

**Start here: [GETTING_STARTED.md](GETTING_STARTED.md)**, a checklist of every step and every
env value (where to get it, where to put it).
Architecture and design details: [DEPLOYMENT.md](DEPLOYMENT.md).

```
git push main ─▶ Cloud Build (test → build → push → deploy) ─▶ Artifact Registry
                                                        │
 caller + ID token ─▶ Cloud Run "todoapp" (private) ◀───┘
                        │  unix socket /cloudsql/PROJECT:REGION:INSTANCE
                        ▼
                     Cloud SQL Auth Proxy ─TLS/IAM─▶ Cloud SQL PostgreSQL 16 (db-f1-micro)
```

## Deliverables

| # | Deliverable | Value |
|---|---|---|
| 1 | Repository | `<GITHUB_REPO_URL>` (app, `Dockerfile`, `cloudbuild.yaml`, `terraform/`) |
| 2 | Cloud Run URL (invoker granted to interviewer) | `<CLOUD_RUN_URL>` |
| 3 | Anonymous access denied | see [curl output](#access-control) |
| 4 | Successful pipeline run | `<CLOUD_BUILD_RUN_URL>` |
| 5 | `/health/db` response | see [curl output](#access-control) |

## Database connection method

**Cloud SQL Auth Proxy through Cloud Run's built-in Cloud SQL connection (unix socket).**
The instance has a public IP with **no authorized networks**. Cloud Run mounts
`/cloudsql/<PROJECT>:<REGION>:<INSTANCE>` and the app uses that path as `POSTGRES_HOST`. The proxy
authenticates with the runtime service account (`roles/cloudsql.client`) and encrypts traffic.
The DB password lives in Secret Manager and is injected as `POSTGRES_PASSWORD`.

## What was added or changed

| File | Change |
|---|---|
| `Dockerfile` | Multi-stage build (deps → test → build → prod-deps → production), non-root `node` user, port 8080, healthcheck |
| `src/server/database/postgres.ts` | Unix-socket support (skips TCP wait when host starts with `/`), `pg.Pool` instead of a single `Client`, `POSTGRES_PORT` honoured, `healthCheck()` |
| `src/server/index.ts` | New `GET /health/db` endpoint (200 with PG version/latency, or 503) |
| `src/server/middleware/errorHandler.ts` | Fixed: Express only treats 4-arg middleware as an error handler |
| `compose.yaml` | Local prod image + Postgres 16 |
| `cloudbuild.yaml` | Test → build → push → deploy pipeline with placeholder substitutions |
| `terraform/` | Artifact Registry, Cloud SQL (instance/db/user), Secret Manager, service accounts + IAM, Cloud Run, invoker bindings, Cloud Build trigger |

## Quick start

### Local

```bash
docker compose up --build        # http://localhost:8080 , http://localhost:8080/health/db
docker build --target test .     # run tests in Docker
```

### Google Cloud (summary; details in [DEPLOYMENT.md](DEPLOYMENT.md))

**Manual steps** (project and APIs, as the brief allows):

```bash
gcloud projects create <PROJECT_ID> && gcloud config set project <PROJECT_ID>
gcloud billing projects link <PROJECT_ID> --billing-account=<BILLING_ACCOUNT_ID>
gcloud services enable run.googleapis.com sqladmin.googleapis.com artifactregistry.googleapis.com \
  cloudbuild.googleapis.com secretmanager.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com
gcloud auth application-default login
# Console: Cloud Build → Triggers → Connect repository → GitHub → select this repo
```

**Terraform:**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set project_id, invoker_members, github_owner/repo
terraform init && terraform apply
```

**First image** (after that, every push to `main` deploys automatically):

```bash
AR=<REGION>-docker.pkg.dev/<PROJECT_ID>/todoapp
gcloud auth configure-docker <REGION>-docker.pkg.dev
docker build --target production -t $AR/todoapp:v1 . && docker push $AR/todoapp:v1
gcloud run deploy todoapp --image=$AR/todoapp:v1 --region=<REGION>   # no --allow-unauthenticated
```

**Browser view** of the private service:
`gcloud run services proxy todoapp --region=<REGION> --port=8080`, then open `http://localhost:8080`.

## Access control

Cloud Run is deployed **without** `--allow-unauthenticated`. `roles/run.invoker` is granted only
to the principals in `invoker_members` (including `user:<INTERVIEWER_EMAIL>`).

```bash
URL=$(gcloud run services describe todoapp --region=<REGION> --format='value(status.url)')

$ curl -i $URL/health
HTTP/2 403
...
Error: Forbidden
Your client does not have permission to get URL /health from this server.

$ curl -i -H "Authorization: Bearer $(gcloud auth print-identity-token)" $URL/health/db
HTTP/2 200
content-type: application/json; charset=utf-8

{"success":true,"message":"Database connection is healthy","database":"todoapp","host":"/cloudsql/<PROJECT_ID>:<REGION>:todoapp-pg","latencyMs":4,"version":"PostgreSQL 16.x ...","timestamp":"..."}
```

> Replace the block above with the real output from your deployment.

### Browser access for the whole Workpay team (production)

I would put the service behind **Identity-Aware Proxy** instead of handing out per-user
`run.invoker` bindings. There are two ways to add it:

- enable IAP directly on the Cloud Run service, or
- use an external HTTPS load balancer with a serverless NEG, a Google-managed certificate on a
  company domain, and IAP on the backend.

The rest of the setup:

- Set Cloud Run ingress to `internal-and-cloud-load-balancing` so the raw `run.app` URL can't
  bypass it.
- Grant `run.invoker` only to the IAP service agent.
- Grant `roles/iap.httpsResourceAccessor` to a Google Group (e.g. the engineering group on the
  Workpay domain).

Team members then open the URL and sign in with their Workpay Google account (SSO, MFA,
context-aware access). Onboarding and offboarding is just group membership, every request is
audit-logged, and Cloud Armor can be added on the LB for WAF and IP rules.

## CI/CD

A push to `main` triggers `todoapp-push-main`, which runs `cloudbuild.yaml` as the least-privilege
`todoapp-cloudbuild` service account:

1. **test**: `docker build --target test` runs the Vitest suite.
2. **build**: builds the production image, tagged `:$SHORT_SHA` and `:latest`.
3. **push**: pushes to Artifact Registry.
4. **deploy**: `gcloud run deploy todoapp --image …:$SHORT_SHA`. Only the image changes; config
   stays as Terraform defined it.

## Terraform-managed resources

Artifact Registry repo · Cloud SQL instance, database and user · Secret Manager secret · Cloud Run
v2 service (with Cloud SQL volume) · runtime and Cloud Build service accounts with IAM · Cloud Run
invoker bindings · Cloud Build trigger.

The manual parts are project creation, billing link, API enablement and the GitHub → Cloud Build
connection.

## Cost and cleanup

Everything uses the smallest option: Cloud Run scales to zero; Cloud SQL is `db-f1-micro`, zonal,
10 GB, no backups; Artifact Registry keeps 5 images. **After the demo:**

```bash
cd terraform && terraform destroy
```

## Progress / time-box notes

| Step | Status |
|---|---|
| 1. Clone | ✅ |
| 2. Containerize + push to AR | ✅ Dockerfile done / `<push status>` |
| 3. Deploy to Cloud Run | `<status>` |
| 4. Cloud SQL | `<status>` |
| 5. Connect app to DB | ✅ code + verified locally via TCP and unix socket / `<cloud status>` |
| 6. Git repo + README | `<status>` |
| 7. CI/CD | ✅ `cloudbuild.yaml` + trigger / `<run status>` |
| 8. Terraform | ✅ `terraform validate` passes / `<apply status>` |
| 9. Restrict access | `<status>` |

`<Where I stopped and why, if applicable>`

## App reference

- `GET /health`: liveness (used as the Cloud Run startup probe)
- `GET /health/db`: database connectivity check
- `GET|POST /api/todos`, `GET|PUT|DELETE /api/todos/:id`
- Env: `POSTGRES_HOST` (hostname or `/cloudsql/...` socket dir), `POSTGRES_PORT`, `POSTGRES_DB`,
  `POSTGRES_USER`, `POSTGRES_PASSWORD` (each also supports a `*_FILE` variant), `PORT` (default 3000;
  8080 in the image)

Original sample by [Kristiyan Velkov](https://github.com/kristiyan-velkov/docker-nodejs-sample), MIT License.
