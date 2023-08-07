# frozen_string_literal: true

class UnreactService < BaseService
  include Payloadable

  def call(account, status, emoji)
    name, domain = emoji.split('@')
    custom_emoji = CustomEmoji.find_by(shortcode: name, domain: domain)
    reaction = StatusReaction.find_by(account: account, status: status, name: name, custom_emoji: custom_emoji)
    # favourite = Favourite.find_by!(account: account, status: status)

    return if reaction.nil?

    # favourite.destroy!
    reaction.destroy!

    json = Oj.dump(serialize_payload(reaction, ActivityPub::UndoEmojiReactionSerializer))
    json = json.gsub("MisskeyReaction", "_misskey_reaction")
    
    if status.account.local?
      ActivityPub::RawDistributionWorker.perform_async(json, status.account.id)
    else
      ActivityPub::DeliveryWorker.perform_async(json, reaction.account_id, status.account.inbox_url)
    end

    reaction
  end
end
