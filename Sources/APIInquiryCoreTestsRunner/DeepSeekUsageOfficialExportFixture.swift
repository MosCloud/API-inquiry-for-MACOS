import Foundation

enum DeepSeekUsageOfficialExportFixture {
    static let sourceFileName = "usage_data_2026_4.zip"
    static let importedAt = Date(timeIntervalSince1970: 1_716_000_000)

    static let costCSV = """
    ﻿user_id,utc_date,model,wallet_type,cost,currency
    00000000-0000-4000-8000-000000000000,2026-04-27,deepseek-v4-flash,Paid,0.0546390000000000,CNY
    00000000-0000-4000-8000-000000000000,2026-04-28,deepseek-v4-flash,Paid,0.0397800000000000,CNY
    00000000-0000-4000-8000-000000000000,2026-04-29,deepseek-v4-flash,Paid,0.0000070000000000,CNY
    00000000-0000-4000-8000-000000000000,2026-04-30,deepseek-v4-flash,Paid,3.5530180000000000,CNY
    """

    static let amountCSV = """
    ﻿user_id,utc_date,model,api_key_name,api_key,type,price,amount
    00000000-0000-4000-8000-000000000000,2026-04-27,deepseek-v4-flash,key-a,sk-test***********************0001,output_tokens,0.000002,1110
    00000000-0000-4000-8000-000000000000,2026-04-27,deepseek-v4-flash,key-a,sk-test***********************0001,request_count,,3
    00000000-0000-4000-8000-000000000000,2026-04-27,deepseek-v4-flash,key-a,sk-test***********************0001,input_cache_miss_tokens,0.000001,52419
    00000000-0000-4000-8000-000000000000,2026-04-28,deepseek-v4-flash,key-b,sk-test***********************0002,output_tokens,0.000002,201
    00000000-0000-4000-8000-000000000000,2026-04-28,deepseek-v4-flash,key-b,sk-test***********************0002,request_count,,3
    00000000-0000-4000-8000-000000000000,2026-04-28,deepseek-v4-flash,key-b,sk-test***********************0002,input_cache_miss_tokens,0.000001,39378
    00000000-0000-4000-8000-000000000000,2026-04-29,deepseek-v4-flash,key-b,sk-test***********************0002,output_tokens,0.000002,1
    00000000-0000-4000-8000-000000000000,2026-04-29,deepseek-v4-flash,key-b,sk-test***********************0002,request_count,,1
    00000000-0000-4000-8000-000000000000,2026-04-29,deepseek-v4-flash,key-b,sk-test***********************0002,input_cache_miss_tokens,0.000001,5
    00000000-0000-4000-8000-000000000000,2026-04-30,deepseek-v4-flash,key-b,sk-test***********************0002,output_tokens,0.000002,299034
    00000000-0000-4000-8000-000000000000,2026-04-30,deepseek-v4-flash,key-b,sk-test***********************0002,request_count,,917
    00000000-0000-4000-8000-000000000000,2026-04-30,deepseek-v4-flash,key-b,sk-test***********************0002,input_cache_hit_tokens,0.00000002,45372800
    00000000-0000-4000-8000-000000000000,2026-04-30,deepseek-v4-flash,key-b,sk-test***********************0002,input_cache_miss_tokens,0.000001,2047494
    """

    static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
