import { ZonedContractCreated } from "../generated/ZonedFactory/ZonedFactory"
import { Zoned, ZonedFactory, Splitter } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"
import { Zoned as ZonedTemplate } from "../generated/templates"

export function handleZonedContractCreated(event: ZonedContractCreated): void {
  let zoned = new Zoned(event.params.contractAddress.toHexString())
  zoned.name = event.params.name
  zoned.address = event.params.contractAddress
  zoned.creatorUserId = event.params.creatorUserId.toString()
  zoned.creator = event.transaction.from
  zoned.parameter = event.params.parameter
  zoned.createdAt = event.block.timestamp
  zoned.blockNumber = event.block.number
  zoned.txHash = event.transaction.hash
  
  // Find the parent splitter that created this zoned holon
  // The splitter is the transaction sender (msg.sender)
  let parentSplitter = Splitter.load(event.transaction.from.toHexString())
  if (parentSplitter != null) {
    // Link the zoned holon to its parent splitter
    parentSplitter.zonedHolon = zoned.id
    parentSplitter.save()
    
    // Link the zoned holon to its parent splitter
    zoned.parentSplitter = parentSplitter.id
  }
  
  // Update factory stats
  let factory = ZonedFactory.load(event.address.toHexString())
  if (factory == null) {
    factory = new ZonedFactory(event.address.toHexString())
    factory.totalZoned = BigInt.fromI32(0)
    factory.createdAt = event.block.timestamp
  }
  factory.totalZoned = factory.totalZoned.plus(BigInt.fromI32(1))
  
  ZonedTemplate.create(event.params.contractAddress)
  zoned.save()
  factory.save()
}