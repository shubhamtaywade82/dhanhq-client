# DhanHQ Client Gem - Code Review Issues

**API Documentation Reference**: https://dhanhq.co/docs/v2/

**Review Date**: 2025-01-27

---

## 🔴 Critical Issues

### 1. **Missing Input Validation in Client Initialization**
**Location**: `lib/DhanHQ/client.rb:40`
**Issue**: The client initializes configuration conditionally, which can lead to runtime errors:
```ruby
DhanHQ.configure_with_env if ENV.fetch("CLIENT_ID", nil)
```
**Problem**: If `CLIENT_ID` exists but `ACCESS_TOKEN` doesn't, configuration will be partially initialized, leading to authentication failures later.
**Recommendation**: Validate both required credentials before proceeding or fail fast with a clear error message.

### 2. **Race Condition in Rate Limiter**
**Location**: `lib/DhanHQ/rate_limiter.rb:51-99`
**Issue**: The `throttle!` method uses a mutex, but the cleanup threads (lines 144-161) modify shared state (`@buckets`) without synchronization.
**Problem**: Cleanup threads can reset counters while `throttle!` is checking/updating them, leading to incorrect rate limiting.
**Recommendation**: Use thread-safe operations for all bucket modifications or synchronize cleanup operations.

### 3. **Incomplete Error Handling in WebSocket Connection**
**Location**: `lib/DhanHQ/ws/connection.rb:142-145`
**Issue**: Exceptions are caught but the connection may continue in an invalid state:
```ruby
rescue StandardError => e
  DhanHQ.logger&.error("[DhanHQ::WS] crashed #{e.class} #{e.message}")
  failed = true
```
**Problem**: The error is logged but the connection state may be inconsistent. No cleanup or state reset is performed.
**Recommendation**: Ensure proper cleanup and state reset on exceptions, and consider exposing error events to callers.

### 4. **Missing Validation for Price Fields**
**Location**: `lib/DhanHQ/contracts/place_order_contract.rb:85-86`
**Issue**: Price validation allows `gt?: 0` but doesn't validate against reasonable upper bounds or check for NaN/Infinity.
**Problem**: Invalid float values (NaN, Infinity) or extremely large values could be sent to the API.
**Recommendation**: Add validation for finite numbers and reasonable bounds.

---

## 🟠 High Priority Issues

### 5. **Inconsistent Error Object Handling**
**Location**: `lib/DhanHQ/core/base_model.rb:162`
**Issue**: The `update` method returns `ErrorObject` but other methods return `nil` or `false` on failure:
```ruby
return DhanHQ::ErrorObject.new(response) unless success_response?(response)
```
**Problem**: Inconsistent return types make error handling difficult for consumers.
**Recommendation**: Standardize error handling across all model methods (return `ErrorObject` consistently or raise exceptions).

### 6. **Memory Leak in Order Tracker**
**Location**: `lib/DhanHQ/ws/orders/client.rb:18`
**Issue**: `@order_tracker` is a `Concurrent::Map` that grows indefinitely:
```ruby
@order_tracker = Concurrent::Map.new
```
**Problem**: Orders are never removed from the tracker, leading to unbounded memory growth over time.
**Recommendation**: Implement a cleanup mechanism (e.g., remove orders older than N days or limit the map size).

### 7. **Missing Validation for Correlation ID Uniqueness**
**Location**: `lib/DhanHQ/models/order.rb:288-298`
**Issue**: The `place` method doesn't validate that `correlation_id` is unique before placing an order.
**Problem**: Duplicate correlation IDs could lead to confusion or idempotency issues.
**Recommendation**: Add validation or check for existing orders with the same correlation_id (if supported by API).

### 8. **Thread Safety Issue in WebSocket Client**
**Location**: `lib/DhanHQ/ws/client.rb:166-172`
**Issue**: The `emit` method duplicates callbacks but doesn't protect against modification during iteration:
```ruby
def emit(event, payload)
  begin
    @callbacks[event].dup
  rescue StandardError
    []
  end.each { |cb| cb.call(payload) }
end
```
**Problem**: While `.dup` is called, if callbacks are modified concurrently, the iteration could still be affected.
**Recommendation**: Use a more robust synchronization mechanism or immutable callback lists.

### 9. **Incomplete Response Parsing**
**Location**: `lib/DhanHQ/helpers/response_helper.rb:77-96`
**Issue**: `parse_json` silently returns empty hash on JSON parse errors:
```ruby
rescue JSON::ParserError
  {} # Return an empty hash if the string is not valid JSON
```
**Problem**: Silent failures make debugging difficult. An empty hash might be treated as success.
**Recommendation**: Log the error and consider raising an exception or returning an ErrorObject.

