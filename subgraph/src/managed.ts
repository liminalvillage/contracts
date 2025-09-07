import { MemberRewarded, RewardDistributed } from "../generated/templates/Managed/Managed"
import { MemberRewarded as MemberRewardedEntity, RewardDistributed as RewardDistributedEntity } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleMemberRewarded(event: MemberRewarded): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let memberReward = new MemberRewardedEntity(id)
  
  memberReward.contractAddress = event.address
  memberReward.recipient = event.params.to
  memberReward.amount = event.params.amount
  memberReward.isContract = event.params.isContract
  memberReward.rewardType = event.params.rewardType
  memberReward.timestamp = event.block.timestamp
  memberReward.blockNumber = event.block.number
  memberReward.txHash = event.transaction.hash
  
  memberReward.save()
}

export function handleRewardDistributed(event: RewardDistributed): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let rewardDistribution = new RewardDistributedEntity(id)
  
  rewardDistribution.contractAddress = event.address
  rewardDistribution.totalAmount = event.params.amount
  rewardDistribution.totalMembers = event.params.totalMembers
  rewardDistribution.rewardType = event.params.rewardType
  rewardDistribution.timestamp = event.block.timestamp
  rewardDistribution.blockNumber = event.block.number
  rewardDistribution.txHash = event.transaction.hash
  
  rewardDistribution.save()
}
