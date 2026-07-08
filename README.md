# Paperclip Coolify Deploy

Self-hosted [Paperclip](https://paperclip.ing) deployment for [Coolify](https://coolify.io), built from source and configured for a public authenticated deployment.

## What's included

- Paperclip server image published to `ghcr.io/lukasparke/paperclip-coolify:latest`
- Paperclip server built from the [paperclipai/paperclip](https://github.com/paperclipai/paperclip) source with the `pi` CLI baked in
- PostgreSQL 16 sidecar
- Traefik labels for Coolify reverse proxy + SSL
- Persistent volumes for Paperclip data and Postgres data
- Provider API key passthrough for Paperclip local adapters and `pi-local` agents

## Requirements

- A Coolify instance
- A domain pointed at your Coolify server
- At least 4 GB RAM / 2 vCPU (8 GB RAM recommended for building Paperclip from source)
- Coolify v4.0.0-beta.411 or newer if you use Coolify magic values for secrets

## Published image

This repo publishes `ghcr.io/lukasparke/paperclip-coolify:latest` from the Dockerfile on every push to `main`. The image is also tagged with the source commit SHA as `sha-<commit>`.

## Build source

The Dockerfile clones and builds Paperclip from source rather than using an upstream prebuilt image. Defaults are pinned for repeatable builds and can be overridden with Docker build args.

| Build arg | Default | Description |
|---|---|---|
| `PAPERCLIP_REPO` | `https://github.com/paperclipai/paperclip.git` | Git repository to clone |
| `PAPERCLIP_REF` | `390627b46eb333309d357004384b220ecf8a65af` | Paperclip commit SHA for release `v2026.707.0` |
| `NODE_IMAGE` | pinned `node:lts-trixie-slim` digest | Base image |
| `USER_UID` | `1000` | UID for the `node` user inside the container |
| `USER_GID` | `1000` | GID for the `node` user inside the container |
| `PI_CODING_AGENT_VERSION` | `0.80.3` | `@earendil-works/pi-coding-agent` version |

In Coolify you can set build arguments under **Resource → Configuration → Build Args**.

## Automated updates

This repo includes lightweight GitHub automation:

- `.github/workflows/publish-image.yml` publishes `ghcr.io/lukasparke/paperclip-coolify:latest` on pushes to `main` and on manual dispatch.
- `.github/workflows/update-components.yml` runs daily and on manual dispatch.
- It checks the latest Paperclip GitHub release, `node:lts-trixie-slim` digest, and bundled CLI npm packages.
- If anything changed, it updates the pinned defaults, validates the Dockerfile and compose config, and opens a pull request.
- `.github/dependabot.yml` keeps the GitHub Actions used by the automation up to date.

## Environment variables

Set these in Coolify → Resource → Environment. The compose file references each variable explicitly so Coolify will display them in the UI.

### Public deployment variables

| Variable | Required | Description |
|---|---|---|
| `PAPERCLIP_FQDN` | no | Public hostname for Traefik routing, e.g. `paperclip.example.com`. Defaults to Coolify's auto-generated `SERVICE_FQDN_PAPERCLIP`. Only set this if you need to override the generated domain. |
| `PAPERCLIP_PUBLIC_URL` | no | Full public URL, e.g. `https://paperclip.example.com`. Defaults to `https://${PAPERCLIP_FQDN}` or `https://${SERVICE_FQDN_PAPERCLIP}`. |
| `PAPERCLIP_DEPLOYMENT_MODE` | no | Defaults to `authenticated`. |
| `PAPERCLIP_DEPLOYMENT_EXPOSURE` | no | Defaults to `public`. |
| `PAPERCLIP_AUTH_BASE_URL_MODE` | no | Defaults to `explicit`, required for public authenticated Paperclip. |

### Required secrets

The compose file references Coolify magic values for the required secrets, so Coolify generates them automatically on first deploy. They are shown in **Resource → Environment** and can be edited there if you prefer to provide your own secure values.

| Variable | Required | Coolify magic value | Description |
|---|---:|---|---|
| `BETTER_AUTH_SECRET` | yes | `${SERVICE_HEX_64_BETTERAUTH}` | Better Auth signing secret. |
| `PAPERCLIP_AGENT_JWT_SECRET` | yes | `${SERVICE_HEX_64_AGENTJWT}` | Separate secret for Paperclip local agent JWTs. |
| `POSTGRES_PASSWORD` | yes | `${SERVICE_PASSWORD_64_POSTGRES}` | PostgreSQL password. Uses the symbol-free magic value because this password is embedded in `DATABASE_URL`. |

### Provider API keys passed through to agents

These are optional. Any value set in Coolify is passed into the Paperclip container and inherited by child agent processes, including the `pi-local` adapter. This lets `pi` see the same API keys you configured in Coolify.

Common keys:

| Provider/use | Environment variable |
|---|---|
| Anthropic / Claude | `ANTHROPIC_API_KEY` |
| OpenAI / Codex | `OPENAI_API_KEY` |
| Gemini | `GEMINI_API_KEY` or `GOOGLE_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| Kimi For Coding | `KIMI_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Groq | `GROQ_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| xAI | `XAI_API_KEY` |
| Cerebras | `CEREBRAS_API_KEY` |
| NVIDIA NIM | `NVIDIA_API_KEY` |
| Fireworks | `FIREWORKS_API_KEY` |
| Together AI | `TOGETHER_API_KEY` |
| Vercel AI Gateway | `AI_GATEWAY_API_KEY` |
| ZAI | `ZAI_API_KEY`, `ZAI_CODING_CN_API_KEY` |
| MiniMax | `MINIMAX_API_KEY`, `MINIMAX_CN_API_KEY` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_BASE_URL`, `AZURE_OPENAI_RESOURCE_NAME`, `AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_DEPLOYMENT_NAME_MAP` |
| Cloudflare AI | `CLOUDFLARE_API_KEY`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_GATEWAY_ID` |
| Amazon Bedrock | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_ENDPOINT_URL_BEDROCK_RUNTIME` |

## Deploy

1. Push this repo to GitHub.
2. In Coolify, create a **New Resource → Application → Public Repository**.
3. Use your fork/repo URL.
4. Select **Docker Compose** build pack.
5. Base compose file: `docker-compose.yml`.
6. Assign a domain to the **paperclip** service in Coolify. `PAPERCLIP_FQDN`, `PAPERCLIP_PUBLIC_URL`, `BETTER_AUTH_URL`, and the Traefik host rule will inherit from Coolify's auto-generated `SERVICE_FQDN_PAPERCLIP`. Set `PAPERCLIP_FQDN` only if you need to override the generated domain.
7. The required secrets are auto-generated by Coolify from the magic values in `docker-compose.yml`; edit them in **Resource → Environment** only if you want to override them.
8. Add any provider API keys you want Paperclip or pi agents to use, such as `KIMI_API_KEY`, `OPENROUTER_API_KEY`, `OPENAI_API_KEY`, or `ANTHROPIC_API_KEY`.
9. Deploy.

> **Note:** `paperclipai onboard` is **not required**. The container generates `/paperclip/instances/default/config.json`, the agent JWT secret, and the local secrets key automatically from the environment variables. On first start it also creates a bootstrap CEO invite and prints the claim URL in the container logs.

## First run

1. Watch the deployment logs in Coolify for the line:
   ```
   [docker-start] creating bootstrap CEO invite...
   Created bootstrap CEO invite.
   Invite URL: https://<your-domain>/invite/<token>
   ```
2. Open the printed invite URL.
3. Create an account to claim instance admin and finish onboarding.

## CLI fallback

If the automatic bootstrap invite fails (for example, because the database was not reachable on first start), exec into the running container and run:

```bash
docker exec -it <container-name> paperclipai auth bootstrap-ceo
```

Then open the printed invite URL. The config file at `/paperclip/instances/default/config.json` is generated automatically, so `paperclipai onboard` is only needed if you want to reconfigure the instance interactively.
