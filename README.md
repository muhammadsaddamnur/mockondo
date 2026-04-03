# Mockondo

**A no-code mock server for frontend developers.**

Mockondo lets you spin up a local HTTP + WebSocket server, define endpoints, and return realistic dynamic responses — all without writing a single line of backend code. Built with Flutter, it runs as a native desktop app on macOS, Windows, and Linux.

---

## Features

| Feature | Description |
|---|---|
| **Multi-project management** | Create and switch between multiple mock API projects, each with its own host and port. |
| **HTTP mock server** | Run a Shelf-based local server on any port; start/stop with one click. |
| **WebSocket mock server** | Define WebSocket endpoints with on-connect messages, message-matching rules, and scheduled push messages. |
| **Mock S3 storage** | S3-compatible local object storage server with bucket/object management, presigned URLs, and file upload/download. |
| **Response interpolation** | Use `${...}` placeholders in response bodies, headers, and endpoint paths for dynamic, realistic data. |
| **Conditional response rules** | Return different responses based on query params, headers, body fields, or route params. |
| **Pagination simulation** | Generate paginated data from a per-item template with configurable `limit` and `page` params. |
| **Artificial response delay** | Simulate network latency per-endpoint (milliseconds). |
| **Custom data store** | Define reusable lists of values and reference them via `${customdata.*}` in responses. |
| **Built-in HTTP client** | Send requests to any URL directly from the app, with headers, query params, JSON/form/binary body types, and interpolation support. |
| **Built-in WebSocket client** | Connect to any WebSocket server, send messages with interpolation, and view the conversation log. |
| **JSON to code generator** | Paste a JSON payload and generate typed model classes for Dart, TypeScript, Kotlin, Swift, and more. |
| **OpenAPI export/import** | Export HTTP mock endpoints as an OpenAPI 3.0.3 spec (JSON) or import an existing spec per-project. Interpolation placeholders are resolved on export. |
| **AsyncAPI export/import** | Export WebSocket mock endpoints as an AsyncAPI 2.6 spec (JSON) or import an existing spec per-project. |
| **Full project export/import** | Export or import the entire app state (all projects, HTTP client requests, WebSocket connections, S3 configuration and objects) as a single JSON file. |
| **Request terminal** | Live log of all incoming requests, expandable to show full request + response headers and body. |
| **Proxy fallback** | When no mock endpoint matches, requests are optionally forwarded to a real upstream API. |
| **Interpolation autocomplete** | All text fields support `${` autocomplete suggestions for the full interpolation API. |

---

## Interpolation

Mockondo's interpolation engine resolves `${...}` placeholders inside response bodies, headers, and endpoint URL paths at request time. Placeholders are organised into namespaces.

### `random.*` — random data

| Placeholder | Output |
|---|---|
| `${random.uuid}` | UUID v4 string, e.g. `"e7a9e2b4-5e6f-44a9-b812-bffb0db6c7c4"` |
| `${random.integer.100}` | Random integer in `[0, 100)`, e.g. `42` |
| `${random.double.10.5}` | Random float in `[0.0, 10.5)`, e.g. `7.2183` |
| `${random.string.20}` | Random 20-character alphanumeric string |
| `${random.name}` | Full name, e.g. `"John Doe"` |
| `${random.username}` | Username, e.g. `"john_doe"` |
| `${random.email}` | Email address, e.g. `"john@example.com"` |
| `${random.url}` | HTTP URL |
| `${random.phone}` | Phone number |
| `${random.lorem}` | Lorem ipsum sentence |
| `${random.jwt}` | Valid JWT token |
| `${random.date}` | Current UTC timestamp in ISO-8601 format |
| `${random.image.400x400}` | `"https://placehold.co/400x400"` |
| `${random.image.400x400.index}` | Placeholder image with current item index as text overlay |
| `${random.image.400x400.label}` | Placeholder image with `"label"` as text overlay |
| `${random.index}` | Current item index (set by the pagination engine) |

### `request.*` — values from the incoming request

