class User < Sequel::Model

  one_to_many :roles
  one_to_many :skills
  one_to_many :languages

end
