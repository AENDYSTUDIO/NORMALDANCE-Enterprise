
import { PubSub } from 'graphql-subscriptions'
import { withFilter } from 'graphql-subscriptions'
import { GraphQLContext } from './types/context'
import { User, Track, NFT, Stake, Playlist, Reward } from './types/user'

// Создаем экземпляр PubSub для управления подписками
const pubsub = new PubSub()

// Топики для подписок
const TOPICS = {
  TRACK_CREATED: 'TRACK_CREATED',
  TRACK_UPDATED: 'TRACK_UPDATED',
  TRACK_DELETED: 'TRACK_DELETED',
  NFT_MINTED: 'NFT_MINTED',
  NFT_PURCHASED: 'NFT_PURCHASED',
  STAKE_CREATED: 'STAKE_CREATED',
  STAKE_UPDATED: 'STAKE_UPDATED',
  STAKE_COMPLETED: 'STAKE_COMPLETED',
  REWARD_CLAIMED: 'REWARD_CLAIMED',
  PLAYLIST_CREATED: 'PLAYLIST_CREATED',
  PLAYLIST_UPDATED: 'PLAYLIST_UPDATED',
  PLAYLIST_DELETED: 'PLAYLIST_DELETED',
  USER_FOLLOWED: 'USER_FOLLOWED',
  USER_UNFOLLOWED: 'USER_UNFOLLOWED',
} as const

// Функция для публикации событий
export const publish = {
  // События треков
  trackCreated: (track: Track) => pubsub.publish(TOPICS.TRACK_CREATED, { trackCreated: track }),
  trackUpdated: (track: Track) => pubsub.publish(TOPICS.TRACK_UPDATED, { trackUpdated: track }),
  trackDeleted: (track: Track) => pubsub.publish(TOPICS.TRACK_DELETED, { trackDeleted: track }),
  
  // События NFT
  nftMinted: (nft: NFT) => pubsub.publish(TOPICS.NFT_MINTED, { nftMinted: nft }),
  nftPurchased: (nft: NFT) => pubsub.publish(TOPICS.NFT_PURCHASED, { nftPurchased: nft }),
  
  // События стейкинга
  stakeCreated: (stake: Stake) => pubsub.publish(TOPICS.STAKE_CREATED, { stakeCreated: stake }),
  stakeUpdated: (stake: Stake) => pubsub.publish(TOPICS.STAKE_UPDATED, { stakeUpdated: stake }),
  stakeCompleted: (stake: Stake) => pubsub.publish(TOPICS.STAKE_COMPLETED, { stakeCompleted: stake }),
  
  // События вознаграждений
  rewardClaimed: (reward: Reward) => pubsub.publish(TOPICS.REWARD_CLAIMED, { rewardClaimed: reward }),
  
  // События плейлистов
  playlistCreated: (playlist: Playlist) => pubsub.publish(TOPICS.PLAYLIST_CREATED, { playlistCreated: playlist }),
  playlistUpdated: (playlist: Playlist) => pubsub.publish(TOPICS.PLAYLIST_UPDATED, { playlistUpdated: playlist }),
  playlistDeleted: (playlist: Playlist) => pubsub.publish(TOPICS.PLAYLIST_DELETED, { playlistDeleted: playlist }),
  
  // События пользователей
  userFollowed: (follower: User, followed: User) => pubsub.publish(TOPICS.USER_FOLLOWED, { userFollowed: { follower, followed } }),
  userUnfollowed: (follower: User, followed: User) => pubsub.publish(TOPICS.USER_UNFOLLOWED, { userUnfollowed: { follower, followed } }),
}

// Резолверы подписок
export const subscriptionResolvers = {
  Subscription: {
    // Подписки на треки
    trackCreated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([TOPICS.TRACK_CREATED]),
        (payload: { trackCreated: Track }, variables: any, context: GraphQLContext) => {
          // Можно добавить фильтрацию по жанрам, артистам и т.д.
          return true
        }
      ),
    },
    trackUpdated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([TOPICS.TRACK_UPDATED]),
        (payload: { trackUpdated: Track }, variables: any, context: GraphQLContext) => {
          // Фильтрация по ID трека, если указан
          return !variables.trackId || payload.trackUpdated.id === variables.trackId
        }
      ),
    },
    trackDeleted: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([TOPICS.TRACK_DELETED]),
        (payload: { trackDeleted: Track }, variables: any, context: GraphQLContext) => {
          // Фильтрация по ID трека, если указан
          return !variables.trackId || payload.trackDeleted.id === variables.trackId
        }
      ),
    },
    
    // Подписки на NFT
    nftMinted: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([TOPICS.NFT_MINTED]),
        (payload: { nftMinted: NFT }, variables: any, context: GraphQLContext) => {
          // Фильтрация по типу NFT или артисту
          return !variables.type || payload.nftMinted.type === variables.type
        }
      ),
    },
    nftPurchased: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([TOPICS.NFT_PURCHASED]),
        (payload: { nftPurchased: NFT }, variables: any, context: GraphQLContext) => {
          // Фильтрация по ID NFT или владельцу
          return (!variables.nftId || payload.nftPurchased.id === variables.nftId) ||
                 (!variables.ownerId || payload.nftPurchased.ownerId === variables.ownerId)
        }
      ),
    },
    
    // Подписки на стейкинг
