class Comment < ActiveRecord::Base
  attr_accessible :content, :user_id, :tag_list

  belongs_to :user
  has_many :votes
  has_many :taggings, order: 'position'
  has_many :tags, through: :taggings, uniq: true

  validates :content, presence: true
  validates :user_id, presence: true

  before_save :order_taggings

  # Class Methods

  def self.tagged_with tags, opts = {}

    # Build Options
    opts = {
        get_tags: false
    }.merge(opts)

    tag_array = Tag.to_tag_array(tags, opts)

    # Collect all comments
    comments = tag_array.map { |tag| tag.comments }.flatten.uniq

    if opts[:get_tags]
      return comments, tag_array
    else
      comments
    end

  end

  def self.most_recent_tagged_as tag
    tag = tag.name if tag.is_a? Tag
    Comment.tagged_with(tag).last.created_at
  end

  # Tag Methods

  def tag_list
    tags.map(&:name).join(' #')
  end

  def tag_list=list
    self.tags = []
    tag_with list
  end

  def tag_with name
    self.tags << Tag.parse(name).map do |n|
      Tag.where(name: n.strip).first_or_create!
    end
    self.save
  end

  def untag_with name
    delete_tags = Tag.parse(name).map { |n| Tag.where(name: n.strip).first }

    self.taggings.where(:tag_id => delete_tags.map(&:id)).destroy_all
    self.tags.delete_if { |t| delete_tags.include? t }

    # remove unused tags
    delete_tags.each { |tag| tag.destroy if tag.count < 1 }
  end

  # Voting Methods

  def vote_sum
    up_votes.size - down_votes.size
  end

  def up_votes
    votes.where(value: true)
  end

  def down_votes
    votes.where(value: false)
  end

  def up_vote user_id
    vote true, user_id
  end

  def down_vote user_id
    vote false, user_id
  end

  private

  def vote value, user_id
    Vote.create!({value: value, user_id: user_id, comment_id: self.id})
  end

  def order_taggings
    taggings.each_with_index do |t, i|
      t.position = i
    end
  end

end
