# TODO List

- [x] Wire `DhanHQ::Models::Order.place` to the resource’s `create` endpoint so order placement stops raising `NoMethodError` (`lib/DhanHQ/models/order.rb:73`, `lib/DhanHQ/resources/orders.rb:14`).
- [x] Align `Order#cancel` with `DhanHQ::Resources::Orders#cancel` to restore cancellation support (`lib/DhanHQ/models/order.rb:120`, `lib/DhanHQ/resources/orders.rb:26`).
- [x] Rework `Order#modify` to send a proper payload and capture the response instead of delegating to the broken generic update flow (`lib/DhanHQ/models/order.rb:99`, `lib/DhanHQ/core/base_model.rb:155`).
- [x] Repair or replace the shared CRUD helpers in `BaseModel` so URL construction and response handling behave (`lib/DhanHQ/core/base_model.rb:120`, `lib/DhanHQ/core/base_model.rb:129`, `lib/DhanHQ/core/base_model.rb:155`).
- [x] Make `BaseModel#save!` raise a real exception type (e.g. `DhanHQ::Error`) to avoid the current `TypeError` (`lib/DhanHQ/core/base_model.rb:165`).
- [x] Strip read-only attributes before posting modify requests to pass API validation (`lib/DhanHQ/models/order.rb:166`, `lib/DhanHQ/core/base_model.rb:197`).
- [x] Require `fileutils` in the WebSocket singleton lock so acquiring the lock no longer raises (`lib/DhanHQ/ws/singleton_lock.rb:11`).
- [x] Implement EDIS and kill-switch endpoints surfaced in the OpenAPI spec so the client can call `/edis/bulkform`, `/edis/form`, `/edis/inquire/{isin}`, `/edis/tpin`, and `/killswitch` (`/home/nemesis/dhanhq-bundled.json:827`, `/home/nemesis/dhanhq-bundled.json:873`, `/home/nemesis/dhanhq-bundled.json:949`).
- [x] Correct `ForeverOrders#all` to hit `/v2/forever/orders` instead of the undocumented `/v2/forever/all` path (`lib/DhanHQ/resources/forever_orders.rb:9`, `/home/nemesis/dhanhq-bundled.json:578`).
- [x] Run the existing `MarginCalculatorContract` before posting to `/margincalculator` so required fields like `transactionType` and `productType` are enforced client-side (`lib/DhanHQ/models/margin.rb:23`, `lib/DhanHQ/contracts/margin_calculator_contract.rb:5`).
- [ ] Validate slice-order payloads with `SliceOrderContract` to uphold STOP_LOSS requirements before calling `/orders/slicing` (`lib/DhanHQ/models/order.rb:217`, `lib/DhanHQ/contracts/slice_order_contract.rb:30`, `/home/nemesis/dhanhq-bundled.json:234`).
- [x] Add a contract-backed validation for `Position.convert` so `PositionConversionRequest` fields like `fromProductType` and `convertQty` are checked prior to hitting `/positions/convert` (`lib/DhanHQ/models/position.rb:39`, `/home/nemesis/dhanhq-bundled.json:1391`).
