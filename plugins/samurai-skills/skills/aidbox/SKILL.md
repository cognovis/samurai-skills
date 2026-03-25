---
name: aidbox
description: >
  Aidbox FHIR platform by Health Samurai. Use when user works with Aidbox — FHIR REST API,
  CRUD operations, search, transactions, bundles, access policies, subscriptions, custom
  resources, SQL on FHIR, bulk operations, terminology, profiles, Aidbox configuration,
  docker setup, environment variables, Aidbox SDK, zen configuration, aidbox-zen-lang,
  AccessPolicy, SearchParameter, AidboxSubscription, AidboxTopicDestination, Operation,
  first-class extensions, or any Aidbox-specific features. Also triggers on mentions of
  "aidbox", "aidboxone", "devbox", "multibox", "aidbox forms", "aidbox MPI".
---

# Aidbox FHIR Platform

Aidbox is a FHIR-native platform built on PostgreSQL. It provides FHIR R4 API with extensions for real-world production use.

## Documentation

Aidbox docs live at `https://docs.aidbox.app` (redirects to `https://www.health-samurai.io/docs/aidbox`).

When you need detailed docs on a specific topic, fetch the relevant page:

```
https://www.health-samurai.io/docs/aidbox/<section>/<page>
```

## Architecture

- **Storage**: PostgreSQL with JSONB, each FHIR resource type maps to a table
- **API layers**: FHIR REST, SQL, GraphQL, Subscriptions
- **Auth**: OAuth 2.0, SMART on FHIR, RBAC/ABAC via AccessPolicy
- **Validation**: FHIR Schema (simplified StructureDefinitions), FHIRPath invariants
- **Config**: Environment variables + zen-lang configuration

## FHIR REST API

### Base URLs

Aidbox exposes two API formats:
- `/fhir/<ResourceType>` — strict FHIR-compliant (for external clients)
- `/<ResourceType>` — Aidbox format (first-class extensions, flat structure)

### CRUD

```http
POST   /fhir/Patient              # Create (server assigns id)
PUT    /fhir/Patient/<id>         # Create or replace
GET    /fhir/Patient/<id>         # Read
PATCH  /fhir/Patient/<id>         # Partial update (merge-patch or json-patch)
DELETE /fhir/Patient/<id>         # Delete
GET    /fhir/Patient/<id>/_history # Instance history
GET    /fhir/Patient/_history      # Type history
```

### Search

```http
GET /fhir/Patient?name=John&birthdate=gt1990-01-01
GET /fhir/Patient?_include=Patient:organization
GET /fhir/Patient?_revinclude=Observation:subject
GET /fhir/Patient?_has:Observation:subject:code=http://loinc.org|1234
GET /fhir/Patient?_sort=-birthdate&_count=10&_page=2
```

Search modifiers: `:exact`, `:contains`, `:missing`, `:not`, `:text`, `:of-type`
Prefixes for date/number: `eq`, `ne`, `gt`, `lt`, `ge`, `le`, `sa`, `eb`, `ap`

### Bundles (Transaction/Batch)

```http
POST /fhir
Content-Type: application/fhir+json

{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "fullUrl": "urn:uuid:patient-1",
      "resource": {"resourceType": "Patient", "name": [{"family": "Smith"}]},
      "request": {"method": "POST", "url": "Patient"}
    },
    {
      "resource": {"resourceType": "Observation", "subject": {"reference": "urn:uuid:patient-1"}},
      "request": {"method": "POST", "url": "Observation"}
    }
  ]
}
```

Transaction = all-or-nothing. Batch = independent operations, partial success OK.

### Conditional Operations

```http
PUT    /fhir/Patient?identifier=http://mrn|12345    # Conditional create/update
DELETE /fhir/Patient?identifier=http://mrn|12345    # Conditional delete
```

### $validate

```http
POST /fhir/Patient/$validate
Content-Type: application/fhir+json

{"resourceType": "Patient", "birthDate": "invalid"}
```

## Aidbox-Specific Features

### First-Class Extensions

In Aidbox format (`/Patient` not `/fhir/Patient`), extensions are first-class attributes:

```json
// FHIR format
{"extension": [{"url": "http://example.com/race", "valueString": "..."}]}

// Aidbox format — flat
{"race": "..."}
```

### Custom Resources

Define custom resource types via zen-lang or Aidbox UI:

