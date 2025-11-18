# Utility Library API Reference

**Location:** `lib/`
**Purpose:** Shared utilities for error handling, logging, validation, and path operations

---

## Error Handling (`lib/errors.js`)

Custom error classes with proper error handling and context.

### Base Error Class

#### `PulseWidgetsError`

Base error class for all pulse widgets errors.

**Properties:**
- `message` (string) - Error message
- `code` (string|null) - Error code
- `metadata` (object) - Additional metadata
- `timestamp` (string) - ISO timestamp

**Example:**
```javascript
const { PulseWidgetsError } = require('./lib/errors');

throw new PulseWidgetsError('Something went wrong', 'ERROR_CODE', { context: 'value' });
```

### Error Classes

#### `ThemeGenerationError`

Theme generation specific errors.

**Properties:**
- `themeName` (string|null) - Name of theme that failed
- `errors` (array) - Array of nested errors

**Example:**
```javascript
const { ThemeGenerationError } = require('./lib/errors');

throw new ThemeGenerationError(
  'Failed to generate theme',
  'brand-faithful',
  [error1, error2]
);
```

#### `ValidationError`

Validation specific errors.

**Properties:**
- `field` (string|null) - Field that failed validation
- `value` (any|null) - Value that failed validation

**Example:**
```javascript
const { ValidationError } = require('./lib/errors');

throw new ValidationError('Invalid URL format', 'url', 'not-a-url');
```

#### `ConfigError`

Configuration specific errors.

**Properties:**
- `configKey` (string|null) - Configuration key that caused error

**Example:**
```javascript
const { ConfigError } = require('./lib/errors');

throw new ConfigError('Invalid port configuration', 'SERVER_PORT');
```

#### `FileOperationError`

File operation specific errors.

**Properties:**
- `filePath` (string|null) - File path that caused error
- `operation` (string|null) - Operation that failed (read, write, delete, etc.)

**Example:**
```javascript
const { FileOperationError } = require('./lib/errors');

throw new FileOperationError('File not found', '/path/to/file', 'read');
```

#### `NetworkError`

Network/HTTP specific errors.

**Properties:**
- `url` (string|null) - URL that caused error
- `statusCode` (number|null) - HTTP status code

**Example:**
```javascript
const { NetworkError } = require('./lib/errors');

throw new NetworkError('Request failed', 'https://example.com', 404);
```

#### `ProcessError`

Process management specific errors.

**Properties:**
- `processName` (string|null) - Process name that caused error
- `pid` (number|null) - Process ID

**Example:**
```javascript
const { ProcessError } = require('./lib/errors');

throw new ProcessError('Process not found', 'node', 12345);
```

#### `PresentationError`

Presentation specific errors (base class).

**Subclasses:**
- `DuplicatePresentationError` - Duplicate presentation attempt
- `PresentationTimeoutError` - Presentation timed out
- `PresentationCancelledError` - Presentation was cancelled

**Example:**
```javascript
const { DuplicatePresentationError } = require('./lib/errors');

throw new DuplicatePresentationError('Survey already presented', 'survey-123');
```

### Error Factory

#### `ErrorFactory`

Factory for creating typed errors.

**Methods:**
- `createThemeGenerationError(message, themeName, errors)`
- `createValidationError(message, field, value)`
- `createConfigError(message, configKey)`
- `createFileOperationError(message, filePath, operation)`
- `createNetworkError(message, url, statusCode)`
- `createProcessError(message, processName, pid)`

**Example:**
```javascript
const { ErrorFactory } = require('./lib/errors');

const error = ErrorFactory.createValidationError('Invalid URL', 'url', 'not-a-url');
```

### Error Handler

#### `ErrorHandler`

Utility for formatting and handling errors.

**Methods:**
- `format(error)` - Format error for display
- `handle(error, context)` - Handle error with context

**Example:**
```javascript
const { ErrorHandler } = require('./lib/errors');

try {
  // ... code that might throw
} catch (error) {
  ErrorHandler.handle(error, { context: 'theme-generation' });
}
```

---

## Logging (`lib/logger.js`)

Standardized logging with levels and formatting.

### Logger Instance

#### `log`

Default logger instance with methods: `debug()`, `info()`, `warn()`, `error()`

**Example:**
```javascript
const { log } = require('./lib/logger');

log.info('Theme generation started', { url: 'https://example.com' });
log.error('Theme generation failed', error, { clientName: 'test-client' });
```

### Methods

#### `log.debug(message, error, context)`

Log debug message.

**Parameters:**
- `message` (string) - Log message
- `error` (Error, optional) - Error object
- `context` (object, optional) - Context object

#### `log.info(message, error, context)`

Log info message.

