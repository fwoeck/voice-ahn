class Skill < Sequel::Model

  many_to_one :user

end