```yaml
# In zen project
MyCustomResource:
  zen/tags: #{zen.fhir/base-schema}
  type: zen/map
  keys:
    myField: {type: zen/string}
```

### Access Policies

```json
{
  "resourceType": "AccessPolicy",
  "id": "patient-read-policy",
  "engine": "json-schema",
  "schema": {
    "required": ["request-method", "uri"],
    "properties": {
      "request-method": {"const": "get"},
      "uri": {"pattern": "^/fhir/Patient.*"}
    }
  }
}
```

Engines: `json-schema`, `sql`, `matcho`, `allow`, `complex`.

### SQL API

```http
POST /$sql
Content-Type: text/yaml

- select * from patient where resource->>'birthDate' > '1990-01-01' limit 10
```

Or via `/\$psql` for interactive queries. Tables follow naming: resource type in lowercase (e.g., `patient`, `observation`). Resource stored in `resource` JSONB column.

### Subscriptions (Topic-Based)

```json
{
  "resourceType": "AidboxTopicDestination",
  "topic": "http://example.com/patient-changes",
  "kind": "webhook",
  "url": "https://my-service.com/webhook",
  "filter": [{"resourceType": "Patient"}]
}
```

### Bulk API

```http
GET /fhir/$export                    # System-level export
GET /fhir/Group/<id>/$export         # Group export
POST /fhir/$import                   # Bulk import (ndjson)
```

### Terminology

```http
GET  /fhir/ValueSet/$expand?url=<vs-url>&filter=<text>
POST /fhir/CodeSystem/$lookup
POST /fhir/ConceptMap/$translate
```

## Running Aidbox

### Docker Compose (typical setup)

```yaml
services:
  aidbox:
    image: healthsamurai/aidboxone:latest
    ports:
      - "8888:8888"
    environment:
      AIDBOX_LICENSE: <license-key>
      PGHOST: db
      PGPORT: 5432
      PGDATABASE: aidbox
      PGUSER: postgres
      PGPASSWORD: postgres
      AIDBOX_PORT: 8888
      AIDBOX_FHIR_VERSION: 4.0.1
      AIDBOX_BASE_URL: http://localhost:8888
      AIDBOX_ADMIN_ID: admin
      AIDBOX_ADMIN_PASSWORD: password
      AIDBOX_CLIENT_ID: root
      AIDBOX_CLIENT_SECRET: secret
    depends_on:
      db:
        condition: service_healthy

  db:
    image: healthsamurai/aidboxdb:17.2
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: aidbox
    healthcheck:
      test: pg_isready -U postgres
      interval: 5s
```

### Key Environment Variables

| Variable | Description |
|----------|-------------|
| `AIDBOX_LICENSE` | License key (required) |
| `AIDBOX_FHIR_VERSION` | `4.0.1` (R4) or `4.0.0` |
| `AIDBOX_PORT` | HTTP port (default 8888) |
| `AIDBOX_BASE_URL` | Public base URL |
| `AIDBOX_ADMIN_ID/PASSWORD` | Admin user credentials |
| `AIDBOX_CLIENT_ID/SECRET` | Root client credentials |
| `AIDBOX_ZEN_PROJECT` | Path to zen project |
| `AIDBOX_ZEN_ENTRYPOINT` | Zen namespace entrypoint |
| `BOX_SEARCH_FHIR__COMPARISONS` | Enable FHIR search comparisons |
| `BOX_FEATURES_VALIDATION_SKIP` | Skip validation (dev only) |

## Auth & Clients

```http
# Get token via client credentials
POST /auth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=root&client_secret=secret
```

```bash
# Use with curl
curl -u root:secret http://localhost:8888/fhir/Patient
```

## SDKs

- **TypeScript**: `@aidbox/sdk-r4` — typed FHIR client
- **Python**: `aidbox-python` — FHIR client
- **Java**: Aidbox Java SDK
- **C#**: Aidbox .NET SDK

## Workflow: Common Tasks

### 1. Loading data
Use transaction bundles or `$import` for bulk loading. For large datasets prefer `$import` with ndjson.

### 2. Setting up search
Create SearchParameter resources for custom search params. Aidbox auto-indexes them.

### 3. Adding profiles
Upload StructureDefinition resources. Enable validation per-resource or globally via `AIDBOX_VALIDATION`.

### 4. Access control
Create AccessPolicy resources. Test with `POST /$access-policy-check`.

### 5. Integrations
Use AidboxTopicDestination for webhooks, or poll `_history` for changes.