| Placeholder | Description |
|---|---|
| `${request.url.query.page}` | Value of the `page` query parameter |
| `${request.url.path.0}` | First path segment (zero-based index) |
| `${request.header.authorization}` | Value of the `Authorization` header (case-insensitive) |
| `${request.body.field}` | Top-level field from the JSON request body |
| `${request.body.user.email}` | Nested field via dot notation |

### `customdata.*` — user-defined data lists

| Placeholder | Description |
|---|---|
| `${customdata.cities}` | First value in the `cities` list |
| `${customdata.random.cities}` | Random value from the `cities` list |
| `${customdata.cities.Jakarta}` | `"Jakarta"` if it exists in the list |

Define your data lists in the **Custom Data** panel (toolbar icon).

### `pagination.*` — pagination context

| Placeholder | Description |
|---|---|
| `${pagination.data}` | The generated array of items for the current page |
| `${pagination.request.url.query.page}` | The `page` query param, read in pagination context |

### `math.*` — arithmetic expressions

| Placeholder | Description |
|---|---|
| `${math.2+3}` | Evaluates to `5` |
| `${math.10*2+1}` | Evaluates to `21` |

Math expressions support nested interpolation, e.g. `${math.${request.url.query.page}*10}`.

---

## HTTP mock server

Each project can define multiple HTTP endpoints. Each endpoint has:

- **Method** — GET, POST, PUT, PATCH, DELETE
- **Endpoint path** — supports path params (`/users/<id>`) and `${customdata.*}` interpolation
- **Default response** — status code, headers, and JSON body with `${...}` placeholders
- **Delay** — optional artificial latency in milliseconds
- **Conditional rules** — override the default response when request conditions match

### Response rules

Rules are evaluated in order; the first matching rule wins.

**Condition targets:**

| Target | What it inspects |
|---|---|
| Query param | URL query string parameter |
| Request header | HTTP request header (case-insensitive) |
| Body field | JSON request body field (dot notation supported) |
| Route param | URL path segment (zero-based index) |

**Operators:** `equals`, `notEquals`, `contains`, `notContains`, `regexMatch`, `isEmpty`, `isNotEmpty`

**Logic:** `AND` (all conditions must match) or `OR` (any condition matches)

Each rule has its own response body, response headers, and HTTP status code.

---

## WebSocket mock server

Each project can define multiple WebSocket endpoints alongside HTTP endpoints.

Each WS endpoint supports:
- **On-connect message** — sent immediately when a client connects
- **Message rules** — evaluate incoming messages in order; the first matching rule's response is sent back. Rules can match by exact text or regular expression.
- **Scheduled messages** — push messages to every connected client after a configurable delay, optionally repeating on an interval

---

## Pagination

Enable pagination on an endpoint via the **Pagination** tab in the response editor.

Configure:
- **Max items** — total number of items in the dataset
- **Limit param** — query parameter name for page size (e.g. `limit`)
- **Page param** — query parameter name for the page number (e.g. `page`)
- **Item template** — response body template for a single item; supports all `${random.*}` and `${request.*}` placeholders

The outer response body uses `${pagination.data}` to inject the generated array.

**Example:**

```json
// Item template (one item)
{
  "id": ${random.uuid},
  "name": ${random.name},
  "avatar": ${random.image.80x80.index}
}

// Outer response body
{
  "page": ${pagination.request.url.query.page},
  "total": 100,
  "data": ${pagination.data}
}
```

---

## Mock S3 storage

Mockondo includes a self-contained S3-compatible object storage server. It accepts standard AWS SDK requests and works as a local drop-in replacement for Amazon S3.

Features:
- Create and delete buckets
- Upload, download, and delete objects (via the UI or any S3-compatible client/SDK)
- Virtual folder navigation via key prefixes
- Presigned URL generation (GET and PUT)
- Binds to the device's Wi-Fi IP automatically; no manual host configuration required
- Objects are persisted to `~/.mockondo/s3/` on disk

Connect your AWS SDK by pointing the endpoint to `http://<wifi-ip>:<port>` with the configured access key, secret key, and region.

---

## Built-in HTTP client