**Parameters:**
- `message` (string) - Log message
- `error` (Error, optional) - Error object
- `context` (object, optional) - Context object

#### `log.warn(message, error, context)`

Log warning message.

**Parameters:**
- `message` (string) - Log message
- `error` (Error, optional) - Error object
- `context` (object, optional) - Context object

#### `log.error(message, error, context)`

Log error message.

**Parameters:**
- `message` (string) - Log message
- `error` (Error, optional) - Error object
- `context` (object, optional) - Context object

### Log Levels

- `debug` - Debug information
- `info` - Informational messages
- `warn` - Warning messages
- `error` - Error messages

### Best Practices

1. **Always include context** - Provide context objects for better debugging
2. **Use appropriate levels** - Don't log everything as error
3. **Include error objects** - Pass error objects for stack traces
4. **Structured logging** - Use context objects for structured data

---

## Validation (`lib/validators.js`)

Input validation for files, URLs, ports, and themes.

### Validators

#### `URLValidator`

URL validation utility.

**Methods:**

##### `validate(url)`

Validate a URL.

**Parameters:**
- `url` (string) - URL to validate

**Returns:** Object with validation result:
```javascript
{
  valid: boolean,
  error?: string
}
```

**Example:**
```javascript
const { URLValidator } = require('./lib/validators');

const result = URLValidator.validate('https://example.com');
if (!result.valid) {
  console.error(result.error);
}
```

#### `FileValidator`

File path validation utility.

**Methods:**

##### `validate(filePath)`

Validate a file path.

**Parameters:**
- `filePath` (string) - File path to validate

**Returns:** Object with validation result:
```javascript
{
  valid: boolean,
  error?: string
}
```

**Example:**
```javascript
const { FileValidator } = require('./lib/validators');

const result = FileValidator.validate('/path/to/file');
if (!result.valid) {
  console.error(result.error);
}
```

#### `ParameterValidator`

CLI parameter validation utility.

**Methods:**

##### `validate(params)`

Validate CLI parameters.

**Parameters:**
- `params` (object) - Parameters to validate

**Returns:** Object with validation result:
```javascript
{
  valid: boolean,
  errors?: string[]
}
```

**Example:**
```javascript
const { ParameterValidator } = require('./lib/validators');

const result = ParameterValidator.validate({ url: 'https://example.com', clientName: 'test' });
if (!result.valid) {
  console.error(result.errors);
}
```

#### `ThemeValidator`

Theme object validation utility.

**Methods:**

##### `validate(theme)`

Validate a theme object.

**Parameters:**
- `theme` (object) - Theme object to validate

**Returns:** Object with validation result:
```javascript
{
  valid: boolean,
  errors?: string[]
}
```

**Example:**
```javascript
const { ThemeValidator } = require('./lib/validators');

const result = ThemeValidator.validate(themeObject);
if (!result.valid) {
  console.error(result.errors);
}
```

### Best Practices

1. **Always validate inputs** - Validate all user inputs before processing
2. **Return structured results** - Use `{ valid, error }` format
3. **Throw ValidationError** - Throw `ValidationError` when validation fails
4. **Validate early** - Validate inputs as early as possible

---

## Path Utilities (`lib/paths.js`)

Path utilities for consistent file operations.

### Functions

#### `resolveFromRoot(relativePath)`

Resolve a path relative to the project root.

**Parameters:**
- `relativePath` (string) - Path relative to project root

**Returns:** string - Absolute path

**Example:**
```javascript
const { resolveFromRoot } = require('./lib/paths');

const path = resolveFromRoot('theme-generator/output');
console.log(path); // /full/path/to/pulse_widgets/theme-generator/output
```

#### `exists(filePath)`

Check if a file or directory exists.

**Parameters:**
- `filePath` (string) - File path to check

**Returns:** boolean - True if exists, false otherwise

**Example:**
```javascript
const { exists } = require('./lib/paths');

if (exists('/path/to/file')) {
  console.log('File exists');
}
```

#### `normalizePath(path)`

Normalize a path (resolve `.` and `..`).

**Parameters:**
- `path` (string) - Path to normalize

**Returns:** string - Normalized path

**Example:**
```javascript
const { normalizePath } = require('./lib/paths');

const normalized = normalizePath('./../theme-generator/output');
console.log(normalized); // theme-generator/output
```

### Best Practices

1. **Use resolveFromRoot** - Always resolve paths from project root
2. **Check existence** - Check file existence before operations
3. **Normalize paths** - Normalize paths before comparison
4. **Handle errors** - Wrap path operations in try/catch

---

## Related Documentation

- [Configuration API](config.md) - Configuration utilities
- [Error Handling Guide](../guides/error-handling.md) - Error handling best practices
- [Validation Guide](../guides/validation.md) - Validation best practices
