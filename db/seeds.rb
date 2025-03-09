# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Clear existing data
Profile.destroy_all
Experience.destroy_all
Education.destroy_all
Skill.destroy_all
Language.destroy_all

# Create profile
Profile.create!(
  name: "Maxwell Creamer",
  title: "Product Manager / Tech Leader",
  summary: "In my current role, I embrace three pivotal positions that highlight my expertise in technical leadership, product strategy, and global team management: Senior Engineer, Product Manager, and Global Tech Liaison. These roles reflect my dedication to transforming technology through innovative solutions and scalable, impactful content delivery.",
  email: "Max.Creamer93@gmail.com",
  phone: "",
  linkedin: "",
  github: "",
  website: ""
)

# Create experiences
experiences = [
  {
    company: "StrongMind",
    position: "Product Manager",
    start_date: Date.new(2024, 10, 1),
    end_date: nil,
    current: true,
    description: "I strategically integrated advanced AI technologies into user-centric products. My role involved aligning technical solutions with business objectives and user needs, ensuring seamless adoption and impactful outcomes."
  },
  {
    company: "StrongMind",
    position: "Global Tech Liaison",
    start_date: Date.new(2023, 11, 1),
    end_date: nil,
    current: true,
    description: "I bridge global engineering teams across continents, fostering effective communication and harmonizing technical practices. I facilitate cohesive and efficient global collaboration by leveraging diverse talents and perspectives."
  },
  {
    company: "StrongMind",
    position: "Sr Software Engineer",
    start_date: Date.new(2023, 5, 1),
    end_date: nil,
    current: true,
    description: "I spearheaded the development of a sophisticated multi-agent application leveraging multistep prompt chains to deliver dynamic and interactive content. My responsibilities included architecting robust systems, prompt engineering, and optimizing model efficiency and accuracy."
  }
]

experiences.each do |exp|
  Experience.create!(exp)
end

# Create education
educations = [
  {
    institution: "Brigham Young University - Idaho",
    degree: "Bachelor of Engineering",
    field: "Computer Engineering",
    start_date: Date.new(2018, 9, 1),  # Assumed start date
    end_date: Date.new(2022, 5, 31),   # Assumed end date
    gpa: "",
    description: ""
  }
]

educations.each do |edu|
  Education.create!(edu)
end

# Create skills by category
skill_categories = {
  "Technical Skills" => [
    { name: "AI Technologies", proficiency: 5 },
    { name: "Prompt Engineering", proficiency: 5 },
    { name: "Multi-agent Systems", proficiency: 5 },
    { name: "Software Development", proficiency: 5 },
    { name: "Model Optimization", proficiency: 4 }
  ],
  "Management Skills" => [
    { name: "Product Strategy", proficiency: 5 },
    { name: "Global Team Management", proficiency: 5 },
    { name: "Technical Leadership", proficiency: 5 },
    { name: "Cross-functional Collaboration", proficiency: 5 }
  ]
}

skill_categories.each do |category, skills|
  skills.each do |skill|
    Skill.create!(name: skill[:name], proficiency: skill[:proficiency], category: category)
  end
end

# Create languages
languages = [
  { name: "English", proficiency: "Native" },
  { name: "Spanish", proficiency: "Fluent" }
]

languages.each do |language|
  Language.create!(name: language[:name], proficiency: language[:proficiency])
end

puts "Seed data created successfully!"