### 10. **Missing Timeout Configuration**
**Location**: `lib/DhanHQ/client.rb:46-51`
**Issue**: Faraday connection doesn't set timeouts:
```ruby
@connection = Faraday.new(url: DhanHQ.configuration.base_url) do |conn|
  conn.request :json, parser_options: { symbolize_names: true }
  conn.response :json, content_type: /\bjson$/
  conn.response :logger if ENV["DHAN_DEBUG"] == "true"
  conn.adapter Faraday.default_adapter
end
```
**Problem**: Requests can hang indefinitely if the server doesn't respond.
**Recommendation**: Add timeout configuration (connect, read, write timeouts).

---

## 🟡 Medium Priority Issues

### 11. **Inconsistent Key Normalization**
**Location**: Multiple files
**Issue**: Some methods use `snake_case`, others use `camelize_keys`, and some use `titleize_keys`:
- `lib/DhanHQ/core/base_api.rb:93` - Uses `titleize_keys` for optionchain
- `lib/DhanHQ/models/order.rb:235` - Uses `camelize_keys` for most APIs
**Problem**: Inconsistent key transformation can lead to API errors.
**Recommendation**: Document and standardize key transformation rules per API endpoint.

### 12. **Missing Retry Logic for Transient Errors**
**Location**: `lib/DhanHQ/client.rb:61-71`
**Issue**: No automatic retry for transient network errors (5xx, timeouts).
**Problem**: Temporary failures require manual retry logic in application code.
**Recommendation**: Add configurable retry logic with exponential backoff for transient errors.

### 13. **WebSocket Reconnection Backoff Not Reset Properly**
**Location**: `lib/DhanHQ/ws/connection.rb:154-162`
**Issue**: Backoff is reset only after a "clean session end", but the definition of "clean" is unclear:
```ruby
else
  backoff = 2.0 # reset only after a clean session end
end
```
**Problem**: Backoff may not reset correctly, leading to excessive delays.
**Recommendation**: Clarify reset conditions and add logging for backoff behavior.

### 14. **Missing Validation for Order Modification**
**Location**: `lib/DhanHQ/models/order.rb:366-390`
**Issue**: The `modify` method doesn't validate that the order is in a modifiable state (e.g., not already TRADED or CANCELLED).
**Problem**: API calls will fail, but validation could happen earlier.
**Recommendation**: Add state validation before attempting modification.

### 15. **Incomplete Error Mapping**
**Location**: `lib/DhanHQ/helpers/response_helper.rb:50`
**Issue**: Error mapping relies on `DHAN_ERROR_MAPPING` but doesn't handle all possible error codes:
```ruby
error_class = DhanHQ::Constants::DHAN_ERROR_MAPPING[error_code]
```
**Problem**: Unknown error codes fall back to generic error handling, losing specificity.
**Recommendation**: Ensure all documented error codes are mapped, or log unmapped codes for investigation.

### 16. **Missing Input Sanitization**
**Location**: `lib/DhanHQ/helpers/request_helper.rb:58-71`
**Issue**: Payload is converted to JSON without sanitization:
```ruby
else req.body = payload.to_json
```
**Problem**: Malicious or malformed data could be sent to the API.
**Recommendation**: Add input sanitization and validation before JSON serialization.

### 17. **WebSocket Subscription State Not Persisted**
**Location**: `lib/DhanHQ/ws/sub_state.rb` (referenced but not reviewed)
**Issue**: Subscription state is in-memory only. On reconnection, subscriptions are restored from `@state.snapshot`, but if the process crashes, subscriptions are lost.
**Problem**: Requires manual re-subscription after crashes.
**Recommendation**: Consider persisting subscription state (optional, configurable).

### 18. **Rate Limiter Cleanup Threads Never Stop**
**Location**: `lib/DhanHQ/rate_limiter.rb:144-161`
**Issue**: Cleanup threads run in infinite loops with no way to stop them:
```ruby
Thread.new do
  loop do
    sleep(60)
    @buckets[:per_minute]&.value = 0
  end
end
```
**Problem**: Threads continue running even after the rate limiter is no longer needed, wasting resources.
**Recommendation**: Add a shutdown mechanism or use a proper thread pool.

### 19. **Missing Logging for Sensitive Operations**
**Location**: `lib/DhanHQ/models/order.rb:493`
**Issue**: Order placement failures are not logged:
```ruby
else
  # maybe store errors?
  false
end
```
**Problem**: Debugging order placement issues is difficult without logs.
**Recommendation**: Add structured logging for order operations (sanitize sensitive data).

### 20. **Inconsistent API Type Handling**
**Location**: `lib/DhanHQ/core/base_api.rb:21`
**Issue**: API type defaults to `:non_trading_api` but some resources override it:
```ruby
def initialize(api_type: self.class::API_TYPE)
```
**Problem**: Inconsistent defaults can lead to incorrect rate limiting.
**Recommendation**: Ensure all resources explicitly set their API type or document the default.

