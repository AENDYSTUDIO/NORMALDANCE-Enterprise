import { Field, ID, ObjectType, registerEnumType } from 'type-graphql'

// Регистрация перечислений
registerEnumType(UserLevel, {
  name: 'UserLevel'
})

registerEnumType(UserRole, {
  name: 'UserRole'
})

export enum UserLevel {
  BRONZE = 'BRONZE',
  SILVER = 'SILVER',
  GOLD = 'GOLD',
  PLATINUM = 'PLATINUM'
}

export enum UserRole {
  LISTENER = 'LISTENER',
  ARTIST = 'ARTIST',
  CURATOR = 'CURATOR',
  ADMIN = 'ADMIN'
}

@ObjectType()
export class User {
  @Field(() => ID)
  id: string

  @Field()
  email: string

  @Field()
  username: string

  @Field({ nullable: true })
  displayName?: string

  @Field({ nullable: true })
  bio?: string

  @Field({ nullable: true })
  avatar?: string

  @Field({ nullable: true })
  banner?: string

  @Field()
  wallet?: string

  @Field(() => UserLevel)
  level: UserLevel

  @Field()
  balance: number

  @Field(() => UserRole)
  role: UserRole

  @Field()
  isActive: boolean

  @Field(() => Date)
  createdAt: Date

  @Field(() => Date)
  updatedAt: Date

  // Relations
  @Field(() => [Track], { nullable: true })
  tracks?: Track[]

  @Field(() => [Playlist], { nullable: true })
  playlists?: Playlist[]

  @Field(() => [Like], { nullable: true })
  likes?: Like[]

  @Field(() => [Comment], { nullable: true })
  comments?: Comment[]

  @Field(() => [Reward], { nullable: true })
  rewards?: Reward[]

  @Field(() => [User], { nullable: true })
  followers?: User[]

  @Field(() => [User], { nullable: true })
  following?: User[]

  @Field(() => [PlayHistory], { nullable: true })
  playHistory?: PlayHistory[]

  @Field(() => [NFT], { nullable: true })
  nfts?: NFT[]

  @Field(() => [Purchase], { nullable: true })
  purchases?: Purchase[]

  @Field(() => [Stake], { nullable: true })
  stakes?: Stake[]

  // Counts
  @Field({ nullable: true })
  trackCount?: number

  @Field({ nullable: true })
  playlistCount?: number

  @Field({ nullable: true })
  followerCount?: number

  @Field({ nullable: true })
  followingCount?: number

  @Field({ nullable: true })
  likeCount?: number

  @Field({ nullable: true })
  commentCount?: number

  // Stats
  @Field({ nullable: true })
  totalEarnings?: number

  @Field({ nullable: true })
  totalPlays?: number
}

// Импортируем остальные типы (в реальном проекте они бы были в своих файлах)
import { Track } from './track'
import { Playlist } from './playlist'
import { Like } from './like'
import { Comment } from './comment'
import { Reward } from './reward'
import { PlayHistory } from './play-history'
import { NFT } from './nft'
import { Purchase } from './purchase'
import { Stake } from './stake'