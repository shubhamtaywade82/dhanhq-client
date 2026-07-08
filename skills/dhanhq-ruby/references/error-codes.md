# Error Codes — Complete Reference (Ruby SDK)

In the Ruby SDK, raw API error codes are automatically mapped in the client layer and raised as structured exceptions.

## Exception Mapping

The Ruby client maps Dhan error codes to specific error classes under the `DhanHQ` module:

| Error Code | Error Class | Meaning |
|------------|-------------|---------|
| `DH-901` | `DhanHQ::InvalidAuthenticationError` | Client ID or access token is invalid or expired |
| `DH-902` | `DhanHQ::InvalidAccessError` | User does not have required Data API or Trading API access |
| `DH-903` | `DhanHQ::UserAccountError` | Account setup issue or segment activation requirement |
| `DH-904` | `DhanHQ::RateLimitError` | Rate limit exceeded |
| `DH-905` | `DhanHQ::InputExceptionError` | Missing or invalid request fields |
| `DH-906` | `DhanHQ::OrderError` | Order request cannot be processed |
| `DH-907` | `DhanHQ::DataError` | Data unavailable or parameters invalid |
| `DH-908` | `DhanHQ::InternalServerError` | Server-side failure |
| `DH-909` | `DhanHQ::NetworkError` | Backend communication failure |
| `DH-1111` | `DhanHQ::NoHoldingsError` | No holdings present in the account |
| `DH-910` / other | `DhanHQ::OtherError` / `DhanHQ::Error` | Other failure reasons |

## Data API Errors

| Code | Exception | Meaning |
|------|-----------|---------|
| `800` | `DhanHQ::InternalServerError` | Internal Server Error |
| `804` | `DhanHQ::Error` | Requested number of instruments exceeds limit |
| `805` | `DhanHQ::RateLimitError` | Too many requests or connections |
| `806` | `DhanHQ::DataError` | Data APIs not subscribed |
| `807` | `DhanHQ::TokenExpiredError` | Access token is expired |
| `808` | `DhanHQ::AuthenticationFailedError` | Authentication failed - client ID or access token invalid |
| `809` | `DhanHQ::InvalidTokenError` | Access token is invalid |
| `810` | `DhanHQ::InvalidClientIDError` | Client ID is invalid |
| `811` | `DhanHQ::InvalidRequestError` | Invalid expiry date |
| `812` | `DhanHQ::InvalidRequestError` | Invalid date format |
| `813` | `DhanHQ::InvalidRequestError` | Invalid security ID |
| `814` | `DhanHQ::InvalidRequestError` | Invalid request |

## User Action Checklist

### Invalid Data Subscription (`806` or `DH-902`)
If you receive access errors:
1. Log in to `web.dhan.co`.
2. Go to **My Profile** -> **Access DhanHQ APIs**.
3. Verify that the **Data API** plan is active.
4. If not active, activate it, generate a fresh access token, and retry.

### Static IP Error (`DH-911` or IP issue)
If placing or managing orders fails with IP errors, ensure that the server's public IP is whitelisted in your Dhan console.
