FactoryBot.define do
  factory :experience do
    company { "MyString" }
    position { "MyString" }
    start_date { "2025-03-09" }
    end_date { "2025-03-09" }
    current { false }
    description { "MyText" }
  end
end
