class Prompt {
  static agentPrompt({
    required currentPort,
    required projects,
    required apiKey,
  }) {
    return {
      // ── 1. System prompt ──────────────────────────────────────────────
      'systemPrompt': '''
You are an AI assistant that manages mock APIs through the Mockondo Remote Server.
Mockondo is a desktop app that lets developers spin up HTTP, WebSocket, and S3-compatible mock servers instantly.
You communicate with Mockondo exclusively through its REST control-plane API described below.

Current remote server base URL: http://localhost:$currentPort
${apiKey.isNotEmpty ? 'Authentication required: send header "Authorization: Bearer <key>" with every request.' : 'Authentication: disabled (no API key set).'}

IMPORTANT RULES:
1. Always call GET /api/status first to discover existing projects and their IDs.
2. Project IDs and endpoint indexes are **integers** (not UUIDs).
3. Endpoint indexes are **zero-based** positions in the project's endpoint array.
4. After creating/updating endpoints, you must POST /api/projects/:id/stop then POST /api/projects/:id/start to apply changes on the running server.
5. All request and response bodies use Content-Type: application/json.
6. Response bodies in mock endpoints support \${...} interpolation (see interpolation reference below).
7. When the user asks you to "create a mock API", you should: create a project → add endpoints → start the server.
8. When the user asks to "test" an endpoint, explain the curl command they can use.

INTERPOLATION RULES (READ CAREFULLY — violations cause invalid JSON or silent wrong output):
A. \${...} placeholders are Mockondo-specific template syntax. They are NOT JavaScript, NOT shell variables. You MUST send them as literal strings exactly as written — never evaluate, expand, or replace them yourself.
B. QUOTING: String-producing placeholders (\${random.uuid}, \${random.name}, \${random.email}, \${random.url}, \${random.jwt}, \${random.date}, \${random.lorem}, \${random.username}, \${random.phone}, \${random.image.*}, \${random.string.*}, \${request.*}, \${customdata.*}) are JSON-encoded by the Mockondo engine — they already output their own surrounding double-quotes. NEVER wrap them in extra quotes.
   CORRECT:   {"id": \${random.uuid}}              → engine produces → {"id": "abc-uuid"}
   WRONG:     {"id": "\${random.uuid}"}             → engine produces → {"id": ""abc-uuid""} — INVALID JSON
C. Number placeholders (\${random.integer.*}, \${random.double.*}, \${math.*}) output raw numbers — no quotes added or needed.
D. \${pagination.data} outputs a raw JSON array — no quotes added or needed. NEVER write [] or substitute it yourself. Always send the literal string "\${pagination.data}" in the responseBody.
E. PAGINATION WORKFLOW — you MUST do these two steps in order:
   Step 1: Set the endpoint responseBody to the WRAPPER (e.g. {"items": \${pagination.data}, "total": 100}) via POST or PUT endpoint.
   Step 2: Add a pagination rule with isPagination:true and responseBody = the PER-ITEM template (one object, not an array).
   Never skip Step 1. Never send [] instead of \${pagination.data}.
''',

      // ── 2. Live state snapshot ────────────────────────────────────────
      'currentState': {'remoteServerPort': currentPort, 'projects': projects},

      // ── 3. Full endpoint reference ────────────────────────────────────
      'apiReference': {
        'baseUrl': 'http://localhost:$currentPort',
        'contentType': 'application/json',
        'responseFormat': {
          'success': {'success': true, 'data': '...'},
          'error': {'success': false, 'message': 'Human readable error'},
        },
        'endpoints': [
          // ── Status
          {
            'method': 'GET',
            'path': '/api/status',
            'summary':
                'Get overall Mockondo state including all projects and S3 status.',
          },
          // ── Agent prompt (self)
          {
            'method': 'GET',
            'path': '/api/agent-prompt',
            'summary':
                'Returns this AI-agent onboarding payload (you are reading it now).',
          },
          // ── Projects
          {
            'method': 'GET',
            'path': '/api/projects',
            'summary': 'List all projects.',
          },
          {
            'method': 'POST',
            'path': '/api/projects',
            'summary': 'Create a new project.',
            'requestBody': {
              'name': {'type': 'string', 'required': true},
              'host': {'type': 'string', 'default': 'localhost'},
              'port': {'type': 'integer', 'default': 8080},
            },
          },
          {
            'method': 'GET',
            'path': '/api/projects/:id',
            'summary': 'Get full project with all endpoints and WS endpoints.',
          },
          {
            'method': 'PUT',
            'path': '/api/projects/:id',
            'summary': 'Update project metadata (name, host, port).',
            'requestBody': {
              'name': {'type': 'string', 'optional': true},
              'host': {'type': 'string', 'optional': true},
              'port': {'type': 'integer', 'optional': true},
            },
          },
          {
            'method': 'DELETE',
            'path': '/api/projects/:id',
            'summary': 'Delete a project and stop its server.',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/start',
            'summary': 'Start the mock server for a project.',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/stop',
            'summary': 'Stop the mock server for a project.',
          },
          // ── HTTP Endpoints
          {
            'method': 'GET',
            'path': '/api/projects/:id/endpoints',
            'summary': 'List all HTTP mock endpoints for a project.',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/endpoints',
            'summary': 'Create a new HTTP mock endpoint.',
            'requestBody': {
              'endpoint': {
                'type': 'string',
                'required': true,
                'description': 'Path, supports :param segments',
              },
              'method': {
                'type': 'string',
                'required': true,
                'description': 'GET, POST, PUT, PATCH, DELETE',
              },
              'statusCode': {'type': 'integer', 'default': 200},
              'responseBody': {
                'type': 'string',
                'default': '',
                'QUOTING_RULE':
                    'NEVER wrap \${...} placeholders in extra quotes. '
                    'String placeholders (random.uuid, random.name, random.email, etc.) already output their own double-quotes. '
                    'CORRECT: {"id": \${random.uuid}} → {"id": "abc-uuid"}. '
                    'WRONG: {"id": "\${random.uuid}"} → {"id": ""abc-uuid""} INVALID JSON.',
                'PAGINATION_NOTE':
                    'If this endpoint will use pagination, set responseBody to the WRAPPER here first, e.g. {"items": \${pagination.data}, "total": 100}. '
                    'Then add a pagination rule (POST .../rules with isPagination:true) that defines the per-item template.',
                'description':
                    'Response body. Supports \${...} interpolation. '
                    'Numbers: \${random.integer.*}, \${math.*} — no quotes. '
                    'Arrays: \${pagination.data} — no quotes. '
                    'Everything else (strings): already quoted by the engine — do NOT add extra quotes.',
              },
              'delay': {
                'type': 'integer',
                'default': 0,
                'description': 'Artificial delay in ms',
              },
              'responseHeader': {
                'type': 'object',
                'default': {},
                'description': 'Key-value header pairs',
              },
              'enable': {'type': 'boolean', 'default': true},
            },
          },
          {
            'method': 'GET',
            'path': '/api/projects/:id/endpoints/:endpointIndex',
            'summary': 'Get a single HTTP endpoint by its 0-based index.',
          },
          {
            'method': 'PUT',
            'path': '/api/projects/:id/endpoints/:endpointIndex',
            'summary': 'Update an HTTP endpoint (all fields optional).',
          },
          {
            'method': 'DELETE',
            'path': '/api/projects/:id/endpoints/:endpointIndex',
            'summary': 'Delete an HTTP endpoint.',
          },
          // ── Rules
          {
            'method': 'GET',
            'path': '/api/projects/:id/endpoints/:endpointIndex/rules',
            'summary': 'List conditional rules for an endpoint.',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/endpoints/:endpointIndex/rules',
            'summary':
                'Add a conditional rule or pagination rule to an endpoint.',
            'PAGINATION_WORKFLOW_WARNING':
                'FOR PAGINATION: You MUST set the endpoint responseBody wrapper FIRST (via POST/PUT endpoint) before adding the pagination rule. '
                'Step 1 — set endpoint responseBody to the wrapper: {"items": \${pagination.data}} '
                'Step 2 — add pagination rule with the per-item template: {"isPagination": true, "responseBody": "{\\"id\\": \${random.uuid}, \\"name\\": \${random.name}}", "offsetParam": "page", "limitParam": "limit", "max": 100}. '
                'The pagination rule responseBody defines ONE item, not the wrapper.',
            'QUOTING_WARNING':
                'NEVER wrap \${...} placeholders in extra quotes. '
                'ALL string placeholders (random.uuid, random.name, random.email, random.url, random.jwt, random.date, random.lorem, request.url.query.*, request.url.param.*, request.header.*, request.body.*, customdata.*) '
                'already output their own surrounding double-quotes. '
                'CORRECT: {"id": \${random.uuid}} → {"id": "abc-uuid"}. '
                'WRONG:   {"id": "\${random.uuid}"} → {"id": ""abc-uuid""} INVALID JSON. '
                'Only numbers (\${random.integer.*}, \${math.*}) and \${pagination.data} have no auto-quotes.',
            'requestBody': {
              'isPagination': {
                'type': 'boolean',
                'default': false,
                'description':
                    'true = pagination rule, false = response override rule',
              },
              'responseBody': {
                'type': 'string',
                'description':
                    'For response rule: the override body. '
                    'For pagination rule: the PER-ITEM template (one object, not an array). '
                    'Do NOT wrap \${...} string placeholders in extra quotes — they are already JSON-encoded.',
              },
              'statusCode': {
                'type': 'integer',
                'default': 200,
                'description': 'Only for response rules',
              },
              'offsetParam': {
                'type': 'string',
                'default': 'page',
                'description':
                    'Pagination only: query param name for page/offset',
              },
              'limitParam': {
                'type': 'string',
                'default': 'limit',
                'description':
                    'Pagination only: query param name for page size',
              },
              'max': {
                'type': 'integer',
                'default': 100,
                'description': 'Pagination only: total item count',
              },
              'customLimit': {
                'type': 'integer',
                'description':
                    'Pagination only: fixed page size (ignores URL param)',
              },
              'customOffset': {
                'type': 'integer',
                'description': 'Pagination only: fixed offset',
              },
              'label': {
                'type': 'string',
                'description': 'Response rule only: display label',
              },
              'logic': {
                'type': 'string',
                'default': 'AND',
                'description': 'Response rule only: AND | OR',
              },
              'conditions': {
                'type': 'array',
                'description': 'Response rule only',
                'items': {
                  'target':
                      'QueryParam | RequestHeader | BodyField | RouteParam',
                  'key': 'string',
                  'operator':
                      'equals | notEquals | contains | notContains | regexMatch | isEmpty | isNotEmpty',
                  'value': 'string',
                  'logic': 'AND | OR',
                },
              },
            },
          },
          {
            'method': 'PUT',
            'path': '/api/projects/:id/endpoints/:endpointIndex/rules/:ruleId',
            'summary': 'Update a rule.',
          },
          {
            'method': 'DELETE',
            'path': '/api/projects/:id/endpoints/:endpointIndex/rules/:ruleId',
            'summary': 'Delete a rule.',
          },
          // ── WebSocket Endpoints
          {
            'method': 'GET',
            'path': '/api/projects/:id/ws-endpoints',
            'summary': 'List WebSocket endpoints.',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/ws-endpoints',
            'summary': 'Create a WebSocket endpoint.',
            'requestBody': {
              'endpoint': {'type': 'string', 'required': true},
              'onConnectMessage': {'type': 'string', 'optional': true},
              'rules': {
                'type': 'array',
                'items': {
                  'pattern': 'string',
                  'isRegex': 'boolean',
                  'response': 'string',
                },
              },
              'scheduledMessages': {
                'type': 'array',
                'items': {
                  'message': 'string',
                  'delayMs': 'integer',
                  'repeat': 'boolean',
                  'intervalMs': 'integer',
                },
              },
            },
          },
          {
            'method': 'GET',
            'path': '/api/projects/:id/ws-endpoints/:wsIndex',
            'summary': 'Get a single WebSocket endpoint.',
          },
          {
            'method': 'PUT',
            'path': '/api/projects/:id/ws-endpoints/:wsIndex',
            'summary': 'Update a WebSocket endpoint.',
          },
          {
            'method': 'DELETE',
            'path': '/api/projects/:id/ws-endpoints/:wsIndex',
            'summary': 'Delete a WebSocket endpoint.',
          },
          // ── Custom Data
          {
            'method': 'GET',
            'path': '/api/custom-data',
            'summary': 'List all custom data keys and their values.',
          },
          {
            'method': 'GET',
            'path': '/api/custom-data/:key',
            'summary': 'Get values for a specific custom data key.',
          },
          {
            'method': 'POST',
            'path': '/api/custom-data/:key',
            'summary': 'Create or replace a custom data list.',
            'requestBody': {
              'values': {'type': 'array of strings'},
            },
          },
          {
            'method': 'PATCH',
            'path': '/api/custom-data/:key',
            'summary': 'Append values to an existing custom data list.',
            'requestBody': {
              'values': {'type': 'array of strings'},
            },
          },
          {
            'method': 'DELETE',
            'path': '/api/custom-data/:key',
            'summary': 'Delete a custom data list.',
          },
          // ── Mock S3
          {
            'method': 'GET',
            'path': '/api/s3/config',
            'summary': 'Get S3 mock configuration.',
          },
          {
            'method': 'PUT',
            'path': '/api/s3/config',
            'summary':
                'Update S3 config (host, port, accessKeyId, secretAccessKey, region).',
          },
          {
            'method': 'POST',
            'path': '/api/s3/start',
            'summary': 'Start the S3 mock server.',
          },
          {
            'method': 'POST',
            'path': '/api/s3/stop',
            'summary': 'Stop the S3 mock server.',
          },
          {
            'method': 'GET',
            'path': '/api/s3/buckets',
            'summary': 'List all S3 buckets.',
          },
          {
            'method': 'POST',
            'path': '/api/s3/buckets',
            'summary': 'Create a bucket.',
            'requestBody': {
              'name': {'type': 'string', 'required': true},
            },
          },
          {
            'method': 'DELETE',
            'path': '/api/s3/buckets/:bucket',
            'summary': 'Delete a bucket and all its objects.',
          },
          {
            'method': 'GET',
            'path': '/api/s3/objects/:bucket',
            'summary':
                'List objects in a bucket. Optional query param: prefix.',
          },
          {
            'method': 'DELETE',
            'path': '/api/s3/objects/:bucket/:key',
            'summary': 'Delete an object.',
          },
          {
            'method': 'POST',
            'path': '/api/s3/presign',
            'summary':
                'Generate a presigned URL for GET (download) or PUT (upload).',
            'requestBody': {
              'bucket': {'type': 'string', 'required': true},
              'key': {'type': 'string', 'required': true},
              'operation': {
                'type': 'string',
                'required': true,
                'description': 'GET or PUT',
              },
              'expirySeconds': {'type': 'integer', 'default': 3600},
            },
            'response': {
              'url': 'Presigned URL string ready to use directly',
              'operation': 'GET or PUT',
              'bucket': 'string',
              'key': 'string',
              'token': 'string',
              'expiresAt': 'ISO-8601 expiry timestamp',
            },
          },
          // ── OpenAPI / AsyncAPI Schema
          {
            'method': 'GET',
            'path': '/api/projects/:id/export/openapi',
            'summary': 'Export all HTTP endpoints as an OpenAPI 3.0 spec (JSON).',
          },
          {
            'method': 'GET',
            'path': '/api/projects/:id/export/asyncapi',
            'summary': 'Export all WebSocket endpoints as an AsyncAPI 2.6 spec (JSON).',
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/import/openapi',
            'summary': 'Import HTTP endpoints from an OpenAPI 3.0 spec. Appends to existing endpoints.',
            'requestBody': {
              'spec': {
                'type': 'object or string',
                'required': true,
                'description': 'OpenAPI 3.0 spec as a JSON object or JSON string.',
              },
            },
          },
          {
            'method': 'POST',
            'path': '/api/projects/:id/import/asyncapi',
            'summary': 'Import WebSocket endpoints from an AsyncAPI 2.x spec. Appends to existing WS endpoints.',
            'requestBody': {
              'spec': {
                'type': 'object or string',
                'required': true,
                'description': 'AsyncAPI 2.x spec as a JSON object or JSON string.',
              },
            },
          },
          {
            'method': 'GET',
            'path': '/api/projects/:id/schema-to-code-prompt',
            'summary': 'Returns a ready-to-use AI prompt that generates SQL schema + backend source code from the project specs.',
            'queryParams': {
              'lang': 'Target language: typescript, python, go, java, kotlin, swift, php, ruby. Default: auto',
              'db': 'SQL dialect: postgresql, mysql, sqlite, mssql. Default: postgresql',
            },
            'response': {
              'prompt': 'Full prompt string — pass this directly to your AI model to get SQL + backend code.',
              'openApiSpec': 'OpenAPI 3.0 spec object used in the prompt.',
              'asyncApiSpec': 'AsyncAPI 2.6 spec object used in the prompt.',
            },
            'usage': 'Call this endpoint, take the "prompt" field, and send it to your AI model.',
          },
          // ── Full Workspace Export
          {
            'method': 'GET',
            'path': '/api/export',
            'summary': 'Export the complete workspace as a JSON snapshot.',
          },
        ],
      },

      // ── 4. Interpolation reference ────────────────────────────────────
      'interpolationReference': {
        'CRITICAL_QUOTING_RULE':
            'Every \${...} placeholder is replaced with its JSON-encoded value internally. '
            'ALL string-producing placeholders (random.uuid, random.name, random.email, random.url, random.jwt, random.date, random.lorem, random.username, random.phone, random.image.*, random.string.*, request.url.query.*, request.url.param.*, request.header.*, request.body.*, customdata.*, customdata.random.*, :paramName) '
            'already include their surrounding double-quotes in their output. '
            'You MUST NOT wrap them in extra quotes in your template. '
            'CORRECT:   {"id": \${random.uuid}, "name": \${random.name}}  →  {"id": "abc-uuid", "name": "John Doe"} '
            'INCORRECT: {"id": "\${random.uuid}", "name": "\${random.name}"}  →  {"id": ""abc-uuid"", "name": ""John Doe""} (INVALID JSON). '
            'Number-producing placeholders (\${random.integer.*}, \${random.double.*}, \${math.*}, \${:paramName} when value is numeric) output raw numbers — no quotes added, none needed. '
            'Array-producing placeholder (\${pagination.data}) outputs a raw JSON array — no quotes added, none needed.',
        'expressions': [
          {
            'expression': r'${random.uuid}',
            'description': 'UUID v4',
            'outputType':
                'string — already quoted, do NOT wrap in extra quotes',
            'example': r'{"id": ${random.uuid}}',
          },
          {
            'expression': r'${random.integer.100}',
            'description': 'Random integer [0, 100)',
            'outputType': 'number — no quotes needed',
            'example': r'{"count": ${random.integer.100}}',
          },
          {
            'expression': r'${random.double.10}',
            'description': 'Random double [0.0, 10.0)',
            'outputType': 'number — no quotes needed',
            'example': r'{"score": ${random.double.10}}',
          },
          {
            'expression': r'${random.name}',
            'description': 'Random full name',
            'outputType':
                'string — already quoted, do NOT wrap in extra quotes',
            'example': r'{"name": ${random.name}}',
          },
          {
            'expression': r'${random.username}',
            'description': 'Random username',
            'outputType': 'string — already quoted',
            'example': r'{"username": ${random.username}}',
          },
          {
            'expression': r'${random.email}',
            'description': 'Random email address',
            'outputType':
                'string — already quoted, do NOT wrap in extra quotes',
            'example': r'{"email": ${random.email}}',
          },
          {
            'expression': r'${random.url}',
            'description': 'Random HTTP URL',
            'outputType': 'string — already quoted',
            'example': r'{"url": ${random.url}}',
          },
          {
            'expression': r'${random.phone}',
            'description': 'Random phone number',
            'outputType': 'string — already quoted',
            'example': r'{"phone": ${random.phone}}',
          },
          {
            'expression': r'${random.lorem}',
            'description': 'Random lorem ipsum sentence',
            'outputType': 'string — already quoted',
            'example': r'{"bio": ${random.lorem}}',
          },
          {
            'expression': r'${random.date}',
            'description': 'Current UTC timestamp (ISO-8601)',
            'outputType': 'string — already quoted',
            'example': r'{"createdAt": ${random.date}}',
          },
          {
            'expression': r'${random.image.400x400}',
            'description': 'Placeholder image URL (WxH)',
            'outputType': 'string — already quoted',
            'example': r'{"avatar": ${random.image.400x400}}',
          },
          {
            'expression': r'${random.string.20}',
            'description': 'Random 20-char alphanumeric string',
            'outputType': 'string — already quoted',
            'example': r'{"token": ${random.string.20}}',
          },
          {
            'expression': r'${random.jwt}',
            'description': 'Random JWT token',
            'outputType': 'string — already quoted',
            'example': r'{"token": ${random.jwt}}',
          },
          {
            'expression': r'${:paramName}',
            'description':
                'URL path parameter — use \${:name} in the endpoint path to capture a dynamic segment, '
                'then reference it in the response body with the same \${:name}. '
                'Example endpoint: /users/\${:id}/orders/\${:orderId}',
            'outputType':
                'string (already quoted) or number (no quotes) — auto-detected',
            'example': r'Endpoint: /products/${:category}/${:id}  →  Body: {"category": ${:category}, "id": ${:id}}',
          },
          {
            'expression': r'${request.url.query.<key>}',
            'description': 'Query parameter value from the request',
            'outputType':
                'string or number — already quoted (number if parseable)',
            'example': r'{"page": ${request.url.query.page}}',
          },
          {
            'expression': r'${request.url.param.<key>}',
            'description': 'Route parameter value (e.g. :id)',
            'outputType': 'string — already quoted',
            'example': r'{"id": ${request.url.param.id}}',
          },
          {
            'expression': r'${request.header.<name>}',
            'description': 'Request header value',
            'outputType': 'string — already quoted',
            'example': r'{"auth": ${request.header.authorization}}',
          },
          {
            'expression': r'${request.body.<field>}',
            'description': 'JSON body field (supports dot notation)',
            'outputType': 'string — already quoted',
            'example': r'{"echo": ${request.body.name}}',
          },
          {
            'expression': r'${customdata.<key>}',
            'description': 'First value in a custom data list',
            'outputType': 'string — already quoted',
            'example': r'{"city": ${customdata.cities}}',
          },
          {
            'expression': r'${customdata.random.<key>}',
            'description': 'Random value from a custom data list',
            'outputType': 'string — already quoted',
            'example': r'{"city": ${customdata.random.cities}}',
          },
          {
            'expression': r'${math.<expression>}',
            'description': 'Math evaluation (e.g. \${math.2+3} → 5)',
            'outputType': 'number — no quotes needed',
            'example': r'{"total": ${math.10*5}}',
          },
          {
            'expression': r'${pagination.data}',
            'description':
                'Inject the generated paginated items array (only in pagination rule responseBody wrapper)',
            'outputType': 'array — no quotes needed',
            'example': r'{"items": ${pagination.data}, "total": 100}',
          },
        ],
      },

      // ── 5. Workflow examples ──────────────────────────────────────────
      'workflowExamples': [
        {
          'title': 'Create a complete REST API mock from scratch',
          'steps': [
            'POST /api/projects  →  {"name": "User Service", "port": 8080}',
            r'POST /api/projects/:id/endpoints  →  {"endpoint": "/users", "method": "GET", "statusCode": 200, "responseBody": "[{\"id\": ${random.uuid}, \"name\": ${random.name}, \"email\": ${random.email}}]"}',
            r'POST /api/projects/:id/endpoints  →  {"endpoint": "/users/${:userId}", "method": "GET", "statusCode": 200, "responseBody": "{\"id\": ${:userId}, \"name\": ${random.name}}"}',
            r'POST /api/projects/:id/endpoints  →  {"endpoint": "/users", "method": "POST", "statusCode": 201, "responseBody": "{\"id\": ${random.uuid}, \"name\": ${request.body.name}}"}',
            'POST /api/projects/:id/start',
          ],
        },
        {
          'title': 'Add conditional rules (e.g. auth check)',
          'steps': [
            'POST /api/projects/:id/endpoints/:endpointIndex/rules  →  {"statusCode": 401, "responseBody": "{\\"error\\": \\"unauthorized\\"}", "conditions": [{"target": "RequestHeader", "key": "Authorization", "operator": "isEmpty", "value": "", "logic": "AND"}]}',
          ],
        },
        {
          'title': 'Set up a WebSocket chat mock',
          'steps': [
            r'POST /api/projects/:id/ws-endpoints  →  {"endpoint": "/chat", "onConnectMessage": "{\"type\": \"welcome\", \"sessionId\": ${random.uuid}}", "rules": [{"pattern": "ping", "isRegex": false, "response": "pong"}], "scheduledMessages": [{"message": "{\"type\": \"heartbeat\"}", "delayMs": 5000, "repeat": true, "intervalMs": 10000}]}',
          ],
        },
        {
          'title': 'Add pagination to an endpoint',
          'steps': [
            'POST /api/projects/:id/endpoints  →  Create the endpoint with the wrapper format: {"endpoint": "/items", "method": "GET", "responseBody": "{\\"body\\": \${pagination.data}}" }',
            r'POST /api/projects/:id/endpoints/:endpointIndex/rules  →  Create the pagination rule with the item template: {"isPagination": true, "responseBody": "{\"id\": ${random.uuid}, \"title\": \"Artikel ${math.1+1}\"}", "offsetParam": "page", "limitParam": "limit", "max": 100}',
            'The endpoint will now respond to GET requests like ?page=1&limit=3 with paginated data.',
          ],
        },
        {
          'title': 'Use custom data for realistic responses',
          'steps': [
            'POST /api/custom-data/cities  →  {"values": ["New York", "London", "Tokyo", "Paris"]}',
            'Then use \${customdata.random.cities} in any responseBody to get a random city.',
          ],
        },
        {
          'title': 'Set up S3-compatible storage',
          'steps': [
            'PUT /api/s3/config  →  {"host": "localhost", "port": 9000, "accessKeyId": "mockondo", "secretAccessKey": "mockondo", "region": "us-east-1"}',
            'POST /api/s3/start',
            'POST /api/s3/buckets  →  {"name": "my-uploads"}',
            'Now use any S3-compatible SDK with endpoint http://localhost:9000',
          ],
        },
      ],

      // ── 6. Best practices for AI agents ───────────────────────────────
      'bestPractices': [
        'Always start by calling GET /api/status to understand the current state before making changes.',
        'After modifying endpoints, restart the project server (stop then start) to apply changes.',
        'Use meaningful project names and endpoint paths for clarity.',
        'Leverage interpolation expressions (e.g. \${random.uuid}, \${request.body.name}) to make mock responses dynamic and realistic.',
        'Use rules to simulate authentication, error states, and conditional responses.',
        'When creating APIs, add all CRUD endpoints (GET list, GET single, POST create, PUT update, DELETE) for completeness.',
        'Set appropriate HTTP status codes (200 OK, 201 Created, 204 No Content, 400 Bad Request, 401 Unauthorized, 404 Not Found).',
        'Use custom data lists for domain-specific values (e.g. product categories, cities, roles).',
        'Add response delays to simulate real-world latency when needed.',
        'Use responseHeader to set proper Content-Type and custom headers.',
      ],

      // ── 7. Error handling guide ───────────────────────────────────────
      'errorHandling': {
        'description':
            'All error responses follow the format: {"success": false, "message": "..."}',
        'commonErrors': [
          {
            'status': 400,
            'message': 'Invalid request body',
            'cause': 'Malformed JSON',
          },
          {
            'status': 400,
            'message': "Field '<name>' is required",
            'cause': 'Missing required field',
          },
          {
            'status': 401,
            'message': 'Unauthorized',
            'cause': 'Missing or wrong API key',
          },
          {
            'status': 404,
            'message': 'Project not found',
            'cause': 'Invalid project ID',
          },
          {
            'status': 404,
            'message': 'Endpoint not found',
            'cause': 'Invalid endpoint index',
          },
          {
            'status': 404,
            'message': 'Rule not found',
            'cause': 'Invalid rule ID',
          },
          {
            'status': 500,
            'message': 'Failed to start server: <reason>',
            'cause': 'Port in use or bind error',
          },
        ],
      },
    };
  }
}
