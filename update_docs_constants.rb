require 'fileutils'

MAP = {
  "BUY" => "DhanHQ::Constants::TransactionType::BUY",
  "SELL" => "DhanHQ::Constants::TransactionType::SELL",
  "NSE_EQ" => "DhanHQ::Constants::ExchangeSegment::NSE_EQ",
  "NSE_FNO" => "DhanHQ::Constants::ExchangeSegment::NSE_FNO",
  "BSE_EQ" => "DhanHQ::Constants::ExchangeSegment::BSE_EQ",
  "IDX_I" => "DhanHQ::Constants::ExchangeSegment::IDX_I",
  "INTRADAY" => "DhanHQ::Constants::ProductType::INTRADAY",
  "MARGIN" => "DhanHQ::Constants::ProductType::MARGIN",
  "CNC" => "DhanHQ::Constants::ProductType::CNC",
  "LIMIT" => "DhanHQ::Constants::OrderType::LIMIT",
  "MARKET" => "DhanHQ::Constants::OrderType::MARKET",
  "STOP_LOSS" => "DhanHQ::Constants::OrderType::STOP_LOSS",
  "DAY" => "DhanHQ::Constants::Validity::DAY",
  "IOC" => "DhanHQ::Constants::Validity::IOC",
  "PENDING" => "DhanHQ::Constants::OrderStatus::PENDING",
  "TRADED" => "DhanHQ::Constants::OrderStatus::TRADED",
  "REJECTED" => "DhanHQ::Constants::OrderStatus::REJECTED",
  "TRANSIT" => "DhanHQ::Constants::OrderStatus::TRANSIT",
  "CANCELLED" => "DhanHQ::Constants::OrderStatus::CANCELLED",
  "INDEX" => "DhanHQ::Constants::InstrumentType::INDEX",
  "EQUITY" => "DhanHQ::Constants::InstrumentType::EQUITY"
}

files = Dir.glob("**/*.md").reject { |f| f.include?("brain") || f == "docs/CONSTANTS_REFERENCE.md" || f == "CHANGELOG.md" }

files.each do |file|
  content = File.read(file)
  
  new_content = content.gsub(/```ruby(.*?)```/m) do |ruby_block|
    modified_block = ruby_block.dup
    
    modified_block.gsub!(/(=>|:|=)\s*"([^"]+)"/) do |match|
      operator = $1
      val = $2
      if MAP.key?(val)
        "#{operator} #{MAP[val]}"
      else
        match
      end
    end
    modified_block
  end
  
  if content != new_content
    puts "Updated #{file}"
    File.write(file, new_content)
  end
end