The HTTP client lets you send requests directly from the app.

- HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD
- Headers and query parameters (toggle-able per entry)
- Body types: JSON, plain text, form data (URL-encoded or multipart), binary file
- Full `${...}` interpolation support in URL, headers, params, and body
- Import from cURL (paste a `curl` command to populate the request)
- Export to cURL
- Organise requests into named groups with drag-and-drop reordering
- Expandable response panel with status code, duration, headers, and pretty-printed body

---

## Built-in WebSocket client

The WS client tab lets you connect to any WebSocket server.

- Connect/disconnect with a single click
- Send messages with full `${...}` interpolation support
- Live conversation log showing sent and received messages with timestamps
- Save connections for later reuse

---

## JSON to code generator

Paste any JSON payload and Mockondo generates typed model classes ready to copy into your project.

Supported languages:
- Dart (with `fromJson` / `toJson`)
- TypeScript (interfaces)
- Kotlin (data classes)
- Swift (structs with Codable)
- And more

---

## OpenAPI & AsyncAPI

Each project's context menu exposes import/export options for standard API schemas.

| Action | Format | Scope |
|---|---|---|
| Export OpenAPI | OpenAPI 3.0.3 JSON | HTTP endpoints of the selected project |
| Import OpenAPI | OpenAPI 3.0.3 JSON | Appends parsed endpoints to the project |
| Export AsyncAPI | AsyncAPI 2.6.0 JSON | WebSocket endpoints of the selected project |
| Import AsyncAPI | AsyncAPI 2.6.0 JSON | Appends parsed WS endpoints to the project |

On export, all `${...}` interpolation placeholders in paths, summaries, and response bodies are resolved to their actual values. Mockondo-specific metadata (delay, enable state, rules) is preserved in `x-mockondo-*` extension fields.

---

## Export / Import

The toolbar's **Export** button saves the complete app state to a single JSON file:

- All mock projects (HTTP + WS endpoints, settings)
- HTTP client requests and groups
- WebSocket client connections
- S3 configuration, buckets, and object metadata

Use **Import** to restore or share an environment between machines.

---

## Request terminal

The terminal panel at the bottom of each project shows a live log of all incoming HTTP requests.

Each entry displays: timestamp · method · path · status code · duration. Clicking an entry expands it to reveal:

- **Request** — headers and body
- **Response** — headers and body (pretty-printed JSON when applicable)

---

## Custom data

The **Custom Data** panel lets you define named lists of values that can be referenced from any response body, header, or endpoint path via `${customdata.<key>}`.

**Use cases:** city names, product categories, status labels, user IDs, or any static set of strings.

---

## Proxy fallback

When a project has a **Host** configured, any request that doesn't match a defined mock endpoint is automatically forwarded to that upstream URL and its response is returned to the client. gzip-encoded upstream responses are decompressed transparently.

---

## Technology stack

| Layer | Technology |
|---|---|
| UI | Flutter (Dart) |
| HTTP server | [Shelf](https://pub.dev/packages/shelf) + [shelf_router](https://pub.dev/packages/shelf_router) |
| WebSocket server | [shelf_web_socket](https://pub.dev/packages/shelf_web_socket) |
| State management | [GetX](https://pub.dev/packages/get) |
| Persistence | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Fake data | [Faker](https://pub.dev/packages/faker) |
| Math evaluation | [math_expressions](https://pub.dev/packages/math_expressions) |
| Code editor | [re_editor](https://pub.dev/packages/re_editor) |
| Network info | [network_info_plus](https://pub.dev/packages/network_info_plus) |

---

## Running locally

```bash
git clone https://github.com/<org>/mockondo.git
cd mockondo
flutter pub get
flutter run -d macos   # or windows / linux
```

Requires Flutter 3.13+ and Dart 3.7+.

---

## Running tests

```bash
flutter test
```

Unit tests cover the interpolation engine, model serialisation, routing rule evaluation, cURL parsing, HTTP client models, WebSocket models, S3 models, and utility functions.

---

## License

MIT License © 2025 — Mockondo Team
