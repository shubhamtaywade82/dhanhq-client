# TODO List

- [x] Wire `DhanHQ::Models::Order.place` to the resource’s `create` endpoint so order placement stops raising `NoMethodError` (`lib/DhanHQ/models/order.rb:73`, `lib/DhanHQ/resources/orders.rb:14`).
- [x] Align `Order#cancel` with `DhanHQ::Resources::Orders#cancel` to restore cancellation support (`lib/DhanHQ/models/order.rb:120`, `lib/DhanHQ/resources/orders.rb:26`).
- [x] Rework `Order#modify` to send a proper payload and capture the response instead of delegating to the broken generic update flow (`lib/DhanHQ/models/order.rb:99`, `lib/DhanHQ/core/base_model.rb:155`).
- [x] Repair or replace the shared CRUD helpers in `BaseModel` so URL construction and response handling behave (`lib/DhanHQ/core/base_model.rb:120`, `lib/DhanHQ/core/base_model.rb:129`, `lib/DhanHQ/core/base_model.rb:155`).
- [x] Make `BaseModel#save!` raise a real exception type (e.g. `DhanHQ::Error`) to avoid the current `TypeError` (`lib/DhanHQ/core/base_model.rb:165`).
- [x] Strip read-only attributes before posting modify requests to pass API validation (`lib/DhanHQ/models/order.rb:166`, `lib/DhanHQ/core/base_model.rb:197`).
- [x] Require `fileutils` in the WebSocket singleton lock so acquiring the lock no longer raises (`lib/DhanHQ/ws/singleton_lock.rb:11`).
