# Mockondo Remote Server API

The **Remote Server** is an optional HTTP control plane that lets external tools (AI agents, CI/CD pipelines, scripts) interact with all Mockondo features programmatically. When enabled, it runs alongside the mock servers and exposes a REST API on a configurable port (default: **`3131`**).

---

## Table of Contents

- [Overview](#overview)
- [Enable / Configuration](#enable--configuration)
- [Base URL](#base-url)
- [Response Format](#response-format)
- [Endpoints](#endpoints)
  - [Status](#status)
  - [Agent Prompt](#agent-prompt)
  - [Projects](#projects)
  - [HTTP Mock Endpoints](#http-mock-endpoints)
  - [Rules](#rules)
  - [WebSocket Mock Endpoints](#websocket-mock-endpoints)
  - [Custom Data](#custom-data)
  - [Mock S3](#mock-s3)
    - [Presigned URLs](#presigned-urls)
  - [OpenAPI / AsyncAPI Schema](#openapi--asyncapi-schema)
  - [Schema to Code Prompt](#schema-to-code-prompt)
  - [Export / Import](#export--import)

---

## Overview

| Feature | Description |
|---|---|
| **Protocol** | HTTP/1.1 |
| **Default Port** | `3131` |
| **Content-Type** | `application/json` |
| **Authentication** | Optional API key (Bearer token) |

---

## Enable / Configuration

Open **Settings** in Mockondo and toggle **"Enable Remote Server"**.

| Setting | Default | Description |
|---|---|---|
| Enabled | `false` | Turn the remote control server on/off |
| Port | `3131` | TCP port to listen on |
| API Key | _(empty)_ | Optional. If set, all requests must include `Authorization: Bearer <key>` |

Changes take effect immediately (server restarts on port/key change).

---

## Base URL

```
http://localhost:3131
```

---

## Response Format

### Success

```json
{
  "success": true,
  "data": { ... }
}
```

### Error

```json
{
  "success": false,
  "message": "Human readable error"
}
```

---

## Endpoints

### Status

#### `GET /api/status`

Returns the overall state of the Mockondo app.

**Response:**
```json
{
  "success": true,
  "data": {
    "remoteServerPort": 3131,
    "projects": [
      {
        "id": "abc123",
        "name": "My API",
        "host": "localhost",
        "port": 8080,
        "isRunning": true,
        "endpointCount": 5,
        "wsEndpointCount": 2
      }
    ],
    "s3": {
      "isRunning": false,
      "host": "localhost",
      "port": 9000
    }
  }
}
```

---

### Agent Prompt

#### `GET /api/agent-prompt`

Returns a comprehensive, structured JSON payload designed to onboard AI agents. The payload contains the system prompt, current server state, full API reference, interpolation examples, workflow examples, and best practices.

**Response:**
```json
{
  "success": true,
  "data": {
    "systemPrompt": "You are an AI assistant...",
    "currentState": { ... },
    "apiReference": { ... },
    "interpolationReference": { ... },
    "workflowExamples": [ ... ],
    "bestPractices": [ ... ],
    "errorHandling": { ... }
  }
}
```

---

### Projects

Projects are the top-level containers. Each project has its own host/port and a list of HTTP and WebSocket mock endpoints.

#### `GET /api/projects`

List all projects.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "abc123",
      "name": "My API",
      "host": "localhost",
      "port": 8080,
      "isRunning": true,
      "endpointCount": 5,
      "wsEndpointCount": 2
    }
  ]
}
```

---

#### `POST /api/projects`

Create a new project.

**Request body:**
```json
{
  "name": "My API",
  "host": "localhost",
  "port": 8080
}
```

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | string | yes | — | Project display name |
| `host` | string | no | `"localhost"` | Bind host |
| `port` | integer | no | `8080` | Listen port |

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "abc123",
    "name": "My API",
    "host": "localhost",
    "port": 8080,
    "isRunning": false
  }
}
```

---

#### `GET /api/projects/:id`

Get a full project including all endpoints and WebSocket endpoints.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "abc123",
    "name": "My API",
    "host": "localhost",
    "port": 8080,
    "isRunning": true,
    "mockModels": [ ... ],
    "wsMockModels": [ ... ]
  }
}
```

---

#### `PUT /api/projects/:id`

Update project metadata (name, host, port). Restarts the server if it was running.

**Request body (all fields optional):**
```json
{
  "name": "New Name",
  "host": "0.0.0.0",
  "port": 9090
}
```

**Response:**
```json
{
  "success": true,
  "data": { "id": "abc123", "name": "New Name", "host": "0.0.0.0", "port": 9090, "isRunning": true }
}
```

---

#### `DELETE /api/projects/:id`

Delete a project. Stops the server if running.

**Response:**
```json
{ "success": true, "data": null }
```

---

#### `POST /api/projects/:id/start`

Start the mock server for a project.

**Response:**
```json
{
  "success": true,
  "data": { "id": "abc123", "isRunning": true, "host": "localhost", "port": 8080 }
}
```

---

#### `POST /api/projects/:id/stop`

Stop the mock server for a project.

**Response:**
```json
{
  "success": true,
  "data": { "id": "abc123", "isRunning": false }
}
```

---

### HTTP Mock Endpoints

Each project contains a list of HTTP mock endpoint definitions (`MockModel`).

#### `GET /api/projects/:id/endpoints`

List all HTTP endpoints for a project.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "ep1",
      "endpoint": "/users",
      "method": "GET",
      "statusCode": 200,
      "responseBody": "{\"users\": []}",
      "delay": 0,
      "responseHeader": "",
      "rules": []
    }
  ]
}
```

---

#### `POST /api/projects/:id/endpoints`

Create a new HTTP endpoint.

**Request body:**
```json
{
  "endpoint": "/users/:id",
  "method": "GET",
  "statusCode": 200,
  "responseBody": "{\"id\": \"${request.url.param.id}\", \"name\": \"${random.name}\"}",
  "delay": 0,
  "responseHeader": "Content-Type: application/json"
}
```

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `endpoint` | string | yes | — | Path (supports `:param` segments) |
| `method` | string | yes | — | `GET`, `POST`, `PUT`, `PATCH`, `DELETE` |
| `statusCode` | integer | no | `200` | HTTP status to return |
| `responseBody` | string | no | `""` | Response body (supports `${...}` interpolation) |
| `delay` | integer | no | `0` | Artificial delay in milliseconds |
| `responseHeader` | string | no | `""` | Extra response headers (`Key: Value` per line) |

**Response:**
```json
{
  "success": true,
  "data": { "id": "ep2", "endpoint": "/users/:id", "method": "GET", ... }
}
```

---

#### `GET /api/projects/:id/endpoints/:endpointId`

Get a single HTTP endpoint.

**Response:**
```json
{
  "success": true,
  "data": { "id": "ep1", "endpoint": "/users", ... }
}
```

---

#### `PUT /api/projects/:id/endpoints/:endpointId`

Update an HTTP endpoint (all fields optional).

**Request body:**
```json
{
  "statusCode": 404,
  "responseBody": "{\"error\": \"not found\"}"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "id": "ep1", "statusCode": 404, ... }
}
```

---

#### `DELETE /api/projects/:id/endpoints/:endpointId`

Delete an HTTP endpoint.

**Response:**
```json
{ "success": true, "data": null }
```

---

### Rules

Rules allow you to define conditional overrides or pagination for an HTTP endpoint. 
Only one pagination rule can exist per endpoint. Normal response rules are evaluated in order; the first match wins.

#### `GET /api/projects/:id/endpoints/:endpointId/rules`

List all rules for an endpoint.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "rule1",
      "type": "response",
      "isPagination": false,
      "response": "{\"error\": \"unauthorized\"}",
      "statusCode": 401,
      "conditions": [
        {
          "target": "RequestHeader",
          "key": "Authorization",
          "operator": "isEmpty",
          "value": "",
          "logic": "AND"
        }
      ]
    },
    {
      "type": "pagination",
      "isPagination": true,
      "responseBody": "{\"body\": ${pagination.data}, \"total\": 100}",
      "offsetParam": "page",
      "limitParam": "limit",
      "max": 100,
      "customLimit": null,
      "customOffset": null,
      "offsetType": null
    }
  ]
}
```

---

#### `POST /api/projects/:id/endpoints/:endpointId/rules`

Add a rule to an endpoint. You can create either a Response Rule or a Pagination Rule.

**Scenario A: Create a Response Override Rule**

**Request body:**
```json
{
  "isPagination": false,
  "responseBody": "{\"error\": \"unauthorized\"}",
  "statusCode": 401,
  "label": "Check Auth",
  "logic": "AND",
  "conditions": [
    {
      "target": "RequestHeader",
      "key": "Authorization",
      "operator": "isEmpty",
      "value": ""
    }
  ]
}
```

**Scenario B: Create a Pagination Rule**

📝 Note for Pagination Rules: 
- For the pagination rule's `responseBody` field in your `POST` request, you define how the **single individual item** should look like.
- For the `responseBody` field in the original **endpoint** configuration (`POST /api/projects/:id/endpoints` or `PUT /api/projects/:id/endpoints/:endpointIndex`), you define the wrapper and inject `${pagination.data}`.
- IMPORTANT: When using interpolation, wrap strings in quotes (e.g., `"id": "${random.uuid}"`). Do not wrap arrays or numbers in quotes (e.g., `"count": ${math.1+1}`).

**Step 1: Set the wrapper in the Endpoint**
`(POST /api/projects/:id/endpoints)` or `(PUT /api/projects/:id/endpoints/:endpointIndex)`
```json
{
  "responseBody": "{\"body\": ${pagination.data}}"
}
```

**Step 2: Set the item template in the Pagination Rule**
`(POST /api/projects/:id/endpoints/:endpointIndex/rules)`
```json
{
  "isPagination": true,
  "responseBody": "{\"id\": ${random.uuid}, \"title\": \"Artikel ${math.1+1}\"}",
  "offsetParam": "page",
  "limitParam": "limit",
  "max": 100
}
```

Now you can test it:
```bash
curl -X GET 'http://localhost:8080/api/items?page=1&limit=3'
```

| Pagination Field | Type | Default | Description |
|---|---|---|---|
| `offsetParam` | string | `"page"` | Query parameter for page index/offset. |
| `limitParam` | string | `"limit"` | Query parameter for page size. |
| `max` | integer | `0` | Total number of items simulated in the data set. |
| `customLimit` | integer | null | Fixed page size (ignores URL limit param). |
| `customOffset` | integer | null | Fixed offset (ignores URL offset param). |
| `offsetType` | string | null | Enum: `"param"` (reads from URL) or `"custom"` (uses `customOffset`). |

**Condition fields (for `isPagination: false`):**

| Field | Values | Description |
|---|---|---|
| `target` | `QueryParam`, `RequestHeader`, `BodyField`, `RouteParam` | Where to look |
| `key` | string | Field name |
| `operator` | `equals`, `notEquals`, `contains`, `notContains`, `regexMatch`, `isEmpty`, `isNotEmpty` | Comparison |
| `value` | string | Value to compare against |
| `logic` | `AND`, `OR` | How to combine with next condition |

**Response:**
```json
{
  "success": true,
  "data": { "id": "rule2", ... }
}
```

---

#### `PUT /api/projects/:id/endpoints/:endpointId/rules/:ruleId`

Update a rule.

---

#### `DELETE /api/projects/:id/endpoints/:endpointId/rules/:ruleId`

Delete a rule.

**Response:**
```json
{ "success": true, "data": null }
```

---

### WebSocket Mock Endpoints

#### `GET /api/projects/:id/ws-endpoints`

List all WebSocket endpoints for a project.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "ws1",
      "endpoint": "/chat",
      "onConnectMessage": "{\"type\": \"welcome\"}",
      "rules": [],
      "scheduledMessages": []
    }
  ]
}
```

---

#### `POST /api/projects/:id/ws-endpoints`

Create a WebSocket endpoint.

**Request body:**
```json
{
  "endpoint": "/chat",
  "onConnectMessage": "{\"type\": \"welcome\", \"id\": \"${random.uuid}\"}",
  "rules": [
    {
      "pattern": "ping",
      "isRegex": false,
      "response": "pong"
    }
  ],
  "scheduledMessages": [
    {
      "message": "{\"type\": \"heartbeat\"}",
      "delayMs": 5000,
      "repeat": true,
      "intervalMs": 10000
    }
  ]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `endpoint` | string | yes | WebSocket path |
| `onConnectMessage` | string | no | Message sent immediately on client connect |
| `rules` | array | no | Message matching rules (first match wins) |
| `scheduledMessages` | array | no | Server-push messages with timer |

**Rule fields:**

| Field | Type | Description |
|---|---|---|
| `pattern` | string | Exact string or regex to match incoming message |
| `isRegex` | boolean | Treat `pattern` as a regex |
| `response` | string | Response to send when matched (supports `${...}`) |

**Scheduled message fields:**

| Field | Type | Description |
|---|---|---|
| `message` | string | Message to push (supports `${...}`) |
| `delayMs` | integer | Initial delay before first send (ms) |
| `repeat` | boolean | Whether to keep sending periodically |
| `intervalMs` | integer | Interval between repeats (ms); only relevant if `repeat: true` |

**Response:**
```json
{
  "success": true,
  "data": { "id": "ws2", "endpoint": "/chat", ... }
}
```

---

#### `GET /api/projects/:id/ws-endpoints/:wsId`

Get a single WebSocket endpoint.

---

#### `PUT /api/projects/:id/ws-endpoints/:wsId`

Update a WebSocket endpoint (all fields optional).

---

#### `DELETE /api/projects/:id/ws-endpoints/:wsId`

Delete a WebSocket endpoint.

**Response:**
```json
{ "success": true, "data": null }
```

---

### Custom Data

Custom data are user-defined lists accessible in interpolation via `${customdata.<key>}` and `${customdata.random.<key>}`.

#### `GET /api/custom-data`

List all custom data keys.

**Response:**
```json
{
  "success": true,
  "data": {
    "cities": ["New York", "London", "Tokyo"],
    "colors": ["red", "green", "blue"]
  }
}
```

---

#### `GET /api/custom-data/:key`

Get values for a single key.

**Response:**
```json
{
  "success": true,
  "data": ["New York", "London", "Tokyo"]
}
```

---

#### `POST /api/custom-data/:key`

Create or replace a custom data list.

**Request body:**
```json
{
  "values": ["New York", "London", "Tokyo"]
}
```

**Response:**
```json
{
  "success": true,
  "data": { "key": "cities", "values": ["New York", "London", "Tokyo"] }
}
```

---

#### `PATCH /api/custom-data/:key`

Append values to an existing list (creates the key if it doesn't exist).

**Request body:**
```json
{
  "values": ["Paris", "Berlin"]
}
```

**Response:**
```json
{
  "success": true,
  "data": { "key": "cities", "values": ["New York", "London", "Tokyo", "Paris", "Berlin"] }
}
```

---

#### `DELETE /api/custom-data/:key`

Delete a custom data list.

**Response:**
```json
{ "success": true, "data": null }
```

---

### Mock S3

#### `GET /api/s3/config`

Get the current S3 mock configuration.

**Response:**
```json
{
  "success": true,
  "data": {
    "host": "localhost",
    "port": 9000,
    "accessKeyId": "mockondo",
    "secretAccessKey": "mockondo",
    "region": "us-east-1",
    "isRunning": false
  }
}
```

---

#### `PUT /api/s3/config`

Update S3 configuration. Restarts the S3 server if it was running.

**Request body (all fields optional):**
```json
{
  "host": "0.0.0.0",
  "port": 9000,
  "accessKeyId": "mykey",
  "secretAccessKey": "mysecret",
  "region": "eu-west-1"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "host": "0.0.0.0", "port": 9000, ... }
}
```

---

#### `POST /api/s3/start`

Start the S3 mock server.

**Response:**
```json
{
  "success": true,
  "data": { "isRunning": true, "host": "localhost", "port": 9000 }
}
```

---

#### `POST /api/s3/stop`

Stop the S3 mock server.

**Response:**
```json
{
  "success": true,
  "data": { "isRunning": false }
}
```

---

#### `GET /api/s3/buckets`

List all buckets.

**Response:**
```json
{
  "success": true,
  "data": [
    { "name": "my-bucket", "createdAt": "2024-01-15T10:30:00Z" }
  ]
}
```

---

#### `POST /api/s3/buckets`

Create a bucket.

**Request body:**
```json
{ "name": "my-bucket" }
```

**Response:**
```json
{
  "success": true,
  "data": { "name": "my-bucket", "createdAt": "2024-01-15T10:30:00Z" }
}
```

---

#### `DELETE /api/s3/buckets/:bucket`

Delete a bucket and all its objects.

**Response:**
```json
{ "success": true, "data": null }
```

---

#### `GET /api/s3/objects/:bucket`

List objects in a bucket.

**Query parameters:**
| Param | Description |
|---|---|
| `prefix` | Filter objects by key prefix (simulates folder navigation) |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "bucket": "my-bucket",
      "key": "images/photo.jpg",
      "size": 204800,
      "contentType": "image/jpeg",
      "lastModified": "2024-01-15T10:30:00Z",
      "etag": "abc123"
    }
  ]
}
```

---

#### `DELETE /api/s3/objects/:bucket/*key`

Delete an object.

**Response:**
```json
{ "success": true, "data": null }
```

---

### Presigned URLs

#### `POST /api/s3/presign`

Generate a presigned URL for a GET (download) or PUT (upload) operation on an object.

**Request body:**
```json
{
  "bucket": "my-bucket",
  "key": "images/photo.jpg",
  "operation": "GET",
  "expirySeconds": 3600
}
```

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `bucket` | string | yes | — | Bucket name |
| `key` | string | yes | — | Object key (path) |
| `operation` | string | yes | — | `GET` (download) or `PUT` (upload) |
| `expirySeconds` | integer | no | `3600` | Token validity in seconds |

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "http://localhost:9000/my-bucket/images/photo.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Signature=<token>",
    "operation": "GET",
    "bucket": "my-bucket",
    "key": "images/photo.jpg",
    "token": "abcdef1234567890",
    "expiresAt": "2024-01-15T11:30:00.000Z"
  }
}
```

The returned `url` can be used directly to download (`GET`) or upload (`PUT`) the object from/to the S3 mock server without authentication credentials.

---

### OpenAPI / AsyncAPI Schema

#### `GET /api/projects/:id/export/openapi`

Export all HTTP endpoints of a project as an **OpenAPI 3.0.3** JSON spec.

**Response:**
```json
{
  "success": true,
  "data": {
    "openapi": "3.0.3",
    "info": { "title": "My API", "version": "1.0.0" },
    "servers": [{ "url": "localhost:8080" }],
    "paths": { ... }
  }
}
```

---

#### `GET /api/projects/:id/export/asyncapi`

Export all WebSocket endpoints of a project as an **AsyncAPI 2.6.0** JSON spec.

**Response:**
```json
{
  "success": true,
  "data": {
    "asyncapi": "2.6.0",
    "info": { "title": "My API", "version": "1.0.0" },
    "channels": { ... }
  }
}
```

---

#### `POST /api/projects/:id/import/openapi`

Import HTTP endpoints from an OpenAPI 3.0 spec. Appends to existing endpoints (does not replace).

**Request body:**
```json
{
  "spec": { "openapi": "3.0.3", "paths": { ... } }
}
```

The `spec` field accepts either a JSON object or a JSON string.

**Response:**
```json
{
  "success": true,
  "data": {
    "imported": 5,
    "endpoints": [ ... ]
  }
}
```

---

#### `POST /api/projects/:id/import/asyncapi`

Import WebSocket endpoints from an AsyncAPI 2.x spec. Appends to existing WS endpoints.

**Request body:**
```json
{
  "spec": { "asyncapi": "2.6.0", "channels": { ... } }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "imported": 2,
    "wsEndpoints": [ ... ]
  }
}
```

---

### Schema to Code Prompt

#### `GET /api/projects/:id/schema-to-code-prompt`

Returns a ready-to-use AI prompt that generates a **SQL database schema** and **backend source code** from the project's OpenAPI + AsyncAPI specs.

**Query parameters:**

| Param | Default | Description |
|---|---|---|
| `lang` | `auto` | Target language: `typescript`, `python`, `go`, `java`, `kotlin`, `swift`, `php`, `ruby` |
| `db` | `postgresql` | SQL dialect: `postgresql`, `mysql`, `sqlite`, `mssql` |

**Example:**
```
GET /api/projects/1/schema-to-code-prompt?lang=typescript&db=postgresql
```

**Response:**
```json
{
  "success": true,
  "data": {
    "projectName": "User Service",
    "language": "typescript",
    "dbDialect": "postgresql",
    "openApiSpec": { ... },
    "asyncApiSpec": { ... },
    "prompt": "You are a senior software engineer. Using the API specifications below, generate production-ready backend code and a database schema.\n\n## Project: User Service\n..."
  }
}
```

**Usage:**

1. Call this endpoint with your desired `lang` and `db` params.
2. Take the `"prompt"` field from the response.
3. Send it directly to any AI model (Claude, GPT, etc.).
4. The AI will return a SQL file with all tables + a backend implementation for every endpoint.

---

### Export / Import

#### `GET /api/export`

Export the complete Mockondo workspace as a JSON snapshot.

**Response:**
```json
{
  "success": true,
  "data": {
    "version": "1.0",
    "exportedAt": "2024-01-15T10:30:00Z",
    "mockData": [ ... ],
    "httpClientRequests": [ ... ],
    "wsClientConnections": [ ... ],
    "s3Config": { ... },
    "customData": { ... }
  }
}
```

---

#### `POST /api/import`

Import a workspace snapshot. Merges or replaces existing data.

**Request body:**
```json
{
  "replace": false,
  "data": { ... }
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `replace` | boolean | `false` | `true` = wipe existing data before importing; `false` = merge |
| `data` | object | — | Exported snapshot object |

**Response:**
```json
{
  "success": true,
  "data": {
    "projectsImported": 3,
    "endpointsImported": 12
  }
}
```

---

## Interpolation Reference

> [!IMPORTANT]
> **Quotes are handled automatically.** String placeholders like `${random.uuid}`, `${random.name}`, etc. are replaced with their JSON-encoded value — the surrounding quotes are added by the engine. Do **not** add extra quotes around them.
> - ✅ `{"id": ${random.uuid}}` → `{"id": "actual-uuid"}`
> - ❌ `{"id": "${random.uuid}"}` → `{"id": ""actual-uuid""}` (double quotes, invalid JSON)
> - Array/number placeholders (`${pagination.data}`, `${random.integer.100}`, `${math.2+3}`) are replaced as-is with no wrapping quotes.

All `responseBody`, `onConnectMessage`, and scheduled `message` fields support `${...}` interpolation:

| Expression | Description |
|---|---|
| `${random.uuid}` | UUID v4 |
| `${random.integer.100}` | Random integer [0, 100) |
| `${random.name}` | Random full name |
| `${random.email}` | Random email |
| `${random.image.400x400}` | Placeholder image URL |
| `${random.jwt}` | Random JWT token |
| `${request.url.query.<key>}` | Query parameter |
| `${request.url.param.<key>}` | Route parameter |
| `${request.header.<name>}` | Request header |
| `${request.body.<field>}` | JSON body field |
| `${customdata.<key>}` | First value in custom list |
| `${customdata.random.<key>}` | Random value from custom list |
| `${math.<expression>}` | Math evaluation (e.g. `${math.2+3}`) |
| `${pagination.data}` | Inject the array of evaluated paginated items (Used only in Pagination Rule `responseBody`) |

---

## HTTP Method Values

Valid values for the `method` field:

| Value | HTTP Method |
|---|---|
| `GET` | GET |
| `POST` | POST |
| `PUT` | PUT |
| `PATCH` | PATCH |
| `DELETE` | DELETE |

---

## Error Codes

| Scenario | HTTP Status | `message` |
|---|---|---|
| Invalid JSON body | `400` | `"Invalid request body"` |
| Missing required field | `400` | `"Field '<name>' is required"` |
| Project not found | `404` | `"Project not found"` |
| Endpoint not found | `404` | `"Endpoint not found"` |
| Rule not found | `404` | `"Rule not found"` |
| WS endpoint not found | `404` | `"WebSocket endpoint not found"` |
| Custom data key not found | `404` | `"Custom data key not found"` |
| Unauthorized (API key mismatch) | `401` | `"Unauthorized"` |
| Server start failure | `500` | `"Failed to start server: <reason>"` |