---

## 🔵 Low Priority / Code Quality Issues

### 21. **Duplicate Code in Error Handling**
**Location**: `lib/DhanHQ/core/base_model.rb:198-213`
**Issue**: `delete` and `destroy` methods have duplicate logic:
```ruby
def delete
  response = self.class.resource.delete("/#{id}")
  success_response?(response)
rescue StandardError
  false
end

def destroy
  response = self.class.resource.delete("/#{id}")
  success_response?(response)
rescue StandardError
  false
end
```
**Recommendation**: Extract common logic or make one delegate to the other.

### 22. **Magic Numbers in Rate Limiter**
**Location**: `lib/DhanHQ/rate_limiter.rb:9-16`
**Issue**: Rate limits are hardcoded:
```ruby
order_api: { per_second: 25, per_minute: 250, per_hour: 1000, per_day: 7000 },
```
**Recommendation**: Make rate limits configurable via environment variables or configuration.

### 23. **Missing Documentation for WebSocket Modes**
**Location**: `lib/DhanHQ/ws/client.rb:21-24`
**Issue**: Modes (`:ticker`, `:quote`, `:full`) are not well documented in the code:
```ruby
@mode  = mode # :ticker, :quote, :full (adjust to your API)
```
**Recommendation**: Add comprehensive documentation explaining the differences and when to use each mode.

### 24. **Inconsistent Method Naming**
**Location**: Various files
**Issue**: Some methods use `snake_case` (Ruby convention) while others use descriptive names inconsistently.
**Recommendation**: Establish and document naming conventions.

### 25. **Missing Type Checking**
**Location**: `lib/DhanHQ/core/base_model.rb:241-243`
**Issue**: The `id` method tries multiple keys without type validation:
```ruby
def id
  @attributes[:id] || @attributes[:order_id] || @attributes[:security_id]
end
```
**Problem**: Could return unexpected types if attributes contain non-string values.
**Recommendation**: Add type validation or conversion.

### 26. **Unused Code**
**Location**: `lib/DhanHQ/contracts/modify_order_contract_copy.rb`
**Issue**: File appears to be a copy/backup that shouldn't be in the codebase.
**Recommendation**: Remove if unused, or rename/consolidate if needed.

### 27. **Missing Validation for Array Responses**
**Location**: `lib/DhanHQ/core/base_model.rb:144-150`
**Issue**: `parse_collection_response` assumes arrays or `[:data]` structure:
```ruby
return [] unless response.is_a?(Array) || (response.is_a?(Hash) && response[:data].is_a?(Array))
```
**Problem**: Other response formats are silently ignored.
**Recommendation**: Add logging for unexpected response formats.

### 28. **WebSocket URL Construction**
**Location**: `lib/DhanHQ/ws/client.rb:33`
**Issue**: URL is constructed with string interpolation:
```ruby
@url  = url || "wss://api-feed.dhan.co?version=#{ver}&token=#{token}&clientId=#{cid}&authType=2"
```
**Problem**: Token and client ID are embedded in URL (visible in logs, connection strings).
**Recommendation**: Use proper URL encoding and consider sanitizing in logs.

### 29. **Missing Validation for Order Status Transitions**
**Location**: `lib/DhanHQ/models/order.rb`
**Issue**: No validation that order status transitions are valid (e.g., can't go from CANCELLED to PENDING).
**Recommendation**: Add state machine validation if order lifecycle is important.

### 30. **Incomplete Test Coverage**
**Location**: `spec/` directory
**Issue**: Based on file structure, some critical paths may lack test coverage (e.g., error handling, WebSocket reconnection).
**Recommendation**: Review and improve test coverage, especially for error paths and edge cases.

---

## 📋 Summary

### Critical Issues: 4
### High Priority Issues: 6
### Medium Priority Issues: 10
### Low Priority Issues: 10

### Key Areas Requiring Attention:
1. **Thread Safety**: Rate limiter and WebSocket clients need better synchronization
2. **Error Handling**: Inconsistent error handling patterns across the codebase
3. **Memory Management**: Order tracker and cleanup threads need lifecycle management
4. **Input Validation**: Missing validation for edge cases (NaN, Infinity, bounds)
5. **Configuration**: Missing timeout configuration and better credential validation
6. **Documentation**: Some areas lack clear documentation

### Recommended Next Steps:
1. Fix critical issues first (especially thread safety and error handling)
2. Add comprehensive integration tests
3. Implement proper logging and monitoring
4. Add configuration validation on startup
5. Document API compliance with official DhanHQ API documentation

---

**Note**: This review is based on static code analysis. Dynamic testing and API compliance verification against https://dhanhq.co/docs/v2/ should be performed to validate these findings.
