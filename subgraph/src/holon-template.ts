import { RewardDistributed as RewardDistributedEvent, MemberRewarded as MemberRewardedEvent } from "../generated/templates/Holon/Managed"
import { RewardDistribution, MemberReward, HolonContract } from "../generated/schema"
import { log } from '@graphprotocol/graph-ts'


export function handleRewardDistributed(event: RewardDistributedEvent): void {

  log.info('====== RewardDistributed Event Received ======', [])
  log.info('Contract Address: {}', [event.address.toHexString()])
  log.info('Transaction Hash: {}', [event.transaction.hash.toHexString()])
  log.info('Block Number: {}', [event.block.number.toString()])
  log.info('Amount: {}', [event.params.amount.toString()])
  log.info('Total Members: {}', [event.params.totalMembers.toString()])
  log.info('Reward Type: {}', [event.params.rewardType])
  let entity = new RewardDistribution(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  
  entity.holon = event.address
  entity.contractAddress = event.params.contractAddress
  entity.amount = event.params.amount
  entity.totalMembers = event.params.totalMembers
  entity.rewardType = event.params.rewardType
  
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash
  log.info('Saving RewardDistribution entity with id: {}', [entity.id.toHexString()])
  entity.save()
}

export function handleMemberRewarded(event: MemberRewardedEvent): void {
  log.info('====== MemberRewarded Event Received ======', [])
  log.info('Contract Address: {}', [event.address.toHexString()])
  log.info('From: {}, To: {}', [event.params.from.toHexString(), event.params.to.toHexString()])
  log.info('Amount: {}', [event.params.amount.toString()])
  log.info('Is Contract: {}', [event.params.isContract ? 'true' : 'false'])
  log.info('Reward Type: {}', [event.params.rewardType])

  let entity = new MemberReward(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  
  entity.holon = event.address
  entity.from = event.params.from
  entity.to = event.params.to
  entity.amount = event.params.amount
  entity.isContract = event.params.isContract
  entity.rewardType = event.params.rewardType
  
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}