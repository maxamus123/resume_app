FactoryBot.define do
  factory :message do
    conversation { nil }
    role { "MyString" }
    content { "MyText" }
  end
end
